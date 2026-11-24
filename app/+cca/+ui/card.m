function C = card(parent, T, eyebrow, title, opts)
%CARD  A white card with a hairline border: an eyebrow label, an optional title, and a body grid.
%   C = cca.ui.card(parent, T, "THE IDEA", "Turn the saturated current, not the converter.")
%   C.panel, C.grid (rows: eyebrow, title, body), C.body (the body grid, 1 x 1 by default)
arguments
    parent
    T struct
    eyebrow (1,1) string = ""
    title (1,1) string = ""
    opts.TitleSize (1,1) double = 22
    opts.TitleFont (1,1) string = "display"
end
C.panel = uipanel(parent, 'BackgroundColor', T.c.surface, 'BorderType', 'line', ...
    'BorderColor', T.c.border, 'BorderWidth', 1);
rows = {};
if strlength(eyebrow) > 0
    rows{end + 1} = 16;
end
if strlength(title) > 0
    rows{end + 1} = ceil(opts.TitleSize * 1.45);
end
rows{end + 1} = '1x';
C.grid = uigridlayout(C.panel, [numel(rows) 1], 'RowHeight', rows, 'ColumnWidth', {'1x'}, ...
    'Padding', [T.px.pad 14 T.px.pad 16], 'RowSpacing', 6, 'BackgroundColor', T.c.surface);
r = 0;
if strlength(eyebrow) > 0
    r = r + 1;
    C.eyebrow = uilabel(C.grid, 'Text', upper(eyebrow), 'FontName', T.font.chromeBold, 'FontSize', 11, ...
        'FontColor', T.c.accent);
    C.eyebrow.Layout.Row = r;
end
if strlength(title) > 0
    r = r + 1;
    if opts.TitleFont == "display"
        fn = T.font.display;
    else
        fn = T.font.chromeBold;
    end
    C.title = uilabel(C.grid, 'Text', title, 'FontName', fn, 'FontSize', opts.TitleSize, 'FontColor', T.c.ink);
    C.title.Layout.Row = r;
end
C.body = uigridlayout(C.grid, [1 1], 'Padding', [0 0 0 0], 'BackgroundColor', T.c.surface);
C.body.Layout.Row = r + 1;
end
