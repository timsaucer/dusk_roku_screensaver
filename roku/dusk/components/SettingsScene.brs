' Two radio lists: the scene (or cycle) and the cycle interval. Up/down moves between them at
' their ends; Back reports done so the main thread saves and closes.

sub init()
    m.ids = ["fireflies", "snow", "blossoms", "cycle"]
    m.minutes = [5, 10, 20, 30, 60]
    m.scenes = m.top.findNode("scenes")
    m.cycle = m.top.findNode("cycle")
    m.scenes.content = ListContent(["Fireflies at dusk", "Snowfall and aurora", "Cherry blossoms on the canal", "Cycle through all scenes"])
    labels = []
    for each n in m.minutes
        labels.Push(n.ToStr() + " minutes")
    end for
    m.cycle.content = ListContent(labels)
    m.scenes.observeField("checkedItem", "onChecked")
    m.cycle.observeField("checkedItem", "onChecked")
    m.scenes.setFocus(true)
end sub

function ListContent(labels as object) as object
    root = CreateObject("roSGNode", "ContentNode")
    for each l in labels
        item = root.createChild("ContentNode")
        item.title = l
    end for
    return root
end function

' Initial values arrive from the main thread after init.
sub onSettingsSet()
    for i = 0 to m.ids.Count() - 1
        if m.ids[i] = m.top.scene then m.scenes.checkedItem = i
    end for
    for i = 0 to m.minutes.Count() - 1
        if m.minutes[i] = m.top.cycleMinutes then m.cycle.checkedItem = i
    end for
end sub

sub onChecked()
    if m.scenes.checkedItem >= 0 then m.top.scene = m.ids[m.scenes.checkedItem]
    if m.cycle.checkedItem >= 0 then m.top.cycleMinutes = m.minutes[m.cycle.checkedItem]
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "back"
        m.top.done = true
        return true
    else if key = "down" and m.scenes.hasFocus() and m.scenes.itemFocused = m.ids.Count() - 1
        m.cycle.setFocus(true)
        return true
    else if key = "up" and m.cycle.hasFocus() and m.cycle.itemFocused = 0
        m.scenes.setFocus(true)
        return true
    end if
    return false
end function
