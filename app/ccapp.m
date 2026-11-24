function [fig, app] = ccapp(opts)
%CCAPP  Start the Current Compass reproduction application.
%
%   fig = ccapp()                      opens the application on its Overview screen
%   fig = ccapp(Screen="compare")      opens on one screen (overview, reproduce, run, compare, scenarios,
%                                      model, provenance, about)
%   fig = ccapp(Key="39_1000_10TF")    opens the Run screen on the paper's runs of that scenario
%   fig = ccapp(Dry=true)              every action button prints what it would do instead of doing it
%   fig = ccapp(Visible=false)         builds the window hidden (tests and screenshots)
%   [fig, app] = ccapp(...)            also returns the shell (cca.App: app.show("compare"), app.state)
%
%   Every number the application prints is read at run time from app/data, which the script
%   app/tools/make_app_data.py generates from the paper's number record. Nothing is typed in the code.
arguments
    opts.Screen (1,1) string = "overview"
    opts.Key (1,1) string = ""
    opts.Dry (1,1) logical = false
    opts.Visible (1,1) logical = true
    opts.RunHandler = []                 % an optional handler of the Run screen's card (none: no control)
end
root = fileparts(mfilename('fullpath'));
if ~contains(path, root)
    addpath(root);
end
D = cca.data.load(root);
T = cca.style("A");
cca.style("A", "css", fullfile(root, 'html', 'tokens.css'));
if strlength(opts.Key) > 0 && ~any(strcmp([D.grid.keys(:); D.runlist.key(:)], char(opts.Key)))
    error('cca:key:notInSet', 'The scenario %s is not one of the scenarios of the paper''s runs.', opts.Key);
end
if ~isempty(opts.RunHandler) && ~isa(opts.RunHandler, 'function_handle')
    error('cca:app:handler', 'RunHandler must be a function handle.');
end
app = cca.shell(D, T, Dry=opts.Dry, Visible=opts.Visible, RunHandler=opts.RunHandler);
if strlength(opts.Key) > 0
    app.state.set('Key', char(opts.Key));
    app.show("run");
else
    app.show(opts.Screen);
end
fig = app.fig;
end
