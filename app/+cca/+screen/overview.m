function S = overview(host, D, T, app)
%OVERVIEW  Screen 01: the idea (the dial and the three channels), the test network, three headline results and
%   the path Problem - Idea - Proof - Evidence. Every number is a leaf of app/data.
lf = @(p) cca.data.leaf(D, p);
fm = @cca.ui.fmt;
pr = @(p) printedOf(D, p);
g = uigridlayout(host, [3 2], 'RowHeight', {420, 172, '1x'}, 'ColumnWidth', {'1x', 516}, ...
    'Padding', [0 0 0 0], 'RowSpacing', T.px.gutter, 'ColumnSpacing', T.px.gutter, 'BackgroundColor', T.c.ground);

% ------------------------------------------------------------------ the idea
C = cca.ui.card(g, T, "The idea", "Turn the saturated current, not the converter.");
C.panel.Layout.Row = 1; C.panel.Layout.Column = 1;
b = C.body;
b.RowHeight = {'1x', 34};
b.ColumnWidth = {'1x', 256};
b.ColumnSpacing = 12;
ax = uiaxes(b);
ax.Layout.Row = 1; ax.Layout.Column = 1;
key = runKey(D);
try     % the measured trail of a run that a figure of the paper draws, where its traces ship
    info = cca.ui.dial(ax, T, D, cca.data.runpack(D, key, 'v'));
catch
    info = cca.ui.dial(ax, T, D, []);
end
chan = uigridlayout(b, [3 1], 'RowHeight', {'1x', '1x', '1x'}, 'Padding', [0 0 0 0], 'RowSpacing', 4, ...
    'BackgroundColor', T.c.surface);
chan.Layout.Row = 1; chan.Layout.Column = 2;
K = D.constants;
channel(chan, 1, T, T.c.cap, 'Power cap', 'q = \min(P^{*},\, c\,|v|\, I_m)', ...
    'the setpoint shrinks with the terminal voltage, so the frame''s rate is bounded in proportion to it');
channel(chan, 2, T, T.c.rot, 'Rotation', '\dot{\psi} = k_q\,(Q_f - Q_t),\;\; 0 \le \psi \le \pi/2', ...
    'turns the saturated current toward lagging, up to a quarter turn');
channel(chan, 3, T, T.c.rel, 'Release', ['v_f > ' sprintf('%g', K.release_ratio.value) '\, v_{\min}:\;\; ' ...
    '\dot{\psi} = -\psi/\tau_r'], ['latches once the filtered voltage recovers, or after the time-out of ' ...
    cca.data.paperref(D, "table", "cc_tab_par") ', never reached; local signals only']);
cap = uilabel(b, 'Text', info.caption, 'FontName', T.font.chrome, 'FontSize', 11, 'FontColor', T.c.ink2, ...
    'WordWrap', 'on', 'VerticalAlignment', 'top');
cap.Layout.Row = 2; cap.Layout.Column = [1 2];

% ------------------------------------------------------------------ the test network
fig5 = figureEntry(D, 'cc_fig_oneline');
N = cca.ui.card(g, T, "The test", "Where the faults are", TitleSize=15, TitleFont="chrome");
N.panel.Layout.Row = 1; N.panel.Layout.Column = 2;
nb = N.body;
nb.RowHeight = {18, '1x', 22, 18, 18};
nb.RowSpacing = 4;
sub = uilabel(nb, 'Text', sprintf('converter-only IEEE %d-bus system, %s: %d grid-following and %d grid-forming units', ...
    lf('system.n_bus'), cca.data.paperref(D, "figure", "cc_fig_oneline"), lf('system.n_gfl'), lf('system.n_gfm')), ...
    'FontName', T.font.chrome, 'FontSize', 12, 'FontColor', T.c.ink2);
sub.Layout.Row = 1;
im = uiimage(nb, 'ImageSource', fullfile(D.root, fig5.asset), 'ScaleMethod', 'fit');
im.Layout.Row = 2;
[nAll, nBus, busLost, busList, busAll] = busSummary(D);
chips = uigridlayout(nb, [1 nBus + 1], 'ColumnWidth', [{'fit'}, repmat({'1x'}, 1, nBus)], 'Padding', [0 0 0 0], ...
    'ColumnSpacing', 3, 'BackgroundColor', T.c.surface);
chips.Layout.Row = 3;
uilabel(chips, 'Text', 'Fault buses', 'FontName', T.font.chrome, 'FontSize', 11, 'FontColor', T.c.ink3);
for q = 1:nBus
    if busAll(q)
        bg = T.c.soft; fc = T.c.accent;
    else
        bg = T.c.lossInk; fc = T.c.white;
    end
    uilabel(chips, 'Text', sprintf('%d', busList(q)), 'FontName', T.font.chromeBold, 'FontSize', 11, ...
        'FontColor', fc, 'BackgroundColor', bg, 'HorizontalAlignment', 'center');
end
l1 = uilabel(nb, 'Text', sprintf(['%s  blue: the Current Compass returns on every scenario at the bus ' ...
    '(%d of %d fault buses)'], char(9679), nAll, nBus), 'FontName', T.font.chrome, 'FontSize', 12, ...
    'FontColor', T.c.ink2);
l1.Layout.Row = 4;
if isempty(busLost)
    busLost = 'a fault bus where it loses a scenario (none in this set)';
end
l2 = uilabel(nb, 'Text', [char(9679) '  red: ' busLost], 'FontName', T.font.chrome, 'FontSize', 12, ...
    'FontColor', T.c.ink2);
l2.Layout.Row = 5;

% ------------------------------------------------------------------ the three headline cards
h3 = uigridlayout(g, [1 3], 'ColumnWidth', {'1x', '1x', '1x'}, 'Padding', [0 0 0 0], ...
    'ColumnSpacing', T.px.gutter, 'BackgroundColor', T.c.ground);
h3.Layout.Row = 2; h3.Layout.Column = [1 2];
% card 1: the law's median return time as the paper prints it (Table III's leaf; the paper prints no per-run
% list behind it, so the card shows the number and its place)
tabParts = cca.data.paperref(D, "table", "cc_tab_parts");
[c1, top1] = headline(h3, 1, T, "Return time after clearing", ...
    fm('secHundredths', lf('s60r.v6.p_rt.rows.v.median_s')), ...
    sprintf('the median return time of the Current Compass, as %s prints it', tabParts), false);
% card 2: fault-on active power against the law of code k, the paired median that Section V prints (its leaf
% and its count of the short three-phase scenarios where both return)
kName = lawName(D, 'k');
[c2, top2] = headline(h3, 2, T, "Active power during the fault", ...
    fm('mw', lf('s60r.v6.p_pairs.v_k.D_PF.S3.median')), ...
    sprintf(['more fault-on active power than %s: the median of the paired differences on all %d short ' ...
    'three-phase scenarios where both return'], [lower(kName(1)) kName(2:end)], ...
    lf('s60r.v6.p_pairs.v_k.verdicts.S3.both_return')), false);
% card 3: theory on the record (the sealed tests on the runs of the application's set), in the paper's print forms
tsv = lf('s60r.v6.r15.pooled.tests.T-S4.violations');
tsn = lf('s60r.v6.r15.pooled.tests.T-S4.samples_v');
[c3, top3, ax3] = headline(h3, 3, T, "Theory on the record", ...
    sprintf('%d', tsv), ...
    sprintf('violations of the drift bound of %s, in %s saturated capped fault-on samples of the law''s %d runs', ...
    cca.data.paperref(D, "section", "cc_sec2_saturated_unit"), pr('s60r.v6.r15.pooled.tests.T-S4.samples_v_print'), ...
    lf('s60r.v6.r15.pooled.tests.T-S4.rows_v')), true);
nIn = tsn - tsv;
barh(ax3, 1, nIn, 0.5, 'FaceColor', T.c.accent, 'EdgeColor', 'none');
hold(ax3, 'on');
barh(ax3, 1, tsv, 0.5, 'FaceColor', T.c.lossInk, 'EdgeColor', 'none');
hold(ax3, 'off');
x3 = {sprintf('%s within the bound, %d outside', pr('s60r.v6.r15.pooled.tests.T-S4.samples_v_print'), tsv)};
if isKey(D.leafmap, 's60r.v6.r15.pooled.tests.T-S1.median')     % carried only where the record holds it as a number
    x3{end + 1} = sprintf('the circle of %s: a median %s from the circle (%s saturated samples)', ...
        cca.data.paperref(D, "statement", "the circle"), pr('s60r.v6.r15.pooled.tests.T-S1.median_print'), ...
        pr('s60r.v6.r15.pooled.tests.T-S1.n_print'));
end
styleMini(ax3, T, x3);
ax3.XLabel.FontSize = 9;
ax3.XLim = [0 tsn];
ax3.YLim = [0.5 1.5];
ax3.YTick = [];
ax3.XTick = [];
ax3.XColor = 'none';
ax3.XLabel.Color = T.c.ink2;

% ------------------------------------------------------------------ the path strip
ps = uipanel(g, 'BackgroundColor', T.c.surface, 'BorderType', 'line', 'BorderColor', T.c.border);
ps.Layout.Row = 3; ps.Layout.Column = [1 2];
pg = uigridlayout(ps, [1 4], 'ColumnWidth', {'1x', '1x', '1x', '1x'}, 'Padding', [20 10 20 10], ...
    'ColumnSpacing', 24, 'BackgroundColor', T.c.surface);
nLaws = numel(lf('chain.census.form.compared_laws'));
step(pg, 1, T, 'Problem', 'See one fault in Run', ...
    'In a deep fault a current-limited grid-forming converter can drift and lose synchronism.', @() go("run"));
step(pg, 2, T, 'Idea', 'Open the law in Model', ...
    'Scale the power by the voltage; turn the saturated current toward lagging.', @() go("model"));
step(pg, 3, T, 'Proof', 'Read the equations', ...
    sprintf('%s, %s and %s: one unit with first-order droop behind a network.', ...
    cca.data.paperref(D, "statement", "the cap's balances"), cca.data.paperref(D, "statement", "the loop with its clamp"), ...
    cca.data.paperref(D, "statement", "a turning network")), @() go("model"));
step(pg, 4, T, 'Evidence', 'Open Compare', sprintf(['%d common scenarios, %d compared settings; the ladder with ' ...
    'its %s and its %s; %s.'], lf('s60r.v6.r15.sets.c101.n_keys'), nLaws, ...
    lf('s60r.v6.r16.sets.r3.print'), lf('s60r.v6.r16.sets.r1.print'), lf('s60r.v6.r16.sets.r2.print')), ...
    @() go("compare"));

S.grid = g;
S.onShow = [];
S.handles = struct('dial', ax, 'cards', {{c1, c2, c3}}, 'tops', {{top1, top2, top3}});

    function go(name)
        if name == "run" && ~isempty(key)
            a = {'Key', key, 'Code', 'v', 'View', 'traces'};
            if isprop(app.state, 'Set')
                a = [a, {'Set', ''}];
            end
            app.state.set(a{:});
        end
        app.show(name);
    end
end

% ======================================================================================================== helpers
function k = runKey(D)
runs = D.runs;
if iscell(runs), runs = [runs{:}]; end
k = '';
for i = 1:numel(runs)
    if strcmp(runs(i).code, 'v')
        k = runs(i).key;
        return
    end
end
end

function e = figureEntry(D, key)
F = D.paper.figures;
if iscell(F), F = [F{:}]; end
e = F(strcmp({F.key}, key));
end

function n = lawName(D, code)
L = D.laws;
if iscell(L), L = [L{:}]; end
n = L(strcmp({L.code}, code)).name;
end

function P = parsedKeys(D)
pk = D.grid.parsed;
if iscell(pk), pk = [pk{:}]; end
P.bus = [pk.bus];
P.dur = [pk.dur_ms] / 1000;
P.short = strcmp(D.grid.cls(:).', 'SHORT');
end

function [nAll, nBus, txt, buses, isAll] = busSummary(D)
% the Compass's column of the grid by fault bus (a count of cells of app_grid.json)
P = parsedKeys(D);
cells = char(D.grid.cells);
v = cells(:, 1).';
buses = unique(P.bus);
nBus = numel(buses);
isAll = false(1, nBus);
nAll = 0;
txt = '';
for q = 1:nBus
    b = buses(q);
    m = P.bus == b;
    if all(v(m) == 'R')
        nAll = nAll + 1;
        isAll(q) = true;
    else
        lostDur = unique(P.dur(m & v == 'L'));
        txt = sprintf('bus %d: %d of %d return; %d lost (faults of %s s)', b, sum(v(m) == 'R'), sum(m), ...
            sum(v(m) == 'L'), strjoin(compose('%g', lostDur), ' and '));
    end
end
end

function channel(parent, row, T, colour, name, tex, words)
g = uigridlayout(parent, [3 2], 'RowHeight', {18, 24, '1x'}, 'ColumnWidth', {3, '1x'}, ...
    'Padding', [0 0 0 0], 'RowSpacing', 2, 'ColumnSpacing', 10, 'BackgroundColor', T.c.surface);
g.Layout.Row = row;
bar = uipanel(g, 'BackgroundColor', colour, 'BorderType', 'none');
bar.Layout.Row = [1 3]; bar.Layout.Column = 1;
n = uilabel(g, 'Text', name, 'FontName', T.font.chromeBold, 'FontSize', 13, 'FontColor', T.c.ink);
n.Layout.Row = 1; n.Layout.Column = 2;
e = uilabel(g, 'Text', ['$' tex '$'], 'Interpreter', 'latex', 'FontSize', 14, 'FontColor', T.c.ink);
e.Layout.Row = 2; e.Layout.Column = 2;
w = uilabel(g, 'Text', words, 'FontName', T.font.chrome, 'FontSize', 11, 'FontColor', T.c.ink2, ...
    'WordWrap', 'on', 'VerticalAlignment', 'top');
w.Layout.Row = 3; w.Layout.Column = 2;
end

function [C, top, ax] = headline(parent, col, T, eyebrow, big, side, withPlot)
% a headline card: the number, its words beside it and, where the card draws one, a small plot below (a card
% without a plot gives its words the whole height)
C = cca.ui.card(parent, T, eyebrow, "");
C.panel.Layout.Column = col;
b = C.body;
b.ColumnWidth = {'fit', '1x'};
b.ColumnSpacing = 14;
if withPlot
    b.RowHeight = {56, '1x'};
else
    b.RowHeight = {'1x'};
end
top = uilabel(b, 'Text', big, 'FontName', T.font.display, 'FontSize', 38, 'FontColor', T.c.accent);
top.Layout.Row = 1; top.Layout.Column = 1;
s = uilabel(b, 'Text', side, 'FontName', T.font.chrome, 'FontSize', 11.5, 'FontColor', T.c.ink2, ...
    'WordWrap', 'on', 'VerticalAlignment', 'center');
s.Layout.Row = 1; s.Layout.Column = 2;
ax = [];
if withPlot
    ax = uiaxes(b);
    ax.Layout.Row = 2; ax.Layout.Column = [1 2];
end
end

function s = printedOf(D, path)
% the paper's print form of one printed leaf (app_printed.json, the numbers view's data)
P = D.printed;
if iscell(P), P = [P{:}]; end
m = P(strcmp({P.path}, path));
if isempty(m)
    s = 'not in the record';
else
    s = m(1).printed;
end
end

function styleMini(ax, T, xl)
ax.FontName = T.font.plot;
ax.FontSize = 10;
ax.Box = 'off';
ax.XColor = T.c.axis;
ax.YColor = T.c.axis;
ax.TickDir = 'out';
ax.Color = T.c.surface;
ax.XLabel.String = xl;
ax.XLabel.FontSize = 10;
ax.XLabel.Color = T.c.ink2;
ax.Toolbar.Visible = 'off';
disableDefaultInteractivity(ax);
end

function step(parent, col, T, name, link, words, fn)
g = uigridlayout(parent, [2 3], 'RowHeight', {20, '1x'}, 'ColumnWidth', {24, 'fit', '1x'}, ...
    'Padding', [0 0 0 0], 'RowSpacing', 2, 'ColumnSpacing', 8, 'BackgroundColor', T.c.surface);
g.Layout.Column = col;
num = uilabel(g, 'Text', sprintf('%d', col), 'FontName', T.font.chromeBold, 'FontSize', 12, ...
    'FontColor', T.c.accent, 'BackgroundColor', T.c.tint, 'HorizontalAlignment', 'center');
num.Layout.Row = 1; num.Layout.Column = 1;
n = uilabel(g, 'Text', name, 'FontName', T.font.chromeBold, 'FontSize', 13, 'FontColor', T.c.ink);
n.Layout.Row = 1; n.Layout.Column = 2;
h = uihyperlink(g, 'Text', [link ' ' char(8250)], 'FontName', T.font.chrome, 'FontSize', 12, ...
    'FontColor', T.c.accent, 'VisitedColor', T.c.accent, 'HyperlinkClickedFcn', @(~, ~) fn());
h.Layout.Row = 1; h.Layout.Column = 3;
w = uilabel(g, 'Text', words, 'FontName', T.font.chrome, 'FontSize', 11, 'FontColor', T.c.ink2, ...
    'WordWrap', 'on', 'VerticalAlignment', 'top');
w.Layout.Row = 2; w.Layout.Column = [2 3];
end
