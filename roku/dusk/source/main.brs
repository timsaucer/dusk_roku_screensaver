' Dusk screensaver: photoreal plate layers with procedural animation drawn over them.
'
' Entry points:
'   RunScreenSaver          the system screensaver; shows the scene chosen in settings, or
'                           cycles through the chosen scenes
'   RunScreenSaverSettings  the settings screen (settings.brs)
'   Main                    dev.brs; development builds only (see tools/sideload.sh)

sub RunScreenSaver()
    st = LoadSettings()
    RunScenes(st.scenes, st.cycleMinutes * 60, false)
end sub

function Scenes() as object
    return {
        fireflies: { init: FirefliesInit, frame: FirefliesFrame }
        snow: { init: SnowInit, frame: SnowFrame }
        blossoms: { init: BlossomsInit, frame: BlossomsFrame }
    }
end function

' Runs a single scene forever, or with several names each in turn for cycleSecs, fading
' through black between them.
sub RunScenes(names as object, cycleSecs as integer, isApp as boolean)
    screen = CreateObject("roScreen", true, 1920, 1080)
    screen.SetAlphaEnable(true)
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)

    cycling = names.Count() > 1
    idx = 0
    while true
        ' Each scene gets a fresh start; the previous one's bitmaps are released first.
        kind = Scenes()[names[idx]]
        cfg = ParseJson(ReadAsciiFile("pkg:/scenes/" + names[idx] + ".json"))
        scene = kind.init(cfg)
        limit = -1
        if cycling then limit = cycleSecs
        if not RunScene(screen, port, kind, scene, cfg, limit, isApp) then return
        scene = invalid
        RunGarbageCollector()
        idx = (idx + 1) mod names.Count()
    end while
end sub

' Plays one scene. Returns false if the user exited (dev app only), true when its time is up.
function RunScene(screen as object, port as object, kind as object, scene as object, cfg as object, limit as integer, isApp as boolean) as boolean
    ' Optional frame cap (scene JSON "fps"): heavy scenes run at a steady 30 rather than an
    ' uneven 35-45, which judders more than a locked lower rate.
    frameMs = 0
    if cfg.fps <> invalid then frameMs = 1000 / cfg.fps
    fade = 1.5
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

        ' Fade in at the start; when cycling, fade out before the next scene.
        k = now / fade
        if limit > 0 and limit - now < fade then k = (limit - now) / fade
        if k < 1
            if k < 0 then k = 0
            screen.DrawRect(0, 0, 1920, 1080, &h00000000 + Int(255 * (1 - k)))
        end if

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
        if limit > 0 and now >= limit then return true

        msg = port.GetMessage()
        if isApp and type(msg) = "roUniversalControlEvent" and msg.GetInt() = 0 then return false
    end while
end function
