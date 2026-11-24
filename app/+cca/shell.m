function app = shell(D, T, opts)
%SHELL  Build the window of the application (see cca.App).
arguments
    D struct
    T struct
    opts.Dry (1,1) logical = false
    opts.Visible (1,1) logical = true
    opts.RunHandler = []
end
app = cca.App(D, T, Dry=opts.Dry, Visible=opts.Visible, RunHandler=opts.RunHandler);
end
