function cc_shots(outdir, screens, opts)
%CC_SHOTS  Build the application, show each screen and save its picture (exportapp), with a lint report.
%   cc_shots(outdir)                         every screen
%   cc_shots(outdir, ["overview" "compare"]) the screens named
%   A record of the run is written with fprintf to outdir/shots_log.txt (never a diary).
arguments
    outdir (1,1) string
    screens (1,:) string = ["overview", "reproduce", "run", "compare", "scenarios", "model", "provenance", "about"]
    opts.Lint (1,1) logical = true
    opts.Settle (1,1) double = 4
    opts.Tests (1,:) string = strings(1, 0)
end
if ~isfolder(outdir)
    mkdir(outdir);
end
fid = fopen(fullfile(outdir, 'shots_log.txt'), 'w');
c = onCleanup(@() fclose(fid));
say = @(varargin) fprintf(fid, [varargin{1} '\n'], varargin{2:end});
root = fileparts(fileparts(mfilename('fullpath')));
say('cc_shots %s; MATLAB %s; app %s', char(datetime('now', 'TimeZone', 'UTC', 'Format', 'yyyy-MM-dd HH:mm:ss')), ...
    version, root);
if opts.Lint
    files = dir(fullfile(root, '**', '*.m'));
    nIssues = 0;
    for i = 1:numel(files)
        f = fullfile(files(i).folder, files(i).name);
        msgs = checkcode(f);
        for k = 1:numel(msgs)
            say('LINT %s:%d %s', erase(f, [root filesep]), msgs(k).line, msgs(k).message);
            nIssues = nIssues + 1;
        end
    end
    say('LINT files %d, messages %d', numel(files), nIssues);
end
for tf = opts.Tests
    tt = tic;
    try
        res = runtests(fullfile(root, 'tests', tf));
        for i = 1:numel(res)
            if res(i).Passed
                v = 'PASS';
            elseif res(i).Incomplete
                v = 'SKIP';
            else
                v = 'FAIL';
            end
            say('TEST %s %s (%.1f s)', v, res(i).Name, res(i).Duration);
            if res(i).Failed
                d = res(i).Details;
                if isfield(d, 'DiagnosticRecord') && ~isempty(d.DiagnosticRecord)
                    for q = 1:numel(d.DiagnosticRecord)
                        say('    %s', strrep(d.DiagnosticRecord(q).Report, newline, ' | '));
                    end
                end
            end
        end
        say('TESTS %s: %d passed, %d failed, %d incomplete in %.0f s', tf, sum([res.Passed]), ...
            sum([res.Failed]), sum([res.Incomplete]), toc(tt));
    catch err
        say('ERROR running %s: %s', tf, getReport(err, 'extended', 'hyperlinks', 'off'));
    end
end
if isempty(screens)
    say('=== DONE (no screens)');
    return
end
t0 = tic;
try
    [fig, app] = ccapp(Visible=true, Dry=true);
catch err
    say('ERROR building the shell: %s', getReport(err, 'extended', 'hyperlinks', 'off'));
    return
end
say('shell built in %.1f s', toc(t0));
first = true;
for s = screens
    t1 = tic;
    try
        app.show(s);
        drawnow;
        if first
            settle(fig, 20);
            first = false;
        end
        settle(fig, opts.Settle);
        f = fullfile(outdir, "app_" + s + ".png");
        exportapp(fig, f);
        info = imfinfo(f);
        say('SHOT %s %dx%d in %.1f s', s, info.Width, info.Height, toc(t1));
        if s == "compare" && isfield(app.screens.compare, 'setTab')
            for tab = ["ablation", "location", "loadsteps"]
                app.screens.compare.setTab(tab);
                settle(fig, opts.Settle);
                exportapp(fig, fullfile(outdir, "app_compare_" + tab + ".png"));
                say('SHOT compare (%s tab)', tab);
            end
            app.screens.compare.setTab('scenario');
            settle(fig, 1);
        end
    catch err
        say('ERROR screen %s: %s', s, getReport(err, 'extended', 'hyperlinks', 'off'));
    end
end
f = fieldnames(app.screens);
for i = 1:numel(f)
    S = app.screens.(f{i});
    if isfield(S, 'card') && ~isfield(S, 'handles')
        say('SCREEN %s: placeholder', f{i});
    else
        say('SCREEN %s: built', f{i});
    end
end
say('dry log: %d lines', numel(app.log));
say('=== DONE %.1f s', toc(t0));
delete(fig);
end

function settle(fig, s)
t = tic;
while toc(t) < s
    drawnow;
    pause(0.25);
end
if ~isvalid(fig)
    error('cc_shots:closed', 'The window was closed.');
end
end
