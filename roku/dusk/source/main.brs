' Dusk screensaver: photoreal plate layers with procedural animation drawn over them.
' Entry points: RunScreenSaver (system), Main (sideloaded app, for development).

sub Main()
    RunScene("fireflies", true)
end sub

sub RunScreenSaver()
    RunScene("fireflies", false)
end sub

sub RunScene(name as string, isApp as boolean)
    screen = CreateObject("roScreen", true, 1920, 1080)
    screen.SetAlphaEnable(true)
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)

    cfg = ParseJson(ReadAsciiFile("pkg:/scenes/" + name + ".json"))
    scene = FirefliesInit(cfg)

    clock = CreateObject("roTimespan")
    fpsClock = CreateObject("roTimespan")
    frames = 0
    last = 0
    while true
        now = clock.TotalMilliseconds() / 1000.0
        dt = now - last
        if dt > 0.1 then dt = 0.1
        last = now
        FirefliesFrame(scene, screen, now, dt)
        screen.SwapBuffers()

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
