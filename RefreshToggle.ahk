#Requires AutoHotkey v2.0
;RefreshToggle.ahk v4.2 — Stable Release

; === Global Setup ===
debugMode := false
scriptEnabled := true
refreshRates := [120, 144, 159.97]
displayLabels := ["120", "144", "160"]
currentIndex := 0
monitorIndex := 0
hzInGame := 160
hzOutOfGame := 120
autoState := "idle"
scriptPath := "C:\Scripts\PowerShell\Cycle-RefreshRate.ps1"

; === Refresh Tracking ===
lastScriptedRate := Round(GetCurrentRefreshRate())
if lastScriptedRate = "" || !IsNumber(lastScriptedRate)
    lastScriptedRate := 120
lastScriptedTime := A_TickCount
lastManualCheck := A_TickCount

; === Tooltip Defaults ===
DefaultGuiOpts := "+AlwaysOnTop -Caption +ToolWindow -DPIScale"
DefaultFont := "s12 bold"
DefaultFontFace := "Segoe UI"
DefaultBackColor := "Black"
DefaultOpacity := 220

; === Tooltip Positions (Per Message) ===
TooltipX := Map(1, 350, 2, 500, 3, 550, 4, 350, 5, 375, 6, 575)
TooltipY := Map(1, 150, 2, 175, 3, 150, 4, 150, 5, 150, 6, 200)

; === Tooltip Durations ===
DurationToggle := 3000
DurationBlocked := 3500
DurationManual := 3000
DurationChanged := 2000
DurationExit := 10000
DurationDebugFade := 5000

; === Sounds ===
SoundSoft := "*64"
SoundAlert := "*48"

; === Logging ===
logDir := "C:\Logs"
logDate := FormatTime(, "yyyy-MM-dd")
logFile := logDir . "\RefreshRate_" . logDate . ".log"
if !FileExist(logDir)
    DirCreate(logDir)
if !FileExist(logFile)
    FileAppend("=== Refresh Rate Log Started: " . logDate . " ===`n", logFile)
Loop Files logDir "\RefreshRate_*.log" {
    if (A_Now - A_LoopFileTimeModified) // 86400 > 30
        FileDelete A_LoopFileFullPath
}

; === Launcher List ===
launchers := [
    "steam.exe", "Playnite.DesktopApp.exe", "EpicGamesLauncher.exe",
    "Amazon Games.exe", "EADesktop.exe", "UbisoftConnect.exe",
    "Battle.net.exe", "RockstarLauncher.exe", "RiotClientServices.exe"
]

; === GUI Handles ===
tooltipGui := Gui(DefaultGuiOpts)
tooltipGui.Opacity := DefaultOpacity
tooltipGui.BackColor := DefaultBackColor
tooltipGui.SetFont(DefaultFont, DefaultFontFace)
debugOverlay := Gui(DefaultGuiOpts)

; === Hotkeys & Timers ===
SetTimer(MainPollingLoop, 3000)
SetTimer(CheckNumLockState, 30000)
^+!Esc::ToggleDebugMode()
NumLock::CheckNumLockState()
Hotkey("^+r", TryToggleRefreshRate)
Hotkey("^!r", TryToggleRefreshRate)
Hotkey("^+!r", TryToggleRefreshRate)

; === Debug Toggle Function ===
ToggleDebugMode() {
    global debugMode, debugOverlay
    debugMode := !debugMode
    debugOverlay.Destroy()
    debugOverlay := Gui(DefaultGuiOpts)
    debugOverlay.Opacity := DefaultOpacity
    debugOverlay.BackColor := DefaultBackColor
    debugOverlay.SetFont(DefaultFont, DefaultFontFace)
    debugOverlay.AddText("cWhite BackgroundBlack", debugMode ? "Debug On" : "Debug Off")
    debugOverlay.Show("x10 y10 NoActivate")
    SoundPlay(SoundSoft)
    if !debugMode
        SetTimer(() => debugOverlay.Hide(), -DurationDebugFade)
}

; === Debug Hotkeys ===
1:: {
    if debugMode {
        msg := scriptEnabled ? "Refresh Toggle (Hz) On" : "Refresh Toggle (Hz) Off"
        color := scriptEnabled ? "Green" : "Red"
        ShowTestTooltip(msg, color, DurationToggle, TooltipX[1], TooltipY[1])
    }
}
2:: {
    if debugMode {
        ShowTestTooltip("⚠️ Cannot change refresh rate:`nSampleApp.exe is currently running.", "Red", DurationBlocked, TooltipX[2], TooltipY[2])
    }
}
3:: {
    if debugMode {
        ShowTestTooltip("Refresh rate manually changed to 144 Hz", "Yellow", DurationManual, TooltipX[3], TooltipY[3])
    }
}
4:: {
    if debugMode {
        ShowTestTooltip("Switched to 160 Hz", "White", DurationChanged, TooltipX[4], TooltipY[4])
    }
}
5:: {
    if debugMode {
        ShowTestTooltip("Closing Refresh Toggle...", "Yellow", DurationExit, TooltipX[5], TooltipY[5])
    }
}
6:: {
    if debugMode {
        ShowConfirmationPopup("Confirm refresh rate change to 160 Hz?", "Y", 10000)
    }
}

; === Tooltip Functions ===
ShowToggleTooltip(text, color, x := 350, y := 150) {
    global tooltipGui
    tooltipGui.Destroy()
    tooltipGui := Gui(DefaultGuiOpts)
    tooltipGui.Opacity := DefaultOpacity
    tooltipGui.BackColor := DefaultBackColor
    tooltipGui.SetFont(DefaultFont, DefaultFontFace)
    tooltipGui.AddText("c" . color . " BackgroundBlack", text)
    MonitorGet(MonitorGetPrimary(), &left, &top, &right, &bottom)
    tooltipGui.Show("x" (right - x) " y" (bottom - y) " NoActivate")
    SoundPlay(SoundSoft)
    SetTimer(() => tooltipGui.Hide(), -DurationToggle)
}

ShowTestTooltip(text, color, duration, x := 350, y := 150) {
    global tooltipGui
    tooltipGui.Destroy()
    tooltipGui := Gui(DefaultGuiOpts)
    tooltipGui.Opacity := DefaultOpacity
    tooltipGui.BackColor := DefaultBackColor
    tooltipGui.SetFont(DefaultFont, DefaultFontFace)
    tooltipGui.AddText("c" . color . " BackgroundBlack", text)
    MonitorGet(MonitorGetPrimary(), &left, &top, &right, &bottom)
    tooltipGui.Show("x" (right - x) " y" (bottom - y) " NoActivate")
    SoundPlay(SoundSoft)
    SetTimer(() => tooltipGui.Hide(), -duration)
}

; === Main Polling ===
MainPollingLoop() {
    if !scriptEnabled
        return
    MonitorLaunchers()
    CheckManualRefreshChange()
}

MonitorLaunchers() {
    global autoState, scriptPath, hzInGame, hzOutOfGame, lastScriptedRate, lastScriptedTime
    if app := GetRunningLauncher() {
        if autoState != "in-game" {
            RunWait('powershell.exe -ExecutionPolicy Bypass -File "' scriptPath '" -Rate ' hzInGame, , "Hide")
            LogRefreshChange(hzInGame, "Auto - Triggered by " . app)
            lastScriptedRate := hzInGame
            lastScriptedTime := A_TickCount
            autoState := "in-game"
        }
    } else if autoState = "in-game" {
        RunWait('powershell.exe -ExecutionPolicy Bypass -File "' scriptPath '" -Rate ' hzOutOfGame, , "Hide")
        LogRefreshChange(hzOutOfGame, "Auto - Reverted after game closed")
        lastScriptedRate := hzOutOfGame
        lastScriptedTime := A_TickCount
        autoState := "idle"
    }
}

CheckNumLockState() {
    global scriptEnabled
    isOn := GetKeyState("NumLock", "T")
    if isOn && !scriptEnabled {
        scriptEnabled := true
        ShowToggleTooltip("Refresh Toggle (Hz) On", "Green", TooltipX[1], TooltipY[1])
        LogRefreshChange("N/A", "Script resumed via Num Lock")
    } else if !isOn && scriptEnabled {
        scriptEnabled := false
        ShowToggleTooltip("Refresh Toggle (Hz) Off", "Red", TooltipX[1], TooltipY[1])
        LogRefreshChange("N/A", "Script paused via Num Lock")
    }
}

CheckManualRefreshChange() {
    global lastScriptedRate, lastScriptedTime, lastManualCheck
    if (A_TickCount - lastManualCheck < 10000)
        return
    lastManualCheck := A_TickCount
    currentHz := Round(GetCurrentRefreshRate())
    if currentHz = "" || !IsNumber(currentHz)
        return
    if Abs(currentHz - lastScriptedRate) > 10 {
        LogRefreshChange(currentHz, "Manual - User changed refresh rate")
        lastScriptedRate := currentHz
        lastScriptedTime := A_TickCount
        ShowTestTooltip("Refresh rate manually changed to " . currentHz . " Hz", "Yellow", DurationManual, TooltipX[3], TooltipY[3])
    }
}

GetCurrentRefreshRate() {
    try {
        query := ComObjGet("winmgmts:").ExecQuery("Select * from Win32_VideoController")
        for item in query
            return Round(item.CurrentRefreshRate)
    } catch {
        return ""
    }
}

GetRunningLauncher() {
    global launchers
    for launcher in launchers {
        if ProcessExist(launcher)
            return launcher
    }
    return ""
}

LogRefreshChange(rate, reason := "") {
    global logFile
    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    entry := "[" . timestamp . "] Switched to " . rate . " Hz"
    if reason != ""
        entry .= " - " . reason
    FileAppend(entry . "`n", logFile)
}

ShowConfirmationPopup(promptText, confirmKey := "Y", timeout := 10000) {
    global TooltipX, TooltipY, DefaultGuiOpts, DefaultFont, DefaultFontFace, DefaultOpacity
    local confirmGui := Gui(DefaultGuiOpts)
    confirmGui.Opacity := DefaultOpacity
    confirmGui.BackColor := "Black"
    confirmGui.SetFont(DefaultFont, DefaultFontFace)

    confirmGui.AddText("cWhite BackgroundBlack", promptText)
    confirmGui.AddText("cGray BackgroundBlack", "Press [" . confirmKey . "] to confirm — auto-closes in " . timeout/1000 . "s")
    MonitorGet(MonitorGetPrimary(), &left, &top, &right, &bottom)
    confirmGui.Show("x" (right - TooltipX[6]) " y" (bottom - TooltipY[6]) " NoActivate")

    listener := InputHook("L1")
    listener.KeyOpt(confirmKey, "E")  ; only trigger on release
    listener.Start(), listener.Wait(timeout)

    confirmGui.Destroy()

    if listener.EndReason = "Key" && listener.Input = confirmKey {
        ShowTestTooltip("✅ Confirmed: Switching to 160 Hz", "Green", 2000, TooltipX[4], TooltipY[4])
        LogRefreshChange(160, "Manual (Confirmed via Debug)")
        lastScriptedRate := 160
        lastScriptedTime := A_TickCount
        ; Optional → RunWait to actually switch
        ; RunWait('powershell.exe -ExecutionPolicy Bypass -File "' scriptPath '" -Monitor ' monitorIndex ' -Rate 160, , "Hide")
    }
}

TryToggleRefreshRate(*) {
    if app := GetRunningLauncher() {
        ShowTestTooltip("⚠️ Cannot change refresh rate:`n" . app . " is currently running.", "Red", DurationBlocked, TooltipX[2], TooltipY[2])
        return
    }
    ToggleRefreshRate()
}

ToggleRefreshRate(*) {
    global currentIndex, refreshRates, displayLabels, monitorIndex, scriptPath
    global lastScriptedRate, lastScriptedTime
    global TooltipX, TooltipY, DurationChanged

    currentIndex := Mod(currentIndex + 1, refreshRates.Length)
    newRate := refreshRates[currentIndex + 1]
    displayLabel := displayLabels[currentIndex + 1]

    ; If switching to 160 and not already there → ask for confirmation
    if newRate = 160 && lastScriptedRate != 160 {
        ShowConfirmationPopup("Confirm refresh rate change to 160 Hz?", "Y", 10000)
        return  ; wait for user to confirm via popup
    }

    ; Otherwise, toggle without confirmation
    RunWait('powershell.exe -ExecutionPolicy Bypass -File "' scriptPath '" -Monitor ' monitorIndex ' -Rate ' newRate, , "Hide")
    LogRefreshChange(newRate, "Manual")
    lastScriptedRate := newRate
    lastScriptedTime := A_TickCount
    ShowTestTooltip("Switched to " . displayLabel . " Hz", "White", DurationChanged, TooltipX[4], TooltipY[4])
}

^!Esc:: {  ; Emergency fallback to 120 Hz and exit
    global scriptPath, monitorIndex, logFile, tooltipGui
    safeRate := 120
    RunWait('powershell.exe -ExecutionPolicy Bypass -File "' scriptPath '" -Monitor ' monitorIndex ' -Rate ' safeRate, , "Hide")
    LogRefreshChange(safeRate, "Manual Emergency Revert")
    tooltipGui.Destroy()
    tooltipGui := Gui(DefaultGuiOpts)
    tooltipGui.Opacity := DefaultOpacity
    tooltipGui.BackColor := DefaultBackColor
    tooltipGui.SetFont(DefaultFont, DefaultFontFace)
    tooltipGui.AddText("cYellow BackgroundBlack", "Closing Refresh Toggle...")
    MonitorGet(MonitorGetPrimary(), &left, &top, &right, &bottom)
    tooltipGui.Show("x" (right - TooltipX[5]) " y" (bottom - TooltipY[5]) " NoActivate")
    SoundPlay(SoundAlert)
    Sleep(DurationExit)
    ExitApp
}
