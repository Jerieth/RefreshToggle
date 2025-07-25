#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All
#Warn LocalSameAsGlobal, Off
global tooltipVisible := false
global isTooltipActive := false

InitTrayMenu()

InitTrayMenu(iconFile := A_ScriptDir "\120.ico") {
    A_TrayMenu.Delete()
    A_TrayMenu.Add("Exit", ExitScript)
}

ExitScript(*) {
    ExitApp
}

TraySetIcon A_ScriptDir "\120.ico"
;RefreshToggle.ahk v4.2 — Stable Release

; === Global Setup ===
;debugMode := false
scriptEnabled := true
refreshRates := [120, 144, 159.97]
displayLabels := ["120", "144", "160"]
currentIndex := 0
monitorIndex := 0
hzInGame := 160
hzOutOfGame := 120
autoState := "idle"
scriptPath := "C:\Scripts\PowerShell\Cycle-RefreshRate.ps1"

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

; === Tray Icon Switching ===
GetRefreshRateViaDll() {
    hDC := DllCall("GetDC", "ptr", 0, "ptr")
    rate := DllCall("GetDeviceCaps", "ptr", hDC, "int", 116)
    DllCall("ReleaseDC", "ptr", 0, "ptr", hDC)
    return Round(rate)
}

SetTrayIconByHz(hz) {
	hz := Round(hz)
    icon := (hz = 120) ? A_ScriptDir "\120.ico"
         : (hz = 144) ? A_ScriptDir "\144.ico"
         : (hz = 160) ? A_ScriptDir "\160.ico"
         : A_ScriptDir "\default.ico"

    TraySetIcon(icon)
}

; ── Delayed Icon Set After Script Load ──
SetTimer(() => SetTrayIconByHz(GetRefreshRateViaDll()), -1000)

; === Refresh Tracking (Safe Initialization) ===
rawHz := GetRefreshRateViaWMI()
if rawHz < 120 {
    LogRefreshChange(120, "Fallback - WMI refresh value below threshold")
}
lastScriptedRate := Round(Max(rawHz, 120))  ; enforces minimum fallback
lastScriptedTime := A_TickCount
lastManualCheck := A_TickCount

;SetTrayIconByHz(GetRefreshRateViaDll())

; === Tooltip Defaults ===
DefaultGuiOpts := "+AlwaysOnTop -Caption +ToolWindow -DPIScale"
DefaultFont := "s12 bold"
DefaultFontFace := "Segoe UI"
DefaultBackColor := "Black"
DefaultOpacity := 220

; === Tooltip Positions (Per Message) ===
TooltipX := Map(1, 350, 2, 500, 3, 550, 4, 350, 5, 375, 6, 575, 7, 595, 8, 375)
TooltipY := Map(1, 150, 2, 175, 3, 150, 4, 150, 5, 150, 6, 200, 7, 200, 8, 185)

; === Tooltip Durations ===
DurationToggle := 3000
DurationBlocked := 3500
DurationManual := 3000
DurationChanged := 5000
DurationExit := 10000
DurationDebugFade := 5000

; === Sounds ===
SoundSoft := "*64"
SoundAlert := "*48"

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
;debugOverlay := Gui(DefaultGuiOpts)

; === Hotkeys & Timers ===
SetTimer(MainPollingLoop, 3000)
;SetTimer(CheckNumLockState, 30000)
;^+!Esc::ToggleDebugMode()
;NumLock::CheckNumLockState()

global SoundOn := A_ScriptDir . "\On.wav"
global SoundOff := A_ScriptDir . "\Off.wav"
;global NoSound := "" ; disables sound

^+!Esc:: {
    global scriptEnabled, SoundOn, SoundOff, SoundSoft 
    scriptEnabled := !scriptEnabled

    msg := scriptEnabled ? "Refresh Toggle (Hz) On" : "Refresh Toggle (Hz) Off"
    color := scriptEnabled ? "Green" : "Red"

    originalSound := SoundSoft
    SoundSoft := ""
    ShowToggleTooltip(msg, color, TooltipX[1], TooltipY[1])
    SoundSoft := originalSound

    LogRefreshChange("N/A", "Script toggled via Ctrl+Shift+Alt+Esc")

    SoundPlay(scriptEnabled ? SoundOn : SoundOff)
}
TryToggleRefreshRate(*) {
    global SoundSoft, DurationBlocked, TooltipX

    originalSound := SoundSoft
    SoundSoft := ""  ; suppress tooltip sound

    if app := GetRunningLauncher() {
        ShowTestTooltip("⚠️ Cannot change refresh rate:`n" . app . " is currently running.", "Red", DurationBlocked, TooltipX[2], TooltipY[2])
        SoundSoft := originalSound
        return
    }

    ToggleRefreshRate()

    SoundSoft := originalSound
}
;Hotkey("^+r", TryToggleRefreshRate)
Hotkey("^!r", TryToggleRefreshRate)
Hotkey("^+!r", TryToggleRefreshRate)

; === Debug Toggle Function ===
ToggleDebugMode() {
    global debugMode, debugOverlay
    debugMode := !debugMode
	if IsObject(debugOverlay) && debugOverlay.Hwnd
		debugOverlay.Destroy()
    debugOverlay := Gui(DefaultGuiOpts)
    debugOverlay.Opacity := DefaultOpacity
    debugOverlay.BackColor := DefaultBackColor
    debugOverlay.SetFont(DefaultFont, DefaultFontFace)
    debugOverlay.AddText("cWhite BackgroundBlack", debugMode ? "Debug On" : "Debug Off")
    debugOverlay.Show("x10 y10 NoActivate")
    if IsSet(SoundSoft) && SoundSoft != ""
		SoundPlay(SoundSoft)
    if !debugMode
        SetTimer(() => debugOverlay.Hide(), -DurationDebugFade)
}

; === Debug Hotkeys ===
/* 1:: {
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
} */

; === Tooltip Functions ===
ShowToggleTooltip(text, color := "White", x := 350, y := 150) {
    global tooltipGui, tooltipTextCtrl
    global DefaultGuiOpts, DefaultOpacity, DefaultBackColor
    global DefaultFont, DefaultFontFace, SoundSoft, DurationToggle

    ; Destroy and recreate GUI for reliability
    if IsObject(tooltipGui)
        tooltipGui.Destroy()

    tooltipGui := Gui(DefaultGuiOpts)
    tooltipGui.Opacity := DefaultOpacity
    tooltipGui.BackColor := DefaultBackColor
    tooltipGui.SetFont(DefaultFont, DefaultFontFace)
    tooltipTextCtrl := tooltipGui.AddText("c" . color . " BackgroundBlack", text)

    ; Position and show
    MonitorGet(MonitorGetPrimary(), &left, &top, &right, &bottom)
    tooltipGui.Show("x" (right - x) " y" (bottom - y) " NoActivate")

    ; Play sound if available
    if IsSet(SoundSoft) && SoundSoft != ""
        SoundPlay(SoundSoft)

    ; Hide after a delay
    SetTimer(() => tooltipGui.Hide(), -DurationToggle)
}

ShowTestTooltip(text, color, duration, x := 350, y := 150) {
    global tooltipGui, SoundSoft, DefaultGuiOpts, DefaultOpacity, DefaultBackColor
    global DefaultFont, DefaultFontFace, isTooltipActive

    if isTooltipActive {
        return  ; Block overlapping tooltips silently
    }
    isTooltipActive := true

    ; Destroy if leftover GUI exists
	if IsObject(tooltipGui) {
		try {
			if tooltipGui.Hwnd
				tooltipGui.Destroy()
		} catch {
			; GUI was already destroyed — safe to continue
		}
	}
    tooltipGui := Gui(DefaultGuiOpts)
    tooltipGui.Opacity := DefaultOpacity
    tooltipGui.BackColor := DefaultBackColor
    tooltipGui.SetFont(DefaultFont, DefaultFontFace)
    tooltipGui.AddText("c" . color . " BackgroundBlack", text)

    MonitorGet(MonitorGetPrimary(), &left, &top, &right, &bottom)
    tooltipGui.Show("x" (right - x) " y" (bottom - y) " NoActivate")

    if IsSet(SoundSoft) && SoundSoft != ""
        SoundPlay(SoundSoft)

    SetTimer(() => (
        (IsObject(tooltipGui) && tooltipGui.Hwnd ? tooltipGui.Destroy() : ""),
        isTooltipActive := false
    ), -duration)

    ; ── Tray Icon Switching Based on Tooltip Text ──
    if InStr(text, "🎮 Launcher detected") {
        SetTrayIconByHz(160)
    } else if InStr(text, "🛑 No launcher detected") {
        SetTrayIconByHz(120)
    } else if InStr(text, "Switched to ") {
        if InStr(text, "120 Hz") {
            SetTrayIconByHz(120)
        } else if InStr(text, "144 Hz") {
            SetTrayIconByHz(144)
        } else if InStr(text, "160 Hz") {
            SetTrayIconByHz(160)
        } else {
            SetTrayIconByHz("")
        }
    }
}

; === Main Polling ===
MainPollingLoop() {
    if !scriptEnabled
        return
    MonitorLaunchers()
    ;Get current refresh rate via WMI
}

MonitorLaunchers() {
    global autoState, scriptPath, hzInGame, hzOutOfGame, lastScriptedRate, lastScriptedTime
    global TooltipX, TooltipY, DurationChanged
	global SoundSoft
	originalSound := SoundSoft
	SoundSoft := ""
    if app := GetRunningLauncher() {
        if autoState != "in-game" {
            RunWait('powershell.exe -ExecutionPolicy Bypass -File "' scriptPath '" -Rate ' hzInGame, , "Hide")
            LogRefreshChange(hzInGame, "Auto - Triggered by " . app)
            lastScriptedRate := hzInGame
            lastScriptedTime := A_TickCount
            autoState := "in-game"
            ShowTestTooltip("🎮 Launcher detected: " . app . "`nSwitched to " . hzInGame . " Hz", "White", DurationChanged, TooltipX[7], TooltipY[7])
        }
    } else if autoState = "in-game" {
        RunWait('powershell.exe -ExecutionPolicy Bypass -File "' scriptPath '" -Rate ' hzOutOfGame, , "Hide")
        LogRefreshChange(hzOutOfGame, "Auto - Reverted after game closed")
        lastScriptedRate := hzOutOfGame
        lastScriptedTime := A_TickCount
        autoState := "idle"
        ShowTestTooltip("🛑 No launcher detected`nSwitched to " . hzOutOfGame . " Hz", "White", DurationChanged, TooltipX[8], TooltipY[8])
    }
	SoundSoft := originalSound
}

/* CheckNumLockState() {
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
} */

CheckManualRefreshChange() {
    global lastScriptedRate, lastScriptedTime, lastManualCheck
    global DurationManual, TooltipX, TooltipY

    ; Avoid checking too frequently
    if (A_TickCount - lastManualCheck < 10000)
        return
    lastManualCheck := A_TickCount

    ; Get current refresh rate with fallback
    rawHz := GetRefreshRateViaWMI()
    if rawHz < 120 {
        LogRefreshChange(120, "Fallback - Manual WMI check returned sub-threshold")
    }
    currentHz := Round(Max(rawHz, 120))

    ; Grace period: ignore changes shortly after a scripted switch
    if (A_TickCount - lastScriptedTime < 5000)
        return

    ; If the current rate differs significantly from what the script last set
    if Abs(currentHz - lastScriptedRate) > 10 {
        LogRefreshChange(currentHz, "Manual - User changed refresh rate")
        lastScriptedRate := currentHz
        lastScriptedTime := A_TickCount
        ShowTestTooltip("Refresh rate manually changed to " . currentHz . " Hz", "Yellow", DurationManual, TooltipX[3], TooltipY[3])
    }
}

GetRefreshRateViaWMI() {
    try {
        query := ComObjGet("winmgmts:").ExecQuery("Select * from Win32_VideoController")
        for item in query {
            hz := item.CurrentRefreshRate
            return (IsNumber(hz) && hz > 0) ? hz : 0
        }
    } catch {
        return 0
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

ShowConfirmationPopup(promptText, rate, confirmKey := "Y", timeout := 10000) {
    global TooltipX, TooltipY, DefaultGuiOpts, DefaultFont, DefaultFontFace, DefaultOpacity
    global lastScriptedRate, lastScriptedTime, scriptPath, monitorIndex, DurationChanged

    local confirmGui := Gui(DefaultGuiOpts)
    confirmGui.Opacity := DefaultOpacity
    confirmGui.BackColor := "Black"
    confirmGui.SetFont(DefaultFont, DefaultFontFace)

    confirmGui.AddText("cWhite BackgroundBlack", promptText)
    confirmGui.AddText("cGray BackgroundBlack", "Press [" . confirmKey . "] to confirm — auto-closes in " . timeout/1000 . "s")

    MonitorGet(MonitorGetPrimary(), &left, &top, &right, &bottom)
    confirmGui.Show("x" (right - TooltipX[6]) " y" (bottom - TooltipY[6]) " NoActivate")

	listener := InputHook("L1")
	listener.Start(), listener.Wait(timeout)

	confirmGui.Destroy()

	if (StrLower(listener.Input) = "y") {
		RunWait('powershell.exe -ExecutionPolicy Bypass -File "' scriptPath '" -Monitor ' monitorIndex ' -Rate ' rate, , "Hide")
		LogRefreshChange(rate, "Manual (Confirmed)")
		lastScriptedRate := rate
		lastScriptedTime := A_TickCount
		ShowTestTooltip("✅ Confirmed: Switched to " . rate . " Hz", "Green", DurationChanged, TooltipX[7], TooltipY[4])
		return true
	}

	ShowTestTooltip("❌ Refresh change canceled", "Gray", 1500, TooltipX[4], TooltipY[4])
	return false
}

ToggleRefreshRate(*) {
    global currentIndex, refreshRates, displayLabels, monitorIndex, scriptPath
    global lastScriptedRate, lastScriptedTime
    global TooltipX, TooltipY, DurationChanged

    currentIndex := Mod(currentIndex + 1, refreshRates.Length)
    newRate := refreshRates[currentIndex + 1]
    displayLabel := displayLabels[currentIndex + 1]

    ; If switching to a higher refresh rate from a high one → ask for confirmation
    if (lastScriptedRate >= 140) && (newRate > lastScriptedRate) {
        if !ShowConfirmationPopup("Confirm refresh rate change to " . newRate . " Hz?", newRate)
            return  ; user canceled
    }

    ; Otherwise, toggle without confirmation
    RunWait('powershell.exe -ExecutionPolicy Bypass -File "' scriptPath '" -Monitor ' monitorIndex ' -Rate ' newRate, , "Hide")
    LogRefreshChange(newRate, "Manual")
    lastScriptedRate := newRate
    lastScriptedTime := A_TickCount
    ShowTestTooltip("Switched to " . newRate . " Hz", "White", DurationChanged, TooltipX[4], TooltipY[4])
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
	SetTrayIconByHz(safeRate)
    Sleep(DurationExit)
    ExitApp
}
