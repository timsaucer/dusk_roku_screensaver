' Sprite throughput benchmark: draws N alpha-blended glow sprites over a
' full-screen plate with roScreen, steps N up, and logs fps per step.
sub Main()
    RunBench()
end sub

sub RunScreenSaver()
    RunBench()
end sub

sub RunBench()
    screen = CreateObject("roScreen", true, 1920, 1080)
    screen.SetAlphaEnable(true)
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)

    plate = CreateObject("roBitmap", "pkg:/images/plate.jpg")
    glow = CreateObject("roBitmap", "pkg:/images/glow64.png")
    gw = glow.GetWidth() : gh = glow.GetHeight()

    counts = [0, 50, 100, 150, 200, 300, 400, 600]
    clock = CreateObject("roTimespan")
    for each n in counts
        xs = [] : ys = [] : vx = [] : vy = [] : ph = []
        for i = 0 to n - 1
            xs.Push(Rnd(1920)) : ys.Push(Rnd(1080))
            vx.Push((Rnd(0) - 0.5) * 2) : vy.Push((Rnd(0) - 0.5) * 2)
            ph.Push(Rnd(0) * 6.283)
        end for
        frames = 0
        clock.Mark()
        while clock.TotalMilliseconds() < 5000
            screen.DrawObject(0, 0, plate)
            t = clock.TotalMilliseconds() / 1000.0
            for i = 0 to n - 1
                xs[i] = xs[i] + vx[i] : ys[i] = ys[i] + vy[i]
                a = Int(128 + 127 * Sin(t * 1.3 + ph[i]))
                screen.DrawObject(xs[i] - gw / 2, ys[i] - gh / 2, glow, &hFFFFFF00 + a)
            end for
            screen.SwapBuffers()
            frames = frames + 1
            msg = port.GetMessage()
        end while
        print "BENCH sprites="; n; " fps="; frames / 5.0
    end for
    print "BENCH done"
end sub
