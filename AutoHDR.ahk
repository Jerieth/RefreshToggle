#Requires AutoHotkey v2.0
#SingleInstance Force

iniPath := A_ScriptDir . "\AutoHDR.ini"
logPath := "C:\Logs\AutoHDR.log"
toggleHDRPath := A_ScriptDir . "\ToggleHDR.ps1"

gameList := []
failCount := 0
maxFails := 5

; === Centralized Color Styling ===
ColorEnabled := "00BFFF"  ; Electric Blue
ColorDisabled := "FFFFFF" ; White
ColorError := "FF0000"    ; Red
ColorInfo := "FFFF00"     ; Yellow
BackgroundColor := "Black"

; === Initialize Log ===
InitLog()

; === INI Validation and Game List Loading ===
if !FileExist(iniPath) {
    LogAction("ERROR", "AutoHDR.ini missing — terminating script")
    ShowInfoTooltip("❗ Missing AutoHDR.ini config file. Add [Games] section with .exe titles.", ColorInfo)
    Sleep 10000
    ShowInfoTooltip("Closing script. No game list available.", ColorInfo)
    Sleep 10000
    ExitApp
}

gameSection := IniRead(iniPath, "Games", , "")
validCount := 0

for line in StrSplit(gameSection, "`n", "`r") {
    trimmed := Trim(line)
    if trimmed = "" || RegExMatch(trimmed, "^(#|;)") {
        continue
    }
    if !RegExMatch(trimmed, "\.exe$") {
        LogAction("ERROR", "Invalid game entry skipped in INI: " . trimmed)
        continue
    }
    if gameList.Has(trimmed) {
        LogAction("INFO", "Duplicate game entry skipped in INI: " . trimmed)
        continue
    }
    gameList.Push(trimmed)
    validCount += 1
}

if validCount = 0 {
    LogAction("ERROR", "INI contains no valid .exe entries — terminating script")
    ShowInfoTooltip("❗ AutoHDR.ini is present but contains no valid game entries.", ColorInfo)
    Sleep 10000
    ShowInfoTooltip("Closing script. No games to monitor.", ColorInfo)
    Sleep 10000
    ExitApp
}

; === Tooltip GUI Defaults ===
DefaultGuiOpts := "+AlwaysOnTop -Caption +ToolWindow -DPIScale"
DefaultFontFace := "Segoe UI"
DefaultOpacity := 220

tooltipGui := Gui(DefaultGuiOpts)
tooltipGui.Opacity := DefaultOpacity
tooltipGui.BackColor := BackgroundColor
tooltipGui.SetFont("s12 bold", DefaultFontFace)

; === Start Monitoring Loop ===
SetTimer(MonitorGames, 3000)

MonitorGames() {
    static hdrOn := false
    if IsGameRunning() {
        if !hdrOn {
            RunToggleHDR("on")
            ShowHDRTooltip("🔆 HDR Enabled for Gaming", ColorEnabled)
            LogAction("INFO", "HDR Enabled")
            hdrOn := true
        }
    } else {
        if hdrOn {
            RunToggleHDR("off")
            ShowHDRTooltip("🌑 HDR Disabled (No Game Running)", ColorDisabled)
            LogAction("INFO", "HDR Disabled")
            hdrOn := false
        }
    }
}

IsGameRunning() {
    global gameList
    for title in gameList {
        if ProcessExist(title)
            return true
    }
    return false
}

RunToggleHDR(state) {
    global failCount, maxFails, toggleHDRPath
    if !FileExist(toggleHDRPath) {
        failCount += 1
        LogAction("ERROR", "ToggleHDR.ps1 not found")
        if failCount <= maxFails
            ShowErrorTooltip("⚠️ HDR script missing")
        return
    }
    result := RunWait('powershell.exe -ExecutionPolicy Bypass -File "' toggleHDRPath '" -State ' state, , "Hide")
    if (state = "on" && result != 0) {
        failCount += 1
        LogAction("ERROR", "PowerShell HDR toggle failed")
        if failCount <= maxFails
            ShowErrorTooltip("⚠️ HDR Enable Failed")
    } else {
        failCount := 0
    }
}

ShowHDRTooltip(text, color) {
    global tooltipGui, BackgroundColor, DefaultGuiOpts, DefaultOpacity, DefaultFontFace
    fontSize := GetFontSizeByText(text)
    tooltipGui.Destroy()
    tooltipGui := Gui(DefaultGuiOpts)
    tooltipGui.Opacity := DefaultOpacity
    tooltipGui.BackColor := BackgroundColor
    tooltipGui.SetFont(fontSize . " bold", DefaultFontFace)
    tooltipGui.AddText("c" . color . " Background" . BackgroundColor, text)
    MonitorGet(MonitorGetPrimary(), &left, &top, &right, &bottom)
    tooltipGui.Show("x" (right - 400) " y" (bottom - 150) " NoActivate")
    SetTimer(() => tooltipGui.Hide(), -2500)
}

ShowErrorTooltip(text) {
    ShowFixedTooltip(text, ColorError, 350, 150)
}

ShowInfoTooltip(text, color := ColorInfo) {
    ShowFixedTooltip(text, color, 350, 150)
}

ShowFixedTooltip(text, color, x, y) {
    global BackgroundColor
    fontSize := GetFontSizeByText(text)
    gui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale")
    gui.Opacity := 220
    gui.BackColor := BackgroundColor
    gui.SetFont(fontSize . " bold", "Segoe UI")
    gui.AddText("c" . color . " Background" . BackgroundColor, text)
    gui.Show("x" x " y" y " NoActivate")
    SetTimer(() => gui.Hide(), -3000)
}

GetFontSizeByText(text) {
    len := StrLen(text)
    lines := StrSplit(text, "`n").Length
    return (len > 80 || lines > 2) ? "s10" : "s12"
}

LogAction(level, message) {
    global logPath
    timestamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    FileAppend "[" . level . "] " . timestamp . " — " . message . "`n", logPath
}

InitLog() {
    global logPath
    if !FileExist(logPath) {
        try FileCreateDir("C:\Logs")
        FileAppend "", logPath
        return
    }
    fileTime := FileGetTime(logPath, "M")
    daysOld := (A_Now - fileTime) // 86400000
    if daysOld >= 30 {
        lines := FileRead(logPath)
        recentLines := StrSplit(lines, "`n")
        if recentLines.Length > 100 {
            FileDelete logPath
            for i, line in recentLines[-100:] {
                FileAppend line . "`n", logPath
            }
        }
    }
}
