' A check list of scenes (at least one stays ticked; two or more cycle) and a radio list for the
' cycle interval, dimmed while only one scene is ticked. Up/Down at the ends of a list moves to
' the other; Back reports done so the main thread saves and closes.

sub init()
    m.ids = ["fireflies", "snow", "blossoms"]
    m.minutes = [5, 10, 20, 30, 60]
    m.scenes = m.top.findNode("scenes")
    m.cycle = m.top.findNode("cycle")
    m.cycleTitle = m.top.findNode("cycleTitle")
    m.scenes.content = ListContent(["Fireflies at dusk", "Snowfall and aurora", "Cherry blossoms on the canal"])
    labels = []
    for each n in m.minutes
        labels.Push(n.ToStr() + " minutes")
    end for
    m.cycle.content = ListContent(labels)
    m.scenes.checkedState = [true, false, false]
    m.scenes.observeField("checkedState", "onChecked")
    m.cycle.observeField("checkedItem", "onCycleChecked")
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
sub onScenesSet()
    state = []
    for each id in m.ids
        state.Push(Instr(1, "," + m.top.scenes + ",", "," + id + ",") > 0)
    end for
    if not SameState(state, m.scenes.checkedState) then m.scenes.checkedState = state
    updateCycleLook()
end sub

sub onMinutesSet()
    for i = 0 to m.minutes.Count() - 1
        if m.minutes[i] = m.top.cycleMinutes and m.cycle.checkedItem <> i then m.cycle.checkedItem = i
    end for
end sub

function SameState(a as object, b as object) as boolean
    if a.Count() <> b.Count() then return false
    for i = 0 to a.Count() - 1
        if a[i] <> b[i] then return false
    end for
    return true
end function

sub onChecked()
    state = m.scenes.checkedState
    picked = []
    for i = 0 to m.ids.Count() - 1
        if state[i] then picked.Push(m.ids[i])
    end for
    if picked.Count() = 0
        ' Never allow an empty choice: re-tick the item just unticked.
        state = [false, false, false]
        state[m.scenes.itemFocused] = true
        m.scenes.checkedState = state
        return
    end if
    m.top.scenes = picked.Join(",")
    updateCycleLook()
end sub

sub onCycleChecked()
    if m.cycle.checkedItem >= 0 then m.top.cycleMinutes = m.minutes[m.cycle.checkedItem]
end sub

' The interval only matters with two or more scenes; dim it otherwise.
sub updateCycleLook()
    n = 0
    for each on in m.scenes.checkedState
        if on then n = n + 1
    end for
    if n > 1 then m.cycle.opacity = 1.0 else m.cycle.opacity = 0.45
    if n > 1 then m.cycleTitle.opacity = 1.0 else m.cycleTitle.opacity = 0.45
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    if key = "back"
        m.top.done = true
        return true
    else if key = "down" and m.scenes.hasFocus()
        m.cycle.setFocus(true)
        return true
    else if key = "up" and m.cycle.hasFocus()
        m.scenes.setFocus(true)
        return true
    end if
    return false
end function
