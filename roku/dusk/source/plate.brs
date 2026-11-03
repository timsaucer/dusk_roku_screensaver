' Layered photo plate shared by every scene.
'
' Draw order a scene composes from these calls:
'   PlateDrawSky   full plate (opaque copy), then twinkling stars (PlateDrawStars)
'   (scene effects that belong in the sky, e.g. aurora)
'   PlateDrawLand  optional non-sky layer (so sky effects sit behind trees), then window
'                  glows (PlateDrawWindows)
'   (scene effects behind the foreground)
'   PlateDrawFg    near foreground layer
'   (scene effects in front of everything)
' Layers are larger than the screen by a margin so the slow parallax drift never shows an edge.

function PlateInit(cfg as object) as object
    p = {
        cfg: cfg
        bg: CreateObject("roBitmap", cfg.bg)
        fg: CreateObject("roBitmap", cfg.fg)
        land: invalid
        winGlow: CreateObject("roBitmap", "pkg:/images/winglow.png")
        starBmps: []
        stars: []
        starCursor: 0
        bx: 0 : by: 0 : fx: 0 : fy: 0
    }
    if cfg.land <> invalid then p.land = CreateObject("roBitmap", cfg.land)
    p.bgMargin = [(p.bg.GetWidth() - 1920) / 2, (p.bg.GetHeight() - 1080) / 2]
    p.fgMargin = [(p.fg.GetWidth() - 1920) / 2, (p.fg.GetHeight() - 1080) / 2]
    p.horizonY = cfg.horizon * 1080
    ' Star and window positions are in unscaled 1080p plate coordinates; map them through the
    ' layer scale so they stay registered with the plate.
    sc = p.bg.GetWidth() / 1920.0

    for i = 0 to 2
        p.starBmps.Push(CreateObject("roBitmap", "pkg:/images/star_" + i.ToStr() + ".png"))
    end for
    ' Stars: precompute position and base brightness (fainter toward the horizon).
    if cfg.stars <> invalid
        for each st in cfg.stars
            p.stars.Push({
                x: (st[0] - 960) * sc + 960 - 1 - st[2], y: (st[1] - 540) * sc + 540 - 1 - st[2], bmp: p.starBmps[st[2]]
                base: 255 * (0.22 + 0.18 * st[2]) * (1 - 0.7 * st[1] / p.horizonY)
                rate: 0.6 + st[3], ph: st[3] * 6.283, rgba: &hFFFFFF00
            })
        end for
    end if
    p.windows = []
    for each w in cfg.windows
        gs = w.size * 1920 / 256.0
        p.windows.Push({ x: (w.x * 1920 - 960) * sc + 960 - 128 * gs, y: (w.y * 1080 - 540) * sc + 540 - 128 * gs, s: gs, alpha: w.alpha })
    end for
    return p
end function

' Slow Lissajous camera drift; the foreground moves more than the plate.
sub PlateDrift(p as object, t as float)
    par = p.cfg.parallax
    pt = t * 6.283 / par.period
    u = Sin(pt) : v = Sin(pt * 0.7 + 1.3)
    p.bx = u * par.bg[0] : p.by = v * par.bg[1]
    p.fx = u * par.fg[0] : p.fy = v * par.fg[1]
    ' Optional sway of the foreground on top of the drift (e.g. a branch in the breeze).
    if par.sway <> invalid
        p.fx = p.fx + par.sway[0] * (0.7 * Sin(t * 0.37) + 0.3 * Sin(t * 1.13 + 0.6))
        p.fy = p.fy + par.sway[1] * Sin(t * 0.29 + 1.7)
    end if
end sub

sub PlateDrawSky(p as object, screen as object, t as float)
    ' The plate is opaque: copy it without blending.
    screen.SetAlphaEnable(false)
    screen.DrawObject(p.bx - p.bgMargin[0], p.by - p.bgMargin[1], p.bg)
    screen.SetAlphaEnable(true)
    PlateDrawStars(p, screen, t)
end sub

sub PlateDrawStars(p as object, screen as object, t as float)
    ' Twinkle is slow, so a quarter of the stars are refreshed each frame.
    ns = p.stars.Count()
    if ns = 0 then return
    for k = 1 to (ns + 3) \ 4
        st = p.stars[p.starCursor]
        p.starCursor = (p.starCursor + 1) mod ns
        st.rgba = &hFFFFFF00 + Int(st.base * (0.7 + 0.3 * Sin(t * st.rate + st.ph)))
    end for
    for each st in p.stars
        screen.DrawObject(st.x + p.bx, st.y + p.by, st.bmp, st.rgba)
    end for
end sub

sub PlateDrawLand(p as object, screen as object, t as float)
    if p.land <> invalid then screen.DrawObject(p.bx - p.bgMargin[0], p.by - p.bgMargin[1] + p.cfg.landTop, p.land)
    PlateDrawWindows(p, screen, t)
end sub

sub PlateDrawWindows(p as object, screen as object, t as float)
    ' Window glows, each flickering on its own.
    k = 0
    for each w in p.windows
        flick = 0.88 + 0.07 * Sin(t * 2.3 + k * 1.9) + 0.05 * Sin(t * 5.7 + 1.1 + k * 0.7)
        screen.DrawScaledObject(w.x + p.bx, w.y + p.by, w.s, w.s, p.winGlow, &hFFFFFF00 + Int(255 * w.alpha * flick))
        k = k + 1
    end for
end sub

sub PlateDrawFg(p as object, screen as object)
    screen.DrawObject(p.fx - p.fgMargin[0], p.fy - p.fgMargin[1], p.fg)
end sub

' Float modulo with a non-negative result (BrightScript's mod works on integers).
function FMod(a as float, m as float) as float
    return a - Int(a / m) * m
end function
