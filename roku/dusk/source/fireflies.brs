' Fireflies over a blue-hour plate.
'
' Each firefly hovers above a ground point (gx, gy). Depth d comes from gy relative to the
' horizon, and sets size, speed and brightness. Flashes follow a per-firefly cycle with weak
' Kuramoto coupling to neighbors, so loose synchrony forms and dissolves.

function FirefliesInit(cfg as object) as object
    s = {
        cfg: cfg
        plate: PlateInit(cfg)
        glowSizes: [8, 12, 17, 24, 34, 48]
        glows: []
        flies: []
        neighborCursor: 0
        frame: 0
    }
    s.horizonY = s.plate.horizonY
    for each px in s.glowSizes
        s.glows.Push(CreateObject("roBitmap", "pkg:/images/glow_" + px.ToStr() + ".png"))
    end for

    n = cfg.fireflies.count
    nearCount = Int(n * cfg.fireflies.nearFrac + 0.5)
    for i = 0 to n - 1
        s.flies.Push(NewFirefly(s, i < nearCount))
    end for
    return s
end function

function NewFirefly(s as object, near as boolean) as object
    if near
        d = 0.9 + Rnd(0) * 0.1
    else
        ' Bias toward the distance: more fireflies far away, as a field would look.
        d = Rnd(0) ^ 1.6 * 0.86
    end if
    ff = s.cfg.fireflies
    period = ff.periodMin + Rnd(0) * (ff.periodMax - ff.periodMin)
    f = {
        d: d
        gx: Rnd(0) * 1920
        gy: s.horizonY + d * (1080 - s.horizonY)
        h: 0.2 + Rnd(0) * 1.6        ' hover height, in "meters"
        ph: Rnd(0)                    ' flash phase, 0..1 cycles
        lit: 0.18 + Rnd(0) * 0.14     ' fraction of the cycle spent glowing
        freq: 1.0 / period
        freqTarget: 1.0 / period
        retarget: 3 + Rnd(0) * 7
        wx: Rnd(0) * 6.283 : wy: Rnd(0) * 6.283
        wsx: 0.05 + Rnd(0) * 0.08 : wsy: 0.07 + Rnd(0) * 0.1
        neighbors: []
        cpl: 0
        x: 0 : y: 0
    }
    return f
end function

sub FirefliesFrame(s as object, screen as object, t as float, dt as float)
    p = s.plate
    PlateDrift(p, t)
    PlateDrawSky(p, screen, t)
    PlateDrawLand(p, screen, t)
    UpdateFlies(s, t, dt)

    ' Far fireflies sit behind the foreground layer; near ones in front of it.
    bright = s.cfg.fireflies.brightness
    for each f in s.flies
        if f.d < 0.88 then DrawFly(s, screen, f, bright, p.bx, p.by)
    end for
    PlateDrawFg(p, screen)
    for each f in s.flies
        if f.d >= 0.88 then DrawFly(s, screen, f, bright, p.fx * 1.6, p.fy * 1.6)
    end for
end sub

sub UpdateFlies(s as object, t as float, dt as float)
    ' Refresh one slice of neighbor lists every frame instead of all of them at once.
    n = s.flies.Count()
    slice = 2
    for k = 1 to slice
        i = s.neighborCursor
        s.neighborCursor = (i + 1) mod n
        a = s.flies[i]
        a.neighbors = []
        r = 160 + 260 * a.d
        for j = 0 to n - 1
            if j <> i
                b = s.flies[j]
                dx = b.x - a.x : dy = b.y - a.y
                if dx * dx + dy * dy < r * r then a.neighbors.Push(b)
            end if
        end for
    end for

    ' Coupling is weak and slow, so each firefly recomputes it every 6th frame.
    ff = s.cfg.fireflies
    K = ff.coupling
    s.frame = s.frame + 1
    phase = s.frame mod 6
    idx = 0
    for each f in s.flies
        ' Drift the natural frequency so synchrony forms and dissolves.
        f.retarget = f.retarget - dt
        if f.retarget <= 0
            f.freqTarget = 1.0 / (ff.periodMin + Rnd(0) * (ff.periodMax - ff.periodMin))
            f.retarget = 3 + Rnd(0) * 7
        end if
        f.freq = f.freq + (f.freqTarget - f.freq) * dt * 0.5

        if idx mod 6 = phase
            coupling = 0
            for each b in f.neighbors
                coupling = coupling + Sin(6.283 * (b.ph - f.ph))
            end for
            cnt = f.neighbors.Count()
            if cnt < 3 then cnt = 3
            f.cpl = K * coupling / cnt
        end if
        idx = idx + 1
        f.ph = f.ph + dt * (f.freq + f.cpl)
        f.ph = f.ph - Int(f.ph)

        ' Lazy wander: sum of slow sines, scaled by depth so far ones move less on screen.
        scale = 0.18 + 1.3 * f.d
        f.wx = f.wx + dt * f.wsx
        f.wy = f.wy + dt * f.wsy
        f.x = f.gx + (Sin(f.wx) * 90 + Sin(f.wx * 2.3 + 1.7) * 30) * scale
        f.y = f.gy - (f.h + 0.35 * Sin(f.wy) + 0.12 * Sin(f.wy * 3.1)) * 70 * scale
    end for
end sub

sub DrawFly(s as object, screen as object, f as object, bright as float, ox as float, oy as float)
    if f.ph >= f.lit then return
    u = f.ph / f.lit
    e = Sin(3.14159 * u ^ 0.65)
    env = e * e
    a = Int(255 * env * bright * (0.6 + 0.4 * f.d))
    if a < 3 then return
    if a > 255 then a = 255
    ' Even close fireflies are small points to the eye, so size grows only gently with depth.
    size = 8 + 22 * f.d
    idx = 0
    while idx < 5 and s.glowSizes[idx] < size
        idx = idx + 1
    end while
    bmp = s.glows[idx] : px = s.glowSizes[idx]
    screen.DrawObject(f.x + ox - px / 2, f.y + oy - px / 2, bmp, &hFFFFFF00 + a)
end sub
