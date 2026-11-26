function S = reproduce(host, D, T, app)
%REPRODUCE  Screen 02: the paper's figures and tables of this build (app_paper.json): a gallery of cards and a
%   detail panel. A figure shows its file, its sha256 and where it comes from; a table shows every cell and note as
%   the paper prints them (Table IV with its 18 scenarios, its cells rebuilt from the number record by the data step).
%   "Regenerate the application's data" runs the data step into a temporary folder and compares every file it
%   writes with app/data/MANIFEST.json, byte for byte (cca.data.regenerate). The card Numbers lists every printed
%   number of the paper by its place (app_printed.json, regenerated from the released record), searchable.
F = D.paper.figures;
if iscell(F), F = [F{:}]; end
X = D.paper.tables;
if iscell(X), X = [X{:}]; end
g = uigridlayout(host, [1 2], 'ColumnWidth', {'1x', 460}, 'RowHeight', {'1x'}, 'Padding', [0 0 0 0], ...
    'ColumnSpacing', T.px.gutter, 'BackgroundColor', T.c.ground);
nItems = numel(F) + numel(X) + 1;
nRows = ceil(nItems / 4);
gal = uigridlayout(g, [nRows 4], 'RowHeight', repmat({200}, 1, nRows), 'ColumnWidth', {'1x', '1x', '1x', '1x'}, ...
    'Padding', [0 0 0 0], 'RowSpacing', 12, 'ColumnSpacing', 12, 'BackgroundColor', T.c.ground, 'Scrollable', 'on');
gal.Layout.Column = 1;
det = uipanel(g, 'BackgroundColor', T.c.surface, 'BorderType', 'line', 'BorderColor', T.c.border);
det.Layout.Column = 2;
dg = uigridlayout(det, [6 1], 'RowHeight', {26, 280, '1x', 70, 34, 30}, 'Padding', [16 10 16 12], ...
    'RowSpacing', 8, 'BackgroundColor', T.c.surface);
tg = uigridlayout(dg, [1 2], 'ColumnWidth', {'1x', 'fit'}, 'Padding', [0 0 0 0], 'BackgroundColor', T.c.surface);
tg.Layout.Row = 1;
dTitle = uilabel(tg, 'Text', '', 'FontName', T.font.chromeBold, 'FontSize', 15, 'FontColor', T.c.ink);
bBack = uibutton(tg, 'Text', [char(8249) ' Back to the gallery'], 'FontName', T.font.chrome, 'FontSize', 12, ...
    'Visible', 'off');
bBack.ButtonPushedFcn = @(~, ~) showFig(1);
dImgHost = uigridlayout(dg, [1 1], 'Padding', [0 0 0 0], 'BackgroundColor', T.c.sunken);
dImgHost.Layout.Row = 2;
dCap = uitextarea(dg, 'Editable', 'off', 'FontName', T.font.chrome, 'FontSize', 12, 'FontColor', T.c.ink2, ...
    'BackgroundColor', T.c.surface);
dCap.Layout.Row = 3;
dFile = uilabel(dg, 'Text', '', 'FontName', T.font.chrome, 'FontSize', 11, 'FontColor', T.c.ink3, ...
    'WordWrap', 'on', 'VerticalAlignment', 'top');
dFile.Layout.Row = 4;
bRegen = uibutton(dg, 'Text', 'Regenerate the application''s data', 'FontName', T.font.chrome, 'FontSize', 13);
bRegen.Layout.Row = 5;
bRegen.ButtonPushedFcn = @(~, ~) app.act(['Run the data step (app/tools/make_app_data.py) into a temporary ' ...
    'folder and compare every file with app/data/MANIFEST.json'], @() regen());
rNote = uilabel(dg, 'Text', '', 'FontName', T.font.chrome, 'FontSize', 11, 'FontColor', T.c.ink3, 'WordWrap', 'on');
rNote.Layout.Row = 6;
shown = struct('cells', {{}}, 'bold', false(0), 'heads', {{}}, 'html', []);
k = 0;
for i = 1:numel(F)
    k = k + 1;
    if isShown(F(i))
        card(k, sprintf('Fig. %d', F(i).number), shortWords(F(i).caption), fullfile(D.root, F(i).file), ...
            @() showFig(i));
    else
        card(k, sprintf('Fig. %d', F(i).number), notShown(), '', @() showFig(i));
    end
end
for i = 1:numel(X)
    k = k + 1;
    card(k, sprintf('Table %s', X(i).number), shortWords(X(i).title), '', @() showTab(i));
end
card(k + 1, 'Numbers', 'Every printed number of the paper, by its place', '', @() showNumbers());
showFig(1);

S.grid = g;
S.onShow = [];
S.handles = struct('gallery', gal, 'detail', dg, 'regenerate', bRegen, 'host', dImgHost, 'caption', dCap, ...
    'note', rNote, 'showTable', @(i) showTab(i), 'runRegeneration', @() regen(), ...
    'showNumbers', @() showNumbers(), 'shownTable', @getShown);
S.help = cca.ui.help(app, T, helpContent(D, F, X));

    function s = getShown()
        % the table shown now: its cells (the head row first), their bold flags, the spanning heads, the html
        s = shown;
    end

    function card(k, head, words, img, fn)
        p = uipanel(gal, 'BackgroundColor', T.c.surface, 'BorderType', 'line', 'BorderColor', T.c.border);
        p.Layout.Row = ceil(k / 4);
        p.Layout.Column = mod(k - 1, 4) + 1;
        cg = uigridlayout(p, [3 1], 'RowHeight', {110, 18, '1x'}, 'Padding', [10 8 10 8], 'RowSpacing', 4, ...
            'BackgroundColor', T.c.surface);
        if strlength(img) > 0 && isfile(img)
            im = uiimage(cg, 'ImageSource', img, 'ScaleMethod', 'fit');
            im.ImageClickedFcn = @(~, ~) fn();
        else
            word = 'Table';
            if startsWith(head, 'Fig'), word = 'Figure'; end
            if startsWith(head, 'Num'), word = 'Numbers'; end
            h = uibutton(cg, 'Text', word, 'FontName', T.font.display, 'FontSize', 18, ...
                'BackgroundColor', T.c.sunken, 'FontColor', T.c.ink2);
            h.ButtonPushedFcn = @(~, ~) fn();
        end
        h1 = uilabel(cg, 'Text', head, 'FontName', T.font.chromeBold, 'FontSize', 12, 'FontColor', T.c.ink);
        h1.Layout.Row = 2;
        w = uilabel(cg, 'Text', words, 'FontName', T.font.chrome, 'FontSize', 11, 'FontColor', T.c.ink2, ...
            'WordWrap', 'on', 'VerticalAlignment', 'top');
        w.Layout.Row = 3;
    end

    function setWide(on)
        % a table and the numbers view take the screen's whole width (every column shows), a figure the side
        % panel beside the gallery
        bBack.Visible = matlab.lang.OnOffSwitchState(on);
        gal.Visible = matlab.lang.OnOffSwitchState(~on);
        if on                             % the tallest table (Table II) fits; its note shows whole below it
            g.ColumnWidth = {0, '1x'};
            dg.RowHeight{2} = 380;
            dg.RowHeight{4} = 44;
            dImgHost.BackgroundColor = T.c.surface;
        else
            g.ColumnWidth = {'1x', 460};
            dg.RowHeight{2} = 280;
            dg.RowHeight{4} = 70;
            dImgHost.BackgroundColor = T.c.sunken;
        end
    end

    function showFig(i)
        f = F(i);
        setWide(false);
        dTitle.Text = sprintf('Fig. %d', f.number);
        delete(dImgHost.Children);
        rNote.Text = '';
        if ~isShown(f)
            uilabel(dImgHost, 'Text', notShown(), 'FontName', T.font.display, 'FontSize', 16, ...
                'FontColor', T.c.ink2, 'WordWrap', 'on', 'HorizontalAlignment', 'center');
            dCap.Value = notShown();
            dFile.Text = '';
            return
        end
        p = fullfile(D.root, f.file);
        if isfile(p)
            uiimage(dImgHost, 'ImageSource', p, 'ScaleMethod', 'fit');
        end
        dCap.Value = f.caption;
        dFile.Text = sprintf('File %s, %s bytes, sha256 %s. From: %s.', f.file, cca.ui.fmt('count', f.bytes), ...
            f.sha256, f.regen);
    end

    function showTab(i)
        t = X(i);
        setWide(true);
        dTitle.Text = sprintf('Table %s', t.number);
        delete(dImgHost.Children);
        rNote.Text = '';
        [C, B] = cellsOf(t.cells);
        heads = {};
        if isfield(t, 'heads') && ~isempty(t.heads)   % the spanning heads over the columns they span
            heads = headList(t.heads);
        end
        % the table as the paper prints it: every cell, the heads wrapped, the bold cells bold, the spanning heads
        h = uihtml(dImgHost, 'HTMLSource', tableHtml(C, B, heads, T));
        shown = struct('cells', {C}, 'bold', B, 'heads', {heads}, 'html', h);
        words = {t.title; ''};
        if ~isempty(t.notes)
            words = [words; reshape(cellstr(t.notes), [], 1)];
        end
        if strcmp(t.key, 'cc_tab_rob') && isfield(D.grid, 'robust')
            words = [words; {''}; robustWords()];
        end
        dCap.Value = words;
        dFile.Text = sprintf('From: %s.', t.regen);
    end

    function showNumbers()
        % the numbers view: every printed number of the paper (place, a name made from its path, the paper's print
        % form), filtered as the search field is typed in
        Pn = D.printed;
        if iscell(Pn), Pn = [Pn{:}]; end
        rowsAll = [{Pn.place}.', {Pn.printed}.', {Pn.name}.'];
        setWide(true);
        dTitle.Text = 'The paper''s printed numbers';
        delete(dImgHost.Children);
        rNote.Text = '';
        ng = uigridlayout(dImgHost, [2 1], 'RowHeight', {26, '1x'}, 'Padding', [0 0 0 0], 'RowSpacing', 4, ...
            'BackgroundColor', T.c.sunken);
        ef = uieditfield(ng, 'text', 'Placeholder', 'Search by place, name or printed value', ...
            'FontName', T.font.chrome, 'FontSize', 11);
        ef.Layout.Row = 1;
        tb = uitable(ng, 'Data', rowsAll, 'ColumnName', {'Place', 'Printed', 'Name'}, 'RowName', {}, ...
            'FontName', T.font.chrome, 'FontSize', 11, 'ColumnWidth', {130, 150, '1x'});
        tb.Layout.Row = 2;
        ef.ValueChangingFcn = @(~, e) set(tb, 'Data', pickRows(rowsAll, e.Value));
        ef.ValueChangedFcn = @(~, e) set(tb, 'Data', pickRows(rowsAll, e.Value));
        dCap.Value = {sprintf('Every printed number of the paper: %d numbers in %d places, each in the paper''s print form.', ...
            numel(Pn), numel(unique({Pn.place}))); ''; ['Each is regenerated from the released record by the data ' ...
            'step; its name is made from its path in the record.']};
        dFile.Text = 'From: regenerated from the released record (app/data/app_printed.json).';
    end

    function w = robustWords()
        % Table IV's scenarios: the record's keys (R140.sets.s18.keys) in the words of Section IV; at the cap
        % factor of the a/b cell, whether the scenario is among the eligible ones (the record's own lists)
        Rb = D.grid.robust;
        K = cellstr(Rb.keys);
        el = cellstr(Rb.capf_0p7.eligible_keys);
        w = {sprintf('The %d scenarios of the table (cap factor %g: eligible or not):', Rb.n, Rb.capf_0p7.cap_factor)};
        for j = 1:numel(K)
            e = 'not eligible';
            if any(strcmp(K{j}, el)), e = 'eligible'; end
            w{end + 1, 1} = sprintf('%s; %s', cca.data.scenario(D, K{j}), e); %#ok<AGROW>
        end
    end

    function regen()
        rNote.Text = 'Running the data step...';
        drawnow;
        [R, info] = cca.data.regenerate(D);
        setWide(true);
        delete(dImgHost.Children);
        dTitle.Text = 'Regeneration of the application''s numbers';
        if isempty(R)
            uilabel(dImgHost, 'Text', 'The data step did not finish; its output is below.', ...
                'FontName', T.font.display, 'FontSize', 14, 'FontColor', T.c.ink2, 'WordWrap', 'on', ...
                'HorizontalAlignment', 'center');
            dCap.Value = cellstr(splitlines(string(info.output)));
            dFile.Text = info.command;
            if info.started
                rNote.Text = sprintf('The data step exited with status %d.', info.status);
            else
                rNote.Text = 'No Python could be started here: the data step needs Python.';
            end
            return
        end
        res = repmat({'equal'}, numel(R), 1);
        res(~[R.equal]) = {'different'};
        uitable(dImgHost, 'Data', [{R.file}.', res, {R.from}.'], 'ColumnName', {'File', 'Result', 'From'}, ...
            'RowName', {}, 'FontName', T.font.chrome, 'FontSize', 11, 'ColumnWidth', {200, 80, '1x'});
        dCap.Value = cellstr(splitlines(string(info.output)));
        dFile.Text = 'Each file compared byte for byte, by its hash, with app/data/MANIFEST.json.';
        rNote.Text = sprintf('%d of %d files equal.', info.equal, info.of);
    end
end

function [C, B] = cellsOf(rows)
% the cells of a table of app_paper.json (a struct array of rows, each with its cells c and their bold flags b) as a
% cell matrix and a logical matrix
if iscell(rows), rows = [rows{:}]; end
n = numel(rows);
m = 0;
for i = 1:n
    m = max(m, numel(cellstr(rows(i).c)));
end
C = repmat({''}, n, m);
B = false(n, m);
for i = 1:n
    c = cellstr(rows(i).c);
    C(i, 1:numel(c)) = reshape(c, 1, []);
    if isfield(rows(i), 'b') && ~isempty(rows(i).b)
        b = logical(rows(i).b(:).');
        B(i, 1:numel(b)) = b;
    end
end
end

function H = headList(heads)
% the paper's spanning heads as a list of {head, first column, last column} (the columns counted from 1 in the table's
% first row); the data give each as such a triple or as a struct with three fields in that order
if isstruct(heads), heads = num2cell(heads); end
H = cell(numel(heads), 3);
for k = 1:numel(heads)
    e = heads{k};
    if isstruct(e)
        f = fieldnames(e);
        e = {e.(f{1}), e.(f{2}), e.(f{3})};
    end
    H(k, :) = {char(e{1}), double(e{2}), double(e{3})};
end
end

function s = tableHtml(C, B, H, T)
% a table of the paper as html: the spanning heads (H) in a first head row over their columns, the columns that no
% head spans across both head rows, then the head row and the body rows of C; a cell is bold where B says so
esc = @(x) strrep(strrep(strrep(char(x), '&', '&amp;'), '<', '&lt;'), '>', '&gt;');
cl = @(b) repmat(' class="b"', 1, b);
nc = size(C, 2);
css = T.css.table;
under = false(1, nc);
for k = 1:size(H, 1)
    under(max(1, H{k, 2}):min(nc, H{k, 3})) = true;
end
rows = {};
r = '<tr>';
if ~isempty(H)
    j = 1;
    while j <= nc
        k = find([H{:, 2}] == j, 1);
        if ~isempty(k)
            r = [r sprintf('<th class="span" colspan="%d">%s</th>', H{k, 3} - H{k, 2} + 1, esc(H{k, 1}))]; %#ok<AGROW>
            j = H{k, 3} + 1;
        else
            if ~under(j)
                r = [r sprintf('<th rowspan="2"%s>%s</th>', cl(B(1, j)), esc(C{1, j}))]; %#ok<AGROW>
            end
            j = j + 1;
        end
    end
    rows{end + 1} = [r '</tr>'];
    r = '<tr>';
end
for j = 1:nc
    if isempty(H) || under(j)
        r = [r sprintf('<th%s>%s</th>', cl(B(1, j)), esc(C{1, j}))]; %#ok<AGROW>
    end
end
rows{end + 1} = [r '</tr>'];
for i = 2:size(C, 1)
    r = '<tr>';
    for j = 1:nc
        r = [r sprintf('<td%s>%s</td>', cl(B(i, j)), esc(C{i, j}))]; %#ok<AGROW>
    end
    rows{end + 1} = [r '</tr>']; %#ok<AGROW>
end
s = ['<!DOCTYPE html><html><head><style>' css '</style></head><body><table>' strjoin(rows, '') ...
    '</table></body></html>'];
end

function s = shortWords(s)
% a card's words: whole words that fit the card's three lines, with an end mark where the text goes on (the whole
% text is in the detail panel)
s = char(s);
n = 62;
if numel(s) > n
    cut = find(s(1:n) == ' ', 1, 'last');
    if isempty(cut), cut = n; end
    s = [strtrim(s(1:cut)) ' ...'];
end
end

function R = pickRows(R, q)
% the rows of the numbers view that hold the search text (in any column, case ignored)
q = strtrim(char(q));
if ~isempty(q)
    R = R(any(contains(R, q, 'IgnoreCase', true), 2), :);
end
end

function tf = isShown(f)
% a figure that draws runs is shown only where app/data says so (the generator checks its file against the record)
tf = ~isfield(f, 'shown') || isempty(f.shown) || logical(f.shown);
end

function s = notShown()
s = 'This figure is not in this build of the application.';
end

function C = helpContent(D, F, X)
% the page of explanations of the Reproduce screen (cca.ui.help): a figure, how to read each figure and each table,
% the numbers view, the regeneration; every number read from the data
ref = @(kind, key) cca.data.paperref(D, kind, key);
Pn = D.printed;
if iscell(Pn), Pn = [Pn{:}]; end
W = D.runinfo.laws;
if iscell(W), W = [W{:}]; end
k9 = W(strcmp({W.code}, 'k')).law;
k9 = [lower(k9(1)) k9(2:end)];
words = struct( ...
    'cc_fig_system', ['the block diagram of one grid-forming unit under the Current Compass: the power cap, the ' ...
    'reactive supervisor that drives the rotation psi, the circular limiter with the rotation, and the release'], ...
    'cc_fig_concept', sprintf(['sketches of the idea: the phasors at the balance A, the line P = P* against the ' ...
    'circle of %s, the rays of the cap meeting the circle of a dip, and psi rising while the reactive power is ' ...
    'below its floor and decaying after the release'], ref("statement", "the circle")), ...
    'cc_fig_circle', sprintf(['the theory measured on the controlled case of %s, one unit behind an impedance to ' ...
    'a stiff source: the circle of %s with the measured end powers, the power factor at the lock against the ' ...
    'turning rate of the source, and the measured travel of the frame against the modelled one'], ...
    ref("subsection", "The Theory Confirmed"), ref("statement", "the circle")), ...
    'cc_fig_flow', sprintf(['the flow of %s computed for the two circles of %s, with trajectories that start at ' ...
    'the onset lag and at the departure points'], ref("statement", "the loop with its clamp"), ...
    ref("figure", "cc_fig_circle")), ...
    'cc_fig_oneline', ['the one-line diagram of the test system as modelled: the buses, the converter units with ' ...
    'their ratings, the fault buses of the common scenarios and the buses of the load steps'], ...
    'cc_fig_compare', ['left: the lost runs of each row by fault duration, on the common scenarios and their ' ...
    'shortened faults, with its returns that end with a limiter engaged; right: the outcome of each row on the ' ...
    'ladder faults through both resistances, by fault bus, and on the load steps; one row a law or part'], ...
    'cc_fig_fault', sprintf(['the decisive three-phase faults through the low fault resistance (%s), one row a ' ...
    'law: the traces and bars of one of them (the caption names its bus and unit), and the instants of loss (for ' ...
    'the Current Compass, the return times) at each fault bus'], ...
    ref("subsection", sprintf('%s Decisive Faults', cca.data.leaf(D, 's60r.v6.r17.d1.n_word_cap')))));
figItems = cell(0, 2);
for i = 1:numel(F)
    if isfield(words, F(i).key)
        figItems(end + 1, :) = {sprintf('Fig. %d', F(i).number), words.(F(i).key)}; %#ok<AGROW>
    end
end
tw = struct( ...
    'cc_tab_par', 'the parameters of the test system and of the Current Compass; the note explains the droop slope, the loop gains and the step', ...
    'cc_tab_set', ['the Current Compass and the compared laws: the grant that each law needs, its setting, how ' ...
    'the one-unit harness reproduced its paper, and Lost, its losses on the common scenarios (a/b where it is ' ...
    'eligible on b of them)'], ...
    'cc_tab_parts', ['what each part of the law buys: the losses of each part on the common scenarios, the ladder ' ...
    'and the load steps, its median return time, and its returns that end with a limiter engaged'], ...
    'cc_tab_rob', sprintf(['robustness: the losses of the Current Compass and of %s with one setting varied at a ' ...
    'time; the note gives the losses of the other published laws at the four current limits of the table'], k9));
tabItems = cell(0, 2);
for i = 1:numel(X)
    if isfield(tw, X(i).key)
        tabItems(end + 1, :) = {sprintf('Table %s', X(i).number), tw.(X(i).key)}; %#ok<AGROW>
    end
end
rb = D.grid.robust;
C.title = 'How to read the Reproduce screen';
C.intro = {['The Reproduce screen holds every figure and every table of the paper, and every number that the paper ' ...
    'prints, each at its place. Click a tile of the gallery to show it on the right; a table and the list of ' ...
    'numbers take the whole width, and "Back to the gallery" returns.']};
C.sections = [ ...
    cca.ui.helpsec('A figure', {sprintf(['The right side shows the image that the paper prints, its caption in ' ...
    'the paper''s words, the file with its size and its hash (%s), and where it comes from. A figure that draws ' ...
    'runs is shown where the record confirms that its file is the one of record. Every number that a caption ' ...
    'prints is in the list of numbers.'], 'sha256')}), ...
    cca.ui.helpsec('How to read each figure', {}, figItems), ...
    cca.ui.helpsec('A table', {sprintf(['A table shows every cell as the paper prints it, with its bold cells and ' ...
    'the heads that span several columns, then its title and its notes. %s also lists its %d scenarios, each ' ...
    'marked eligible or not at the cap factor %g of its a/b cell.'], ref("table", "cc_tab_rob"), rb.n, ...
    rb.capf_0p7.cap_factor)}, tabItems), ...
    cca.ui.helpsec('The numbers', {sprintf(['The tile Numbers lists every number that the paper prints: %s ' ...
    'numbers in %d places (the abstract, the sections, the tables and the captions). Place is where the paper ' ...
    'prints it, Printed is the number as it is printed, and Name is made from its path in the released record; ' ...
    'the Provenance screen gives the path and the value. Type in the box above the list to keep the rows that ' ...
    'hold the text, for example the name of a table or a value.'], cca.ui.fmt('count', numel(Pn)), ...
    numel(unique({Pn.place})))}), ...
    cca.ui.helpsec('Regenerate the application''s data', {['The button runs the data step of the application ' ...
    '(a Python script) on the released files alone (the released record, its inputs and the campaign table) into a new ' ...
    'folder, and compares each number file that it writes with the file that the application ships, byte for ' ...
    'byte by its hash. The table that it shows has one row a file, and the line under the button gives how many ' ...
    'files are equal.']})];
end
