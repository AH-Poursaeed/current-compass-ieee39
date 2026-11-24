import sys, os, h5py, numpy as np
for tag in sys.argv[1:]:
    fn = 'case_frt_%s.mat' % tag
    if not os.path.exists(fn):
        print(tag, 'ABSENT'); continue
    sz = os.path.getsize(fn) / 1e6
    try:
        f = h5py.File(fn, 'r'); A = f['A']
        ok = bool(np.array(A['ok']).ravel()[0]) if 'ok' in A else None
        st = ''.join(chr(int(c)) for c in np.array(A['stage']).ravel()) if 'stage' in A else '?'
        n = max(A['t'].shape) if 't' in A else 0
        tsim = float(np.array(A['tsim']).ravel()[0]) if 'tsim' in A else float('nan')
        f.close()
        print(tag, 'size_MB %.1f ok %s stage %s n_cycles %d tsim %g' % (sz, ok, st, n, tsim))
    except Exception as e:
        print(tag, 'size_MB %.3f OPEN FAILED %s' % (sz, e))
