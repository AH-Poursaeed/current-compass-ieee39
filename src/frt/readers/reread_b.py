#!/usr/bin/env python3
"""RE-READ B (CURRENTS, VOLTAGES AND POWERS) of its sealed rule (sha256
d44ee4ef...) with addendum 1 (eec6c94e...) and addendum 2 (9092b672...). One CSV line per archive. Reads only.

W = the fine samples with t_on + 0.020 <= t <= t_off - 0.005 (inclusive); means over W are arithmetic means.
G = the reader of record's set (map_reader.gfm_set, imported).
B1: e_k = i_k / I_m,k - 1 on the samples of W where satf_k > 0.5 (addendum 2, 3.); i_k the inductor current
    |tap iL| on tapped rows (no suffix) and the output current |(idf, iqf)| on every row (suffix _io, addendum 1);
    I_m,k = iLimPu (2/3) Srated_k / Vpk0_k, Vpk0_k = sqrt(2/3) Vbase Vref(bus_k), the builder's Imax of the row's
    own load flow (the model's converter layer; addendum 2). Per row EMED, EP95, EMAX, EMIN, NS, NPOS (e > +0.05),
    NNEG (e < -0.05). Instrument check on tapped rows: IMCHK = max |hypot(lim_d, lim_q)/I_m,k - 1| on those samples.
B2: VFAULT, VGFM, VALL (fine Vfpu over W); T_V (record Vpu, samples with t > t_off, band 0.90 to 1.10 pu).
B3: PF, QF = means over W of the sums over G of Pf, Qf, in MW and Mvar.
B4 (tapped rows): per unit of G and saturated interval (satf > 0.5) inside W, the range of unwrap(atan2(raw_q,
    raw_d)) in deg; PHIR the largest, PHIM the median, NINT the number of intervals.
--b5: the band after clearing (addendum 2, 5.) on named rows: DFT of the fine samples in (t_off, t_off + 0.15],
    mean removed, no window, no detrend; the largest line above 20 Hz, its frequency and 4|X|/N; for the sum over G
    of Pf and for each unit's |io| (and |iL| where the row has taps).
"""
import argparse
import csv
import math
import os
import sys

import h5py
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import map_reader as MR  # noqa: E402

COLS = ['tag', 'status', 'reason', 'ftype', 'bus', 'dur_s', 'load', 'net', 'G', 'taps', 'nW',
        'EMED', 'EP95', 'EMAX', 'EMIN', 'NS', 'NPOS', 'NNEG', 'IMCHK', 'IMCHK_N',
        'EMED_io', 'EP95_io', 'EMAX_io', 'EMIN_io', 'NS_io', 'NPOS_io', 'NNEG_io',
        'VFAULT', 'VGFM', 'VALL', 'T_V', 'PF', 'QF', 'PF_trapz',
        'PHIR', 'PHIM', 'NINT', 'Im_A']


def fm(x, nd=7):
    if x is None:
        return 'na'
    if isinstance(x, str):
        return x
    if not math.isfinite(x):
        return 'na'
    return ('%.' + str(nd) + 'g') % x


def runs(mask):
    """(start, stop) index pairs of the True runs of a 1-D boolean array (stop exclusive)."""
    m = np.concatenate([[False], mask, [False]])
    d = np.diff(m.astype(int))
    return list(zip(np.where(d == 1)[0], np.where(d == -1)[0]))


def stats(e):
    if e.size == 0:
        return dict(EMED=float('nan'), EP95=float('nan'), EMAX=float('nan'), EMIN=float('nan'), NS=0, NPOS=0, NNEG=0)
    return dict(EMED=float(np.median(e)), EP95=float(np.percentile(e, 95)), EMAX=float(np.max(e)),
                EMIN=float(np.min(e)), NS=int(e.size), NPOS=int(np.sum(e > 0.05)), NNEG=int(np.sum(e < -0.05)))


def common(A):
    t_on = MR.num(A, 'fault/t_on')
    t_off = MR.num(A, 'fault/t_off')
    tf = MR.arr(A, 'tf').ravel()
    ibr = MR.arr(A, 'IBR_data')
    g = MR.gfm_set(ibr, A)
    sb = MR.num(A, 'Sbase', 1e8)
    busu = [int(round(x)) for x in MR.arr(A, 'bus').ravel()]
    vref = MR.arr(A, 'Vref').ravel()
    v1 = float(A['Vf'][busu[g[0]] - 1, 0])
    v2 = float(A['Vfpu'][busu[g[0]] - 1, 0])
    vbase = math.sqrt(3.0) * v1 / v2
    ilim = MR.num(A, 'conv/iLimPu', 1.25)
    imax = {}
    for k in g:
        sr = ibr[8, k] * sb
        vpk0 = math.sqrt(2.0 / 3.0) * vbase * vref[busu[k] - 1]
        imax[k] = ilim * (2.0 / 3.0) * sr / vpk0
    taps = {}
    if 'tap' in A and 'units' in A['tap']:
        tu = [int(round(x)) for x in np.array(A['tap/units']).ravel()]
        for j, u in enumerate(tu):
            taps[u - 1] = j
    return t_on, t_off, tf, ibr, g, sb, busu, vref, vbase, imax, taps


def read_one(path):
    tag = MR.tag_of(path)
    r = {c: 'na' for c in COLS}
    r['tag'] = tag
    with h5py.File(path, 'r') as f:
        A = f['A']
        if not MR.num(A, 'ok', 0.0) > 0.5:
            r['status'] = 'NOTOK'
            r['reason'] = 'A.ok false (stopped %s)' % ('y' if MR.num(A, 'stopped', 0.0) > 0.5 else 'n')
            return r
        t_on, t_off, tf, ibr, g, sb, busu, vref, vbase, imax, taps = common(A)
        bus = int(round(MR.num(A, 'fault/bus', 0.0)))
        if bus <= 0:
            r['status'] = 'UNREAD'
            r['reason'] = 'no fault bus in the archive'
            return r
        ft = MR.txt(A, 'fault/type')
        r['ftype'] = ft if ft else '3ph'
        r['bus'] = str(bus)
        r['dur_s'] = fm(t_off - t_on, 6)
        r['load'] = fm(MR.num(A, 'conv/sens/loadScale', 1.0), 4)
        r['net'] = MR.net_state(A).replace(',', ';')
        r['G'] = ' '.join(str(k + 1) for k in g)
        hasTap = all(k in taps for k in g) and len(taps) > 0
        r['taps'] = 'y' if hasTap else 'n'
        W = (tf >= t_on + 0.020 - 1e-9) & (tf <= t_off - 0.005 + 1e-9)
        iW = np.where(W)[0]
        r['nW'] = str(iW.size)
        lo, hi = int(iW[0]), int(iW[-1]) + 1
        satf = MR.rows(A, 'satf', g)[:, lo:hi] > 0.5
        idf = MR.rows(A, 'idf', g)[:, lo:hi]
        iqf = MR.rows(A, 'iqf', g)[:, lo:hi]
        r['Im_A'] = ' '.join('%.6g' % imax[k] for k in g)
        # ---- B1 on the output current (every row) ----------------------------
        e_io = np.concatenate([np.hypot(idf[j], iqf[j])[satf[j]] / imax[k] - 1.0 for j, k in enumerate(g)])
        for kk, vv in stats(e_io).items():
            r[kk + '_io'] = fm(vv) if isinstance(vv, float) else str(vv)
        # ---- B1 on the inductor current, B4 (tapped rows) ----------------------
        if hasTap:
            tj = [taps[k] for k in g]
            ild = np.array(A['tap/iL_d'][tj, lo:hi], dtype=float)
            ilq = np.array(A['tap/iL_q'][tj, lo:hi], dtype=float)
            lmd = np.array(A['tap/lim_d'][tj, lo:hi], dtype=float)
            lmq = np.array(A['tap/lim_q'][tj, lo:hi], dtype=float)
            rwd = np.array(A['tap/raw_d'][tj, lo:hi], dtype=float)
            rwq = np.array(A['tap/raw_q'][tj, lo:hi], dtype=float)
            e_il = np.concatenate([np.hypot(ild[j], ilq[j])[satf[j]] / imax[k] - 1.0 for j, k in enumerate(g)])
            for kk, vv in stats(e_il).items():
                r[kk] = fm(vv) if isinstance(vv, float) else str(vv)
            chk = [np.abs(np.hypot(lmd[j], lmq[j])[satf[j]] / imax[k] - 1.0) for j, k in enumerate(g)]
            chk = np.concatenate(chk)
            r['IMCHK'] = fm(float(chk.max())) if chk.size else 'na'
            r['IMCHK_N'] = str(int(np.sum(chk > 1e-6)))
            rng = []
            for j in range(len(g)):
                ph = np.arctan2(rwq[j], rwd[j])
                for a, b in runs(satf[j]):
                    seg = np.unwrap(ph[a:b])
                    rng.append(math.degrees(float(seg.max() - seg.min())))
            r['NINT'] = str(len(rng))
            if rng:
                r['PHIR'] = fm(max(rng))
                r['PHIM'] = fm(float(np.median(rng)))
        # ---- B2 voltages -------------------------------------------------------
        vfa = MR.rows(A, 'Vfpu', [bus - 1])[0, lo:hi]
        r['VFAULT'] = fm(float(np.mean(vfa)))
        gb = [busu[k] - 1 for k in g]
        r['VGFM'] = fm(float(np.mean(MR.rows(A, 'Vfpu', gb)[:, lo:hi])))
        r['VALL'] = fm(float(np.mean(np.array(A['Vfpu'][:, lo:hi], dtype=float))))
        t = MR.arr(A, 't').ravel()
        vpu = MR.arr(A, 'Vpu')
        last = np.where(np.all(np.isfinite(vpu), axis=0))[0][-1]
        t, vpu = t[:last + 1], vpu[:, :last + 1]
        post = t > t_off
        out = np.any((vpu < 0.90) | (vpu > 1.10), axis=0) & post
        if out[-1]:
            r['T_V'] = 'at the end'
        elif out.any():
            r['T_V'] = fm(float(t[np.where(out)[0][-1]] - t_off))
        else:
            r['T_V'] = '0'
        # ---- B3 powers ---------------------------------------------------------
        pf = MR.rows(A, 'Pf', g)[:, lo:hi]
        qf = MR.rows(A, 'Qf', g)[:, lo:hi]
        ps = pf.sum(axis=0) / 1e6
        r['PF'] = fm(float(np.mean(ps)))
        r['QF'] = fm(float(np.mean(qf.sum(axis=0) / 1e6)))
        tw = tf[lo:hi]
        r['PF_trapz'] = fm(MR.trapz(ps, tw) / (tw[-1] - tw[0]))
    r['status'] = 'OK'
    return r


def b5_one(path, out):
    tag = MR.tag_of(path)
    with h5py.File(path, 'r') as f:
        A = f['A']
        t_on, t_off, tf, ibr, g, sb, busu, vref, vbase, imax, taps = common(A)
        sel = (tf > t_off + 1e-9) & (tf <= t_off + 0.15 + 1e-9)
        idx = np.where(sel)[0]
        dt = float(np.median(np.diff(tf)))
        sig = {'sumPf_MW': MR.rows(A, 'Pf', g)[:, idx].sum(axis=0) / 1e6}
        idf = MR.rows(A, 'idf', g)[:, idx]
        iqf = MR.rows(A, 'iqf', g)[:, idx]
        for j, k in enumerate(g):
            sig['io_u%d_A' % (k + 1)] = np.hypot(idf[j], iqf[j])
        if all(k in taps for k in g) and taps:
            for k in g:
                j = taps[k]
                sig['iL_u%d_A' % (k + 1)] = np.hypot(np.array(A['tap/iL_d'][j, idx]), np.array(A['tap/iL_q'][j, idx]))
    n = idx.size
    for name, x in sig.items():
        X = np.fft.rfft(x - np.mean(x))
        fr = np.fft.rfftfreq(n, dt)
        m = fr > 20.0 + 1e-6      # strictly above 20 Hz (the 20 Hz bin itself is not above it)
        i = int(np.argmax(np.where(m, np.abs(X), -1.0)))
        out.writerow([tag, name, n, '%.6g' % dt, '%.6g' % fr[i], '%.6g' % (4.0 * abs(X[i]) / n),
                      '%.6g' % (fr[1] - fr[0])])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--list', required=True)
    ap.add_argument('--reports', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--slice', default='0/1')
    ap.add_argument('--b5', action='store_true')
    a = ap.parse_args()
    tags = [x.strip() for x in open(a.list) if x.strip()]
    i, n = (int(x) for x in a.slice.split('/'))
    mine = tags[i::n]
    with open(a.out, 'w', newline='') as fo:
        w = csv.writer(fo, lineterminator='\n')
        if a.b5:
            w.writerow(['tag', 'signal', 'N', 'dt_s', 'line_Hz', 'pp', 'resolution_Hz'])
            for tg in mine:
                b5_one(os.path.join(a.reports, 'case_frt_%s.mat' % tg), w)
            print('=== DONE reread_b --b5 %d rows' % len(mine))
            return
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
    print('=== DONE reread_b %d rows' % len(mine))


if __name__ == '__main__':
    main()
