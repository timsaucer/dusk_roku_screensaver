' Screensaver settings: which scenes to show (any of the three; two or more cycle) and how
' often to change scene. Roku opens RunScreenSaverSettings from the screensaver's "Change
' screensaver settings" entry. That context only shows SceneGraph screens, so the UI is
' components/SettingsScene.xml; this side loads the saved choice into it and saves it back to
' the registry when the user leaves.

function AllScenes() as object
    return ["fireflies", "snow", "blossoms"]
end function

' "a,b,c" -> ["a", "b", "c"] as an roArray (String.Split returns an roList).
function SplitNames(text as string) as object
    out = []
    for each part in text.Split(",")
        if part <> "" then out.Push(part)
    end for
    return out
end function

function LoadSettings() as object
    reg = CreateObject("roRegistrySection", "dusk")
    s = { scenes: ["fireflies"], cycleMinutes: 10 }
    if reg.Exists("scenes")
        s.scenes = SplitNames(reg.Read("scenes"))
    else if reg.Exists("scene")
        ' Settings saved by 1.0.1, which stored one scene or "cycle" (meaning all of them).
        old = reg.Read("scene")
        if old = "cycle" then s.scenes = AllScenes() else s.scenes = [old]
    end if
    ' Drop anything unknown (e.g. a scene removed in a later version); never leave it empty.
    known = []
    for each name in s.scenes
        for each k in AllScenes()
            if k = name then known.Push(name)
        end for
    end for
    if known.Count() = 0 then known = ["fireflies"]
    s.scenes = known
    if reg.Exists("cycleMinutes") then s.cycleMinutes = reg.Read("cycleMinutes").ToInt()
    return s
end function

sub SaveSettings(s as object)
    reg = CreateObject("roRegistrySection", "dusk")
    reg.Write("scenes", s.scenes.Join(","))
    reg.Write("cycleMinutes", s.cycleMinutes.ToStr())
    if reg.Exists("scene") then reg.Delete("scene")
    reg.Flush()
end sub

sub RunScreenSaverSettings()
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    ui = screen.CreateScene("SettingsScene")
    screen.Show()
    st = LoadSettings()
    ui.cycleMinutes = st.cycleMinutes
    ui.scenes = st.scenes.Join(",")
    ui.ObserveField("done", port)

    while true
        msg = wait(0, port)
        t = type(msg)
        if (t = "roSGNodeEvent" and msg.GetField() = "done") or (t = "roSGScreenEvent" and msg.IsScreenClosed())
            SaveSettings({ scenes: SplitNames(ui.scenes), cycleMinutes: ui.cycleMinutes })
            print "SETTINGS saved scenes="; ui.scenes; " cycleMinutes="; ui.cycleMinutes
            return
        end if
    end while
end sub
