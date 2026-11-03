' Cherry petals drifting down onto a lantern-lit canal at dusk.
'
' Back to front: plate and lantern glows, petals beyond the branch, petals floating on the
' water with their ripples, the foreground branch (swaying), petals in front of the branch.
'
' Petals tumble in 3D: the sprite's width follows cos(flip), floored so a petal seen edge-on
' never vanishes, and they fall slower face-on, when they catch the air. BrightScript can only
' scale bitmaps, so the in-plane spin picks from 8 pre-rotated sprites. Each petal has a depth d
' (0 at the far bank .. 1 at the bottom of the screen) that sets its size, speed and where it
' comes down. Over water it lands, sends out a ripple, floats with the current and fades within
' a few seconds, so petals never pile up; elsewhere it just fades. Occasional gusts sweep across
' as a moving Gaussian wind front, pushing petals and spinning them faster.

function BlossomsInit(cfg as object) as object
    p = PlateInit(cfg)
    s = {
        cfg: cfg
        plate: p
        sprites: []
        ripple: CreateObject("roBitmap", "pkg:/images/ripple.png")
        petals: []
        ripples: []
        gust: { active: false, wait: 8 + Rnd(0) * 12 }
    }
    for i = 0 to 7
        s.sprites.Push(CreateObject("roBitmap", "pkg:/images/petal_" + i.ToStr() + ".png"))
    end for
    s.spriteSize = s.sprites[0].GetWidth()

    ' Water spans are traced in unscaled plate coordinates; map them like stars and windows.
    sc = p.bg.GetWidth() / 1920.0
    w = cfg.water
    s.waterTop = (w.top - 540) * sc + 540
    s.waterStep = w.step * sc
    s.waterSpans = []
    for each sp in w.spans
        s.waterSpans.Push([(sp[0] - 960) * sc + 960, (sp[1] - 960) * sc + 960])
    end for

    for i = 1 to cfg.petals.count
        s.petals.Push(NewPetal(s, Rnd(0) * 1080))
    end for
    return s
end function

function NewPetal(s as object, y as float) as object
    pc = s.cfg.petals
    p = s.plate
    d = Rnd(0) ^ 0.8
    return {
        d: d
        x: Rnd(0) * 2000 - 40, y: y
        size: (pc.size[0] + d * (pc.size[1] - pc.size[0])) / s.spriteSize
        fall: pc.fall[0] + d * (pc.fall[1] - pc.fall[0])
        land: p.horizonY + d * (1080 - p.horizonY) + (Rnd(0) - 0.5) * 20
        flip: Rnd(0) * 6.283, flipRate: 1.2 + Rnd(0) * 1.8
        spin: Rnd(0) * 180, spinRate: (Rnd(0) - 0.5) * 70
        sw: Rnd(0) * 6.283, swRate: 0.5 + Rnd(0) * 0.7, swAmp: 15 + Rnd(0) * 25
        state: 0, age: 0, life: 0
        alpha: 255 * pc.alpha * (0.7 + 0.3 * d)
    }
end function

sub BlossomsFrame(s as object, screen as object, t as float, dt as float)
    p = s.plate
    PlateDrift(p, t)
    PlateDrawSky(p, screen, t)
    PlateDrawWindows(p, screen, t)

    UpdateGust(s, dt)
    for each f in s.petals
        UpdatePetal(s, f, t, dt)
    end for
    UpdateRipples(s, screen, dt, p.bx, p.by)

    ' Floating petals lie on the water; falling ones split around the branch by depth.
    for each f in s.petals
        if f.state = 1 then DrawFloating(s, screen, f, p.bx, p.by)
    end for
    for each f in s.petals
        if f.state <> 1 and f.d < 0.85 then DrawPetal(s, screen, f, p.bx)
    end for
    PlateDrawFg(p, screen)
    for each f in s.petals
        if f.state <> 1 and f.d >= 0.85 then DrawPetal(s, screen, f, p.fx * 1.4)
    end for
end sub

sub UpdateGust(s as object, dt as float)
    g = s.gust
    gc = s.cfg.gusts
    if g.active
        g.x = g.x + g.speed * dt
        if g.x > 1920 + 3 * gc.width
            g.active = false
            g.wait = gc.every[0] + Rnd(0) * (gc.every[1] - gc.every[0])
        end if
    else
        g.wait = g.wait - dt
        if g.wait <= 0
            g.active = true
            g.x = -3 * gc.width
            g.speed = gc.speed * (0.8 + 0.4 * Rnd(0))
            g.strength = gc.strength * (0.6 + 0.4 * Rnd(0))
        end if
    end if
end sub

function WaterAt(s as object, x as float, y as float) as boolean
    i = Int((y - s.waterTop) / s.waterStep)
    if i < 0 or i >= s.waterSpans.Count() then return false
    sp = s.waterSpans[i]
    return x >= sp[0] and x <= sp[1]
end function

sub UpdatePetal(s as object, f as object, t as float, dt as float)
    pc = s.cfg.petals
    if f.state = 0
        ' Falling. Gust strength at this petal's x: a Gaussian front moving across the screen.
        gw = 0
        g = s.gust
        if g.active
            dx = (f.x - g.x) / s.cfg.gusts.width
            gw = g.strength * Exp(-dx * dx)
        end if
        c = Cos(f.flip)
        if c < 0 then c = -c
        ' Face-on (c near 1) catches the air and falls slower.
        f.y = f.y + f.fall * (1.15 - 0.55 * c) * dt
        f.x = f.x + (pc.drift + gw) * (0.4 + 0.6 * f.d) * dt
        f.sw = f.sw + f.swRate * dt
        tumble = 1 + 2.5 * gw / s.cfg.gusts.strength
        f.flip = f.flip + f.flipRate * tumble * dt
        f.spin = f.spin + f.spinRate * tumble * dt
        if f.y >= f.land
            x = f.x + f.swAmp * Sin(f.sw)
            if WaterAt(s, x, f.land)
                f.state = 1 : f.x = x : f.age = 0 : f.life = pc.float[0] + Rnd(0) * (pc.float[1] - pc.float[0])
                if s.ripples.Count() < 16 then s.ripples.Push({ x: x, y: f.land, age: 0, size: 0.3 + 0.9 * f.d })
            else
                f.state = 2 : f.age = 0 : f.life = 0.6
            end if
        end if
    else
        ' Floating (1) drifts with the current; landed elsewhere (2) just fades.
        f.age = f.age + dt
        if f.state = 1 then f.x = f.x + pc.current * (0.3 + 0.7 * f.d) * dt
        if f.age >= f.life
            n = NewPetal(s, -20 - Rnd(0) * 200)
            f.Append(n)
        end if
    end if
    if f.x < -60 then f.x = f.x + 2040
    if f.x > 1980 then f.x = f.x - 2040
end sub

'' Petals are drawn tinted cooler and darker than their sprite, so they sit in the dusk light.
function PetalTint() as integer
    return &hC8BCCC00
end function

sub DrawPetal(s as object, screen as object, f as object, ox as float)
    c = Cos(f.flip)
    if c < 0 then c = -c
    if c < 0.18 then c = 0.18
    a = f.alpha
    if f.state = 2 then a = a * (1 - f.age / f.life)
    idx = Int(FMod(f.spin, 180) / 22.5)
    sx = f.size * c : sy = f.size
    half = s.spriteSize / 2
    screen.DrawScaledObject(f.x + f.swAmp * Sin(f.sw) + ox - half * sx, f.y - half * sy, sx, sy, s.sprites[idx], PetalTint() + Int(a))
end sub

sub DrawFloating(s as object, screen as object, f as object, ox as float, oy as float)
    ' Lying flat on the water: squashed vertically, fading over its life.
    a = f.alpha * (1 - f.age / f.life)
    if f.age < 0.4 then a = a * (0.5 + f.age / 0.8)
    sx = f.size : sy = f.size * 0.45
    half = s.spriteSize / 2
    idx = Int(FMod(f.spin, 180) / 22.5)
    screen.DrawScaledObject(f.x + ox - half * sx, f.land + oy - half * sy, sx, sy, s.sprites[idx], PetalTint() + Int(a))
end sub

sub UpdateRipples(s as object, screen as object, dt as float, ox as float, oy as float)
    life = 2.6
    keep = []
    for each r in s.ripples
        r.age = r.age + dt
        if r.age < life
            k = r.age / life
            sx = r.size * (0.15 + 0.85 * k) : sy = sx * 0.3
            screen.DrawScaledObject(r.x + ox - 64 * sx, r.y + oy - 64 * sy, sx, sy, s.ripple, &hFFFFFF00 + Int(110 * (1 - k)))
            keep.Push(r)
        end if
    end for
    s.ripples = keep
end sub
