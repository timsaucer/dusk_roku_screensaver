' Fill-rate experiments: what does each way of drawing a full-screen layer cost?
sub Main()
    screen = CreateObject("roScreen", true, 1920, 1080)
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    bg = CreateObject("roBitmap", "pkg:/images/bg.jpg")
    fg = CreateObject("roBitmap", "pkg:/images/fg.png")
    off = CreateObject("roBitmap", { width: 1968, height: 600, AlphaEnable: false })
    off.DrawObject(0, 0, bg)
    reg = CreateObject("roRegion", screen, 0, 100, 1920, 200)
    print "BENCH region from screen: "; type(reg)

    au = CreateObject("roBitmap", "pkg:/images/aurora_0.png")
    tile = CreateObject("roBitmap", "pkg:/images/snowtile_0.png")
    screen.SetAlphaEnable(true)
    for each n in [4, 5, 6, 8]
        RunTest(screen, port, "fg alpha x" + n.ToStr(), function(screen, n, a, b) : for k = 1 to n : screen.DrawObject(-24, -13, a) : end for : end function, n, fg, invalid)
    end for
    RunTest(screen, port, "aurora scaled x2 + bg", function(screen, n, a, b) : screen.DrawObject(-24, -13, b) : for k = 1 to n : screen.DrawScaledObject(0, 0, 2.4, 1.0, a, &hFFFFFF80) : screen.DrawScaledObject(1100, 0, 2.4, 1.0, a, &hFFFFFF80) : end for : end function, 2, au, bg)
    RunTest(screen, port, "aurora unscaled x4 + bg", function(screen, n, a, b) : screen.DrawObject(-24, -13, b) : for k = 1 to n : screen.DrawObject(0, 0, a, &hFFFFFF80) : screen.DrawObject(1024, 0, a, &hFFFFFF80) : end for : end function, 2, au, bg)
    RunTest(screen, port, "tiles 20 + bg", function(screen, n, a, b) : screen.DrawObject(-24, -13, b) : for y = 0 to 3 : for x = 0 to 4 : screen.DrawObject(x * 512 - 100, y * 512 - 100, a, &hFFFFFFB0) : end for : end for : end function, 1, tile, bg)
    RunTest(screen, port, "100 small sprites + bg", function(screen, n, a, b) : screen.DrawObject(-24, -13, b) : for k = 1 to 100 : screen.DrawObject(k * 18, 400, a, &hFFFFFFB0) : end for : end function, 1, CreateObject("roBitmap", { width: 13, height: 13, AlphaEnable: true }), bg)
    print "BENCH done"
end sub

sub RunTest(screen, port, name, fn, n, a, b)
    frames = 0
    clock = CreateObject("roTimespan")
    while clock.TotalMilliseconds() < 4000
        fn(screen, n, a, b)
        screen.SwapBuffers()
        frames = frames + 1
        port.GetMessage()
    end while
    print "BENCH "; name; " fps="; frames / 4.0
end sub
