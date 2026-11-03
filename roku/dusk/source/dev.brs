' Development entry point: lets the package run as a sideloaded app so scenes can be launched
' and inspected over ECP. Release builds leave this file out and drop "title" from the
' manifest: Roku only invokes RunScreenSaverSettings for a screensaver-only package.
'
' Launch parameters: scene=<name>[,<name>...]|all, cycle=<seconds> (cycle interval), settings=1

sub Main(args as dynamic)
    if type(args) <> "roAssociativeArray" then args = {}
    if args.settings <> invalid
        RunScreenSaverSettings()
        return
    end if
    names = ["fireflies"]
    if args.scene <> invalid
        if args.scene = "all" then names = AllScenes() else names = SplitNames(args.scene)
    end if
    secs = 60
    if args.cycle <> invalid then secs = args.cycle.ToInt()
    RunScenes(names, secs, true)
end sub
