function S = model(host, D, T, app)
%MODEL  Screen 06: the test system and the controls (a tree), the look-inside walk (read-only pictures of the
%   model's levels: the network, one grid-forming converter, its controller, the proposed law), and the law's
%   equations and constants. Every picture is a file under app/assets (read-only pictures printed from the
%   model; this screen never opens the model).
lf = @(p) cca.data.leaf(D, p);
L = D.laws;
if iscell(L), L = [L{:}]; end
g = uigridlayout(host, [1 3], 'ColumnWidth', {330, '1x', 300}, 'RowHeight', {'1x'}, 'Padding', [0 0 0 0], ...
    'ColumnSpacing', T.px.gutter, 'BackgroundColor', T.c.ground);

% ------------------------------------------------------------------ left: the tree
left = uipanel(g, 'BackgroundColor', T.c.surface, 'BorderType', 'line', 'BorderColor', T.c.border);
left.Layout.Column = 1;
lg = uigridlayout(left, [3 1], 'RowHeight', {22, '1x', 120}, 'Padding', [14 10 14 12], 'RowSpacing', 8, ...
    'BackgroundColor', T.c.surface);
uilabel(lg, 'Text', 'The model', 'FontName', T.font.chromeBold, 'FontSize', 15, 'FontColor', T.c.ink);
tr = uitree(lg, 'FontName', T.font.chrome, 'FontSize', 11);
tr.Layout.Row = 2;
sysNode = uitreenode(tr, 'Text', sprintf('IEEE %d-bus system, converters only', lf('system.n_bus')));
uitreenode(sysNode, 'Text', sprintf('%d buses', lf('system.n_bus')));
uitreenode(sysNode, 'Text', sprintf('%.2f MW of load', lf('system.load_MW')));
un = uitreenode(sysNode, 'Text', sprintf('%d converter units', lf('system.n_unit')));
uitreenode(un, 'Text', sprintf('%d grid-forming', lf('system.n_gfm')));
uitreenode(un, 'Text', sprintf('%d grid-following', lf('system.n_gfl')));
ctlNode = uitreenode(tr, 'Text', sprintf('The Current Compass and %d compared settings', numel(L) - 1));
nodes = gobjects(numel(L), 1);
for i = 1:numel(L)
    nodes(i) = uitreenode(ctlNode, 'Text', L(i).name, 'NodeData', L(i).code);
end
expand(sysNode); expand(ctlNode);
lawCard = uilabel(lg, 'Text', '', 'FontName', T.font.chrome, 'FontSize', 12, 'FontColor', T.c.ink2, ...
    'WordWrap', 'on', 'VerticalAlignment', 'top');
lawCard.Layout.Row = 3;
tr.SelectionChangedFcn = @(~, e) onNode(e);

% ------------------------------------------------------------------ centre: the look-inside walk
mid = uipanel(g, 'BackgroundColor', T.c.surface, 'BorderType', 'line', 'BorderColor', T.c.border);
mid.Layout.Column = 2;
mg = uigridlayout(mid, [4 1], 'RowHeight', {22, 30, '1x', 58}, 'Padding', [16 10 16 12], 'RowSpacing', 8, ...
    'BackgroundColor', T.c.surface);
uilabel(mg, 'Text', 'Look inside', 'FontName', T.font.chromeBold, 'FontSize', 15, 'FontColor', T.c.ink);
crumbs = uigridlayout(mg, [1 9], 'ColumnWidth', repmat({'fit'}, 1, 9), 'Padding', [0 0 0 0], ...
    'ColumnSpacing', 4, 'BackgroundColor', T.c.surface);
crumbs.Layout.Row = 2;
% the picture's own ground: a fitted picture fills its panel without bands of another colour around it
picHost = uigridlayout(mg, [1 1], 'Padding', [0 0 0 0], 'BackgroundColor', T.c.surface, 'Scrollable', 'on');
picHost.Layout.Row = 3;
nav = uigridlayout(mg, [1 4], 'ColumnWidth', {72, '1x', 60, 72}, 'Padding', [0 0 0 0], 'ColumnSpacing', 8, ...
    'BackgroundColor', T.c.surface);
nav.Layout.Row = 4;
bBack = uibutton(nav, 'Text', [char(8249) ' Back'], 'FontName', T.font.chrome, 'FontSize', 12);
bBack.Layout.Column = 1;
cap = uilabel(nav, 'Text', '', 'FontName', T.font.chrome, 'FontSize', 11, 'FontColor', T.c.ink2, ...
    'WordWrap', 'on', 'HorizontalAlignment', 'center');
cap.Layout.Column = 2;
bFit = uibutton(nav, 'state', 'Text', 'Fit', 'Value', true, 'FontName', T.font.chrome, 'FontSize', 12, ...
    'Tooltip', 'Fit the picture to the panel, or show it at full size and scroll');
bFit.Layout.Column = 3;
bFit.ValueChangedFcn = @(~, ~) go(level);
bNext = uibutton(nav, 'Text', ['Next ' char(8250)], 'FontName', T.font.chrome, 'FontSize', 12);
bNext.Layout.Column = 4;
fig1 = figEntry(D, 'cc_fig_system');
lv = struct( ...
    'name', {'Network', 'Converter', 'Controller', 'Current Compass'}, ...
    'file', {viewOf(fullfile(D.root, 'assets', 'model', 'level1_network.png')), ...
             viewOf(fullfile(D.root, 'assets', 'model', 'level2_converter.png')), ...
             viewOf(fullfile(D.root, 'assets', 'model', 'level3_controller.png')), ...
             fullfile(D.root, fig1.asset)}, ...
    'words', {sprintf('The network as the builder lays it out from the one-line master (%s).', ...
              cca.data.paperref(D, "figure", "cc_fig_oneline")), ...
              'One grid-forming converter unit: its controller, its power stage and its measurements.', ...
              ['The unit''s controller: the frame, the voltage loop and the block Iref, which computes the ' ...
              'limited current reference where the law acts. Values are shown as symbols.'], ...
              sprintf('The proposed law as drawn in the paper (%s): the cap, the rotation and the release.', ...
              cca.data.paperref(D, "figure", "cc_fig_system"))});
% the fitted network copy carries the bus numbers of the one-line master: its caption says so, where the copy's
% record of the overlay exists
fitWords = {lv.words};
if isfile(strrep(fullfile(D.root, 'assets', 'model', 'level1_network.png'), '.png', '_overlay.txt'))
    fitWords{1} = sprintf('From the one-line master (%s), bus numbers overlaid; lower left: the bus frequency PLLs.', ...
        cca.data.paperref(D, "figure", "cc_fig_oneline"));
end
level = 1;
bBack.ButtonPushedFcn = @(~, ~) go(level - 1);
bNext.ButtonPushedFcn = @(~, ~) go(level + 1);
go(1);

% ------------------------------------------------------------------ right: the equations and the constants
right = uipanel(g, 'BackgroundColor', T.c.surface, 'BorderType', 'line', 'BorderColor', T.c.border);
right.Layout.Column = 3;
rg = uigridlayout(right, [13 1], 'RowHeight', {22, 14, 30, 14, 30, 30, 14, 30, 30, 14, 30, 64, '1x'}, ...
    'Padding', [16 10 16 12], 'RowSpacing', 4, 'BackgroundColor', T.c.surface);
uilabel(rg, 'Text', 'The law', 'FontName', T.font.chromeBold, 'FontSize', 15, 'FontColor', T.c.ink);
K = D.constants;
eqrow(rg, 2, 3, T, 'Power cap, its factor at the unit''s rating', 'q = \min(P^{*},\; c\,|v|\,I_m),\;\; c = 1/I_m');
eqrow(rg, 4, 5, T, 'Rotation of the saturated current', 'I_r = I_m\, e^{\,j(\varphi_0 - \psi)},\;\; \varphi_0 = \arg I_c');
eqrow(rg, 0, 6, T, '', '\dot{\psi} = k_q\,(Q_f - Q_t),\;\; 0 \le \psi \le \pi/2');
eqrow(rg, 7, 8, T, 'Release', sprintf('v_f > %g\\, v_{\\min}\\;\\Rightarrow\\; \\dot{\\psi} = -\\psi/\\tau_r', K.release_ratio.value));
eqrow(rg, 0, 9, T, '', '\theta'' = \kappa\,(q - P),\;\; |\theta''| \le \kappa\,(1+c)\,|v|\,I_m');
eqrow(rg, 10, 11, T, 'Constants of the law in the runs', '');
msOf = @(s) s * 1000;
cst = sprintf(['cap factor c = %g by the rule %s, at the current limit I_m = %g pu\nQ_f = %g pu    k_q = %g ' ...
    'rad/s per pu\nT_f = %g ms    tau_r = %g ms    time-out %g s, never reached\n(%s)'], K.c.value, ...
    K.cap_rule.option, K.I_m.value, K.Q_f.value, K.k_q.value, msOf(K.T_f.value), msOf(K.tau_r.value), ...
    K.timer_s.value, cca.data.paperref(D, "table", "cc_tab_par"));
cl = uilabel(rg, 'Text', cst, 'FontName', T.font.chrome, 'FontSize', 11, 'FontColor', T.c.ink2, 'WordWrap', 'on', ...
    'VerticalAlignment', 'top');
cl.Layout.Row = [11 12];
st = D.paper.statements;
if iscell(st), st = [st{:}]; end
th = strjoin(arrayfun(@(x) sprintf('%s %d (%s), %s', x.kind, x.number, x.name, ...
    cca.data.paperref(D, "section", x.module)), st, 'UniformOutput', false), newline);
% the current limits of the robustness table, named from the leaves (Table IV's set)
lim = '';
if isKey(D.leafmap, 's60r.v6.r15.lim.limits_print')
    lim = sprintf('Also run at the current limits %s pu on the %d scenarios of %s, with %s.', ...
        lf('s60r.v6.r15.lim.limits_print'), lf('s60r.v6.r15.sets.s18.n_keys'), ...
        cca.data.paperref(D, "table", "cc_tab_rob"), lf('s60r.v6.r15.lim.cap_rule'));
    lim = [lim newline newline];
end
tl = uilabel(rg, 'Text', [lim 'Proved in the paper:' newline th], 'FontName', T.font.chrome, 'FontSize', 11, ...
    'FontColor', T.c.ink2, 'WordWrap', 'on', 'VerticalAlignment', 'top');
tl.Layout.Row = 13;

S.grid = g;
S.onShow = [];
S.handles = struct('tree', tr, 'next', bNext, 'back', bBack, 'fit', bFit, 'pic', picHost);
S.go = @go;
S.level = @getLevel;

    function v = getLevel()
        v = level;
    end

    function go(k)
        k = max(1, min(numel(lv), k));
        level = k;
        delete(crumbs.Children);
        for q = 1:numel(lv)
            if q > 1
                uilabel(crumbs, 'Text', char(8250), 'FontColor', T.c.ink3, 'FontSize', 12);
            end
            if q == k
                uilabel(crumbs, 'Text', lv(q).name, 'FontName', T.font.chromeBold, 'FontSize', 12, ...
                    'FontColor', T.c.accent);
            else
                h = uihyperlink(crumbs, 'Text', lv(q).name, 'FontName', T.font.chrome, 'FontSize', 12, ...
                    'FontColor', T.c.ink2, 'VisitedColor', T.c.ink2);
                h.HyperlinkClickedFcn = @(~, ~) go(q);
            end
        end
        delete(picHost.Children);
        if isfile(lv(k).file)
            if bFit.Value
                picHost.RowHeight = {'1x'};
                picHost.ColumnWidth = {'1x'};
                im = uiimage(picHost, 'ImageSource', lv(k).file, 'ScaleMethod', 'fit');
            else
                f = printOf(lv(k).file);       % full size: the print itself, where its names are legible
                info = imfinfo(f);
                picHost.RowHeight = {info.Height};
                picHost.ColumnWidth = {info.Width};
                im = uiimage(picHost, 'ImageSource', f, 'ScaleMethod', 'none');
            end
            im.Layout.Row = 1;
            im.Layout.Column = 1;
            if bFit.Value
                cap.Text = fitWords{k};
            else
                cap.Text = lv(k).words;
            end
        else
            uilabel(picHost, 'Text', lv(k).words, 'WordWrap', 'on', 'FontName', T.font.chrome, 'FontSize', 13, ...
                'FontColor', T.c.ink2, 'HorizontalAlignment', 'center');
            cap.Text = lv(k).words;
        end
        bBack.Enable = k > 1;
        bNext.Enable = k < numel(lv);
    end

    function onNode(e)
        n = e.SelectedNodes;
        if isempty(n) || isempty(n.NodeData)
            return
        end
        w = L(strcmp({L.code}, n.NodeData));
        tot = D.grid.totals.(w.code);
        lawCard.Text = sprintf(['%s\nfamily: %s; setting: %s\nlost on %d of the %d common scenarios where it is ' ...
            'eligible (%s)'], w.name, w.group, w.setting, tot.n_lost, tot.n_eligible, ...
            cca.data.paperref(D, "table", "cc_tab_set"));
        app.state.Code = w.code;
    end
end

function eqrow(parent, rowLabel, rowEq, T, label, tex)
if rowLabel > 0 && strlength(label) > 0
    l = uilabel(parent, 'Text', label, 'FontName', T.font.chromeBold, 'FontSize', 11, 'FontColor', T.c.ink2);
    l.Layout.Row = rowLabel;
end
if strlength(tex) > 0
    e = uilabel(parent, 'Text', ['$' tex '$'], 'Interpreter', 'latex', 'FontSize', 14, 'FontColor', T.c.ink);
    e.Layout.Row = rowEq;
end
end

function f = viewOf(f)
% the display copy of a level picture, where it exists
v = strrep(f, '.png', '_view.png');
if isfile(v)
    f = v;
end
end

function f = printOf(f)
% the print a display copy was made from, where it exists
p = strrep(f, '_view.png', '.png');
if ~strcmp(p, f) && isfile(p)
    f = p;
end
end

function e = figEntry(D, key)
F = D.paper.figures;
if iscell(F), F = [F{:}]; end
e = F(strcmp({F.key}, key));
end
