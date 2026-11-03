' Screensaver settings: which scene to show, or cycle through all of them.
' Roku opens RunScreenSaverSettings from the screensaver's "Change screensaver settings" entry.
' That context only shows SceneGraph screens, so the UI is components/SettingsScene.xml; this
' side loads the saved choice into it and saves it back to the registry when the user leaves.

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
    screen = CreateObject("roSGScreen")
    port = CreateObject("roMessagePort")
    screen.SetMessagePort(port)
    ui = screen.CreateScene("SettingsScene")
    screen.Show()
    st = LoadSettings()
    ui.scene = st.scene
    ui.cycleMinutes = st.cycleMinutes
    ui.ObserveField("done", port)

    while true
        msg = wait(0, port)
        t = type(msg)
        if (t = "roSGNodeEvent" and msg.GetField() = "done") or (t = "roSGScreenEvent" and msg.IsScreenClosed())
            SaveSettings({ scene: ui.scene, cycleMinutes: ui.cycleMinutes })
            print "SETTINGS saved scene="; ui.scene; " cycleMinutes="; ui.cycleMinutes
            return
        end if
    end while
end sub
