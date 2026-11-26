function S = model(host, D, T, app)
%MODEL  Screen 06: the test system and the controls (a tree), the look-inside walk (pictures of the
%   model's levels: the network, one grid-forming converter, its controller under the law chosen, that law's own
%   blocks enlarged, and for the Current Compass the paper's drawing), and the law's equations and constants. The
%   law is chosen in the drop-down above the picture or in the tree. Every picture is a file under app/assets
%   (pictures printed from the model; this screen never opens the model); the laws' pictures and their
%   words are listed in app/assets/model/law_pictures.json.
lf = @(p) cca.data.leaf(D, p);
L = D.laws;
if iscell(L), L = [L{:}]; end
O = D.others;                             % the law's parts and the circular limiter alone (Table III)
if iscell(O), O = [O{:}]; end
W = D.runinfo.laws;                       % each law as the list of the paper's runs names it, with its reference
if iscell(W), W = [W{:}]; end
X = lawIndex(D);                          % the laws' controller pictures (empty: the walk of the controller alone)
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
sysNode = uitreenode(tr, 'Text', sprintf('IEEE %d-bus system, every source a converter', lf('system.n_bus')));
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
mg = uigridlayout(mid, [5 1], 'RowHeight', {26, 30, '1x', 96, 30}, 'Padding', [16 10 16 12], 'RowSpacing', 6, ...
    'BackgroundColor', T.c.surface);
hg = uigridlayout(mg, [1 3], 'ColumnWidth', {'fit', 'fit', '1x'}, 'Padding', [0 0 0 0], 'ColumnSpacing', 10, ...
    'BackgroundColor', T.c.surface);
hg.Layout.Row = 1;
uilabel(hg, 'Text', 'Look inside', 'FontName', T.font.chromeBold, 'FontSize', 15, 'FontColor', T.c.ink);
codes = {X.laws.code};
items = cellfun(@(c) lawName(W, L, c), codes, 'UniformOutput', false);
ddLab = uilabel(hg, 'Text', 'Control shown', 'FontName', T.font.chrome, 'FontSize', 12, 'FontColor', T.c.ink2, ...
    'Visible', matlab.lang.OnOffSwitchState(~isempty(codes)));
ddLab.Layout.Column = 2;
if isempty(codes)
    ddLaw = uidropdown(hg, 'Items', {''}, 'ItemsData', {''}, 'Visible', 'off');
else
    ddLaw = uidropdown(hg, 'Items', items, 'ItemsData', codes, 'FontName', T.font.chrome, 'FontSize', 12, ...
        'Tooltip', 'The law whose controller the walk shows, as it is built in the model');
    ddLaw.ValueChangedFcn = @(~, ~) onLaw();   % a nested function reads the value at the click, not at the build
end
ddLaw.Layout.Column = 3;
crumbs = uigridlayout(mg, [1 11], 'ColumnWidth', repmat({'fit'}, 1, 11), 'Padding', [0 0 0 0], ...
    'ColumnSpacing', 4, 'BackgroundColor', T.c.surface);
crumbs.Layout.Row = 2;
% the picture's own ground: a fitted picture fills its panel without bands of another colour around it
picHost = uigridlayout(mg, [1 1], 'Padding', [0 0 0 0], 'BackgroundColor', T.c.surface, 'Scrollable', 'on');
picHost.Layout.Row = 3;
cap = uilabel(mg, 'Text', '', 'FontName', T.font.chrome, 'FontSize', 11, 'FontColor', T.c.ink2, ...
    'WordWrap', 'on', 'VerticalAlignment', 'top');
cap.Layout.Row = 4;
nav = uigridlayout(mg, [1 4], 'ColumnWidth', {72, '1x', 60, 72}, 'Padding', [0 0 0 0], 'ColumnSpacing', 8, ...
    'BackgroundColor', T.c.surface);
nav.Layout.Row = 5;
bBack = uibutton(nav, 'Text', [char(8249) ' Back'], 'FontName', T.font.chrome, 'FontSize', 12);
bBack.Layout.Column = 1;
bFit = uibutton(nav, 'state', 'Text', 'Fit', 'Value', true, 'FontName', T.font.chrome, 'FontSize', 12, ...
    'Tooltip', 'Fit the picture to the panel, or show it at full size and scroll');
bFit.Layout.Column = 3;
bFit.ValueChangedFcn = @(~, ~) refit();   % a nested function reads the level at the click, not at the build
bNext = uibutton(nav, 'Text', ['Next ' char(8250)], 'FontName', T.font.chrome, 'FontSize', 12);
bNext.Layout.Column = 4;
fig1 = figEntry(D, 'cc_fig_system');
mdir = fullfile(D.root, 'assets', 'model');
% the walk's first two levels, the same under every law
base = struct( ...
    'name', {'Network', 'Converter'}, ...
    'file', {viewOf(fullfile(mdir, 'level1_network.png')), viewOf(fullfile(mdir, 'level2_converter.png'))}, ...
    'words', {sprintf('The network as the builder lays it out from the one-line master (%s).', ...
              cca.data.paperref(D, "figure", "cc_fig_oneline")), ...
              'One grid-forming converter unit: its controller, its power stage and its measurements.'}, ...
    'fitWords', {'', ''});
base(2).fitWords = base(2).words;
base(1).fitWords = base(1).words;
% the fitted network copy carries the bus numbers of the one-line master: its caption says so, where the copy's
% record of the overlay exists
if isfile(strrep(fullfile(mdir, 'level1_network.png'), '.png', '_overlay.txt'))
    base(1).fitWords = sprintf('From the one-line master (%s), bus numbers overlaid; lower left: the bus frequency PLLs.', ...
        cca.data.paperref(D, "figure", "cc_fig_oneline"));
end
paperLevel = struct('name', 'In the paper', 'file', fullfile(D.root, fig1.asset), ...
    'words', sprintf('The proposed law as drawn in the paper (%s): the cap, the rotation and the release.', ...
    cca.data.paperref(D, "figure", "cc_fig_system")), 'fitWords', '');
paperLevel.fitWords = paperLevel.words;
law = '';
lv = base;
level = 1;
bBack.ButtonPushedFcn = @(~, ~) stepLevel(-1);
bNext.ButtonPushedFcn = @(~, ~) stepLevel(1);
if isempty(codes)
    chooseLaw('', false);
else
    chooseLaw(codes{1}, false);
end
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
S.handles = struct('tree', tr, 'next', bNext, 'back', bBack, 'fit', bFit, 'pic', picHost, 'law', ddLaw, ...
    'card', lawCard, 'caption', cap, 'crumbs', crumbs);
S.help = cca.ui.help(app, T, cca.ui.helpModel(D));   % the button How to read this screen and its page (U's words)
S.go = @go;
S.level = @getLevel;
S.levels = @getLevels;
S.law = @getLaw;
S.lawFor = @lawFor;
S.chooseLaw = @(c) chooseLaw(c, true);
S.index = X;

    function v = getLevel()
        v = level;
    end

    function n = getLevels()
        n = numel(lv);
    end

    function c = getLaw()
        c = law;
    end

    function c = lawFor(code)
        % the law whose pictures stand for a control of the tree: its own where they exist; a selected setting
        % without pictures of its own takes its published law's (the same mode of app_laws.json)
        c = '';
        if any(strcmp(codes, code))
            c = code;
            return
        end
        w = L(strcmp({L.code}, code));
        if isempty(w), return, end
        same = L(strcmp({L.mode}, w.mode) & ismember({L.code}, codes));
        if ~isempty(same)
            c = same(1).code;
        end
    end

    function stepLevel(d)
        % Back and Next: one level from the level shown now (an anonymous function would keep the level of the build)
        go(level + d);
    end

    function refit()
        % Fit: the level shown now, fitted to the panel or at full size
        go(level);
    end

    function chooseLaw(code, keepLevel)
        % the walk under the law code: the network and the converter, the controller under the law, the law's own
        % blocks, and for the Current Compass the paper's drawing; the drop-down and the tree follow the choice
        law = char(code);
        lv = base;
        e = X.laws(strcmp(codes, law));
        if isempty(e)
            % no law's picture in this build: the controller of the walk as the builder prints it
            lv(end + 1) = struct('name', 'Controller', 'file', viewOf(fullfile(mdir, 'level3_controller.png')), ...
                'words', ['The unit''s controller: the frame, the voltage loop and the block Iref, which computes ' ...
                'the limited current reference where the law acts. Values are shown as symbols.'], 'fitWords', '');
            lv(end).fitWords = lv(end).words;
            lv(end + 1) = paperLevel;
        else
            nm = lawName(W, L, law);
            what = sprintf(['%s: the controller of grid-forming unit %d at bus %d of the %d-bus model, printed ' ...
                'from the model built for its fault-free run %s at base load (no simulation). '], nm, X.unit, ...
                X.bus, lf('system.n_bus'), e.run);
            lv(end + 1) = struct('name', 'Controller', 'file', fullfile(D.root, e.controller_view), ...
                'words', [what e.words_controller], 'fitWords', [what e.words_controller]);
            bf = blockFiles(e);
            for q = 1:numel(bf)
                % the law's own blocks enlarged: one level a region of the print where they lie together; the words
                % name every own block of the law, so a level of several says which part of them it shows
                nmq = 'Blocks';
                bw = sprintf('%s, its own blocks enlarged: %s', nm, e.words_blocks);
                if numel(bf) > 1
                    nmq = sprintf('Blocks %d', q);
                    bw = sprintf('%s, its own blocks enlarged, part %d of %d: %s', nm, q, numel(bf), e.words_blocks);
                end
                lv(end + 1) = struct('name', nmq, 'file', fullfile(D.root, bf{q}), 'words', bw, ...
                    'fitWords', bw); %#ok<AGROW>
            end
            if strcmp(law, 'v')
                lv(end + 1) = paperLevel;
            end
            if ~strcmp(ddLaw.Value, law)
                ddLaw.Value = law;
            end
        end
        if keepLevel
            go(level);
        end
    end

    function go(k)
        k = max(1, min(numel(lv), k));
        level = k;
        delete(crumbs.Children);
        crumbs.ColumnWidth = repmat({'fit'}, 1, 2 * numel(lv) - 1);   % one cell a level and one a separator
        for q = 1:numel(lv)
            if q > 1
                uilabel(crumbs, 'Text', char(8250), 'FontColor', T.c.ink3, 'FontSize', 11);
            end
            if q == k
                uilabel(crumbs, 'Text', lv(q).name, 'FontName', T.font.chromeBold, 'FontSize', 11, ...
                    'FontColor', T.c.accent);
            else
                h = uihyperlink(crumbs, 'Text', lv(q).name, 'FontName', T.font.chrome, 'FontSize', 11, ...
                    'FontColor', T.c.ink2, 'VisitedColor', T.c.ink2, 'UserData', q);
                h.HyperlinkClickedFcn = @(~, ~) go(q);   % q is this link's own level, fixed for the link
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
                cap.Text = lv(k).fitWords;
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
        % a law of the tree: its card, the shared selection, and its controller in the walk
        n = e.SelectedNodes;
        if isempty(n) || isempty(n.NodeData)
            return
        end
        showCard(n.NodeData);
        c = lawFor(n.NodeData);
        if ~isempty(c) && ~strcmp(c, law)
            chooseLaw(c, true);
        end
    end

    function onLaw()
        % the drop-down: the law chosen there, in the walk, its node selected in the tree (a law of the tree) and
        % its card shown
        c = ddLaw.Value;
        chooseLaw(c, true);
        k = find(strcmp({L.code}, c), 1);
        if ~isempty(k)
            tr.SelectedNodes = nodes(k);
        end
        showCard(c);
    end

    function showCard(code)
        % the law's card: its name, family and setting, and its losses on the common scenarios (Table II's for a
        % compared law, Table III's for a part of the law), counted from the grid's cells
        w = L(strcmp({L.code}, code));
        ref = cca.data.paperref(D, "table", "cc_tab_set");
        if isempty(w)
            w = O(strcmp({O.code}, code));
            ref = cca.data.paperref(D, "table", "cc_tab_parts");
        end
        if isempty(w)
            return
        end
        if isfield(D.grid.totals, code)
            tot = D.grid.totals.(code);
            nl = tot.n_lost;
            ne = tot.n_eligible;
        else
            c = D.grid.ablation_cells.(code);
            nl = sum(c(:) == 'L');
            ne = sum(c(:) ~= 'N');
        end
        lawCard.Text = sprintf(['%s\nfamily: %s; setting: %s\nlost on %d of the %d common scenarios where it is ' ...
            'eligible (%s)'], w.name, w.group, w.setting, nl, ne, ref);
        app.state.Code = w.code;
    end
end

function X = lawIndex(D)
% the laws' controller pictures (app/assets/model/law_pictures.json); an index without laws where it is absent
X = struct('unit', NaN, 'bus', NaN, 'laws', struct('code', {}, 'run', {}, 'controller_view', {}, 'blocks', {}, ...
    'words_controller', {}, 'words_blocks', {}));
f = fullfile(D.root, 'assets', 'model', 'law_pictures.json');
if ~isfile(f)
    return
end
J = jsondecode(fileread(f));
Lw = J.laws;
if iscell(Lw), Lw = [Lw{:}]; end
keep = arrayfun(@(e) isfile(fullfile(D.root, e.controller_view)), Lw);
X.unit = J.unit;
X.bus = J.bus;
X.laws = Lw(keep);
end

function f = blockFiles(e)
% the files of a law's enlarged blocks (a list in the index, one file a region)
f = {};
if isfield(e, 'blocks') && ~isempty(e.blocks)
    f = cellstr(e.blocks);
end
f = reshape(f, 1, []);
end

function s = lawName(W, L, code)
% a law's name with its reference number, as the list of the paper's runs names it (app_runs.json), else as
% app_laws.json names it
s = code;
m = W(strcmp({W.code}, code));
if ~isempty(m)
    s = m(1).law;
    return
end
m = L(strcmp({L.code}, code));
if ~isempty(m)
    s = m(1).name;
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
