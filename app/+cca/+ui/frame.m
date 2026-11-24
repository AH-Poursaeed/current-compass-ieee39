function F = frame(host, T, title, hint)
%FRAME  The frame of one screen: the title (display face, 28), the hint line, and the content grid.
%   F.grid (the screen's grid, in the host's one cell), F.content (the grid cell the screen builds into),
%   F.tools (a grid at the right of the title for a screen's status pills)
F.grid = uigridlayout(host, [4 2], 'RowHeight', {40, 20, 16, '1x'}, 'ColumnWidth', {'1x', 'fit'}, ...
    'Padding', [T.px.margin 12 T.px.margin T.px.margin], 'RowSpacing', 0, 'BackgroundColor', T.c.ground);
F.grid.Layout.Row = 1;
F.grid.Layout.Column = 1;
F.title = uilabel(F.grid, 'Text', title, 'FontName', T.font.display, 'FontSize', 28, 'FontColor', T.c.ink);
F.title.Layout.Row = 1;
F.title.Layout.Column = 1;
F.tools = uigridlayout(F.grid, [1 1], 'Padding', [0 6 0 6], 'ColumnSpacing', 8, 'BackgroundColor', T.c.ground, ...
    'ColumnWidth', {'fit'});
F.tools.Layout.Row = 1;
F.tools.Layout.Column = 2;
F.hint = uilabel(F.grid, 'Text', hint, 'FontName', T.font.chrome, 'FontSize', 13, 'FontColor', T.c.ink2);
F.hint.Layout.Row = 2;
F.hint.Layout.Column = [1 2];
F.content = uigridlayout(F.grid, [1 1], 'Padding', [0 0 0 0], 'BackgroundColor', T.c.ground);
F.content.Layout.Row = 4;
F.content.Layout.Column = [1 2];
end
