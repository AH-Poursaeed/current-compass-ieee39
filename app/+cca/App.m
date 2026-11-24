classdef App < handle
    %APP  The shell of the application: the window, the top bar, the rail, the screen host and the navigation.
    %   A screen is built on its first visit and then kept (Visible off and on).
    properties
        fig            % the uifigure
        D              % the data (cca.data.load)
        T              % the style tokens (cca.style)
        state          % cca.State, the shared selection
        dry logical = false
        host           % the grid that holds the screens (one cell)
        topbar         % uihtml
        rail           % uihtml
        screens = struct()
        current = ""
        log = strings(0, 1)   % what the Dry mode printed, newest last
        building = []         % the frame of the screen being built (its title tools)
        handler = []          % the optional handler of the Run screen's card (ccapp's RunHandler; none: no control)
    end
    properties (Constant)
        NAMES = ["overview", "reproduce", "run", "compare", "scenarios", "model", "provenance", "about"]
        TITLES = ["Overview", "Reproduce", "Run", "Compare", "Scenarios", "Model", "Provenance", "About"]
    end
    methods
        function app = App(D, T, opts)
            arguments
                D struct
                T struct
                opts.Dry (1,1) logical = false
                opts.Visible (1,1) logical = true
                opts.RunHandler = []
            end
            app.D = D;
            app.T = T;
            app.dry = opts.Dry;
            app.handler = opts.RunHandler;
            app.state = cca.State();
            app.fig = uifigure('Name', 'Current Compass - Reproduction application', 'Theme', 'light', ...
                'Visible', 'off', 'Color', T.c.ground);
            app.fig.Position = [40 40 1440 900];
            g = uigridlayout(app.fig, [2 2], 'RowHeight', {T.px.top, '1x'}, 'ColumnWidth', {T.px.rail, '1x'}, ...
                'Padding', [0 0 0 0], 'RowSpacing', 0, 'ColumnSpacing', 0, 'BackgroundColor', T.c.ground);
            html = fullfile(D.root, 'html');
            app.topbar = uihtml(g, 'HTMLSource', fullfile(html, 'topbar.html'));
            app.topbar.Layout.Row = 1;
            app.topbar.Layout.Column = [1 2];
            app.topbar.HTMLEventReceivedFcn = @(~, e) app.onHtml(e);
            rec = D.record;
            % the released record that ships (app/data/record) by its short sha256 and its newest group (the
            % record builder's stamp is on the About screen)
            app.topbar.Data = struct('pill', sprintf('Released record %s . %s', rec.sha256_8, rec.group), ...
                'badge', 'Release 1');
            app.rail = uihtml(g, 'HTMLSource', fullfile(html, 'rail.html'));
            app.rail.Layout.Row = 2;
            app.rail.Layout.Column = 1;
            app.rail.HTMLEventReceivedFcn = @(~, e) app.onHtml(e);
            app.rail.Data = struct('active', 'overview');
            app.host = uigridlayout(g, [1 1], 'Padding', [0 0 0 0], 'BackgroundColor', T.c.ground);
            app.host.Layout.Row = 2;
            app.host.Layout.Column = 2;
            if opts.Visible
                app.fig.Visible = 'on';
            end
        end

        function show(app, name)
            name = string(name);
            if ~any(app.NAMES == name)
                error('cca:app:screen', 'No screen %s.', name);
            end
            if ~isfield(app.screens, name)
                frame = cca.ui.frame(app.host, app.T, app.TITLES(app.NAMES == name), cca.ui.hints(name));
                try
                    app.building = frame;
                    S = feval("cca.screen." + name, frame.content, app.D, app.T, app);
                catch err
                    S = cca.screen.placeholder(frame.content, app.D, app.T, app, ...
                        "This screen could not be built: " + string(err.message));
                end
                S.frame = frame;
                app.screens.(name) = S;
            end
            f = fieldnames(app.screens);
            for i = 1:numel(f)
                app.screens.(f{i}).frame.grid.Visible = matlab.lang.OnOffSwitchState(f{i} == name);
            end
            app.current = name;
            app.rail.Data = struct('active', char(name));
            S = app.screens.(name);
            if isfield(S, 'onShow') && ~isempty(S.onShow)
                S.onShow();
            end
        end

        function act(app, statement, fn)
            %ACT  Run an action, or in the Dry mode print the statement instead.
            if app.dry
                app.log(end + 1) = string(statement);
                fprintf('[dry] %s\n', statement);
            else
                fn();
            end
        end

        function onHtml(app, e)
            switch e.HTMLEventName
                case 'nav'
                    app.show(string(e.HTMLEventData));
            end
        end
    end
end
