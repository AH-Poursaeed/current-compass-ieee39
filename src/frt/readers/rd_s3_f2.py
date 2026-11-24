"""rd_s3_f2.py - worker RD, part 13: VERSION 2 of reading (f) of RULE S3 under ADDENDUM 2 (945b32bc...): on every
row the grid-forming and grid-following sets are the archive's own (IBR_data col 3): on the 24 rows with unit 8
under grid-following control the reference is the mean of units 7, 9 and 10 and unit 8 is one of the g. The
statistic is read_f of rd_s3.py (42e9735e...) with only those two sets changed. Usage:
  python rd_s3_f2.py --list LIST.txt --reports DIR --out DIR
"""
import argparse
import hashlib
import json
import os
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import rd_lib2 as L  # noqa: E402

EPS_T = 1e-9


def sha256(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def before(t, x, span):
    return (t > x - span + EPS_T) & (t <= x + EPS_T)


def read_f(ar):
    t = ar.t
    dth = ar.ch('dth')
    if dth is None:
        return dict(readable=False, reason='missing dth')
    th = np.degrees(dth)
    step = float(np.nanmax(np.abs(np.diff(th, axis=0))))
    if not np.isfinite(step):
        return dict(readable=False, reason='angle not finite')
    if step > 170.0:
        return dict(readable=False, reason='unwrap step %.1f deg > 170' % step, max_step_deg=step)
    on = ar.t_on
    pre = before(t, on, 0.5)
    last = before(t, t[-1], 1.0)
    after = t > on + EPS_T
    g_mean = np.mean(th[:, [u - 1 for u in ar.gfm_units]], axis=1)
    units = {}
    for g in ar.gfl_units:
        r = th[:, g - 1] - g_mean
        r0 = np.mean(r[pre])
        units[str(g)] = dict(Delta=float(np.mean(r[last]) - r0),
                             exc=float(np.max(np.abs(r[after] - r0))))
    D = [abs(v['Delta']) for v in units.values()]
    return dict(readable=True, max_step_deg=step, units=units, slip=bool(max(D) > 180.0),
                max_abs_Delta=float(max(D)), max_exc=float(max(v['exc'] for v in units.values())),
                rec_end_s=float(t[-1]), n_last=int(last.sum()), n_pre=int(pre.sum()),
                gfm_units=ar.gfm_units, gfl_units=ar.gfl_units)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--list', required=True)
    ap.add_argument('--reports', required=True)
    ap.add_argument('--out', required=True)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    rows = [ln.split()[0] for ln in open(a.list) if ln.strip() and not ln.startswith('#')]
    res = {}
    t0 = time.time()
    for tag in rows:
        path = os.path.join(a.reports, 'case_frt_%s.mat' % tag)
        try:
            ar = L.Archive(path, strict=False)
            try:
                out = read_f(ar)
                out['meta'] = dict(limMode=ar.limMode, t_on=ar.t_on, t_off=ar.t_off, rec_end=float(ar.t[-1]), matlab=ar.matlab)
            finally:
                ar.close()
        except Exception as e:  # noqa: BLE001
            out = dict(readable=False, reason='ERROR %s: %s' % (type(e).__name__, e))
        out['extra'] = []
        res[tag] = out
        print('%-24s %s %.1fs' % (tag, 'OK' if out.get('readable') else 'NOT READABLE: ' + out.get('reason', ''), time.time() - t0), flush=True)
    fn = os.path.join(a.out, 'rd_s3_f2.json')
    json.dump(res, open(fn, 'w'), indent=1)
    print('wrote', fn, sha256(fn))


if __name__ == '__main__':
    main()
