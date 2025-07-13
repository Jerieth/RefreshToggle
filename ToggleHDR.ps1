param([string]$State)

$registryPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\VideoSettings"
$currentValue = Get-ItemPropertyValue -Path $registryPath -Name "EnableHDR" -ErrorAction SilentlyContinue

if ($State -eq "on" -and $currentValue -ne 1) {
    Set-ItemProperty -Path $registryPath -Name "EnableHDR" -Value 1
    exit 0
}
elseif ($State -eq "off" -and $currentValue -ne 0) {
    Set-ItemProperty -Path $registryPath -Name "EnableHDR" -Value 0
    exit 0
}

exit 1  # Nothing changed
