param (
    [int]$Rate = 144,
    [int]$Monitor = 0  # Currently unused, but placeholder for future multi-monitor support
)

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
public struct DEVMODE {
    private const int CCHDEVICENAME = 32;
    private const int CCHFORMNAME = 32;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = CCHDEVICENAME)]
    public string dmDeviceName;
    public ushort dmSpecVersion;
    public ushort dmDriverVersion;
    public ushort dmSize;
    public ushort dmDriverExtra;
    public uint dmFields;
    public int dmPositionX;
    public int dmPositionY;
    public uint dmDisplayOrientation;
    public uint dmDisplayFixedOutput;
    public short dmColor;
    public short dmDuplex;
    public short dmYResolution;
    public short dmTTOption;
    public short dmCollate;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = CCHFORMNAME)]
    public string dmFormName;
    public ushort dmLogPixels;
    public uint dmBitsPerPel;
    public uint dmPelsWidth;
    public uint dmPelsHeight;
    public uint dmDisplayFlags;
    public uint dmDisplayFrequency;
    public uint dmICMMethod;
    public uint dmICMIntent;
    public uint dmMediaType;
    public uint dmDitherType;
    public uint dmReserved1;
    public uint dmReserved2;
    public uint dmPanningWidth;
    public uint dmPanningHeight;
}

public class NativeMethods {
    [DllImport("user32.dll", CharSet = CharSet.Ansi)]
    public static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);

    [DllImport("user32.dll", CharSet = CharSet.Ansi)]
    public static extern int ChangeDisplaySettingsEx(string deviceName, ref DEVMODE devMode, IntPtr hwnd, uint flags, IntPtr lParam);
}
"@

function Set-RefreshRate($hz) {
    $devmode = New-Object DEVMODE
    $devmode.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($devmode)
    $success = [NativeMethods]::EnumDisplaySettings("\\.\DISPLAY1", -1, [ref]$devmode)
    if (-not $success) { throw "Failed to get current display settings." }

    $devmode.dmFields = (0x80000 -bor 0x100000 -bor 0x400000)  # DM_PELSWIDTH | DM_PELSHEIGHT | DM_DISPLAYFREQUENCY
    $devmode.dmPelsWidth = 3840
    $devmode.dmPelsHeight = 2160
    $devmode.dmDisplayFrequency = [math]::Round($hz)

    $result = [NativeMethods]::ChangeDisplaySettingsEx("\\.\DISPLAY1", [ref]$devmode, [IntPtr]::Zero, 0, [IntPtr]::Zero)
    if ($result -ne 0) {
        throw "Failed to set refresh rate to $hz Hz. Error code: $result"
    }
}

Set-RefreshRate -hz $Rate
