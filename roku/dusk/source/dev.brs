' Development entry point: lets the package run as a sideloaded app so scenes can be launched
' and inspected over ECP. Release builds leave this file out and drop "title" from the
' manifest: Roku only invokes RunScreenSaverSettings for a screensaver-only package.
'
' Launch parameters: scene=<name>|cycle, cycle=<seconds> (cycle interval), settings=1

sub Main(args as dynamic)
    if type(args) <> "roAssociativeArray" then args = {}
    if args.settings <> invalid
        RunScreenSaverSettings()
        return
    end if
    name = "fireflies"
    if args.scene <> invalid then name = args.scene
    secs = 60
    if args.cycle <> invalid then secs = args.cycle.ToInt()
    RunScenes(name, secs, true)
end sub
