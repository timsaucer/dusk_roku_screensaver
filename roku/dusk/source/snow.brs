' Snowfall in a pine forest under a faint aurora.
'
' Back to front: plate and stars, aurora curtains, land layer (treeline and cabin, so they hide
' the aurora), dense far snow, ground layer, window glow, mid flakes, near pines, near flakes.
'
' Every flake has a depth d (0 at the horizon .. 1 at the bottom of the screen). Size, fall
' speed, brightness and the screen row where it reaches the ground all follow from d, so flakes
' fade into the snow at their own distance instead of falling to the bottom of the screen. The
' far snow is one scrolling tiled texture; the ground layer drawn over it (the plate below the
' far ground line, with a soft top edge) makes it vanish at the far ground line.
'
' This scene runs at 30 fps: a low-end stick cannot blend all of these full-screen layers at 60.

function SnowInit(cfg as object) as object
    s = {
        cfg: cfg
        plate: PlateInit(cfg)
        curtains: []
        tile: CreateObject("roBitmap", "pkg:/images/snowtile_0.png")
        ground: CreateObject("roBitmap", cfg.ground)
        mid: []
        near: []
        windX: 0
        flakeBmps: {}
    }
    for i = 0 to 1
        s.curtains.Push(CreateObject("roBitmap", "pkg:/images/aurora_" + i.ToStr() + ".png"))
    end for
    for each px in [6, 9, 13, 24, 36]
        s.flakeBmps[px.ToStr()] = CreateObject("roBitmap", "pkg:/images/flake_" + px.ToStr() + ".png")
    end for
    sc = cfg.snow
    for i = 1 to sc.mid.count
        s.mid.Push(NewFlake(s, sc.mid, Rnd(0) * 1080))
    end for
    for i = 1 to sc.near.count
        s.near.Push(NewFlake(s, sc.near, Rnd(0) * 1080))
    end for
    return s
end function

' Screen row where the ground is at depth d (0 = horizon, 1 = bottom of the screen).
function GroundY(p as object, d as float) as float
    return p.horizonY + d * (1080 - p.horizonY)
end function

function NewFlake(s as object, layer as object, y as float) as object
    d = layer.depth[0] + Rnd(0) * (layer.depth[1] - layer.depth[0])
    u = (d - layer.depth[0]) / (layer.depth[1] - layer.depth[0] + 0.0001)
    sizes = layer.sizes
    px = sizes[Int(u * sizes.Count() * 0.999)]
    bmp = s.flakeBmps[px.ToStr()]
    return {
        d: d, bmp: bmp, half: bmp.GetWidth() / 2
        x: Rnd(0) * 2000 - 40, y: y
        ' Nearer flakes fall faster on screen; a little randomness so they don't move in lockstep.
        vy: (layer.speed[0] + u * (layer.speed[1] - layer.speed[0])) * (0.85 + 0.3 * Rnd(0))
        ground: GroundY(s.plate, d) + (Rnd(0) - 0.5) * 30
        amp: 6 + Rnd(0) * layer.sway, fr: 0.3 + Rnd(0) * 0.6, ph: Rnd(0) * 6.283
        alpha: 255 * layer.alpha * (0.7 + 0.3 * u)
        rgba: &hFFFFFF00
    }
end function

sub SnowFrame(s as object, screen as object, t as float, dt as float)
    cfg = s.cfg
    p = s.plate
    PlateDrift(p, t)
    PlateDrawSky(p, screen, t)
    DrawAurora(s, screen, t)
    if p.land <> invalid then screen.DrawObject(p.bx - p.bgMargin[0], p.by - p.bgMargin[1] + cfg.landTop, p.land)

    ' One shared breeze, slowly changing strength and direction; nearer snow feels more of it.
    sc = cfg.snow
    wind = sc.wind * (0.6 * Sin(t * 0.031) + 0.4 * Sin(t * 0.077 + 1.0))
    s.windX = s.windX + wind * dt

    tl = sc.tile
    DrawSnowTile(screen, s.tile, t * tl.speed, s.windX * tl.drift + p.bx, tl.alpha, cfg.groundTop - p.bgMargin[1] + 80)
    screen.DrawObject(p.bx - p.bgMargin[0], p.by - p.bgMargin[1] + cfg.groundTop, s.ground)
    PlateDrawWindows(p, screen, t)

    UpdateFlakes(s.mid, sc.mid, wind, dt)
    DrawFlakes(s.mid, screen, t, p.bx)
    PlateDrawFg(p, screen)
    UpdateFlakes(s.near, sc.near, wind, dt)
    DrawFlakes(s.near, screen, t, p.fx * 1.6)
end sub

sub DrawAurora(s as object, screen as object, t as float)
    au = s.cfg.aurora
    p = s.plate
    k = 0
    for each c in au.curtains
        bmp = s.curtains[k]
        ' Breathing: brightness and height drift on slow, unrelated periods.
        a = au.alpha * c.alpha * (0.55 + 0.45 * Sin(t * c.pulse + c.ph))
        if a > 0.01
            sx = 1920.0 * c.width / bmp.GetWidth()
            sy = c.height * (1 + 0.12 * Sin(t * c.pulse * 0.7 + c.ph * 2))
            w = bmp.GetWidth() * sx
            x = -FMod(t * c.speed + c.ph * 400, w)
            y = c.y - bmp.GetHeight() * sy + p.by
            rgba = &hFFFFFF00 + Int(255 * a)
            while x < 1920
                screen.DrawScaledObject(x + p.bx, y, sx, sy, bmp, rgba)
                x = x + w
            end while
        end if
        k = k + 1
    end for
end sub

' Tiles the far-snow texture over the screen down to row yMax (the ground layer hides the rest).
sub DrawSnowTile(screen as object, bmp as object, oy as float, ox as float, alpha as float, yMax as float)
    size = bmp.GetWidth()
    x0 = FMod(ox, size) - size
    y = FMod(oy, size) - size
    rgba = &hFFFFFF00 + Int(255 * alpha)
    while y < yMax
        x = x0
        while x < 1920
            screen.DrawObject(x, y, bmp, rgba)
            x = x + size
        end while
        y = y + size
    end while
end sub

sub UpdateFlakes(flakes as object, layer as object, wind as float, dt as float)
    for each f in flakes
        f.y = f.y + f.vy * dt
        f.x = f.x + wind * layer.drift * (0.4 + 0.6 * f.d) * dt
        ' Fade over the last 40 px above the flake's ground line, then respawn at the top.
        fade = (f.ground - f.y) / 40
        if fade <= 0
            f.y = -f.half - Rnd(0) * 60
            f.x = Rnd(0) * 2000 - 40
            fade = 1
        else if fade > 1
            fade = 1
        end if
        f.rgba = &hFFFFFF00 + Int(f.alpha * fade)
        if f.x < -60 then f.x = f.x + 2040
        if f.x > 1980 then f.x = f.x - 2040
    end for
end sub

sub DrawFlakes(flakes as object, screen as object, t as float, ox as float)
    for each f in flakes
        screen.DrawObject(f.x + f.amp * Sin(t * f.fr + f.ph) + ox - f.half, f.y - f.half, f.bmp, f.rgba)
    end for
end sub
