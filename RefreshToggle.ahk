#Requires AutoHotkey v2.0

; === Global Setup ===
debugMode := false
debugToggleState := false
scriptEnabled := true
refreshRates := [120, 144, 159.97]
displayLabels := ["120", "144", "160"]
currentIndex := 0
monitorIndex := 0
hzInGame := 160
hzOutOfGame := 120
autoState := "idle"
lastScriptedRate := 120
lastScriptedTime := A_TickCount
scriptPath := "C:\Scripts\PowerShell\Cycle-RefreshRate.ps1"

; === Tooltip & GUI Defaults ===
DefaultGuiOpts := "+AlwaysOnTop -Caption +ToolWindow -DPIScale"
DefaultFont := "s10 bold"
DefaultFontFace := "Segoe UI"
DefaultBackColor := "Black"
DefaultOpacity := 220
TooltipOffsetX := 350
TooltipOffsetY := 150

; === Tooltip Durations ===
DurationToggle := 3000
DurationBlocked := 3500
DurationManual := 3000
DurationChanged := 2000
DurationExit := 10000
DurationDebugFade := 5000

; === Sound Cues ===
SoundSoft := "*64"
SoundAlert := "*48"

; === Logging Setup ===
logDir := "C:\Logs"
logDate := FormatTime(, "yyyy-MM-dd")
logFile := logDir . "\RefreshRate_" . logDate . ".log"
if !FileExist(logDir)
    DirCreate(logDir)
if !FileExist(logFile)
    FileAppend("=== Refresh Rate Log Started: " . logDate . " ===`n", logFile)
Loop Files logDir "\RefreshRate_*.log" {
    age := (A_Now - A_LoopFileTimeModified) // 86400
    if age > 30
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

; === Timers & Hotkeys ===
SetTimer(MainPollingLoop, 3000)
SetTimer(CheckNumLockState, 30000)
^+!Esc::ToggleDebugMode()
NumLock::CheckNumLockState()
Hotkey("^+r", (*) => TryToggleRefreshRate())
Hotkey("^!r", (*) => TryToggleRefreshRate())
Hotkey("^+!r", (*) => TryToggleRefreshRate())

; === Debug Toggle ===
ToggleDebugMode() {
    global debugMode, debugOverlay
    debugMode := !debugMode
    debugOverlay.Destroy()
    debugOverlay := Gui(DefaultGuiOpts)
    debugOverlay.Opacity := DefaultOpacity
    debugOverlay.BackColor := DefaultBackColor
    debugOverlay.SetFont(DefaultFont, DefaultFontFace)
    msg := debugMode ? "Debug On" : "Debug Off"
    debugOverlay.AddText("cWhite BackgroundBlack", msg)
    debugOverlay.Show("x10 y10 NoActivate")
    SoundPlay(SoundSoft)
    if !debugMode
        SetTimer(() => debugOverlay.Hide(), -DurationDebugFade)
}

; === Debug Test Keys (Always Active, Gated by debugMode) ===
1:: {
    global debugToggleState, debugMode
    if !debugMode
        return
    debugToggleState := !debugToggleState
    msg := debugToggleState ? "Refresh Toggle (Hz) On" : "Refresh Toggle (Hz) Off"
    color := debugToggleState ? "Green" : "Red"
    ShowTestTooltip(msg, color, DurationToggle)
}
2:: {
    if debugMode
        ShowTestTooltip("⚠️ Cannot change refresh rate:`nSampleApp.exe is currently running.", "Red", DurationBlocked)
}
3:: {
    if debugMode
        ShowTestTooltip("Refresh rate manually changed to 144 Hz", "Yellow", DurationManual)
}
4:: {
    if debugMode
        ShowTestTooltip("Switched to 160 Hz", "White", DurationChanged)
}
5:: {
    if debugMode
        ShowTestTooltip("Closing Refresh Toggle...", "Yellow", DurationExit)
}
6:: {
    if debugMode
        ShowDebugConfirmationPrompt()
}

; === Main Polling ===
MainPollingLoop() {
    if !scriptEnabled
        return
    MonitorLaunchers()
    CheckManualRefreshChange()
}

CheckNumLockState() {
    global scriptEnabled
    isOn := GetKeyState("NumLock", "T")
    if isOn && !scriptEnabled {
        scriptEnabled := true
        ShowToggleTooltip("Refresh Toggle (Hz) On", "Green")
        LogRefreshChange("N/A", "Script resumed (Num Lock ON)")
    } else if !isOn && scriptEnabled {
        scriptEnabled := false
        ShowToggleTooltip("Refresh Toggle (Hz) Off", "Red")
        LogRefreshChange("N/A", "Script paused (Num Lock OFF)")
    }
}

ShowToggleTooltip(text, color) {
    global tooltipGui
    tooltipGui.Destroy()
    tooltipGui := Gui(DefaultGuiOpts)
    tooltipGui.Opacity := DefaultOpacity
    tooltipGui.BackColor := DefaultBackColor
    tooltipGui.SetFont(DefaultFont, DefaultFontFace)
    tooltipGui.AddText("c" . color . " BackgroundBlack", text)
    MonitorGet(MonitorGetPrimary(), &left, &top, &right, &bottom)
    tooltipGui.Show("x" (right - TooltipOffsetX) " y" (bottom - TooltipOffsetY) " NoActivate")
    SoundPlay(SoundSoft)
    SetTimer(() => tooltipGui.Hide(), -DurationToggle)
}

ShowTestTooltip(text, color, duration) {
    global tooltipGui
    tooltipGui.Destroy()
    tooltipGui := Gui(DefaultGuiOpts)
    tooltipGui.Opacity := DefaultOpacity
    tooltipGui.BackColor := DefaultBackColor
    tooltipGui.SetFont(DefaultFont, DefaultFontFace)
    tooltipGui.AddText("c" . color . " BackgroundBlack", text)
    MonitorGet(MonitorGetPrimary(), &left, &top, &right, &bottom)
    tooltipGui.Show("x" (right - TooltipOffsetX) " y" (bottom - TooltipOffsetY) " NoActivate")
    SoundPlay(SoundSoft)
    SetTimer(() => tooltipGui.Hide(), -duration)
}

ShowDebugConfirmationPrompt() {
    global tooltipGui
    tooltipGui.Destroy()
    tooltipGui := Gui(DefaultGuiOpts)
    tooltipGui.Opacity := DefaultOpacity
    tooltipGui.BackColor := DefaultBackColor
    tooltipGui.SetFont(DefaultFont, DefaultFontFace)
    tooltipGui.AddText("cWhite BackgroundBlack", "Switched to 160 Hz`nPress Y to confirm")
    MonitorGet(MonitorGetPrimary(), &left, &top, &right, &bottom)
    tooltipGui.Show("x" (right - 300) " y" (bottom - TooltipOffsetY) " NoActivate")
    SoundPlay(SoundSoft)
    confirmed := false
    Hotkey("y", (*) => confirmed := true, "On")
    Loop 100 {
        Sleep(100)
        if confirmed
            break
    }
    Hotkey("y", "Off")
    tooltipGui.Hide()
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

CheckManualRefreshChange() {
    global lastScriptedRate, lastScriptedTime
    currentHz := GetCurrentRefreshRate()
    if currentHz != "" && currentHz != lastScriptedRate {
        if (A_TickCount - lastScriptedTime > 5000) {
            LogRefreshChange(currentHz, "Manual - User changed refresh rate")
            lastScriptedRate := currentHz
            lastScriptedTime := A_TickCount
            ShowTestTooltip("Refresh rate manually changed to " . currentHz . " Hz", "Yellow", DurationManual)
        }
    }
}

GetCurrentRefreshRate() {
    try {
        output := ""
        RunWait('powershell -Command "Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorBasicDisplayParams | ForEach-Object { $_.MaxVerticalImageSize }"', , "Hide", &output)
        return Trim(output)
    } catch {
        return ""
    }
}

TryToggleRefreshRate(*) {
    if app := GetRunningLauncher() {
        ShowTestTooltip("⚠️ Cannot change refresh rate:`n" . app . " is currently running.", "Red", DurationBlocked)
        return
    }
    ToggleRefreshRate()
}

ToggleRefreshRate(*) {
    global currentIndex, refreshRates, displayLabels, tooltipGui, monitorIndex, scriptPath
    global lastScriptedRate, lastScriptedTime
    static currentRate := 120

    currentIndex := Mod(currentIndex + 1, refreshRates.Length)
    newRate := refreshRates[currentIndex + 1]
    displayRate := displayLabels[currentIndex + 1]

    needsConfirmation := (newRate = 159.97 && currentRate != 159.97)

    psCommand := 'powershell.exe -ExecutionPolicy Bypass -File "' scriptPath '" -Monitor ' monitorIndex ' -Rate ' newRate
    RunWait(psCommand, , "Hide")
    LogRefreshChange(newRate, "Manual")
    lastScriptedRate := newRate
    lastScriptedTime := A_TickCount

    if needsConfirmation {
        primary := MonitorGetPrimary()
        MonitorGet(primary, &left, &top, &right, &bottom)
        x := right - 300
        y := bottom - TooltipOffsetY

        tooltipGui.Destroy()
        tooltipGui := Gui(DefaultGuiOpts)
        tooltipGui.Opacity := DefaultOpacity
        tooltipGui.BackColor := DefaultBackColor
        tooltipGui.SetFont(DefaultFont, DefaultFontFace)
        tooltipGui.AddText("cWhite BackgroundBlack", "Switched to " displayRate " Hz`nPress Y to confirm")
        tooltipGui.Show("x" x " y" y " NoActivate")
        SoundPlay(SoundSoft)

        confirmed := false
        Hotkey("y", (*) => confirmed := true, "On")
        Loop 100 {
            Sleep(100)
            if confirmed
                break
        }
        Hotkey("y", "Off")
        tooltipGui.Hide()

        if confirmed {
            currentRate := newRate
        } else {
            revertCommand := 'powershell.exe -ExecutionPolicy Bypass -File "' scriptPath '" -Monitor ' monitorIndex ' -Rate ' lastScriptedRate
            RunWait(revertCommand, , "Hide")
            LogRefreshChange(lastScriptedRate, "Auto - Reverted after no confirmation")
            MsgBox("No confirmation received. Reverted to " lastScriptedRate " Hz.")
            currentRate := lastScriptedRate
        }
    } else {
        currentRate := newRate
        ShowTestTooltip("Switched to " displayRate " Hz", "White", DurationChanged)
    }
}

^!Esc::  ; Ctrl+Alt+Esc → Emergency fallback to 120 Hz and exit
{
    global scriptPath, monitorIndex, logFile, tooltipGui
    safeRate := 120
    psCommand := 'powershell.exe -ExecutionPolicy Bypass -File "' scriptPath '" -Monitor ' monitorIndex ' -Rate ' safeRate
    RunWait(psCommand, , "Hide")
    LogRefreshChange(safeRate, "Manual Emergency Revert")

    tooltipGui.Destroy()
    tooltipGui := Gui(DefaultGuiOpts)
    tooltipGui.Opacity := DefaultOpacity
    tooltipGui.BackColor := DefaultBackColor
    tooltipGui.SetFont(DefaultFont, DefaultFontFace)
    tooltipGui.AddText("cYellow BackgroundBlack", "Closing Refresh Toggle...")
    MonitorGet(MonitorGetPrimary(), &left, &top, &right, &bottom)
    tooltipGui.Show("x" (right - TooltipOffsetX) " y" (bottom - TooltipOffsetY) " NoActivate")
    SoundPlay(SoundAlert)

    Sleep(DurationExit)
    ExitApp
}
