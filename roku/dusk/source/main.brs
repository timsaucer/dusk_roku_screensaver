' Dusk screensaver: photoreal plate layers with procedural animation drawn over them.
' Entry points: RunScreenSaver (system), Main (sideloaded app, for development; pass
' scene=<name> as a launch parameter to pick the scene).

sub Main(args as dynamic)
    name = "fireflies"
    if type(args) = "roAssociativeArray" and args.scene <> invalid then name = args.scene
    RunScene(name, true)
end sub

sub RunScreenSaver()
    RunScene("fireflies", false)
end sub

function Scenes() as object
    return {
        fireflies: { init: FirefliesInit, frame: FirefliesFrame }
        snow: { init: SnowInit, frame: SnowFrame }
    }
end function

sub RunScene(name as string, isApp as boolean)
    screen = CreateObject("roScreen", true, 1920, 1080)
    screen.SetAlphaEnable(true)
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)

    kind = Scenes()[name]
    cfg = ParseJson(ReadAsciiFile("pkg:/scenes/" + name + ".json"))
    scene = kind.init(cfg)

    ' Optional frame cap (scene JSON "fps"): heavy scenes run at a steady 30 rather than an
    ' uneven 35-45, which judders more than a locked lower rate.
    frameMs = 0
    if cfg.fps <> invalid then frameMs = 1000 / cfg.fps
    frameClock = CreateObject("roTimespan")
    clock = CreateObject("roTimespan")
    fpsClock = CreateObject("roTimespan")
    frames = 0
    last = 0
    while true
        now = clock.TotalMilliseconds() / 1000.0
        dt = now - last
        if dt > 0.1 then dt = 0.1
        last = now
        kind.frame(scene, screen, now, dt)
        if frameMs > 0
            ' Wait out most of the frame, then let SwapBuffers land on the next vsync.
            left = frameMs - 2 - frameClock.TotalMilliseconds()
            if left > 0 then sleep(left)
        end if
        screen.SwapBuffers()
        frameClock.Mark()

        frames = frames + 1
        if fpsClock.TotalMilliseconds() >= 10000
            print "FPS "; frames / 10.0
            frames = 0
            fpsClock.Mark()
        end if

        msg = port.GetMessage()
        if isApp and type(msg) = "roUniversalControlEvent" and msg.GetInt() = 0 then return
    end while
end sub
