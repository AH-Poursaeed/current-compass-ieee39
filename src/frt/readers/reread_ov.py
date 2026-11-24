#!/usr/bin/env python3
"""RE-READ OV, THE VOLTAGE AFTER CLEARING, of its sealed rule (sha256
f3a7a4ca...). One CSV line per archive. Reads only.

The channel is the fine bus-voltage magnitude Vfpu (pu) of re-read B2, at every bus, on the fine window; "after
clearing" is t > fault/t_off (strict, as T_EXIT and B5 of the rule AB). G and the terminal buses of G are those of
re-read B (reread_b.common, which takes G from the reader of record map_reader.gfm_set): bus_k = A.bus(k).
 OV1 VPK_G: the largest Vfpu over the terminal buses of G and over the fine samples after clearing, with its bus and
     its time after clearing; VPK_ALL: the same over all 39 buses.
 OV2 T110, T120, T130, T150: the total time after clearing during which the largest Vfpu over the terminal buses of G
     exceeds 1.10, 1.20, 1.30, 1.50 pu: the sum of the sample intervals of the exceeding samples (each sample's
     interval is its forward step tf(i+1) - tf(i); the last sample's is the median step).
 OV3 VCYC_G: the largest value after clearing (t > t_off) of the one-cycle moving mean of each terminal bus's Vfpu over
     the whole fine window, over the buses of G; the mean is the reader of record's one-cycle averaging
     (map_reader.movmean_shrink, centred, shrinking ends, window round(1/(Fref dt)) samples).
 OV4 VPK_ON: the largest Vfpu over the terminal buses of G on the fault-on window W of the rule AB
     (t_on + 0.020 <= t <= t_off - 0.005, inclusive).
 OV5 PSI_OFF (tapped rows of the codes v, z, u1): psi = -tap/dphi of the unit of G whose terminal bus is VPK_G's bus,
     at the last fine sample before clearing (t < t_off), the sample of the census D5.
Usage: python3 reread_ov.py --list tags --reports dir --out file.csv [--slice i/n]"""
import argparse
import csv
import math
import os
import re
import sys

import h5py
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import map_reader as MR  # noqa: E402  (the reader of record, hash asserted by the job)
import reread_b as RB  # noqa: E402  (re-read B, hash asserted by the job: G, the buses, the taps)

LEVELS = (1.10, 1.20, 1.30, 1.50)
PSI_CODES = ('v', 'z', 'u1')
TAG = re.compile(r'^(?:N?F?M[A-Z]|LRF)([a-z][0-9]{0,2})(\d\d)_(\d{4})_(\d\d)([TS])(\w+)$')
COLS = ['tag', 'status', 'reason', 'code', 'ftype', 'dur_s', 'G', 'G_buses', 'taps', 'n_post', 'dt', 'dt_dev',
        'VPK_G', 'VPK_G_bus', 'VPK_G_t', 'VPK_ALL', 'VPK_ALL_bus', 'VPK_ALL_t',
        'T110', 'T120', 'T130', 'T150', 'VCYC_G', 'VCYC_G_bus', 'VCYC_G_t', 'wc', 'VPK_ON', 'nW',
        'PSI_OFF', 'PSI_unit', 'nonfinite']


def fm(x, nd=7):
    if x is None:
        return 'na'
    if isinstance(x, str):
        return x
    if not math.isfinite(x):
        return 'na'
    return ('%.' + str(nd) + 'g') % x


def read_one(path):
    tag = MR.tag_of(path)
    r = {c: 'na' for c in COLS}
    r['tag'] = tag
    m = TAG.match(tag)
    code = m.group(1) if m else 'na'
    r['code'] = code
    with h5py.File(path, 'r') as f:
        A = f['A']
        if not MR.num(A, 'ok', 0.0) > 0.5:
            r['status'] = 'NOTOK'
            r['reason'] = 'A.ok false (stopped %s)' % ('y' if MR.num(A, 'stopped', 0.0) > 0.5 else 'n')
            return r
        t_on, t_off, tf, ibr, g, sb, busu, vref, vbase, imax, taps = RB.common(A)
        ft = MR.txt(A, 'fault/type')
        r['ftype'] = ft if ft else '3ph'
        r['dur_s'] = fm(t_off - t_on, 6)
        r['G'] = ' '.join(str(k + 1) for k in g)
        gb = [busu[k] - 1 for k in g]
        r['G_buses'] = ' '.join(str(b + 1) for b in gb)
        hasTap = len(taps) > 0 and all(k in taps for k in g)
        r['taps'] = 'y' if hasTap else 'n'
        V = np.array(A['Vfpu'][:, :], dtype=float)          # 39 buses x fine samples
        r['nonfinite'] = str(int((~np.isfinite(V)).sum()))
        steps = np.diff(tf)
        dt = float(np.median(steps))
        r['dt'] = fm(dt)
        post = tf > t_off
        ip = np.where(post)[0]
        r['n_post'] = str(ip.size)
        r['dt_dev'] = fm(float(np.max(np.abs(steps[ip[0] - 1:] - dt))) if ip.size else None)
        fwd = np.append(steps, dt)                             # forward step of each sample; the last: the median
        vg = V[gb, :]
        mg = np.max(vg, axis=0)                                # the largest over the terminal buses of G
        # OV1
        i = ip[int(np.argmax(mg[ip]))]
        r['VPK_G'] = fm(float(mg[i]))
        r['VPK_G_bus'] = str(gb[int(np.argmax(vg[:, i]))] + 1)
        r['VPK_G_t'] = fm(float(tf[i] - t_off))
        ma = np.max(V, axis=0)
        ia = ip[int(np.argmax(ma[ip]))]
        r['VPK_ALL'] = fm(float(ma[ia]))
        r['VPK_ALL_bus'] = str(int(np.argmax(V[:, ia])) + 1)
        r['VPK_ALL_t'] = fm(float(tf[ia] - t_off))
        # OV2
        for lv in LEVELS:
            r['T%d' % int(round(lv * 100))] = fm(float(np.sum(fwd[ip][mg[ip] > lv])))
        # OV3
        fref = MR.num(A, 'Fref', 60.0)
        wc = int(round(1.0 / (fref * dt)))
        r['wc'] = str(wc)
        mm = MR.movmean_shrink(vg, wc)
        mmp = mm[:, ip]
        jb, jt = np.unravel_index(int(np.nanargmax(mmp)), mmp.shape)
        r['VCYC_G'] = fm(float(mmp[jb, jt]))
        r['VCYC_G_bus'] = str(gb[jb] + 1)
        r['VCYC_G_t'] = fm(float(tf[ip[jt]] - t_off))
        # OV4
        W = (tf >= t_on + 0.020 - 1e-9) & (tf <= t_off - 0.005 + 1e-9)
        r['nW'] = str(int(W.sum()))
        r['VPK_ON'] = fm(float(np.max(mg[W]))) if W.any() else 'na'
        # OV5
        if hasTap and code in PSI_CODES:
            ib = int(np.where(tf < t_off - 1e-9)[0][-1])
            kb = [k for k in g if busu[k] == int(r['VPK_G_bus'])]
            if len(kb) == 1:
                k = kb[0]
                r['PSI_OFF'] = fm(-float(A['tap/dphi'][taps[k], ib]))
                r['PSI_unit'] = str(k + 1)
    r['status'] = 'OK'
    return r


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--list', required=True)
    ap.add_argument('--reports', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--slice', default='0/1')
    a = ap.parse_args()
    tags = [x.strip() for x in open(a.list) if x.strip()]
    i, n = (int(x) for x in a.slice.split('/'))
    mine = tags[i::n]
    with open(a.out, 'w', newline='') as fo:
        w = csv.writer(fo, lineterminator='\n')
        w.writerow(COLS)
        for tg in mine:
            p = os.path.join(a.reports, 'case_frt_%s.mat' % tg)
            if not os.path.isfile(p):
                r = {c: 'na' for c in COLS}
                r['tag'], r['status'], r['reason'] = tg, 'MISSING', 'no archive'
            else:
                try:
                    r = read_one(p)
                except Exception as exc:  # noqa: BLE001
                    r = {c: 'na' for c in COLS}
                    r['tag'], r['status'] = tg, 'READ FAILED'
                    r['reason'] = ('%s: %s' % (type(exc).__name__, exc))[:200].replace(',', ';')
            w.writerow([r[c] for c in COLS])
            fo.flush()
    print('=== DONE reread_ov %d rows' % len(mine))


if __name__ == '__main__':
    main()
