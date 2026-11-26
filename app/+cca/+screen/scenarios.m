function S = scenarios(host, D, T, app)
%SCENARIOS  Screen 05: the common scenarios by fault bus. At each fault bus a ring of one sector for the Current
%   Compass and one for each compared setting, clockwise from the top: a sector is red where the law loses
%   synchronism on at least one scenario at that bus, blue where it returns on every scenario there where it is
%   eligible, grey where it is not eligible on any. The cells are app_grid.json's; nothing is computed beyond
%   counting them.
G = D.grid;
P = G.parsed;
if iscell(P), P = [P{:}]; end
bus = [P.bus];
cls = G.cls(:).';
cells = char(G.cells);
nCol = size(cells, 2);
g = uigridlayout(host, [1 2], 'ColumnWidth', {'1x', 580}, 'RowHeight', {'1x'}, 'Padding', [0 0 0 0], ...
    'ColumnSpacing', T.px.gutter, 'BackgroundColor', T.c.ground);
mapP = uipanel(g, 'BackgroundColor', T.c.surface, 'BorderType', 'line', 'BorderColor', T.c.border);
mapP.Layout.Column = 1;
mg = uigridlayout(mapP, [2 1], 'RowHeight', {'1x', 40}, 'Padding', [14 10 14 10], 'BackgroundColor', T.c.surface);
ax = uiaxes(mg);
ax.Layout.Row = 1;
leg = uilabel(mg, 'Text', sprintf(['Each ring: one sector for the Current Compass and one for each compared ' ...
    'setting, clockwise from the top in the order of %s. Red: lost on at least one scenario at the bus; blue: ' ...
    'returns on every scenario at the bus where it is eligible; grey: not eligible there. Click a ring.'], ...
    cca.data.paperref(D, "table", "cc_tab_set")), ...
    'FontName', T.font.chrome, 'FontSize', 11, 'FontColor', T.c.ink2, 'WordWrap', 'on');
leg.Layout.Row = 2;
side = uipanel(g, 'BackgroundColor', T.c.surface, 'BorderType', 'line', 'BorderColor', T.c.border);
side.Layout.Column = 2;
sg = uigridlayout(side, [6 1], 'RowHeight', {22, 30, 22, '1x', 34, 34}, 'Padding', [16 10 16 12], ...
    'RowSpacing', 6, 'BackgroundColor', T.c.surface);
uilabel(sg, 'Text', 'Scenarios', 'FontName', T.font.chromeBold, 'FontSize', 15, 'FontColor', T.c.ink);
isS = strcmp(cls, 'SHORT');
dur = [P.dur_ms] / 1000;
chips = uigridlayout(sg, [1 3], 'ColumnWidth', {'fit', 'fit', 'fit'}, 'Padding', [0 0 0 0], 'ColumnSpacing', 6, ...
    'BackgroundColor', T.c.surface);
chips.Layout.Row = 2;
cAll = uibutton(chips, 'state', 'Text', sprintf('All . %d', numel(bus)), 'Value', true, 'FontSize', 11);
cS = uibutton(chips, 'state', 'Text', sprintf('%g to %g s', min(dur(isS)), max(dur(isS))), 'FontSize', 11);
cL = uibutton(chips, 'state', 'Text', sprintf('%g to %g s', min(dur(~isS)), max(dur(~isS))), 'FontSize', 11);
busLabel = uilabel(sg, 'Text', '', 'FontName', T.font.chromeBold, 'FontSize', 13, 'FontColor', T.c.ink);
busLabel.Layout.Row = 3;
tbl = uitable(sg, 'ColumnName', {'Scenario', 'Load, network', 'Current Compass', 'Compared settings lost'}, ...
    'RowName', {}, 'ColumnWidth', {110, 160, 112, 'auto'}, ...
    'FontName', T.font.chrome, 'FontSize', 11, 'SelectionType', 'row', 'Multiselect', 'off');
tbl.Layout.Row = 4;
bRun = uibutton(sg, 'Text', 'Open in Run', 'FontName', T.font.chromeBold, 'FontSize', 13, ...
    'BackgroundColor', T.c.accent, 'FontColor', T.c.white);
bRun.Layout.Row = 5;
bCmp = uibutton(sg, 'Text', 'Open in Compare', 'FontName', T.font.chrome, 'FontSize', 13);
bCmp.Layout.Row = 6;
buses = unique(bus);
setCommon = cca.ui.runset(D, G.keys);
% each scenario's load and network state in the list's own words (the Current Compass's row of the scenario), so
% that two scenarios at one bus never read alike
loadNet = repmat({''}, numel(G.keys), 1);
if isfield(D, 'runlist')
    Rl = D.runlist;
    iv = find(strcmp(Rl.code, 'v'));
    [tf, loc] = ismember(G.keys(:), Rl.key(iv));
    loadNet(tf) = strcat(Rl.load(iv(loc(tf))), {', '}, Rl.network(iv(loc(tf))));
end
sel = struct('bus', buses(1), 'mask', true(size(bus)), 'keys', {{}});
cAll.ValueChangedFcn = @(~, ~) setFilter('all');
cS.ValueChangedFcn = @(~, ~) setFilter('SHORT');
cL.ValueChangedFcn = @(~, ~) setFilter('LONG');
tbl.SelectionChangedFcn = @(~, e) onRow(e);
bRun.ButtonPushedFcn = @(~, ~) openIn("run");
bCmp.ButtonPushedFcn = @(~, ~) openIn("compare");
draw();
pickBus(buses(1));

S.grid = g;
S.onShow = [];
S.handles = struct('axes', ax, 'table', tbl);
S.pickBus = @pickBus;
S.help = cca.ui.help(app, T, helpContent(D, numel(bus), cS.Text, cL.Text));

    function setFilter(which)
        cAll.Value = strcmp(which, 'all');
        cS.Value = strcmp(which, 'SHORT');
        cL.Value = strcmp(which, 'LONG');
        switch which
            case 'all', sel.mask = true(size(bus));
            otherwise, sel.mask = strcmp(cls, which);
        end
        draw();
        pickBus(sel.bus);
    end

    function draw()
        cla(ax);
        hold(ax, 'on');
        nb = numel(buses);
        ncols = 5;
        for k = 1:nb
            b = buses(k);
            cx = mod(k - 1, ncols) * 3;
            cy = -floor((k - 1) / ncols) * 3;
            m = bus == b & sel.mask;
            for j = 1:nCol
                a0 = pi / 2 - (j - 1) * 2 * pi / nCol;
                a1 = a0 - 2 * pi / nCol;
                tt = linspace(a0, a1, 12);
                xs = [cx + 0.55 * cos(tt), cx + 1.15 * cos(fliplr(tt))];
                ys = [cy + 0.55 * sin(tt), cy + 1.15 * sin(fliplr(tt))];
                c = cells(m, j);
                if isempty(c) || all(c == 'N')
                    f = T.c.sunken;
                elseif any(c == 'L')
                    f = T.c.lossInk;
                elseif j == 1
                    f = T.c.soft;
                else
                    f = T.c.ret;
                end
                pa = patch(ax, xs, ys, f, 'EdgeColor', T.c.surface, 'LineWidth', 1);
                pa.ButtonDownFcn = @(~, ~) pickBus(b);
            end
            if any(m)
                txt = sprintf('bus %d\n%d', b, nnz(m));
            else
                txt = sprintf('bus %d\n-', b);
            end
            t = text(ax, cx, cy, txt, 'HorizontalAlignment', 'center', 'FontName', T.font.plot, 'FontSize', 10, ...
                'Color', T.c.ink);
            t.ButtonDownFcn = @(~, ~) pickBus(b);
            if b == sel.bus
                th = linspace(0, 2 * pi, 90);
                plot(ax, cx + 1.3 * cos(th), cy + 1.3 * sin(th), '-', 'Color', T.c.ink, 'LineWidth', 1.2);
            end
        end
        hold(ax, 'off');
        axis(ax, 'equal');
        ax.Visible = 'off';
        ax.Toolbar.Visible = 'off';
        disableDefaultInteractivity(ax);
    end

    function pickBus(b)
        sel.bus = b;
        draw();
        m = find(bus == b & sel.mask);
        rows = cell(numel(m), 4);
        for q = 1:numel(m)
            i = m(q);
            c = cells(i, :);
            rows(q, :) = {cca.data.scenario(D, G.keys{i}, "short"), loadNet{i}, verdict(c(1)), sprintf('%d of %d', ...
                sum(c(2:end) == 'L'), sum(c(2:end) ~= 'N'))};
        end
        sel.keys = G.keys(m);
        tbl.Data = rows;
        busLabel.Text = sprintf('bus %d: %d scenarios', b, numel(m));
        if ~isempty(m)
            tbl.Selection = 1;
        end
    end

    function onRow(e)
        if isempty(e.Selection), return, end
        app.state.Key = sel.keys{e.Selection(1)};
    end

    function openIn(name)
        % the scenario chosen, in Run (its runs in the list of the paper's runs, the set of the common scenarios
        % read from that list) or in Compare
        r = tbl.Selection;
        if isempty(r) && ~isempty(sel.keys), r = 1; end
        if ~isempty(r)
            a = {'Key', sel.keys{r(1)}};
            if name == "run" && isprop(app.state, 'Set')
                a = [a, {'Set', setCommon}];
            end
            app.state.set(a{:});
        end
        app.show(name);
    end
end

function w = verdict(ch)
switch ch
    case 'R', w = 'returns';
    case 'L', w = 'lost';
    otherwise, w = 'not eligible';
end
end

function C = helpContent(D, nScen, shortLabel, longLabel)
% the page of explanations of the Scenarios screen (cca.ui.help): the common scenarios in the paper's words, the
% rings, the table and its buttons; every number read from the data
ref = @(kind, key) cca.data.paperref(D, kind, key);
q = '';
if isfield(D.paper, 'texts') && isfield(D.paper.texts, 'section_iv')
    P = cellstr(D.paper.texts.section_iv);
    k = find(contains(P, 'common scenarios are'), 1);
    if ~isempty(k), q = P{k}; end
end
C.title = 'How to read the Scenarios screen';
C.intro = {['The Scenarios screen shows the common scenarios by the bus of the fault: one ring a bus and one sector ' ...
    'a law. It shows at a glance at which buses the compared settings lose synchronism and where the Current ' ...
    'Compass stays synchronised.']};
C.sections = [ ...
    cca.ui.helpsec('The common scenarios', {sprintf(['Every law is compared on these %d scenarios: %s prints the ' ...
    'losses of each law on them in its column Lost, and %s and %s count them too.'], nScen, ...
    ref("table", "cc_tab_set"), ref("table", "cc_tab_parts"), ref("figure", "cc_fig_compare"))}, cell(0, 2), q, ...
    sprintf('The paper, %s:', ref("section", "cc_sec4_test_system"))), ...
    cca.ui.helpsec('The rings', {sprintf(['Each ring is one fault bus; the numbers in it are the bus and the number ' ...
    'of scenarios at that bus. A ring has one sector for the Current Compass and one for each compared setting, ' ...
    'clockwise from the top in the order of %s. A red sector: the law loses synchronism on at least one scenario ' ...
    'at that bus. A blue sector: it returns on every scenario at that bus where it is eligible. A grey sector: it ' ...
    'is not eligible on any of them. Click a ring, or the bus name inside it, to list its scenarios.'], ...
    ref("table", "cc_tab_set"))}), ...
    cca.ui.helpsec('The table and the buttons', {sprintf(['The table lists the scenarios of the chosen bus: the ' ...
    'fault (its type and duration), the load and network state, the outcome of the Current Compass, and "a of ' ...
    'b": a compared settings lose synchronism of the b that are eligible on that scenario. The buttons above it ' ...
    'keep all the scenarios, the short ones (%s) or the long ones (%s). Select a row, then click Open in Run (its ' ...
    'runs in the list of the paper''s runs) or Open in Compare (its row marked in the grid).'], shortLabel, ...
    longLabel)}), ...
    cca.ui.explain(D, "eligible"), ...
    cca.ui.explain(D, "test")];
end
