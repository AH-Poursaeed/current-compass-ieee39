#!/usr/bin/env python3
"""RE-READ A (REST) of its sealed rule (sha256 d44ee4ef...) with addendum 1
(eec6c94e...). One CSV line per archive. Reads only.

The set G, the relative angle, the one-cycle averaging of unbalanced rows, the verdict, the return time T_RET and the
largest swing SWING are those of the reader of record map_reader.py (sha256 1973dbe1..., imported, not re-written):
T_RET = its t_ret_s, SWING = its fine_maxRel_deg, the verdict its verdict.

A1 DRIFT, OSC (last 3.0 s of the record, rel from map_reader.record_read); A2 RELF, BANDEND; A3 T_EXIT (fine window
after clearing, then the record beyond the fine window; on unbalanced rows the fine frequencies averaged over one cycle
as the reader of record averages them: question Q1 to the decider) and T_EXIT_RAW (raw fine frequencies; carried, not
tabulated unless ruled); A4 SATEND (addendum 1 item 3: record sat > 0 at any sample of the last 1.0 s); A5 SWINGV (the
terminal-voltage angle dthf + unwrap(atan2(vqf, vdf)), averaged over one cycle on unbalanced rows; question Q2) beside
SWING. The rest condition: RETURNS and DRIFT <= 0.5 deg/s and RELF <= 0.0015 Hz and BANDEND <= 0.05 Hz.
"""
import argparse
import csv
import math
import os
import sys

import h5py
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import map_reader as MR  # noqa: E402  (the reader of record, hash asserted by the job)

BAND = MR.BAND_HZ            # 0.05 Hz
LAST_S = 3.0                 # A1, A2: the last 3.0 s of the record
SAT_S = 1.0                  # A4: the last 1.0 s of the record
REST_DRIFT = 0.5             # deg/s
REST_RELF = 0.0015           # Hz
REST_BAND = 0.05             # Hz

COLS = ['tag', 'status', 'reason', 'ftype', 'bus', 'dur_s', 'load', 'net', 'gfm_wd', 'G', 'rec_after_s', 'fine_after_s',
        'verdict', 'basis', 'settled', 'T_RET', 'SWING', 'vflags',
        'DRIFT', 'DRIFT_unit', 'OSC', 'RELF', 'RELF_unit', 'BANDEND', 'n_last',
        'T_EXIT', 'T_EXIT_src', 'T_EXIT_RAW', 'T_EXIT_RAW_src', 'SATEND', 'SATEND_units',
        'SWINGV', 'SWING_mine', 'V_WRAPS', 'V_LEFTOUT', 'V_LEFTOUT_SAMPLES', 'REST']


def fm(x, nd=6):
    if x is None:
        return 'na'
    if isinstance(x, str):
        return x
    if not math.isfinite(x):
        return 'na'
    return ('%.' + str(nd) + 'g') % x


def last_exit(tf, fcf, t_off, t, fc, fref):
    """The last instant after clearing with any converter outside 60 +/- 0.05 Hz: the fine samples after clearing,
    then the record samples beyond the fine window (map_reader's t_retu_s pattern). Returns (value, source)."""
    with np.errstate(invalid='ignore'):
        pf = tf > t_off
        badf = np.any(np.abs(fcf[:, pf] - fref) > BAND, axis=0)
        beyond = t > tf[-1]
        badr = np.any(np.abs(fc[:, beyond] - fref) > BAND, axis=0)
        end_out = bool(np.any(np.abs(fc[:, -1] - fref) > BAND))
    if end_out:
        return float('inf'), 'at the end'
    if badr.any():
        return float(t[beyond][np.where(badr)[0][-1]] - t_off), 'record'
    if badf.any():
        return float(tf[pf][np.where(badf)[0][-1]] - t_off), 'fine'
    return 0.0, 'none'


def read_one(path):
    tag = MR.tag_of(path)
    r = {c: 'na' for c in COLS}
    r['tag'] = tag
    with h5py.File(path, 'r') as f:
        A = f['A']
        ok = MR.num(A, 'ok', 0.0) > 0.5
        if not ok:
            r['status'] = 'NOTOK'
            r['reason'] = 'A.ok false (stopped %s)' % ('y' if MR.num(A, 'stopped', 0.0) > 0.5 else 'n')
            return r
    row, why = MR.read_row(path, os.path.dirname(path), {})
    if row is None:
        r['status'] = 'UNREAD'
        r['reason'] = 'map_reader: ' + str(why)
        return r
    for c_src, c_dst in (('ftype', 'ftype'), ('bus', 'bus'), ('dur_s', 'dur_s'), ('load', 'load'), ('net', 'net'),
                         ('gfm_wd', 'gfm_wd'), ('rec_after_s', 'rec_after_s'), ('fine_after_s', 'fine_after_s'),
                         ('verdict', 'verdict'), ('basis', 'basis'), ('settled', 'settled'), ('t_ret_s', 'T_RET'),
                         ('fine_maxRel_deg', 'SWING'), ('vflags', 'vflags')):
        r[c_dst] = str(row.get(c_src, 'na')).replace(',', ';')
    with h5py.File(path, 'r') as f:
        A = f['A']
        fref = MR.num(A, 'Fref', 60.0)
        t_off = MR.num(A, 'fault/t_off')
        ibr = MR.arr(A, 'IBR_data')
        g = MR.gfm_set(ibr, A)
        r['G'] = ' '.join(str(k + 1) for k in g)
        ft = MR.txt(A, 'fault/type')
        unbal = (ft is not None and ft != '' and ft != '3ph')
        # ---- the record ---------------------------------------------------
        t = MR.arr(A, 't').ravel()
        fc = MR.arr(A, 'fc')
        dth_g = MR.rows(A, 'dth', g)
        tf = MR.arr(A, 'tf').ravel()
        rec = MR.record_read(t, fc, dth_g, tf[0], t_off, fref, g)
        rel, tc = rec['rel'], rec['tc']          # G x samples, deg, to the last finite sample
        tend = tc[-1]
        L = tc > tend - LAST_S + 1e-9
        r['n_last'] = str(int(L.sum()))
        slopes, oscs = [], []
        for j in range(len(g)):
            x = tc[L]
            y = rel[j, L]
            p = np.polyfit(x, y, 1)
            slopes.append(float(p[0]))
            res = y - np.polyval(p, x)
            oscs.append(float((res.max() - res.min()) / 2.0))
        jd = int(np.argmax(np.abs(slopes)))
        r['DRIFT'] = fm(abs(slopes[jd]))
        r['DRIFT_unit'] = str(g[jd] + 1)
        r['OSC'] = fm(max(oscs))
        last = np.where(np.all(np.isfinite(fc[g, :]), axis=0))[0][-1]
        t_r = t[:last + 1]
        fc_r = fc[:, :last + 1]
        Lr = t_r > t_r[-1] - LAST_S + 1e-9
        fg = fc_r[g][:, Lr]
        relf = np.mean(fg - fg.mean(axis=0, keepdims=True), axis=1)
        jf = int(np.argmax(np.abs(relf)))
        r['RELF'] = fm(abs(float(relf[jf])))
        r['RELF_unit'] = str(g[jf] + 1)
        r['BANDEND'] = fm(float(np.max(np.abs(fc_r[:, Lr] - fref))))
        # ---- A3 T_EXIT ------------------------------------------------------
        fcf_raw = MR.arr(A, 'fcf')
        dt = float(np.median(np.diff(tf)))
        wc = int(round(1.0 / (fref * dt)))
        fcf_avg = MR.movmean_shrink(fcf_raw, wc) if unbal else fcf_raw
        te, ts = last_exit(tf, fcf_avg, t_off, t_r, fc_r, fref)
        r['T_EXIT'] = 'at the end' if math.isinf(te) else fm(te)
        r['T_EXIT_src'] = ts
        te2, ts2 = last_exit(tf, fcf_raw, t_off, t_r, fc_r, fref)
        r['T_EXIT_RAW'] = 'at the end' if math.isinf(te2) else fm(te2)
        r['T_EXIT_RAW_src'] = ts2
        # ---- A4 SATEND (addendum 1, 3.) ---------------------------------------
        sat = MR.rows(A, 'sat', g)
        if sat is None:
            r['SATEND'] = 'na'
        else:
            sat = sat[:, :last + 1]
            Ls = t_r > t_r[-1] - SAT_S + 1e-9
            on = [g[j] + 1 for j in range(len(g)) if np.nanmax(sat[j, Ls]) > 0]
            r['SATEND'] = str(len(on))
            r['SATEND_units'] = ' '.join(str(k) for k in on) if on else 'none'
        # ---- A5 SWINGV beside SWING -------------------------------------------
        dthf = MR.rows(A, 'dthf', g)
        vdf = MR.rows(A, 'vdf', g)
        vqf = MR.rows(A, 'vqf', g)
        if vdf is not None and vqf is not None and dthf is not None:
            # addendum 2, item 2: samples with |v_k| below 0.05 of the unit's pre-fault value (the first fine sample)
            # are left out of unit k's voltage angle; the angle is unwrapped in time over the kept samples; on
            # unbalanced rows it is averaged over one cycle as the frame angle is (and the left-out samples stay out);
            # a sample at which any unit of G is left out has no mean over G, so no relV there (strict reading)
            vm = np.hypot(vdf, vqf)
            keep = vm >= 0.05 * vm[:, [0]]
            ang = np.arctan2(vqf, vdf)
            thv = np.full_like(dthf, np.nan)
            wraps = 0
            for j in range(len(g)):
                kk = np.where(keep[j])[0]
                a = ang[j, kk]
                wraps += int(np.sum(np.abs(np.diff(a)) > math.pi))
                thv[j, kk] = dthf[j, kk] + np.unwrap(a)
            th = dthf
            if unbal:
                thv = MR.movmean_shrink(thv, wc)
                thv[~keep] = np.nan
                th = MR.movmean_shrink(th, wc)
            post = tf > t_off
            with np.errstate(invalid='ignore'):
                relv = MR.rel_deg(thv, 0)[:, post]
            relt = MR.rel_deg(th, 0)[:, post]
            r['SWINGV'] = fm(float(np.nanmax(np.abs(relv)))) if np.isfinite(relv).any() else 'na'
            r['SWING_mine'] = fm(float(np.max(np.abs(relt))))
            r['V_WRAPS'] = str(wraps)
            r['V_LEFTOUT'] = str(int((~keep).sum()))
            r['V_LEFTOUT_SAMPLES'] = str(int((~keep).any(axis=0).sum()))
    # ---- the rest condition ----------------------------------------------------
    if r['verdict'] == 'RETURNS':
        d, rf, be = float(r['DRIFT']), float(r['RELF']), float(r['BANDEND'])
        r['REST'] = 'AT REST' if (d <= REST_DRIFT and rf <= REST_RELF and be <= REST_BAND) else 'NOT AT REST'
    else:
        r['REST'] = r['verdict']
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
    print('=== DONE reread_a %d rows' % len(mine))


if __name__ == '__main__':
    main()
