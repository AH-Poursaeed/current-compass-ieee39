function info = dial(ax, T, D, R, tSel)
%DIAL  The compass dial: the current command's direction at 0 deg, the limited current turned by the rotation
%   psi toward lagging (clockwise), the quarter-turn clamp, and the measured trail of psi over the fault, from the
%   run R (cca.data.runpack; [] draws the dial without a trail).
%   info = cca.ui.dial(ax, T, D, R, tSel)   tSel: the time shown (s after clearing; default: clearing)
%   info.caption, info.needle (the line handle), info.psi (deg at tSel), info.update(t) moves the needle
if nargin < 5
    tSel = 0;
end
cla(ax);
hold(ax, 'on');
th = linspace(0, 2 * pi, 361);
plot(ax, cos(th), sin(th), '-', 'Color', T.c.border2, 'LineWidth', 1.2);
plot(ax, 0.55 * cos(th), 0.55 * sin(th), ':', 'Color', T.c.border2, 'LineWidth', 0.8);
% the clamp: a quarter turn toward lagging
tc = linspace(0, -pi / 2, 91);
plot(ax, 1.1 * cos(tc), 1.1 * sin(tc), '-', 'Color', T.c.soft, 'LineWidth', 5);
plot(ax, [0.98 1.22] * cos(-pi / 2), [0.98 1.22] * sin(-pi / 2), '-', 'Color', T.c.accent, 'LineWidth', 1.4);
text(ax, 1.2 * cos(-pi / 3.2), 1.2 * sin(-pi / 3.2) - 0.12, 'quarter-turn clamp', 'Color', T.c.accent, ...
    'FontName', T.font.chrome, 'FontSize', 10, 'HorizontalAlignment', 'left');
% the command's direction
plot(ax, [0 1.25], [0 0], '-', 'Color', T.c.ink, 'LineWidth', 1);
text(ax, 1.29, 0, '$I_c$', 'Interpreter', 'latex', 'FontSize', 14, 'Color', T.c.ink);
text(ax, -0.05, 1.18, 'leading', 'Color', T.c.ink3, 'FontName', T.font.chrome, 'FontSize', 10, ...
    'HorizontalAlignment', 'center');
text(ax, -0.05, -1.22, 'lagging', 'Color', T.c.ink3, 'FontName', T.font.chrome, 'FontSize', 10, ...
    'HorizontalAlignment', 'center');
info.psi = NaN;
info.needle = [];
info.caption = ['The rotation of the saturated current toward lagging, from the current command''s direction, ' ...
    'held within the quarter-turn clamp.'];
if ~isempty(R) && isfield(R.series, 'psi') && any(~isnan(R.series.psi.y))
    s = R.series.psi;
    fw = R.meta.fault_window_s(:).';
    m = s.t >= fw(1) & s.t <= fw(2) & ~isnan(s.y);
    a = -deg2rad(s.y(m));
    r = linspace(0.62, 0.95, nnz(m));
    plot(ax, r .* cos(a), r .* sin(a), '-', 'Color', [T.c.accent 0.35], 'LineWidth', 1.2);
    [~, i] = min(abs(s.t - tSel) + 1e9 * isnan(s.y));
    info.psi = s.y(i);
    ang = -deg2rad(info.psi);
    info.needle = plot(ax, [0 cos(ang)], [0 sin(ang)], '-', 'Color', T.c.accent, 'LineWidth', 2.4);
    info.tip = plot(ax, cos(ang), sin(ang), 'o', 'MarkerSize', 7, 'MarkerFaceColor', T.c.accent, ...
        'MarkerEdgeColor', T.c.surface);
    info.label = text(ax, 0.42 * cos(ang / 2) + 0.05, 0.42 * sin(ang / 2), ...
        sprintf('%s = %.1f deg', char(968), info.psi), 'Color', T.c.accent, 'FontName', T.font.plot, 'FontSize', 11);
    [~, P] = cca.data.scenario(D, R.index.key);
    W = D.grid.words;
    fig = figureNumber(D, 'cc_fig_fault');
    info.caption = sprintf(['Measured: unit %d at the %s fault of %g s at bus %d (%s), a fault of Fig. %d of the ' ...
        'paper: the rotation %s of its saturated current over the fault, held within the quarter-turn clamp; the ' ...
        'needle shows it at clearing.'], R.meta.unit, W.type.(P.type), P.dur_s, P.bus, ...
        W.load.(matlab.lang.makeValidName(P.load)), fig, char(968));
end
plot(ax, 0, 0, 'o', 'MarkerSize', 5, 'MarkerFaceColor', T.c.ink, 'MarkerEdgeColor', T.c.ink);
hold(ax, 'off');
axis(ax, 'equal');
ax.XLim = [-1.45 1.6];
ax.YLim = [-1.35 1.35];
ax.Visible = 'off';
ax.Toolbar.Visible = 'off';
disableDefaultInteractivity(ax);
end

function n = figureNumber(D, key)
F = D.paper.figures;
if iscell(F), F = [F{:}]; end
n = F(strcmp({F.key}, key)).number;
end
