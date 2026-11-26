function H = help(app, T, content)
%HELP  The button "How to read this screen" at the right of a screen's title, and the page of explanations that it
%   opens in place of the screen (a second press, "Back to the screen", closes it). The page is built at its first
%   opening, from the words of content (a struct: title, intro, sections; see cca.ui.helpsec).
%   H = cca.ui.help(app, T, content)   app.building is the frame of the screen being built (cca.ui.frame)
%   H.button, H.show(tf) (as a press does), H.isShown(), H.page() (the uihtml once built, else []),
%   H.content() (the words the page shows)
H = struct('button', [], 'show', @noop, 'isShown', @() false, 'page', @() [], 'content', @() content);
F = app.building;
if isempty(F) || ~isstruct(F) || ~isfield(F, 'tools') || ~isfield(F, 'content')
    return
end
openText = 'How to read this screen';
closeText = [char(8249) ' Back to the screen'];
b = uibutton(F.tools, 'Text', openText, 'FontName', T.font.chrome, 'FontSize', 12, 'Tooltip', ...
    'What each number on this screen means, where the paper prints it, and how the paper judges a run');
pnl = [];
h = [];
on = false;
b.ButtonPushedFcn = @(~, ~) toggle();     % a nested function reads the state at the click, not at the build
H.button = b;
H.show = @show;
H.isShown = @isShown;
H.page = @getPage;

    function toggle()
        show(~on);
    end

    function show(tf)
        % the page in place of the screen's content (tf true), or the screen again (tf false)
        if tf && isempty(pnl)
            pnl = uipanel(F.grid, 'BackgroundColor', T.c.surface, 'BorderType', 'line', 'BorderColor', T.c.border);
            pnl.Layout.Row = 4;
            pnl.Layout.Column = [1 2];
            g = uigridlayout(pnl, [1 1], 'Padding', [0 0 0 0], 'BackgroundColor', T.c.surface);
            h = uihtml(g, 'HTMLSource', fullfile(app.D.root, 'html', 'help.html'));
            h.Data = content;
        end
        on = logical(tf);
        if ~isempty(pnl)
            pnl.Visible = matlab.lang.OnOffSwitchState(on);
        end
        F.content.Visible = matlab.lang.OnOffSwitchState(~on);
        if on
            b.Text = closeText;
        else
            b.Text = openText;
        end
    end

    function v = isShown()
        v = on;
    end

    function p = getPage()
        p = h;
    end
end

function noop(~)
end
