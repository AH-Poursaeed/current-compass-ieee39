function S = about(host, D, T, app)
%ABOUT  Screen 08: how to cite the work, its licence and the third-party notice, the authors, what it needs to
%   run, and the version of the data it shows. The texts are the repository's own files (app/data/app_text.json).
X = D.text;
g = uigridlayout(host, [1 2], 'ColumnWidth', {'1x', 380}, 'RowHeight', {'1x'}, 'Padding', [0 0 0 0], ...
    'ColumnSpacing', T.px.gutter, 'BackgroundColor', T.c.ground);
L = uigridlayout(g, [3 1], 'RowHeight', {'1x', '1x', '1x'}, 'Padding', [0 0 0 0], 'RowSpacing', T.px.gutter, ...
    'BackgroundColor', T.c.ground);
c1 = cca.ui.card(L, T, "Cite this work", D.paper.title, TitleSize=14, TitleFont="chrome");
c1.panel.Layout.Row = 1;
c1.body.RowHeight = {'1x', 30};
ta1 = uitextarea(c1.body, 'Value', txt(X, 'citation'), 'Editable', 'off', 'FontName', 'Consolas', 'FontSize', 11);
ta1.Layout.Row = 1;
b1 = uibutton(c1.body, 'Text', 'Copy citation', 'FontName', T.font.chrome, 'FontSize', 12, ...
    'ButtonPushedFcn', @(~, ~) app.act('Copy the citation to the clipboard', @() clipboard('copy', txt(X, 'citation'))));
b1.Layout.Row = 2;
c2 = cca.ui.card(L, T, "Licence", "", TitleSize=14);
c2.panel.Layout.Row = 2;
uitextarea(c2.body, 'Value', txt(X, 'licence'), 'Editable', 'off', 'FontName', 'Consolas', 'FontSize', 11);
c3 = cca.ui.card(L, T, "Third-party notice", "", TitleSize=14);
c3.panel.Layout.Row = 3;
uitextarea(c3.body, 'Value', txt(X, 'notices'), 'Editable', 'off', 'FontName', 'Consolas', 'FontSize', 11);
R = uigridlayout(g, [3 1], 'RowHeight', {'1x', 170, 200}, 'Padding', [0 0 0 0], 'RowSpacing', T.px.gutter, ...
    'BackgroundColor', T.c.ground);
R.Layout.Column = 2;
c4 = cca.ui.card(R, T, "Authors", "", TitleSize=14);
c4.panel.Layout.Row = 1;
uitextarea(c4.body, 'Value', txt(X, 'authors'), 'Editable', 'off', 'FontName', T.font.chrome, 'FontSize', 11);
c5 = cca.ui.card(R, T, "Requirements", "", TitleSize=14);
c5.panel.Layout.Row = 2;
req = sprintf(['To read the record: MATLAB (this window).\nTo regenerate the application''s numbers: Python 3 ' ...
    '(app/tools/make_app_data.py; the Reproduce screen''s button runs it and compares every file with ' ...
    'app/data/MANIFEST.json).\nThe model''s files join this repository when the paper is published.']);
uilabel(c5.body, 'Text', req, 'FontName', T.font.chrome, 'FontSize', 11, 'FontColor', T.c.ink2, ...
    'WordWrap', 'on', 'VerticalAlignment', 'top');
c6 = cca.ui.card(R, T, "Version", "", TitleSize=14);
c6.panel.Layout.Row = 3;
rec = D.record;
runs = D.runs;
if iscell(runs), runs = [runs{:}]; end
ver = sprintf('Released record %s (sha256 of %s), group %s (%s).', rec.sha256_8, rec.files(1).file, rec.group, ...
    rec.group_state);
if ~isempty(runs) && isfield(runs, 'matlab')
    ver = sprintf('%s\nThe traces shown were made with MATLAB %s.', ver, strjoin(unique({runs.matlab}), ', '));
end
ver = sprintf('%s\nThis window runs MATLAB %s.', ver, version);
if isfield(X, 'acknowledgment') && ~isempty(X.acknowledgment)   % only while the paper prints it
    ver = sprintf('%s\n%s', ver, X.acknowledgment);
end
uilabel(c6.body, 'Text', ver, 'FontName', T.font.chrome, 'FontSize', 11, 'FontColor', T.c.ink2, ...
    'WordWrap', 'on', 'VerticalAlignment', 'top');
S.grid = g;
S.onShow = [];
S.handles = struct('copy', b1);
end

function s = txt(X, f)
if isfield(X, f) && ~isempty(X.(f))
    s = X.(f);
else
    s = 'not in the record';
end
end
