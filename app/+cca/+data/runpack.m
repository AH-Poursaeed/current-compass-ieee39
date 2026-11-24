function R = runpack(D, key, code, file)
%RUNPACK  The shipped traces of one run, from app/data/runs, checked against their index (sha256).
%   R = cca.data.runpack(D, '39_1000_10TF', 'v')            the run of that scenario under that control
%   R = cca.data.runpack(D, key, code, 'runs/<tag>.json')   the run of that file (the list's trace field)
%   R is [] when no traces of that run ship. R.meta (the export's header), R.series.<name>.t (s after clearing)
%   and .y (the bin extremes in temporal order), R.index (the index entry), R.origin = "archived".
R = [];
runs = D.runs;
if iscell(runs)
    runs = [runs{:}];
end
if nargin < 4
    file = '';
end
file = regexprep(char(file), '^runs/', '');
for i = 1:numel(runs)
    if (isempty(file) && strcmp(runs(i).key, char(key)) && strcmp(runs(i).code, char(code))) || ...
            (~isempty(file) && strcmp(runs(i).file, file))
        f = fullfile(D.root, 'data', 'runs', runs(i).file);
        bytes = fileread_bytes(f);
        if ~strcmpi(sha256hex(bytes), runs(i).sha256)
            error('cca:data:runHash', 'The run file %s does not match its index (sha256).', runs(i).file);
        end
        J = jsondecode(native2unicode(bytes, 'UTF-8'));
        R.index = runs(i);
        R.meta = rmfield(J, 'series');
        R.origin = "archived";
        names = fieldnames(J.series);
        for k = 1:numel(names)
            s = J.series.(names{k});
            dt = (s.t2 - s.t1) / s.n;
            tb = s.t1 + dt * (0:s.n - 1);
            t = reshape([tb + 0.25 * dt; tb + 0.75 * dt], 1, []);
            v = s.v;
            if iscell(v)   % an array of nulls only
                v = nan(numel(v), 1);
            end
            y = double(v(:)).';
            R.series.(names{k}) = struct('t', t, 'y', y);
        end
        return
    end
end
end

function b = fileread_bytes(f)
fid = fopen(f, 'r');
if fid < 0
    error('cca:data:runFile', 'The run file %s is missing.', f);
end
c = onCleanup(@() fclose(fid));
b = fread(fid, Inf, '*uint8').';
end

function h = sha256hex(b)
md = java.security.MessageDigest.getInstance('SHA-256');
md.update(b);
d = typecast(md.digest(), 'uint8');
h = lower(reshape(dec2hex(d, 2).', 1, []));
end
