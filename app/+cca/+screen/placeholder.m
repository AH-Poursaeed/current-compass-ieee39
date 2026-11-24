function S = placeholder(host, ~, T, ~, why)
%PLACEHOLDER  A plain card for a screen (or a part of one) that this build does not have yet.
arguments
    host
    ~
    T struct
    ~
    why (1,1) string = "This screen is not built in this version of the application."
end
C = cca.ui.card(host, T, "Not built yet", "");
lbl = uilabel(C.body, 'Text', why, 'FontName', T.font.chrome, 'FontSize', 14, 'FontColor', T.c.ink2, ...
    'WordWrap', 'on', 'VerticalAlignment', 'top');
lbl.Layout.Row = 1;
S.card = C;
S.onShow = [];
end
