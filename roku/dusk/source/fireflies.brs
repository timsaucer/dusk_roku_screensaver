' Fireflies over a blue-hour plate.
'
' Each firefly hovers above a ground point (gx, gy). Depth d comes from gy relative to the
' horizon, and sets size, speed and brightness. Flashes follow a per-firefly cycle with weak
' Kuramoto coupling to neighbors, so loose synchrony forms and dissolves.

function FirefliesInit(cfg as object) as object
    s = {
        cfg: cfg
        bg: CreateObject("roBitmap", cfg.bg)
        fg: CreateObject("roBitmap", cfg.fg)
        winGlow: CreateObject("roBitmap", "pkg:/images/winglow.png")
        glowSizes: [8, 12, 17, 24, 34, 48]
        stars: []
        glows: []
        flies: []
        neighborTimer: 0
        neighborCursor: 0
    }
    for each px in s.glowSizes
        s.glows.Push(CreateObject("roBitmap", "pkg:/images/glow_" + px.ToStr() + ".png"))
    end for
    for i = 0 to 2
        s.stars.Push(CreateObject("roBitmap", "pkg:/images/star_" + i.ToStr() + ".png"))
    end for
    ' Layers are larger than the screen by a margin so parallax never shows an edge.
    s.bgMargin = [(s.bg.GetWidth() - 1920) / 2, (s.bg.GetHeight() - 1080) / 2]
    s.fgMargin = [(s.fg.GetWidth() - 1920) / 2, (s.fg.GetHeight() - 1080) / 2]
    s.horizonY = cfg.horizon * 1080
    ' Stars: precompute position and base brightness; twinkle is refreshed a quarter per frame.
    s.starList = []
    s.starCursor = 0
    if cfg.stars <> invalid
        for each st in cfg.stars
            s.starList.Push({
                x: st[0] - 1 - st[2], y: st[1] - 1 - st[2], bmp: s.stars[st[2]]
                base: 255 * (0.22 + 0.18 * st[2]) * (1 - 0.7 * st[1] / s.horizonY)
                rate: 0.6 + st[3], ph: st[3] * 6.283, rgba: &hFFFFFF00
            })
        end for
    end if
    s.frame = 0

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
    cfg = s.cfg
    if s.prof = invalid then s.prof = { clk: CreateObject("roTimespan"), bg: 0, stars: 0, upd: 0, far: 0, fg: 0, near: 0, n: 0 }
    pf = s.prof : pf.clk.Mark()

    ' Slow Lissajous camera drift; the foreground moves more than the plate.
    pt = t * 6.283 / cfg.parallax.period
    px = Sin(pt) : py = Sin(pt * 0.7 + 1.3)
    screen.DrawObject(-s.bgMargin[0] + px * cfg.parallax.bg[0], -s.bgMargin[1] + py * cfg.parallax.bg[1], s.bg)

    pf.bg = pf.bg + pf.clk.TotalMicroseconds() : pf.clk.Mark()
    ' Stars twinkle slowly; fainter near the horizon. Placed offline in open sky only.
    ns = s.starList.Count()
    if ns > 0
        for k = 1 to (ns + 3) \ 4
            st = s.starList[s.starCursor]
            s.starCursor = (s.starCursor + 1) mod ns
            st.rgba = &hFFFFFF00 + Int(st.base * (0.7 + 0.3 * Sin(t * st.rate + st.ph)))
        end for
        sx = px * cfg.parallax.bg[0] : sy = py * cfg.parallax.bg[1]
        for each st in s.starList
            screen.DrawObject(st.x + sx, st.y + sy, st.bmp, st.rgba)
        end for
    end if

    ' Window glows, each flickering on its own.
    k = 0
    for each w in cfg.windows
        flick = 0.88 + 0.07 * Sin(t * 2.3 + k * 1.9) + 0.05 * Sin(t * 5.7 + 1.1 + k * 0.7)
        gs = w.size * 1920 / 256.0
        ga = Int(255 * w.alpha * flick)
        screen.DrawScaledObject(w.x * 1920 - 128 * gs + px * cfg.parallax.bg[0], w.y * 1080 - 128 * gs + py * cfg.parallax.bg[1], gs, gs, s.winGlow, &hFFFFFF00 + ga)
        k = k + 1
    end for

    pf.stars = pf.stars + pf.clk.TotalMicroseconds() : pf.clk.Mark()
    UpdateFlies(s, t, dt)
    pf.upd = pf.upd + pf.clk.TotalMicroseconds() : pf.clk.Mark()

    ' Far fireflies sit behind the foreground layer; near ones in front of it.
    bright = cfg.fireflies.brightness
    for each f in s.flies
        if f.d < 0.88 then DrawFly(s, screen, f, bright, px * cfg.parallax.bg[0], py * cfg.parallax.bg[1])
    end for
    pf.far = pf.far + pf.clk.TotalMicroseconds() : pf.clk.Mark()
    screen.DrawObject(-s.fgMargin[0] + px * cfg.parallax.fg[0], -s.fgMargin[1] + py * cfg.parallax.fg[1], s.fg)
    for each f in s.flies
        if f.d >= 0.88 then DrawFly(s, screen, f, bright, px * cfg.parallax.fg[0] * 1.6, py * cfg.parallax.fg[1] * 1.6)
    end for
    pf.near = pf.near + pf.clk.TotalMicroseconds()
    pf.n = pf.n + 1
    if pf.n = 300
        print "PROF us/frame bg "; pf.bg / 300; " stars "; pf.stars / 300; " upd "; pf.upd / 300; " far "; pf.far / 300; " fg+near "; pf.near / 300
        pf.bg = 0 : pf.stars = 0 : pf.upd = 0 : pf.far = 0 : pf.near = 0 : pf.n = 0
    end if
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
