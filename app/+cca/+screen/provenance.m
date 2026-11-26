function S = provenance(host, D, T, app)
%PROVENANCE  Screen 07: where each printed number comes from: every leaf of app/data with its path in the released
%   record, and every file of the application's data (the manifest's files and pictures, the released record, the
%   run files of the figures) with its bytes and sha256.
g = uigridlayout(host, [3 1], 'RowHeight', {34, '1x', 210}, 'Padding', [0 0 0 0], 'RowSpacing', T.px.gutter, ...
    'BackgroundColor', T.c.ground);
top = uigridlayout(g, [1 3], 'ColumnWidth', {360, '1x', 'fit'}, 'Padding', [0 0 0 0], 'ColumnSpacing', 12, ...
    'BackgroundColor', T.c.ground);
ef = uieditfield(top, 'text', 'Placeholder', 'Search a number or a leaf path', 'FontName', T.font.chrome, ...
    'FontSize', 13);
rec = D.record;
M = struct();
if isfield(D, 'manifest')
    M = D.manifest;
end
gen = '';
if isfield(M, 'record') && isfield(M.record, 'generated_utc')
    gen = sprintf('; the application''s data written %s', M.record.generated_utc);
end
info = uilabel(top, 'Text', sprintf('Released record %s, its newest group %s (%s)%s', rec.sha256_8, rec.group, ...
    rec.date, gen), 'FontName', T.font.chrome, 'FontSize', 12, 'FontColor', T.c.ink2);
info.Layout.Column = 2;
% the leaves
k = keys(D.leafmap);
vals = cellfun(@(p) cca.data.safetext(D.leafmap(p)), k, 'UniformOutput', false);
tl = uitable(g, 'Data', [k(:), vals(:)], 'ColumnName', {'Path in the released record', 'Value'}, 'RowName', {}, ...
    'ColumnWidth', {520, 'auto'}, 'FontName', T.font.chrome, 'FontSize', 11);
tl.Layout.Row = 2;
ef.ValueChangingFcn = @(~, e) filterRows(e.Value);
ef.ValueChangedFcn = @(~, e) filterRows(e.Value);     % a value set without typing (a paste) filters too
% the files: the released record, the manifest's data files and pictures, and the run files of the figures
rowsF = cell(0, 4);
files = asList(rec, 'files');
for i = 1:numel(files)
    rowsF(end + 1, :) = {files(i).file, 'the released record', cca.ui.fmt('count', files(i).bytes), files(i).sha256}; %#ok<AGROW>
end
mf = asList(M, 'files');
for i = 1:numel(mf)
    w = '';
    if isfield(mf, 'from')   % the manifest's words up to their first clause, so that the cell shows them whole
        w = regexprep(mf(i).from, '\s*[:(;].*$', '');
    end
    rowsF(end + 1, :) = {['app/data/' mf(i).file], w, cca.ui.fmt('count', mf(i).bytes), mf(i).sha256}; %#ok<AGROW>
end
ma = asList(M, 'assets');
for i = 1:numel(ma)
    rowsF(end + 1, :) = {['app/' ma(i).file], 'a picture that the application shows', ...
        cca.ui.fmt('count', ma(i).bytes), ma(i).sha256}; %#ok<AGROW>
end
runs = D.runs;
if iscell(runs), runs = [runs{:}]; end
for i = 1:numel(runs)
    r = runs(i);
    if ~isfield(r, 'file')
        continue
    end
    f = ['app/data/runs/' r.file];
    if ~any(strcmp(rowsF(:, 1), f))
        rb = '';
        rh = '';
        if isfield(r, 'bytes'), rb = cca.ui.fmt('count', r.bytes); end
        if isfield(r, 'sha256'), rh = r.sha256; end
        rowsF(end + 1, :) = {f, 'the traces of a run that a figure of the paper draws', rb, rh}; %#ok<AGROW>
    end
end
tf = uitable(g, 'Data', rowsF, 'ColumnName', {'File', 'What it is', 'Bytes', 'sha256'}, ...
    'RowName', {}, 'ColumnWidth', {300, 'auto', 80, 470}, 'FontName', T.font.chrome, 'FontSize', 11);
tf.Layout.Row = 3;
S.grid = g;
S.onShow = [];
S.handles = struct('leaves', tl, 'files', tf, 'search', ef);
S.help = cca.ui.help(app, T, helpContent(numel(k), size(rowsF, 1)));

    function filterRows(q)
        q = lower(strtrim(q));
        if isempty(q)
            tl.Data = [k(:), vals(:)];
            return
        end
        kk = k(:);
        vv = vals(:);
        m = contains(lower(kk), q) | contains(lower(vv), q);
        tl.Data = [kk(m), vv(m)];
    end
end

function C = helpContent(nLeaves, nFiles)
% the page of explanations of the Provenance screen (cca.ui.help)
C.title = 'How to read the Provenance screen';
C.intro = {['The Provenance screen says where each number of the screens comes from. No number that the application ' ...
    'prints is typed in its program: each one is read from its data, the released record and the files that the ' ...
    'data step makes from it, when the application starts.']};
C.sections = [ ...
    cca.ui.helpsec('The line at the top', {sprintf(['It names the released record by the start of its hash (%s), ' ...
    'its newest group of numbers and its date, and the time at which the data of the application were written. ' ...
    'The pill at the right of the top bar names the same record.'], 'sha256')}), ...
    cca.ui.helpsec('The upper table', {sprintf(['Every value that the screens read (%d values): its path in the ' ...
    'released record and its value, in full precision. Type a number or a part of a path in the search box to ' ...
    'keep the rows that hold it.'], nLeaves)}), ...
    cca.ui.helpsec('The lower table', {sprintf(['Every file of the data of the application (%d files): the file, ' ...
    'what it is (the released record, a file regenerated from it, a file shipped as data, a picture, or the ' ...
    'recorded traces of a run of the paper), its size in bytes and its hash. The Regenerate button of the ' ...
    'Reproduce screen makes the regenerated files again and compares them with these hashes.'], nFiles)}), ...
    cca.ui.helpsec('Two lists of numbers', {['This screen lists the values that the screens read, by their paths ' ...
    'in the released record. The tile Numbers of the Reproduce screen lists every number that the paper prints, ' ...
    'with its place and a name made from its path. The released record (app/data/record/released_record.json) ' ...
    'holds both.']})];
end

function x = asList(s, f)
% a list field of the data (a struct array, a cell of structs, or absent) as a struct array
x = struct('file', {}, 'bytes', {}, 'sha256', {});
if isstruct(s) && isfield(s, f) && ~isempty(s.(f))
    x = s.(f);
    if iscell(x), x = [x{:}]; end
end
end
