' Screensaver settings: which scene to show, or cycle through all of them.
' Roku opens RunScreenSaverSettings from the screensaver's entry under Settings > Theme >
' Screensavers. Choices persist in the registry and RunScreenSaver reads them.

function SceneChoices() as object
    return [
        { id: "fireflies", label: "Fireflies at dusk" }
        { id: "snow", label: "Snowfall and aurora" }
        { id: "blossoms", label: "Cherry blossoms on the canal" }
        { id: "cycle", label: "Cycle through all scenes" }
    ]
end function

function CycleChoices() as object
    return [5, 10, 20, 30, 60]
end function

function LoadSettings() as object
    reg = CreateObject("roRegistrySection", "dusk")
    s = { scene: "fireflies", cycleMinutes: 10 }
    if reg.Exists("scene") then s.scene = reg.Read("scene")
    if reg.Exists("cycleMinutes") then s.cycleMinutes = reg.Read("cycleMinutes").ToInt()
    return s
end function

sub SaveSettings(s as object)
    reg = CreateObject("roRegistrySection", "dusk")
    reg.Write("scene", s.scene)
    reg.Write("cycleMinutes", s.cycleMinutes.ToStr())
    reg.Flush()
end sub

sub RunScreenSaverSettings()
    screen = CreateObject("roScreen", true, 1920, 1080)
    screen.SetAlphaEnable(true)
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    fonts = CreateObject("roFontRegistry")
    title = fonts.GetDefaultFont(56, true, false)
    font = fonts.GetDefaultFont(40, false, false)
    small = fonts.GetDefaultFont(30, false, false)

    st = LoadSettings()
    choices = SceneChoices()
    cycles = CycleChoices()
    ' Rows: the choices, then the cycle interval (only meaningful when cycling).
    sel = 0
    for i = 0 to choices.Count() - 1
        if choices[i].id = st.scene then sel = i
    end for
    ci = 1
    for i = 0 to cycles.Count() - 1
        if cycles[i] = st.cycleMinutes then ci = i
    end for

    while true
        screen.Clear(&h0B1020FF)
        screen.DrawText("Dusk", 160, 120, &hF2E6D0FF, title)
        screen.DrawText("Choose what the screensaver shows. OK selects, Back saves and exits.", 160, 200, &h9AA3B5FF, small)
        y = 300
        for i = 0 to choices.Count() - 1
            on = choices[i].id = st.scene
            if i = sel then screen.DrawRect(140, y - 12, 1100, 68, &h2A3550FF)
            mark = "   "
            if on then mark = "*  "
            screen.DrawText(mark + choices[i].label, 170, y, &hF2E6D0FF, font)
            y = y + 80
        end for
        y = y + 30
        if sel = choices.Count() then screen.DrawRect(140, y - 12, 1100, 68, &h2A3550FF)
        color = &h9AA3B5FF
        if st.scene = "cycle" then color = &hF2E6D0FF
        screen.DrawText("Change scene every  <  " + cycles[ci].ToStr() + " minutes  >", 170, y, color, font)
        screen.SwapBuffers()

        msg = wait(0, port)
        if type(msg) = "roUniversalControlEvent"
            k = msg.GetInt()
            if k = 0 ' back
                SaveSettings(st)
                return
            else if k = 2 and sel > 0 ' up
                sel = sel - 1
            else if k = 3 and sel < choices.Count() ' down
                sel = sel + 1
            else if k = 6 and sel < choices.Count() ' OK
                st.scene = choices[sel].id
            else if sel = choices.Count() and k = 4 and ci > 0 ' left
                ci = ci - 1
            else if sel = choices.Count() and k = 5 and ci < cycles.Count() - 1 ' right
                ci = ci + 1
            end if
            st.cycleMinutes = cycles[ci]
        end if
    end while
end sub
