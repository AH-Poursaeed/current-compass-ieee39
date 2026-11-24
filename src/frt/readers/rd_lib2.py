"""rd_lib2.py (version 2 of the first archive library: Archive(path, strict=False) keeps the archive's own GFM/GFL sets) - worker RD, session 60 resumed part 13: archive access shared by the readers of S3 and S6.

Nothing here computes a statistic: it opens a case_frt_<tag>.mat (MAT v7.3 = HDF5) with h5py, returns its time
bases, channels and constants in a fixed orientation (samples x units), and names where each constant comes from
(the census, section (1)). Patterns follow the registered test reader (8ae4ab0a...) and map_reader.py
(1973dbe1...). Arrays: MATLAB is column-major, so h5py returns (units, N); every channel here is returned (N, units).
"""
import re
import numpy as np
import h5py

GFM_UNITS = (7, 8, 9, 10)          # unit numbers (1-based); IBR_data col 3 == 2 is asserted per archive
GFL_UNITS = (1, 2, 3, 4, 5, 6)
TAG_RX = re.compile(r'^([A-Z]+?)([a-z]+[0-9]*?)(\d\d)_(\d{4})_(\d\d)([ST])(F|W|O1718|U08)$')


def tag_fields(tag):
    t = tag[4:] if tag.startswith('frt_') else tag
    m = TAG_RX.match(t)
    if not m:
        return None
    fam, code, bus, ms, ld, typ, st = m.groups()
    return dict(tag=t, fam=fam, code=code, bus=int(bus), ms=int(ms), load=ld, typ=typ, state=st,
                key='%s_%s_%s%s%s' % (bus, ms, ld, typ, st))


def _ds(g, name):
    d = g[name]
    if d.attrs.get('MATLAB_empty', 0):
        return np.zeros((0,))
    return np.array(d)


def num(g, name, default=None):
    if name not in g:
        return default
    x = _ds(g, name)
    return x.T if x.ndim == 2 else x


def scalar(g, name, default=np.nan):
    if name not in g:
        return default
    x = _ds(g, name).ravel()
    return float(x[0]) if x.size else default


def char(g, name, default=''):
    if name not in g:
        return default
    d = g[name]
    if d.attrs.get('MATLAB_empty', 0):
        return ''
    return ''.join(chr(int(c)) for c in np.array(d).ravel())


class Archive:
    """Lazy reader of one archive. ch(name) returns a channel as (N, units) float array (or None if absent/empty)."""

    def __init__(self, path, strict=True):
        self.path = path
        self.F = h5py.File(path, 'r')
        self.A = self.F['A']
        A = self.A
        self.tag = char(A, 'tag')
        self.t = num(A, 't').ravel()
        self.tf = num(A, 'tf').ravel() if 't' in A and 'tf' in A else None
        self.Fref = scalar(A, 'Fref')
        self.Sb = scalar(A, 'Sbase')
        self.bus = num(A, 'bus').ravel().astype(int)
        ibr = np.asarray(num(A, 'IBR_data'), dtype=float)
        self.IBR = ibr if ibr.shape[0] == 10 else ibr.T          # rows = units, cols as the model's parameter table
        self.Vref = num(A, 'Vref').ravel()
        fg = A['fault'] if 'fault' in A else None
        self.fault_on = bool(scalar(fg, 'on', 0.0)) if fg is not None else False
        self.t_on = scalar(fg, 't_on') if fg is not None else np.nan
        self.t_off = scalar(fg, 't_off') if fg is not None else np.nan
        self.ramp = scalar(fg, 'ramp') if fg is not None else np.nan
        self.fbus = int(scalar(fg, 'bus', 0.0)) if fg is not None else 0
        self.ftype = char(fg, 'type') if fg is not None else ''
        self.Rf_pu = scalar(fg, 'Rf_pu') if fg is not None else np.nan
        cv = A['conv']
        self.iLimPu = scalar(cv, 'iLimPu')
        self.lpf_wc = scalar(cv, 'lpf_wc')
        self.Ts = scalar(cv, 'Ts_ctrl')
        self.fdev_max = scalar(cv, 'fdev_max')
        self.C_gfm = scalar(cv, 'C_gfm')
        self.C_gfm_pu = scalar(cv, 'C_gfm_pu')
        sens = cv['sens']
        self.loadScale = scalar(sens, 'loadScale', 1.0)
        self.droopScale = scalar(sens, 'droopScale', 1.0)
        nb = num(sens, 'netBrOut', np.zeros((0,)))
        self.netBrOut = np.asarray(nb, dtype=float).ravel().tolist() if np.size(nb) else []
        fr = cv['frt']
        self.limMode = char(fr, 'limMode')
        self.pShape = scalar(fr, 'pShape', 0.0)
        self.frt = {k: scalar(fr, k) for k in ('qFloor', 'qGain', 'relCv', 'relTb', 'relTau', 'relTf')}
        self.flavour = char(A, 'flavour')
        self.matlab = char(A, 'matlab')
        self.has_tap = 'tap' in A and all(k in A['tap'] for k in ('units', 'iL_d', 'iL_q', 'dphi'))
        self.tap_units = num(A['tap'], 'units').ravel().astype(int).tolist() if self.has_tap else []
        kinds = self.IBR[:, 2]
        self.gfm_units = [int(k) for k in np.nonzero(kinds == 2)[0] + 1]     # v2: the archive's own sets
        self.gfl_units = [int(k) for k in np.nonzero(kinds == 1)[0] + 1]     # (RULE S3 addendum 2)
        if strict:
            assert self.gfm_units == list(GFM_UNITS), 'GFM units differ from 7-10'

    def close(self):
        self.F.close()

    def ch(self, name):
        """A per-unit or per-bus channel, (N, columns); None when absent or MATLAB-empty."""
        if name not in self.A:
            return None
        x = num(self.A, name)
        if x is None or x.size == 0:
            return None
        x = np.asarray(x, dtype=float)          # num() already transposed MATLAB's (N, cols) back to (N, cols)
        sizes = (self.t.size, self.tf.size if self.tf is not None else -1)
        if x.shape[0] not in sizes and x.ndim == 2 and x.shape[1] in sizes:
            x = x.T
        assert x.shape[0] in sizes, 'channel %s has shape %s, time bases %s' % (name, x.shape, sizes)
        return x

    def tap(self, name):
        if not self.has_tap:
            return None
        x = np.asarray(num(self.A['tap'], name), dtype=float)
        return x if x.shape[0] == self.tf.size else x.T

    # ---- constants (the census, section (1)) -------------------------------------------------------------
    def unit_const(self, unit):
        """Per-unit constants of unit `unit` (1-based) from the archive alone."""
        k = unit - 1
        Sb = self.Sb
        D = self.IBR[k, 3]
        M = self.IBR[k, 4]
        Srated = self.IBR[k, 8] * Sb
        b = int(self.bus[k])
        w0 = 2 * np.pi * self.Fref
        return dict(unit=unit, k=k, bus=b,
                    Pstar_pu=self.IBR[k, 5], Pstar_W=self.IBR[k, 5] * Sb,          # the model's converter layer
                    D=D, M=M, kappa_pu=w0 / D,                                    # rad/s per pu on Sb (tst_reader 265)
                    Srated_W=Srated,
                    Imax_pu=self.iLimPu * Srated / (Sb * self.Vref[b - 1]),       # pu on Sb at Vref (map_reader 176)
                    Bc_pu=self.C_gfm_pu,                                          # pu on Sb (w0 C Zb, 345 kV)
                    c=self.pShape, T1=1.0 / self.lpf_wc if self.lpf_wc > 0 else np.nan,
                    T2=M / D if D > 0 else np.nan)


def runs(mask):
    """(start, end) inclusive index pairs of the True runs of a boolean vector (tst_reader.runs)."""
    m = np.concatenate([[False], np.asarray(mask, bool), [False]])
    d = np.diff(m.astype(int))
    s = np.nonzero(d == 1)[0]
    e = np.nonzero(d == -1)[0] - 1
    return list(zip(s, e))
