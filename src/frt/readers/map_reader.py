#!/usr/bin/env python3
"""map_reader.py - THE MAP READER of the TPWRS_V4 fault archives (reads only).

Reads the MATLAB v7.3 archives case_frt_<tag>.mat (HDF5) that the run driver
writes, with numpy and h5py only (Python 3.8 or later, Linux or Windows, no
MATLAB, no project import), and writes ONE TAB-SEPARATED LINE PER FAULT ROW.
Every archive is opened read-only (h5py mode 'r'); nothing is written beside
it. One archive's fine signals are held at a time.

USAGE
  python map_reader.py --reports <folder> [<folder> ...] [--tags <file>]
      [--exclude <file>] --out <file> [--append] [--self-test]

  --reports  one or more folders; each is listed NON-recursively for
             case_*.mat (subfolders such as withdrawn/ are not read unless named)
  --tags     a text file of tags (one per line; "frt_", "case_frt_" and ".mat"
             are stripped; '#' starts a comment): only those rows are read
  --exclude  the same form: those rows are skipped (reason "excluded")
  --out      the map file (a header line, then one line per row; "na" marks a
             field the archive cannot give). The rows NOT mapped are written
             to <out stem>_tags.txt (tag, folder, reason), one per line
  --append   append to an existing map (no second header; the header of the
             existing file must equal this reader's, or the run stops)
  --self-test  read the named registered archives found under the --reports
             folders (searched to a depth of 3) and print this reader's
             numbers beside the numbers printed in the committed artifacts,
             with the difference; written to --out when given, else stdout.

TIME BASES (every time column names its base)
  "after clearing" = t - t_off, "after onset" = t - t_on, in s, with
  t_on = A.fault.t_on and t_off = A.fault.t_off.
  The FINE WINDOW is A.tf (uniform, the controller step, 1e-4 s), from 2.95 s
  to 1.5 s after clearing on every registered row. The RECORD is A.t (one
  point per 60 Hz cycle: the time-weighted mean over the cycle, stamped at the
  cycle's end) to the run's end: 2 s after clearing on a standard row, 20 s on
  an N row (the [0.287] N rule).

UNITS
  The grid-forming set G = the units whose A.IBR_data column 3 is 2 (units 7
  to 10 at buses 36 to 39 on every registered archive); a unit named in a
  withdrawn-unit field (gfmAsGfl or gfmGfl, in A.conv.sens, A.conv or
  A.conv.frt) is removed from G. THE FAULTED UNIT u = the unit of G at the
  faulted bus when the fault is at a grid-forming terminal (u_how "term");
  otherwise the unit of G with the LOWEST mean terminal voltage over W_F (the
  mean of A.Vfpu at its bus; ties to the lower index; u_how "vmin"). The
  registered rule (frt_channels) takes the largest fault-window limiter
  occupancy in the circular limiter's archive of the same point; on one row
  it cannot see that twin, and the occupancy of the row's own archive picks
  a different unit where the occupancies are near equal (PG03c, NPG01gd),
  while the voltage rule gives unit 7, the registered read unit, at every
  bus-16 row checked. The slip unit (slip_unit) = the unit of G with the
  largest |rel| at the first record sample after clearing beyond 180 deg.

THE RELATIVE ANGLE (as frt_report and frt_lw2 take it)
  rel_k(t) = [th_k(t) - th_k(t0)] - mean over G of [th_j(t) - th_j(t0)], deg,
  th = the archived converter angle (A.dthf on the fine window, A.dth on the
  record), t0 = the fine window's first sample (on the record the sample
  nearest A.tf(1), frt_lw2's k0). Positive = AHEAD of the fleet's mean.
  relK_clr_deg = rel_k at the fine sample nearest t_off (unit K = 7..10);
  relu_clr_deg = the faulted unit's; relS_clr_deg = the slip unit's.
  t180_on_s = the first fine sample at or after onset at which any |rel| of
  G exceeds 180 deg, s AFTER ONSET ("never" within the fine window);
  lost_phase = "fault" when that crossing is at or before clearing (the
  unit slipped during the fault), "post" when after it or when a LOST row
  never crosses inside the fine window; "pre" when the fleet was not quiet
  before the fault (pre_dev_Hz > 0.05): such a row's loss is not the
  fault's. pre_dev_Hz = the largest |f - Fref| of any converter over the
  fine samples before onset; pre_maxRel_deg = the largest |rel| of G there
  (a row at its equilibrium reads about 1e-4 Hz and 0 deg; the registered
  pre-fault gate, which compares with a no-fault twin, is not repeated
  here). On an unbalanced row (fault type not
  3ph) the fine angle and the fine frequencies are the one-cycle centred
  moving averages of frt_report's cyc restatement ([0.346]: window
  round(1/(Fref dt)) samples, shrinking ends, NaN omitted) everywhere they
  are read; the powers, voltages and flags stay raw.

THE VERDICT (verdict, basis, t_verdict_s)
  fine_*: frt_report's 1.5 s rule on the fine window: fine_tRec_s = the last
  fine sample after clearing at which ANY archived converter frequency
  (A.fcf, all columns) is outside 0.05 Hz of Fref, minus t_off (0 if none);
  fine_maxRel_deg = the largest |rel| of G after clearing; fine_slip = 1 when
  fine_maxRel > 180, or |rel at the window's end| > 90 deg and growing, or the
  largest grid-forming |f - Fref| at the end > 0.3 Hz and growing ("growing":
  |rel| of the unit largest at the end rises over the last 0.5 s in two
  0.25 s steps and is above 20 deg). INVALID (no fine verdict) when the window
  ends less than 1.0 s after clearing or a frequency or G angle it reads is
  not finite.
  rec_*: frt_lw2's reading of the record (to its last finite sample):
  rec_tLost_s = the first record sample after clearing at which any |rel| of
  G exceeds 180 deg, minus t_off; rec_class = LOST (that crossing, or at the
  record's end |rel| > 90 deg or a G frequency > 0.3 Hz off, either with the
  angle growing as above), else "RETURNS, SETTLED" when every converter
  frequency (A.fc, all columns) is within 0.05 Hz at the last sample, else
  "RETURNS, NOT SETTLED". tSetAll_s / tSetGFM_s = the last record sample
  after clearing at which any converter / any unit of G is outside 0.05 Hz,
  minus t_off (0 if none; on a 2 s record they cannot exceed about 2 s; a
  record kept to a solver stop ends at the stop, where frt_lw2 prints them
  and the native grid's reading prints none).
  verdict (frt_grid_readers' route words, LOST / RETURNS / UNDECIDED):
   basis "rec" (a record of 7 s or more after clearing: the N rows): the
     record's class decides; LOST with t_verdict_s = rec_tLost_s ("na" when
     lost by the growing leg only); RETURNS with t_verdict_s = THE RETURN TIME
     t_r of frt_grid_readers: fine_tRec_s, or rec tSetAll_s when the fine
     return is window-limited (fine_tRec_s >= 1.5 - 1e-6) or the fine verdict
     is a second-clause slip (fine_maxRel < 180) (frt_nrule's "settled" and
     "returned"); a return never settled on the record prints settled "n"
     and t_verdict_s "na".
   basis "fine+N" (a short record whose 20 s twin case_frt_N<tag>.mat is in
     a --reports folder): frt_nrule: a window-limited fine return or a
     second-clause fine slip takes the twin record's class (LOST: LOST at the
     twin's rec_tLost_s; RETURNS, SETTLED: RETURNS at the twin's tSetAll_s;
     a second-clause slip whose twin returns but never settles: RETURNS at
     the twin's tSetAll_s, settled "n"; a window-limited return whose twin
     returns but never settles: RETURNS, settled "n", t "na" (frt_grid_
     readers' route word and paper_numbers' reading; frt_nrule alone says
     "undecided"); a twin stopped before half a turn, or unreadable:
     UNDECIDED); a fine
     slip through 180 deg is LOST and a return inside the window is RETURNS
     at fine_tRec_s, as without a twin. The twin's instrument check (its
     fine verdict against the parent's) is not repeated here: the twin's
     own line carries its fine verdict.
   basis "fine" (a short record, no twin): a fine slip through 180 deg is
     LOST at the first FINE sample after clearing with any |rel| > 180, minus
     t_off; a second-clause slip is LOST with t_verdict_s "na"; a return
     inside the window is RETURNS at fine_tRec_s; a window-limited return
     is RETURNS at 1.50 with flag WL (the window decided nothing more).
   basis "stopped" (A.ok false with A.stopped, the record kept to a solver
     stop): frt_lw2's words: LOST (the angle passed half a turn before the
     stop; t_verdict_s = rec_tLost_s) or UNDECIDED ("STOPPED at X s, not
     lost before", X = A.tStop - t_off).
   A fine INVALID row with a short record is UNDECIDED.

THE RECOVERY METRICS (the definitions fixed for the sealed predictions)
  t_ret_s      THE RETURN TIME = t_verdict_s of a RETURNS row (above): band
               0.05 Hz on every converter frequency, s after clearing.
  t_rel_s      THE RELEASE TIME: the first fine sample after clearing at
               which the faulted unit's tapped rotation A.tap.dphi > -pi/2 +
               0.02 rad, minus t_off; "never" if not within the fine window;
               "na" without taps; "norot" when the tapped channel is 0 at
               every sample (a chart without a rotation taps a constant 0,
               the converter controller). dphi_clr_deg = the tapped rotation at the
               fine sample nearest t_off.
  t_rel_rec_s, dphi_rec_clr_deg: the same read on the rotation RECONSTRUCTED
               by the chart's law (the converter controller) from the archived Qf and
               satf of the faulted unit, limMode qrot only: dphi(k) =
               clip(dphi(k-1) - kq Ts (Qfloor - Q(k)), -pi/2, 0) while
               satf(k) > 0.5, else 0 (qrotReset) or dphi(k-1); kq =
               qGain/Srated, Qfloor = qFloor Srated, dphi = 0 at the window's
               start. Approximate (the archived flag and Q are the chart's
               inputs one step apart); flagged "rec".
  excu_deg, excu_t_s  THE EXCURSION: the largest |rel_u| over the record
               after clearing, deg, and its time, s after clearing.
               excall_deg = rec maxRel (all of G, frt_lw2's maxRel).
  tSetGFM_s    THE SETTLING TIME (frt_lw2): last record sample after
               clearing with any unit of G outside 0.05 Hz, minus t_off.
  t_sync_s     THE RE-SYNCHRONISATION TIME: the first record sample after
               clearing from which |rel_u(t) - rel_u(end)| <= 5 deg holds to
               the record's end, minus t_off (rel_u(end) = the faulted unit's
               relative angle at the record's last finite sample); "na" for a
               LOST row.
  t_retu_s     the faulted unit's own frequency band: the last sample after
               clearing (fine window, then the record beyond it) with
               |f_u - Fref| > 0.05 Hz, minus t_off (0 if none).

THE FAULT WINDOW READS (frt_exposure_support and frt_grid_readers, D-2)
  W_F = [t_on + ramp, t_off - ramp] on A.tf (each end with 1e-9 s; ramp =
  A.fault.ramp, else 4 A.solver.ctrlTs, else 4e-4 s).
  EPu_MWs, EQu_Mvars: trapz over W_F of the faulted unit's A.Pf, A.Qf (MW s,
  Mvar s); EPg_MWs, EQg_Mvars: the sums over G (frt_grid_readers' EP_gfm,
  EQ_gfm; dEQ_gfm of a pair = EQg of z - EQg of c).
  Vret_f_pu = trapz(A.Vfpu(faulted bus)) over W_F / its span; Vret_n_pu =
  the mean over the faulted bus's first neighbours of the same (the case39
  branch list, all 46 branches, also on a row with a branch out).
  X1u = max over W_F of r = |I_L|/Imax of the faulted unit, I_L = (P -
  jQ)/(Sb V) + j Bc V (pu on Sb, V = A.Vfpu at the unit's bus, Bc = C_gfm w0
  Zbase), Imax = iLimPu Srated/(Sb A.Vref(bus)) (the census route);
  X1u_t_s its time AFTER ONSET; X1g the largest over G.
  sat_last_s: the last time after clearing at which the faulted unit's
  limiter flag is up (fine A.satf > 0.5, then the record's A.sat > 0.5 beyond
  the fine window), minus t_off; 0 if never.
  fu_min_Hz, fu_max_Hz: the extremes of f_u - Fref after clearing (fine
  window, then the record beyond it).

THE POST-CLEARING MECHANISM (fine samples with t_off < t <= t_off + 0.5 s)
  ang_iv_deg: the circular mean of angle(i_L) - angle(v) of the faulted
  unit, i_L = i_o + j w0 C_gfm v in the converter frame (A.vdf, A.vqf,
  A.idf, A.iqf), else by the census route from P, Q, V (ang_route dq / pq):
  near -90 = lagging quadrature (reactive), near 0 = in phase (active).
  P_MW, Peff_MW, def_MW: the means of the unit's P, of the cap's reference
  Peff* = min(P0, pShape 1.5 |v| Imax) (n39_conv_ctrl PShape; P0 = A.Pf at
  the fine window's first sample; Peff* = P0 when pShape = 0, no cap) and of
  the deficit Peff* - P (a positive deficit accelerates the unit through
  the droop). For limMode gao, vap or xf with a VSM reference the
  controller's own power reference is not this one (flag ownref).
  Q_Mvar: mean Q of the unit. fu_Hz: mean f_u - Fref; frel_Hz: mean f_u -
  the mean frequency of G; drel_deg = rel_u(t_off + 0.5) - rel_u(t_off)
  (fine).
  rot_clamp_005: limMode qrot only: "y" when the rotation (tapped, else
  reconstructed, flag "rotation reconstructed") is still at its clamp
  (dphi <= -pi/2 + 0.02 rad) at the fine sample nearest t_off + 0.05 s.
  pulled: "y" when sign(drel_deg) = -sign(relu_clr_deg) (the unit moved
  toward the fleet in the first 0.5 s), else "n".
  def_away: "y" when the mean deficit pushes the unit away from the fleet:
  sign(def_MW) = sign(relu_clr_deg) (behind with P above Peff*, or ahead
  with P below its reference), else "n" (the droop path's drive; flag
  ownref where the controller's angle is not driven by this deficit).
  mech (the faulted unit): AHEAD (relu_clr > 0, pulled back), BOTH
  (relu_clr > 0, not pulled back), BLOCKED (relu_clr <= 0, not pulled
  back), NEITHER (relu_clr <= 0, pulled back): "blocked" = NOT PULLED BACK,
  the observed relative motion, which reads every controller alike.
  drelS_deg, defS_MW, frelS_Hz, mechS: the same at the SLIP unit of a LOST
  row (mechS "DURING-FAULT" when lost_phase is "fault": the unit passed
  half a turn before clearing, so no clearing state applies; "PRE-FAULT"
  when lost_phase is "pre").

STRATEGY AND CONDITION COLUMNS
  block, code: from the tag (N?<BLOCK><code><bus>_<ms>[_<load><droop><sfx>]);
  limMode qFloor qGain pShape advSteps rot iLimPu from A.conv.frt / A.conv;
  frt_opts: every build option of A.req.build whose name starts with "frt"
  (name=value;...); bus, line (A.fault.line as i-j when present), ftype,
  phases, dur_s = t_off - t_on, load = A.conv.sens.loadScale, droop =
  A.conv.sens.droopScale, net = "full" or the lines of netBrOut as i-j,
  gfm_wd = the withdrawn-unit field or "na"; ok, stopped, release, wall_s
  (A.wall), rec_after_s, fine_after_s (the record's / window's end after
  clearing), twin (the N twin read, or na).
"""
import argparse
import math
import os
import re
import sys
import time

import numpy as np
import h5py

ALL_BRANCHES = (
    (1, 2), (1, 39), (2, 3), (2, 25), (2, 30), (3, 4), (3, 18), (4, 5), (4, 14),
    (5, 6), (5, 8), (6, 7), (6, 11), (6, 31), (7, 8), (8, 9), (9, 39), (10, 11),
    (10, 13), (10, 32), (12, 11), (12, 13), (13, 14), (14, 15), (15, 16),
    (16, 17), (16, 19), (16, 21), (16, 24), (17, 18), (17, 27), (19, 20),
    (19, 33), (20, 34), (21, 22), (22, 23), (22, 35), (23, 24), (23, 36),
    (25, 26), (25, 37), (26, 27), (26, 28), (26, 29), (28, 29), (29, 38))

NA = 'na'
BAND_HZ = 0.05
SYNC_BAND_DEG = 5.0
REL_CLAMP_TOL = 0.02          # rad above -pi/2: the release threshold
FINE_RULE_S = 1.5             # the registered fine window after clearing
LONG_RECORD_S = 7.0           # a record this long after clearing is read on the record (the 8 s map rows and the 20 s N rows)
VBASE_DEFAULT = 345e3

COLS = [
    'tag', 'folder', 'block', 'code', 'limMode', 'qFloor', 'qGain', 'pShape',
    'advSteps', 'rot_deg', 'iLimPu', 'frt_opts',
    'bus', 'line', 'ftype', 'phases', 'dur_s', 'load', 'droop', 'net', 'gfm_wd',
    'ok', 'stopped', 'release', 'wall_s', 'rec_after_s', 'fine_after_s',
    'verdict', 'basis', 't_verdict_s', 'settled', 'vflags', 'twin',
    'fine_slip', 'fine_tRec_s', 'fine_maxRel_deg',
    'rec_class', 'rec_tLost_s', 'rec_maxRel_deg', 'rec_relEnd_deg', 'rec_fcEnd_Hz',
    'rec_grow', 'tSetAll_s', 'tSetGFM_s',
    'u', 'u_how', 'slip_unit',
    'rel7_clr_deg', 'rel8_clr_deg', 'rel9_clr_deg', 'rel10_clr_deg', 'relu_clr_deg',
    'relS_clr_deg', 't180_on_s', 'lost_phase', 'pre_dev_Hz', 'pre_maxRel_deg',
    't_ret_s', 't_rel_s', 'dphi_clr_deg', 't_rel_rec_s', 'dphi_rec_clr_deg',
    'excu_deg', 'excu_t_s', 'excall_deg', 't_sync_s', 't_retu_s',
    'fu_min_Hz', 'fu_max_Hz',
    'EPu_MWs', 'EQu_Mvars', 'EPg_MWs', 'EQg_Mvars', 'WF_s',
    'Vret_f_pu', 'Vret_n_pu', 'nbrs',
    'X1u', 'X1u_t_s', 'X1g', 'sat_last_s',
    'ang_iv_deg', 'ang_route', 'P_MW', 'Peff_MW', 'def_MW', 'Q_Mvar', 'fu_Hz', 'frel_Hz',
    'drel_deg', 'rot_clamp_005', 'pulled', 'def_away', 'mech',
    'drelS_deg', 'defS_MW', 'frelS_Hz', 'mechS', 'mflags']


# ----------------------------------------------------------------------------
# HDF5 helpers (MATLAB v7.3 layout: arrays transposed, char as uint16 codes,
# empties marked by the MATLAB_empty attribute, cells as object references)
# ----------------------------------------------------------------------------

def _obj(g, path):
    try:
        return g[path] if path in g else None
    except (KeyError, ValueError):
        return None


def _cls(o):
    c = o.attrs.get('MATLAB_class', b'')
    return c.decode() if isinstance(c, bytes) else str(c)


def _empty(o):
    return bool(o.attrs.get('MATLAB_empty', 0))


def num(g, path, default=float('nan')):
    o = _obj(g, path)
    if o is None or not isinstance(o, h5py.Dataset) or _empty(o):
        return default
    try:
        v = np.array(o, dtype=float).ravel()
    except (TypeError, ValueError):
        return default
    return float(v[0]) if v.size else default


def arr(g, path):
    o = _obj(g, path)
    if o is None or not isinstance(o, h5py.Dataset) or _empty(o):
        return None
    try:
        return np.array(o, dtype=float)
    except (TypeError, ValueError):
        return None


def rows(g, path, idx):
    """Rows idx (0-based unit or bus indices) of a MATLAB (samples x n) array."""
    o = _obj(g, path)
    if o is None or not isinstance(o, h5py.Dataset) or _empty(o):
        return None
    idx = list(idx)
    order = sorted(set(idx))
    if order and max(order) >= o.shape[0]:
        return None
    if order == list(range(order[0], order[-1] + 1)):
        blk = np.array(o[order[0]:order[-1] + 1, :], dtype=float)
    else:
        blk = np.array(o[order, :], dtype=float)
    pos = {k: i for i, k in enumerate(order)}
    return blk[[pos[k] for k in idx], :]


def txt(g, path):
    o = _obj(g, path)
    if o is None or not isinstance(o, h5py.Dataset):
        return None
    if _empty(o):
        return ''
    if _cls(o) != 'char':
        return None
    v = np.array(o).ravel()
    return ''.join(chr(int(c)) for c in v)


def _deref(f, ref):
    try:
        o = f[ref]
    except (KeyError, ValueError, TypeError):
        return '?'
    if not isinstance(o, h5py.Dataset):
        return '<struct>'
    if _empty(o):
        return ''
    c = _cls(o)
    if c == 'char':
        return ''.join(chr(int(x)) for x in np.array(o).ravel())
    if c == 'cell':
        return '{' + ','.join(str(_deref(f, r)) for r in np.array(o).ravel()) + '}'
    if c == 'function_handle':
        return '<fh>'
    try:
        v = np.array(o, dtype=float).ravel()
    except (TypeError, ValueError):
        return '?'
    if v.size == 1:
        return v[0]
    return list(v)


def build_pairs(f, A):
    """A.req.build as a list of (name, value); None when absent."""
    o = _obj(A, 'req/build')
    if o is None or not isinstance(o, h5py.Dataset):
        return None
    if _empty(o):
        return []
    if _cls(o) != 'cell':
        return None
    refs = np.array(o).ravel()
    vals = [_deref(f, r) for r in refs]
    return [(vals[i], vals[i + 1]) for i in range(0, len(vals) - 1, 2)]


# ----------------------------------------------------------------------------
# formatting
# ----------------------------------------------------------------------------

def fm(x, nd):
    if x is None:
        return NA
    if isinstance(x, str):
        return x
    try:
        xf = float(x)
    except (TypeError, ValueError):
        return NA
    if not math.isfinite(xf):
        return NA
    return f"{xf:.{nd}f}"


def fval(v):
    if isinstance(v, str):
        return v
    if isinstance(v, list):
        return '[' + ' '.join(fval(x) for x in v) + ']'
    if isinstance(v, float):
        if math.isfinite(v) and v == round(v):
            return str(int(v))
        return f"{v:.6g}"
    return str(v)


# ----------------------------------------------------------------------------
# the readers' arithmetic
# ----------------------------------------------------------------------------

def movmean_shrink(x, k):
    """MATLAB movmean(x, k, 2, 'omitnan', 'Endpoints', 'shrink') along axis 1."""
    k = int(k)
    if k <= 1:
        return x.copy()
    nb = k // 2
    na = k - 1 - nb
    n = x.shape[1]
    fin = np.isfinite(x)
    z = np.where(fin, x, 0.0)
    cs = np.concatenate([np.zeros((x.shape[0], 1)), np.cumsum(z, axis=1)], axis=1)
    cc = np.concatenate([np.zeros((x.shape[0], 1)), np.cumsum(fin, axis=1)], axis=1)
    i = np.arange(n)
    lo = np.maximum(0, i - nb)
    hi = np.minimum(n, i + na + 1)
    s = cs[:, hi] - cs[:, lo]
    c = cc[:, hi] - cc[:, lo]
    with np.errstate(invalid='ignore', divide='ignore'):
        return np.where(c > 0, s / np.maximum(c, 1), np.nan)


def rel_deg(th, i0):
    """Relative angles (deg) of the rows of th (units x samples), the change
    since sample i0 minus the mean over the rows."""
    d = th - th[:, [i0]]
    return np.degrees(d - d.mean(axis=0, keepdims=True))


def growing_test(rel_unit_deg, n25):
    a0 = abs(rel_unit_deg[-1])
    a1 = abs(rel_unit_deg[max(0, len(rel_unit_deg) - 1 - n25)])
    a2 = abs(rel_unit_deg[max(0, len(rel_unit_deg) - 1 - 2 * n25)])
    return bool(a0 > a1 and a1 > a2 and a0 > 20.0)


def trapz(y, x, axis=-1):
    y = np.asarray(y, dtype=float)
    x = np.asarray(x, dtype=float)
    d = np.diff(x)
    if y.ndim == 1:
        return float(np.sum(d * (y[1:] + y[:-1]) / 2.0))
    return np.sum(d[None, :] * (y[:, 1:] + y[:, :-1]) / 2.0, axis=1)


def record_read(t, fc, dth_g, tf0, t_off, fref, gfm_cols):
    """frt_lw2's i_read on the record. fc: all units x samples; dth_g: G rows."""
    out = {'class': 'NO RECORD', 'tLost': float('nan'), 'maxRel': float('nan'),
           'relEnd': float('nan'), 'fcEnd': float('nan'), 'grow': False,
           'tSetAll': float('nan'), 'tSetGFM': float('nan'), 'rec_after': float('nan'),
           'iu_end': -1, 'slip_row': -1, 'rel': None, 'tc': None}
    if t is None or fc is None or dth_g is None or t.size < 4:
        return out
    fin = np.all(np.isfinite(fc[gfm_cols, :]), axis=0) & np.all(np.isfinite(dth_g), axis=0)
    if not fin.any():
        return out
    last = int(np.where(fin)[0][-1])
    t = t[:last + 1]
    fc = fc[:, :last + 1]
    dth_g = dth_g[:, :last + 1]
    k0 = int(np.argmin(np.abs(t - tf0)))
    tc = t[k0:]
    rel = rel_deg(dth_g[:, k0:], 0)
    post = tc > t_off
    relP = rel[:, post]
    tP = tc[post]
    out['rel'] = rel
    out['tc'] = tc
    out['rec_after'] = float(t[-1] - t_off)
    if relP.size:
        out['maxRel'] = float(np.max(np.abs(relP)))
        big = np.any(np.abs(relP) > 180.0, axis=0)
        if big.any():
            il = int(np.argmax(big))
            out['tLost'] = float(tP[il] - t_off)
            out['slip_row'] = int(np.argmax(np.abs(relP[:, il])))
    iu = int(np.argmax(np.abs(rel[:, -1])))
    out['iu_end'] = iu
    out['relEnd'] = float(rel[iu, -1])
    dtc = float(np.median(np.diff(tc))) if tc.size > 1 else float('nan')
    n25 = max(1, int(round(0.25 / dtc))) if math.isfinite(dtc) and dtc > 0 else 1
    out['grow'] = growing_test(rel[iu, :], n25)
    out['fcEnd'] = float(np.max(np.abs(fc[gfm_cols, -1] - fref)))
    lost = math.isfinite(out['tLost']) or (abs(out['relEnd']) > 90 and out['grow']) \
        or (out['fcEnd'] > 0.3 and out['grow'])
    with np.errstate(invalid='ignore'):
        dev = np.abs(fc - fref)
        bad_all = np.any(dev > BAND_HZ, axis=0) & (t > t_off)
        bad_g = np.any(dev[gfm_cols, :] > BAND_HZ, axis=0) & (t > t_off)
        end_ok = bool(np.all(dev[:, -1] <= BAND_HZ))
    out['tSetAll'] = float(t[np.where(bad_all)[0][-1]] - t_off) if bad_all.any() else 0.0
    out['tSetGFM'] = float(t[np.where(bad_g)[0][-1]] - t_off) if bad_g.any() else 0.0
    if lost:
        out['class'] = 'LOST'
    elif end_ok:
        out['class'] = 'RETURNS, SETTLED'
    else:
        out['class'] = 'RETURNS, NOT SETTLED'
    return out


def fine_read(tf, fcf_all, dth_g, t_off, fref, gfm_cols):
    """frt_report's verdict on the fine window (already cyc-averaged if needed)."""
    out = {'slip': None, 'tRec': float('nan'), 'maxRel': float('nan'),
           'invalid': '', 't180': float('nan')}
    with np.errstate(invalid='ignore'):
        dev = np.abs(fcf_all - fref)
        bad = np.any(dev > BAND_HZ, axis=0) & (tf > t_off)
    out['tRec'] = float(tf[np.where(bad)[0][-1]] - t_off) if bad.any() else 0.0
    rel = rel_deg(dth_g, 0)
    post = tf > t_off
    relp = rel[:, post]
    out['maxRel'] = float(np.max(np.abs(relp)))
    iu = int(np.argmax(np.abs(relp[:, -1])))
    rel_end = float(relp[iu, -1])
    dt = float(np.median(np.diff(tf)))
    n25 = max(1, int(round(0.25 / dt)))
    grow = growing_test(relp[iu, :], n25)
    fc_end = float(np.max(np.abs(fcf_all[gfm_cols, -1] - fref)))
    out['slip'] = bool(out['maxRel'] > 180 or (abs(rel_end) > 90 and grow) or (fc_end > 0.3 and grow))
    big = np.any(np.abs(relp) > 180.0, axis=0)
    if big.any():
        out['t180'] = float(tf[post][int(np.argmax(big))] - t_off)
    return out


def fine_invalid(tf, fcf_raw, dth_g_raw, t_off):
    if tf is None or tf.size == 0 or tf[-1] - t_off < 1.0:
        end = float('nan') if tf is None or tf.size == 0 else tf[-1] - t_off
        return 'the record ends %.2f s after clearing; the verdict needs 1.0 s' % end
    post = tf > t_off
    if fcf_raw is None:
        return 'no fine converter frequency'
    nf = int(np.count_nonzero(~np.isfinite(fcf_raw[:, post])))
    if nf:
        return '%d non-finite sample(s) of the converter frequency after clearing' % nf
    if dth_g_raw is None:
        return 'the record carries no converter angle, which the slip rule reads'
    na_ = int(np.count_nonzero(~np.isfinite(dth_g_raw[:, post]))) + \
        int(np.count_nonzero(~np.isfinite(dth_g_raw[:, 0])))
    if na_:
        return '%d non-finite sample(s) of the grid-forming angle' % na_
    return ''


def neighbours(bus):
    nb = set()
    for a, b in ALL_BRANCHES:
        if a == bus:
            nb.add(b)
        elif b == bus:
            nb.add(a)
    return sorted(nb)


def last_up_after(tf, flag_f, t_rec, flag_r, t_off):
    """Last time after clearing at which a flag is up (> 0.5): fine samples,
    then record samples beyond the fine window's end."""
    t_last = None
    if flag_f is not None:
        m = (tf > t_off) & (flag_f > 0.5)
        if m.any():
            t_last = float(tf[np.where(m)[0][-1]])
    if flag_r is not None and t_rec is not None:
        m = (t_rec > tf[-1]) & (flag_r > 0.5)
        if m.any():
            t_last = float(t_rec[np.where(m)[0][-1]])
    return 0.0 if t_last is None else t_last - t_off


def reconstruct_dphi(tf, sat, Q, q_floor, q_gain, s_rated, reset, slew):
    kq = q_gain / s_rated
    qf = q_floor * s_rated
    ts = float(np.median(np.diff(tf)))
    d = np.zeros(tf.size)
    lo = -math.pi / 2
    prev = 0.0
    for k in range(1, tf.size):
        if sat[k] > 0.5:
            if slew is not None and math.isfinite(slew):
                x = prev + ts * min(max(-kq * (qf - Q[k]), -slew), slew)
            else:
                x = prev - kq * ts * (qf - Q[k])
            x = min(max(x, lo), 0.0)
        else:
            x = 0.0 if reset else prev
        d[k] = x
        prev = x
    return d


def release_after(tf, dphi, t_off):
    post = np.where(tf > t_off)[0]
    if post.size == 0:
        return float('nan'), 'na'
    up = dphi[post] > -math.pi / 2 + REL_CLAMP_TOL
    if up.any():
        return float(tf[post[int(np.argmax(up))]] - t_off), ''
    return float('nan'), 'never'


# ----------------------------------------------------------------------------
# one archive
# ----------------------------------------------------------------------------

TAG_RE = re.compile(r'^(N?)([A-Z]+)([a-z]?)(\d{2})_(\d{4})(?:_(\d{2})([A-Z]?)([a-z]*))?$')


def tag_of(fname):
    b = os.path.basename(fname)
    if b.lower().endswith('.mat'):
        b = b[:-4]
    if b.startswith('case_'):
        b = b[5:]
    if b.startswith('frt_'):
        b = b[4:]
    return b


def block_code(tag):
    m = TAG_RE.match(tag)
    if m:
        return m.group(1) + m.group(2), (m.group(3) or NA)
    m2 = re.match(r'^(N?[A-Z]+)', tag)
    return (m2.group(1) if m2 else NA), NA


def withdrawn_field(A):
    for base in ('conv/sens/', 'conv/', 'conv/frt/'):
        for name in ('gfmAsGfl', 'gfmGfl'):
            o = _obj(A, base + name)
            if o is not None and isinstance(o, h5py.Dataset):
                if _empty(o):
                    return name, []
                try:
                    v = np.array(o, dtype=float).ravel()
                except (TypeError, ValueError):
                    return name, None
                return name, [int(x) for x in v if math.isfinite(x) and x > 0]
    return None, None


def net_state(A):
    v = arr(A, 'conv/sens/netBrOut')
    if v is None:
        v = arr(A, 'conv/netBrOut')
    if v is None or v.size == 0:
        return 'full'
    v = v.ravel()
    if v.size % 2:
        return 'netBrOut?' + fval(list(v))
    # MATLAB k x 2 stored transposed: the pairs are columns of the HDF5 (2 x k)
    o = _obj(A, 'conv/sens/netBrOut')
    if o is None:
        o = _obj(A, 'conv/netBrOut')
    m = np.array(o, dtype=float)
    if m.ndim == 2 and m.shape[0] == 2:
        pairs = [(int(m[0, j]), int(m[1, j])) for j in range(m.shape[1])]
    else:
        pairs = [(int(v[2 * j]), int(v[2 * j + 1])) for j in range(v.size // 2)]
    return ';'.join('%d-%d' % p for p in pairs)


def twin_record(path_twin, tf0_parent, t_off_parent):
    """The 20 s twin's record class (frt_lw2) for frt_nrule."""
    with h5py.File(path_twin, 'r') as f:
        A = f['A']
        ok = num(A, 'ok', 0.0) > 0.5
        stopped = num(A, 'stopped', 0.0) > 0.5
        t = arr(A, 't')
        fc = arr(A, 'fc')
        ibr = arr(A, 'IBR_data')
        fref = num(A, 'Fref', 60.0)
        t_off = num(A, 'fault/t_off')
        tf = arr(A, 'tf')
        tstop = num(A, 'tStop')
        if t is None or fc is None or ibr is None or tf is None:
            return {'class': 'RUN FAILED' if not ok else 'NO RECORD'}
        g = gfm_set(ibr, A)
        dth = rows(A, 'dth', g)
    rec = record_read(t.ravel(), fc, dth, float(tf.ravel()[0]), t_off, fref, g)
    if not ok and not stopped:
        return {'class': 'RUN FAILED'}
    if not ok and stopped:
        ts = tstop - t_off
        if rec['class'] == 'LOST':
            rec['class'] = 'LOST, then stopped at %.2f s' % ts
        else:
            rec['class'] = 'STOPPED at %.2f s, not lost before' % ts
    return rec


def gfm_set(ibr, A):
    """0-based unit indices of G (IBR_data column 3 == 2, h5py-transposed)."""
    if ibr is None:
        return [6, 7, 8, 9]
    typ = ibr[2, :] if ibr.shape[0] >= 3 else None
    g = [k for k in range(ibr.shape[1]) if typ is not None and int(round(typ[k])) == 2]
    if not g:
        g = [6, 7, 8, 9]
    name, wd = withdrawn_field(A)
    if wd:
        g = [k for k in g if (k + 1) not in wd]
    return g


def read_row(path, folder, twin_paths):
    """Returns (row dict, None) or (None, skip reason)."""
    r = {c: NA for c in COLS}
    tag = tag_of(path)
    r['tag'] = tag
    r['folder'] = folder
    r['block'], r['code'] = block_code(tag)
    with h5py.File(path, 'r') as f:
        if 'A' not in f:
            return None, 'no A struct in the file'
        A = f['A']
        ok = num(A, 'ok', 0.0) > 0.5
        stopped = num(A, 'stopped', 0.0) > 0.5
        t_on = num(A, 'fault/t_on')
        t_off = num(A, 'fault/t_off')
        bus = num(A, 'fault/bus')
        ln_pre = arr(A, 'fault/line')          # a mid-line fault (D32): the line's end buses, bus NaN
        has_line = ln_pre is not None and ln_pre.size >= 2
        tf = arr(A, 'tf')
        if not ok and not stopped:
            err = txt(A, 'err') or ''
            return None, 'run failed (A.ok false, no kept record): ' + re.sub(r'\s+', ' ', err)[:90]
        if not math.isfinite(t_on) or not math.isfinite(t_off) or ((not math.isfinite(bus) or bus <= 0) and not has_line):
            return None, 'health row (no fault in the archive: fault.t_on or fault.bus absent or 0)'
        if tf is None or tf.size < 4:
            return None, 'no fine window (A.tf absent)'
        tf = tf.ravel()
        if not (tf[0] < t_on < tf[-1]):
            return None, 'the fault lies outside the fine window'
        bus = int(round(bus)) if (math.isfinite(bus) and bus > 0) else 0
        # the faulted buses: the bus itself, or a mid-line fault's two end buses
        fbuses = [bus] if bus > 0 else [int(round(float(x))) for x in ln_pre.ravel()[:2]]
        fref = num(A, 'Fref', 60.0)
        ibr = arr(A, 'IBR_data')
        g = gfm_set(ibr, A)
        nunits = ibr.shape[1] if ibr is not None else 10
        busu = arr(A, 'bus')
        busu = [int(round(x)) for x in busu.ravel()] if busu is not None else list(range(30, 40))
        vref = arr(A, 'Vref')
        vref = vref.ravel() if vref is not None else np.ones(39)
        sb = num(A, 'Sbase', 1e8)
        if sb < 1e6:
            sb *= 1e6
        ilim = num(A, 'conv/iLimPu', 1.25)
        cg = num(A, 'conv/C_gfm')
        lim = txt(A, 'conv/frt/limMode')
        pshape = num(A, 'conv/frt/pShape', 0.0)
        qfloor = num(A, 'conv/frt/qFloor')
        qgain = num(A, 'conv/frt/qGain')
        adv = num(A, 'conv/frt/advSteps')
        rot = num(A, 'conv/frt/rot')
        reset = num(A, 'conv/frt/qrotReset', 1.0) > 0.5
        slew = num(A, 'conv/frt/slewGov')
        xfref = txt(A, 'conv/sens/xfRef') or txt(A, 'conv/frt/xfRef') or ''
        r['limMode'] = lim if lim is not None else NA
        r['qFloor'] = fm(qfloor, 3)
        r['qGain'] = fm(qgain, 3)
        r['pShape'] = fm(pshape, 3)
        r['advSteps'] = fm(adv, 3)
        r['rot_deg'] = fm(math.degrees(rot) if math.isfinite(rot) else rot, 2)
        r['iLimPu'] = fm(ilim, 3)
        bp = build_pairs(f, A)
        if bp is None:
            r['frt_opts'] = NA
        else:
            fo = ['%s=%s' % (n, fval(v)) for n, v in bp if isinstance(n, str) and n.startswith('frt')]
            r['frt_opts'] = ';'.join(fo) if fo else 'none'
        r['bus'] = str(bus) if bus > 0 else NA
        ln = arr(A, 'fault/line')
        r['line'] = NA if ln is None else '-'.join(str(int(x)) for x in ln.ravel())
        ft = txt(A, 'fault/type')
        r['ftype'] = ft if ft else ('3ph' if ft is None else ft)
        ph = txt(A, 'fault/phases')
        r['phases'] = ph if ph else ('abc' if ph is None else ph)
        r['dur_s'] = fm(t_off - t_on, 4)
        r['load'] = fm(num(A, 'conv/sens/loadScale', 1.0), 3)
        r['droop'] = fm(num(A, 'conv/sens/droopScale', 1.0), 3)
        r['net'] = net_state(A)
        wn, wd = withdrawn_field(A)
        r['gfm_wd'] = NA if wn is None else '%s=%s' % (wn, ','.join(str(x) for x in wd) if wd else 'none')
        r['ok'] = 'y' if ok else 'n'
        r['stopped'] = 'y' if stopped else 'n'
        rel_ = txt(A, 'release')
        r['release'] = rel_ if rel_ else NA
        r['wall_s'] = fm(num(A, 'wall'), 1)
        unbal = (ft is not None and ft != '' and ft != '3ph')
        tstop = num(A, 'tStop')

        # ---- the faulted unit --------------------------------------------
        satf_g = rows(A, 'satf', g)
        ramp = num(A, 'fault/ramp')
        if not math.isfinite(ramp):
            cts = num(A, 'solver/ctrlTs')
            ramp = 4 * cts if math.isfinite(cts) else 4e-4
        wF = (tf >= t_on + ramp - 1e-9) & (tf <= t_off - ramp + 1e-9)
        iF = np.where(wF)[0]
        u_how = NA
        u = None
        for k in g:
            if k < len(busu) and busu[k] == bus:
                u, u_how = k, 'term'
        if u is None:
            vg = rows(A, 'Vfpu', sorted(set(busu[k] - 1 for k in g)))
            if vg is not None and iF.size >= 2:
                gb = sorted(set(busu[k] - 1 for k in g))
                vmean = [float(np.mean(vg[gb.index(busu[k] - 1), iF])) for k in g]
                u = g[int(np.argmin(vmean))]
                u_how = 'vmin'
            elif satf_g is not None:
                won = (tf >= t_on) & (tf <= t_off)
                occ = np.nanmean(satf_g[:, won], axis=1)
                u = g[int(np.argmax(occ))]
                u_how = 'occ'
            else:
                u = g[-1]
                u_how = 'last'
        ju = g.index(u)
        r['u'] = str(u + 1)
        r['u_how'] = u_how
        bu = busu[u]

        # ---- fine signals --------------------------------------------------
        fcf_raw = arr(A, 'fcf')
        dthf_raw = rows(A, 'dthf', g)
        why = fine_invalid(tf, fcf_raw, dthf_raw, t_off)
        dt = float(np.median(np.diff(tf)))
        if unbal and fcf_raw is not None and dthf_raw is not None:
            wc = int(round(1.0 / (fref * dt)))
            fcf = movmean_shrink(fcf_raw, wc)
            dthf = movmean_shrink(dthf_raw, wc)
        else:
            fcf, dthf = fcf_raw, dthf_raw
        del fcf_raw, dthf_raw
        r['fine_after_s'] = fm(tf[-1] - t_off, 4)
        fine = None
        if not why:
            fine = fine_read(tf, fcf, dthf, t_off, fref, g)
            r['fine_slip'] = '1' if fine['slip'] else '0'
            r['fine_tRec_s'] = fm(fine['tRec'], 4)
            r['fine_maxRel_deg'] = fm(fine['maxRel'], 2)
        else:
            r['fine_slip'] = 'INVALID'

        # ---- the record --------------------------------------------------
        t = arr(A, 't')
        fc = arr(A, 'fc')
        dth_r = rows(A, 'dth', g)
        t = t.ravel() if t is not None else None
        rec = record_read(t, fc, dth_r, tf[0], t_off, fref, g)
        sat_r = rows(A, 'sat', [u])
        sat_r = sat_r[0] if sat_r is not None else None

        # ---- the verdict -----------------------------------------------------
        flags = []
        twin = None
        basis = NA
        verdict, tv, settled = 'UNDECIDED', float('nan'), NA
        rec_after = rec['rec_after']
        if not ok and stopped:
            basis = 'stopped'
            ts = tstop - t_off
            if rec['class'] == 'LOST':
                verdict, tv = 'LOST', rec['tLost']
                rec['class'] = 'LOST, then stopped at %.2f s' % ts
            else:
                rec['class'] = 'STOPPED at %.2f s, not lost before' % ts
                flags.append('stopped %.2f s after clearing' % ts)
        elif math.isfinite(rec_after) and rec_after >= LONG_RECORD_S:
            basis = 'rec'
            c = rec['class']
            if c == 'LOST':
                verdict, tv = 'LOST', rec['tLost']
                if not math.isfinite(tv):
                    flags.append('lost by the growing leg')
            elif c.startswith('RETURNS'):
                verdict = 'RETURNS'
                settled = 'y' if c == 'RETURNS, SETTLED' else 'n'
                if fine is None:
                    tv = float('nan')
                    flags.append('fine INVALID')
                elif c == 'RETURNS, NOT SETTLED':
                    tv = float('nan')
                    flags.append('not settled')
                elif (not fine['slip'] and fine['tRec'] >= FINE_RULE_S - 1e-6) or \
                        (fine['slip'] and fine['maxRel'] < 180):
                    tv = rec['tSetAll']
                    flags.append('t_r from the record (window-limited or second-clause)')
                else:
                    tv = fine['tRec']
                    if fine['slip']:
                        flags.append('fine slip, record returns')
        else:
            twin_rec = None
            if tag in twin_paths:
                twin = tag_of(twin_paths[tag])
                try:
                    twin_rec = twin_record(twin_paths[tag], tf[0], t_off)
                except Exception as exc:  # noqa: BLE001
                    twin_rec = {'class': 'TWIN UNREADABLE ' + type(exc).__name__}
            basis = 'fine+N' if twin_rec is not None else 'fine'
            if fine is None:
                flags.append('fine INVALID: ' + why)
            elif fine['slip'] and fine['maxRel'] > 180:
                verdict = 'LOST'
                tv = rec['tLost'] if math.isfinite(rec['tLost']) else fine['t180']
                flags.append('t from the record' if math.isfinite(rec['tLost']) else 't from the fine window')
            elif not fine['slip'] and fine['tRec'] < FINE_RULE_S - 1e-6:
                verdict, tv, settled = 'RETURNS', fine['tRec'], 'y'
            elif twin_rec is not None:
                c = twin_rec['class']
                wl = not fine['slip']
                if c.startswith('LOST'):
                    verdict, tv = 'LOST', twin_rec.get('tLost', float('nan'))
                    flags.append('N rule: ' + ('lost' if wl else 'confirmed'))
                elif c.startswith('RETURNS, SETTLED'):
                    verdict, tv, settled = 'RETURNS', twin_rec['tSetAll'], 'y'
                    flags.append('N rule: ' + ('settled' if wl else 'returned'))
                elif c.startswith('RETURNS') and not wl:
                    verdict, tv, settled = 'RETURNS', twin_rec['tSetAll'], 'n'
                    flags.append('N rule: returned, not settled')
                elif c.startswith('RETURNS'):
                    verdict, tv, settled = 'RETURNS', float('nan'), 'n'
                    flags.append('twin RETURNS, NOT SETTLED: a return, not settled (the grid readers, '
                                 'the number record); the N rule alone calls it undecided')
                else:
                    flags.append('N rule undecided: twin ' + c)
            elif fine['slip']:
                verdict = 'LOST'
                flags.append('second-clause slip, no 20 s record')
            else:
                verdict, tv, settled = 'RETURNS', fine['tRec'], 'n'
                flags.append('WL: window-limited return, no 20 s record')
        r['verdict'] = verdict
        r['basis'] = basis
        r['t_verdict_s'] = fm(tv, 4)
        r['settled'] = settled
        r['vflags'] = '; '.join(flags) if flags else NA
        r['twin'] = twin if twin else NA
        r['rec_class'] = rec['class']
        r['rec_tLost_s'] = fm(rec['tLost'], 4)
        r['rec_maxRel_deg'] = fm(rec['maxRel'], 2)
        r['rec_relEnd_deg'] = fm(rec['relEnd'], 2)
        r['rec_fcEnd_Hz'] = fm(rec['fcEnd'], 4)
        r['rec_grow'] = '1' if rec['grow'] else '0'
        r['tSetAll_s'] = fm(rec['tSetAll'], 4)
        r['tSetGFM_s'] = fm(rec['tSetGFM'], 4)
        r['rec_after_s'] = fm(rec_after, 4)
        r['t_ret_s'] = fm(tv, 4) if verdict == 'RETURNS' else NA
        if rec['slip_row'] >= 0:
            r['slip_unit'] = str(g[rec['slip_row']] + 1)
        elif verdict == 'LOST' and fine is not None:
            relf = rel_deg(dthf, 0)[:, tf > t_off]
            r['slip_unit'] = str(g[int(np.argmax(np.max(np.abs(relf), axis=1)))] + 1)

        # ---- the displacement at clearing ----------------------------------
        relf_all = rel_deg(dthf, 0) if dthf is not None else None
        pre = tf < t_on
        pre_dev = float('nan')
        if pre.any() and fcf is not None:
            pre_dev = float(np.nanmax(np.abs(fcf[:, pre] - fref)))
            r['pre_dev_Hz'] = fm(pre_dev, 5)
        if pre.any() and relf_all is not None:
            r['pre_maxRel_deg'] = fm(float(np.nanmax(np.abs(relf_all[:, pre]))), 2)
        kc = int(np.argmin(np.abs(tf - t_off)))
        if relf_all is not None:
            for j, k in enumerate(g):
                if 6 <= k <= 9:
                    r['rel%d_clr_deg' % (k + 1)] = fm(relf_all[j, kc], 2)
            relu_clr = float(relf_all[ju, kc])
            r['relu_clr_deg'] = fm(relu_clr, 2)
            if r['slip_unit'] != NA:
                r['relS_clr_deg'] = fm(relf_all[g.index(int(r['slip_unit']) - 1), kc], 2)
            on = tf >= t_on
            big = np.any(np.abs(relf_all[:, on]) > 180.0, axis=0)
            if big.any():
                t180 = float(tf[on][int(np.argmax(big))] - t_on)
                r['t180_on_s'] = fm(t180, 4)
                r['lost_phase'] = 'fault' if t180 <= t_off - t_on else 'post'
            else:
                r['t180_on_s'] = 'never'
                if verdict == 'LOST':
                    r['lost_phase'] = 'post'
            if math.isfinite(pre_dev) and pre_dev > BAND_HZ:
                r['lost_phase'] = 'pre'
        else:
            relu_clr = float('nan')

        # ---- excursion, re-synchronisation, settling ------------------------
        if rec['rel'] is not None:
            relr = rec['rel'][ju]
            tc = rec['tc']
            post = tc > t_off
            if post.any():
                a = np.abs(relr[post])
                i = int(np.argmax(a))
                r['excu_deg'] = fm(a[i], 2)
                r['excu_t_s'] = fm(tc[post][i] - t_off, 4)
                r['excall_deg'] = fm(rec['maxRel'], 2)
                if verdict != 'LOST':
                    off = np.abs(relr[post] - relr[-1]) > SYNC_BAND_DEG
                    if off.any():
                        lastoff = int(np.where(off)[0][-1])
                        tpp = tc[post]
                        r['t_sync_s'] = fm(tpp[lastoff + 1] - t_off, 4) if lastoff + 1 < tpp.size else NA
                    else:
                        r['t_sync_s'] = fm(tc[post][0] - t_off, 4)
        # the unit's own frequency band and extremes
        fu_f = fcf[u] - fref if fcf is not None else None
        fu_r = (fc[u] - fref) if (fc is not None and t is not None) else None
        if fu_f is not None:
            pf = tf > t_off
            vals = [fu_f[pf]]
            tt = [tf[pf]]
            if fu_r is not None:
                beyond = (t > tf[-1]) & np.isfinite(fu_r)
                vals.append(fu_r[beyond])
                tt.append(t[beyond])
            vv = np.concatenate(vals)
            ttt = np.concatenate(tt)
            if vv.size:
                r['fu_min_Hz'] = fm(np.nanmin(vv), 4)
                r['fu_max_Hz'] = fm(np.nanmax(vv), 4)
                with np.errstate(invalid='ignore'):
                    badu = np.abs(vv) > BAND_HZ
                r['t_retu_s'] = fm(ttt[np.where(badu)[0][-1]] - t_off, 4) if badu.any() else fm(0.0, 4)
        r['sat_last_s'] = fm(last_up_after(tf, satf_g[ju] if satf_g is not None else None, t, sat_r, t_off), 4)
        del fc, dth_r

        # ---- fault-window reads -------------------------------------------
        pf_g = rows(A, 'Pf', g)
        qf_g = rows(A, 'Qf', g)
        nb = neighbours(bus) if bus > 0 else sorted(set(b for fb in fbuses for b in neighbours(fb)) - set(fbuses))
        vb = sorted(set([fb - 1 for fb in fbuses] + [b - 1 for b in nb] + [busu[k] - 1 for k in g]))
        vfp = rows(A, 'Vfpu', vb)
        vrow = {b: i for i, b in enumerate(vb)}
        r['nbrs'] = ','.join(str(b) for b in nb)
        if iF.size >= 2 and pf_g is not None and qf_g is not None:
            tF = tf[iF]
            EP = trapz(pf_g[:, iF], tF) / 1e6
            EQ = trapz(qf_g[:, iF], tF) / 1e6
            r['EPu_MWs'] = fm(EP[ju], 2)
            r['EQu_Mvars'] = fm(EQ[ju], 2)
            r['EPg_MWs'] = fm(np.sum(EP), 2)
            r['EQg_Mvars'] = fm(np.sum(EQ), 2)
            r['WF_s'] = fm(tF[-1] - tF[0], 4)
            if vfp is not None:
                span = tF[-1] - tF[0]
                vr_f = float(np.mean([trapz(vfp[vrow[fb - 1], iF], tF) / span for fb in fbuses]))
                vr_n = [trapz(vfp[vrow[b - 1], iF], tF) / span for b in nb]
                r['Vret_f_pu'] = fm(vr_f, 4)
                r['Vret_n_pu'] = fm(float(np.mean(vr_n)) if vr_n else float('nan'), 4)
                # the census route's current ratio
                vbase = VBASE_DEFAULT
                try:
                    v1 = float(A['Vf'][fbuses[0] - 1, 0])
                    v2 = float(A['Vfpu'][fbuses[0] - 1, 0])
                    if v2 > 0 and math.isfinite(v1 / v2):
                        vbase = math.sqrt(3.0) * v1 / v2
                except (KeyError, ValueError, TypeError, IndexError):
                    pass
                zb = vbase ** 2 / sb
                w0 = 2 * math.pi * fref
                bc = cg * w0 * zb if math.isfinite(cg) else float('nan')
                x1 = []
                tpk = []
                for j, k in enumerate(g):
                    vk = vfp[vrow[busu[k] - 1], iF]
                    sr = ibr[8, k] * sb
                    imax = ilim * sr / (sb * vref[busu[k] - 1])
                    with np.errstate(invalid='ignore', divide='ignore'):
                        rat = np.abs((pf_g[j, iF] - 1j * qf_g[j, iF]) / sb / vk + 1j * bc * vk) / imax
                    ip = int(np.nanargmax(rat))
                    x1.append(float(rat[ip]))
                    tpk.append(float(tF[ip] - t_on))
                r['X1u'] = fm(x1[ju], 6)
                r['X1u_t_s'] = fm(tpk[ju], 4)
                r['X1g'] = fm(max(x1), 6)

        # ---- the post-clearing mechanism (first 0.5 s) -----------------------
        mflags = []
        w5 = (tf > t_off) & (tf <= t_off + 0.5 + 1e-9)
        i5 = np.where(w5)[0]

        def post_mech(k):
            """The first 0.5 s after clearing at unit k (0-based, in G)."""
            j = g.index(k)
            m = {'P': float('nan'), 'Peff': float('nan'), 'def': float('nan'), 'Q': float('nan'),
                 'ang': float('nan'), 'route': NA, 'fu': float('nan'), 'frel': float('nan'),
                 'drel': float('nan')}
            if not i5.size or pf_g is None:
                return m
            bk = busu[k]
            p0k = float(pf_g[j, 0])
            srk = ibr[8, k] * sb
            vdk, vqk = rows(A, 'vdf', [k]), rows(A, 'vqf', [k])
            idk, iqk = rows(A, 'idf', [k]), rows(A, 'iqf', [k])
            vbk = VBASE_DEFAULT
            try:
                v1 = float(A['Vf'][bk - 1, 0])
                v2 = float(A['Vfpu'][bk - 1, 0])
                if v2 > 0:
                    vbk = math.sqrt(3.0) * v1 / v2
            except (KeyError, ValueError, TypeError, IndexError):
                pass
            Pk = pf_g[j, i5]
            if vdk is not None and vqk is not None:
                vabs_pu = np.hypot(vdk[0, i5], vqk[0, i5]) / (vbk * math.sqrt(2.0 / 3.0))
            elif vfp is not None:
                vabs_pu = vfp[vrow[bk - 1], i5]
            else:
                vabs_pu = None
            if vabs_pu is not None:
                cap = pshape * ilim * srk * vabs_pu / vref[bk - 1] if pshape > 0 else np.full(i5.size, p0k)
                peff = np.minimum(p0k, cap)
                m['P'] = float(np.mean(Pk))
                m['Peff'] = float(np.mean(peff))
                m['def'] = float(np.mean(peff - Pk))
            if qf_g is not None:
                m['Q'] = float(np.mean(qf_g[j, i5]))
            if vdk is not None and vqk is not None and idk is not None and iqk is not None and math.isfinite(cg):
                v = vdk[0, i5] + 1j * vqk[0, i5]
                il = (idk[0, i5] + 1j * iqk[0, i5]) + 1j * 2 * math.pi * fref * cg * v
                ang = np.angle(il) - np.angle(v)
                m['ang'] = math.degrees(float(np.angle(np.mean(np.exp(1j * ang)))))
                m['route'] = 'dq'
            elif vfp is not None and qf_g is not None:
                vk = vfp[vrow[bk - 1], i5]
                zb = vbk ** 2 / sb
                bc = cg * 2 * math.pi * fref * zb if math.isfinite(cg) else 0.0
                with np.errstate(invalid='ignore', divide='ignore'):
                    il = (Pk - 1j * qf_g[j, i5]) / sb / vk + 1j * bc * vk
                m['ang'] = math.degrees(float(np.angle(np.nanmean(np.exp(1j * np.angle(il))))))
                m['route'] = 'pq'
            if fcf is not None:
                m['fu'] = float(np.mean(fcf[k, i5] - fref))
                m['frel'] = float(np.mean(fcf[k, i5] - np.mean(fcf[g][:, i5], axis=0)))
            if relf_all is not None:
                m['drel'] = float(relf_all[j, i5[-1]] - relf_all[j, kc])
            return m

        def answer(rel0, mm):
            """AHEAD/BLOCKED/BOTH/NEITHER: ahead = rel0 > 0; blocked = not pulled back (the
            relative angle did not move toward the fleet over the first 0.5 s)."""
            if not (math.isfinite(rel0) and math.isfinite(mm['drel'])):
                return NA, NA, NA
            pulled = bool(np.sign(mm['drel']) == -np.sign(rel0) and mm['drel'] != 0)
            away = NA
            if math.isfinite(mm['def']):
                away = 'y' if (np.sign(mm['def']) == np.sign(rel0) and mm['def'] != 0) else 'n'
            blk = not pulled
            mech = ('BOTH' if blk else 'AHEAD') if rel0 > 0 else ('BLOCKED' if blk else 'NEITHER')
            return ('y' if pulled else 'n'), away, mech

        mu = post_mech(u)
        r['P_MW'] = fm(mu['P'] / 1e6, 1)
        r['Peff_MW'] = fm(mu['Peff'] / 1e6, 1)
        r['def_MW'] = fm(mu['def'] / 1e6, 1)
        r['Q_Mvar'] = fm(mu['Q'] / 1e6, 1)
        r['ang_iv_deg'] = fm(mu['ang'], 1)
        r['ang_route'] = mu['route']
        r['fu_Hz'] = fm(mu['fu'], 4)
        r['frel_Hz'] = fm(mu['frel'], 4)
        r['drel_deg'] = fm(mu['drel'], 2)
        sr_u = ibr[8, u] * sb if ibr is not None else float('nan')
        if lim in ('gao', 'vap', 'qsyn') or (lim == 'xf' and xfref == 'vsm'):
            mflags.append('ownref')

        # ---- the rotation (taps, else reconstructed for qrot) ---------------
        clamp_005 = None
        tap_units = arr(A, 'tap/units')
        if tap_units is not None and _obj(A, 'tap/dphi') is not None:
            tu = [int(round(x)) for x in tap_units.ravel()]
            if (u + 1) in tu:
                dph = rows(A, 'tap/dphi', [tu.index(u + 1)])[0]
                r['dphi_clr_deg'] = fm(math.degrees(dph[kc]), 2)
                if np.all(dph[np.isfinite(dph)] == 0.0):
                    r['t_rel_s'] = 'norot'      # a chart without a rotation taps a constant 0
                else:
                    trel, why_rel = release_after(tf, dph, t_off)
                    r['t_rel_s'] = fm(trel, 4) if not why_rel else why_rel
                    k05 = int(np.argmin(np.abs(tf - (t_off + 0.05))))
                    clamp_005 = bool(dph[k05] <= -math.pi / 2 + REL_CLAMP_TOL)
        if lim == 'qrot' and satf_g is not None and qf_g is not None and math.isfinite(qgain) \
                and math.isfinite(qfloor):
            dr = reconstruct_dphi(tf, satf_g[ju], qf_g[ju], qfloor, qgain, sr_u, reset, slew)
            trel, why_rel = release_after(tf, dr, t_off)
            r['t_rel_rec_s'] = fm(trel, 4) if not why_rel else why_rel
            r['dphi_rec_clr_deg'] = fm(math.degrees(dr[kc]), 2)
            if clamp_005 is None:
                k05 = int(np.argmin(np.abs(tf - (t_off + 0.05))))
                clamp_005 = bool(dr[k05] <= -math.pi / 2 + REL_CLAMP_TOL)
                mflags.append('rotation reconstructed')

        # ---- classification ---------------------------------------------
        if clamp_005 is not None:
            r['rot_clamp_005'] = 'y' if clamp_005 else 'n'
        r['pulled'], r['def_away'], r['mech'] = answer(relu_clr, mu)
        if r['slip_unit'] != NA:
            ks = int(r['slip_unit']) - 1
            if r.get('lost_phase') == 'pre':
                r['mechS'] = 'PRE-FAULT'
            elif r.get('lost_phase') == 'fault':
                r['mechS'] = 'DURING-FAULT'
            elif ks in g and relf_all is not None:
                ms = mu if ks == u else post_mech(ks)
                r['drelS_deg'] = fm(ms['drel'], 2)
                r['defS_MW'] = fm(ms['def'] / 1e6, 1)
                r['frelS_Hz'] = fm(ms['frel'], 4)
                r['mechS'] = answer(float(relf_all[g.index(ks), kc]), ms)[2]
        r['mflags'] = '; '.join(mflags) if mflags else NA
    return r, None


# ----------------------------------------------------------------------------
# folders, the run, the self-test
# ----------------------------------------------------------------------------

def read_taglist(path):
    out = []
    with open(path, 'r', encoding='ascii', errors='replace') as fh:
        for line in fh:
            line = line.split('#', 1)[0].strip()
            if line:
                out.append(tag_of(line.split()[0]))
    return out


def list_archives(folders):
    """(path, folder name) of every case_*.mat in each folder (non-recursive)."""
    items = []
    for d in folders:
        d = os.path.abspath(d)
        try:
            names = sorted(os.listdir(d))
        except OSError as exc:
            sys.stderr.write('cannot list %s: %s\n' % (d, exc))
            continue
        for n in names:
            p = os.path.join(d, n)
            if n.startswith('case_') and n.lower().endswith('.mat') and os.path.isfile(p):
                items.append((p, os.path.basename(d.rstrip('/\\'))))
    return items


def twin_index(items):
    """parent tag -> the path of its N twin, when both are listed."""
    by_tag = {}
    for p, _ in items:
        by_tag.setdefault(tag_of(p), p)
    tw = {}
    for t, p in by_tag.items():
        if t.startswith('N') and t[1:] in by_tag:
            tw[t[1:]] = p
    return tw


def header_line():
    return '\t'.join(COLS)


def run_map(args):
    items = list_archives(args.reports)
    want = set(read_taglist(args.tags)) if args.tags else None
    excl = set(read_taglist(args.exclude)) if args.exclude else set()
    tw = twin_index(items)
    out = args.out
    stem, ext = os.path.splitext(out)
    skip_path = stem + '_tags' + (ext if ext else '.txt')
    new = not (args.append and os.path.isfile(out) and os.path.getsize(out) > 0)
    if not new:
        with open(out, 'r', encoding='ascii', errors='replace') as fh:
            first = fh.readline().rstrip('\r\n')
        if first != header_line():
            sys.stderr.write('the existing map %s has a different header; not appended\n' % out)
            return 2
    mode = 'w' if new else 'a'
    n_read = n_skip = n_fail = 0
    t0 = time.time()
    with open(out, mode, encoding='ascii', newline='\n') as fo, \
            open(skip_path, 'a' if args.append else 'w', encoding='ascii', newline='\n') as fs:
        if new:
            fo.write(header_line() + '\n')
        for i, (p, folder) in enumerate(items):
            tag = tag_of(p)
            if want is not None and tag not in want:
                continue
            if tag in excl:
                fs.write('%s\t%s\texcluded by --exclude\n' % (tag, folder))
                n_skip += 1
                continue
            ts = time.time()
            try:
                row, why = read_row(p, folder, tw)
            except Exception as exc:  # noqa: BLE001
                row, why = None, 'READ FAILED: %s: %s' % (type(exc).__name__, str(exc)[:120])
            if row is None:
                fs.write('%s\t%s\t%s\n' % (tag, folder, why.encode('ascii', 'replace').decode()))
                if why.startswith('READ FAILED'):
                    n_fail += 1
                else:
                    n_skip += 1
            else:
                line = '\t'.join(str(row[c]).replace('\t', ' ') for c in COLS)
                fo.write(line.encode('ascii', 'replace').decode() + '\n')
                fo.flush()
                n_read += 1
            sys.stderr.write('%5d %-28s %6.2f s %s\n' % (i + 1, tag, time.time() - ts,
                                                        'mapped' if row is not None else 'skipped'))
    sys.stderr.write('done: %d mapped, %d skipped, %d failed in %.0f s; map %s; skipped %s\n' % (
        n_read, n_skip, n_fail, time.time() - t0, out, skip_path))
    return 0


# the committed artifacts' printed numbers (file, line) for the self-test
SELF_TEST = [
    # tag, column, printed value, decimals, source
]


def find_archive(folders, tag, depth=3):
    name = 'case_frt_%s.mat' % tag
    for d in folders:
        d = os.path.abspath(d)
        base_depth = d.rstrip('/\\').count(os.sep)
        for root, dirs, files in os.walk(d):
            if root.count(os.sep) - base_depth >= depth:
                dirs[:] = []
            if name in files:
                return os.path.join(root, name)
    return None


def _cmp(val, ref, nd):
    if nd is None:
        return (val == ref), ('' if val == ref else 'DIFFERS')
    try:
        v = float(val)
        rf = float(ref)
    except (TypeError, ValueError):
        return False, 'not numeric'
    d = v - rf
    ok = abs(d) <= 0.5 * 10 ** (-nd) * (1 + 1e-9) + 1e-12
    return ok, '%+.*g' % (4, d)


def self_test(args):
    lines = []
    say = lines.append
    say('MAP READER SELF-TEST   %s' % time.strftime('%Y-%m-%d %H:%M:%S'))
    say('  folders searched (depth 3): %s' % '; '.join(os.path.abspath(d).replace('\\', '/') for d in args.reports))
    say('  the reader: %s' % os.path.abspath(__file__).replace('\\', '/'))
    say('  definitions: the module docstring (the return time = tRec of the report rule on all converter frequencies, '
        'band 0.05 Hz, s after clearing, extended per the N rule to the 20 s record; tLost = the first record '
        'sample after clearing with any grid-forming |rel| > 180 deg; energies and V_ret over W_F = '
        '[t_on + ramp, t_off - ramp]; X1 by the census route)')
    say('  verdict per row: EQUAL = this reader equals the printed number at the printed digits '
        '(|difference| <= half a unit of the last printed digit); DIFF otherwise, reported, not hidden')
    say('')
    cache = {}
    tw_folders = list_archives(args.reports)
    tw = twin_index(tw_folders)
    # the twins may sit in a subfolder: index the found archives too
    needed = sorted(set(t for t, *_ in SELF_TEST if not t.startswith('pair:')))
    for t in needed:
        p = find_archive(args.reports, t)
        if p is None:
            cache[t] = (None, 'not found under the folders')
            continue
        ptw = find_archive(args.reports, 'N' + t)
        twl = dict(tw)
        if ptw:
            twl[t] = ptw
        ts = time.time()
        try:
            row, why = read_row(p, os.path.basename(os.path.dirname(p)), twl)
        except Exception as exc:  # noqa: BLE001
            row, why = None, 'READ FAILED %s: %s' % (type(exc).__name__, exc)
        cache[t] = (row, why if row is None else '%s read in %.1f s' % (p.replace('\\', '/'), time.time() - ts))
    say('%-38s %-16s %14s %14s %12s  %-6s  %s' % ('row', 'field', 'this reader', 'printed', 'difference', 'match', 'source'))
    n_eq = n_diff = n_na = 0
    for tag, col, ref, nd, src in SELF_TEST:
        if tag.startswith('pair:'):
            z, c = tag[5:].split('-')
            rz, rc = cache.get(z, (None, ''))[0], cache.get(c, (None, ''))[0]
            key = {'dEQ_gfm': 'EQg_Mvars', 'dEP_gfm': 'EPg_MWs'}[col]
            if rz is None or rc is None or rz[key] == NA or rc[key] == NA:
                val = NA
            else:
                val = '%.4f' % (float(rz[key]) - float(rc[key]))
        else:
            row = cache.get(tag, (None, ''))[0]
            val = NA if row is None else row[col]
        if val == NA:
            ok, d = False, 'unavailable'
            n_na += 1
        else:
            ok, d = _cmp(val, ref, nd)
            if ok:
                n_eq += 1
            else:
                n_diff += 1
        say('%-38s %-16s %14s %14s %12s  %-6s  %s' % (tag, col, val, ref, d, 'EQUAL' if ok else ('DIFF' if val != NA else 'NA'), src))
    say('')
    say('  %d compared: %d EQUAL, %d DIFF, %d unavailable' % (len(SELF_TEST), n_eq, n_diff, n_na))
    say('')
    say('  the archives read:')
    for t in needed:
        say('    %-18s %s' % (t, cache[t][1]))
    text = '\n'.join(lines) + '\n'
    if args.out:
        with open(args.out, 'w', encoding='ascii', newline='\n') as fh:
            fh.write(text.encode('ascii', 'replace').decode())
    sys.stdout.write(text)
    return 0 if n_diff == 0 and n_na == 0 else 1


def main(argv=None):
    ap = argparse.ArgumentParser(description='The map reader of the fault archives (reads only).')
    ap.add_argument('--reports', nargs='+', required=True, help='folder(s) holding case_*.mat')
    ap.add_argument('--tags', help='file of tags to read (one per line)')
    ap.add_argument('--exclude', help='file of tags to skip (one per line)')
    ap.add_argument('--out', help='the map file (required unless --self-test)')
    ap.add_argument('--append', action='store_true', help='append to an existing map')
    ap.add_argument('--self-test', action='store_true', help='compare with the committed artifacts')
    args = ap.parse_args(argv)
    if args.self_test:
        return self_test(args)
    if not args.out:
        ap.error('--out is required unless --self-test')
    return run_map(args)


if __name__ == '__main__':
    sys.exit(main())
