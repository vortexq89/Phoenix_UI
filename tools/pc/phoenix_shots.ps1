<#
  Phoenix UI passive screen capture for the overnight self-test loop. Called by bugwatch.ps1 each time a
  Phoenix_UI SavedVariables file changes and every 10 minutes while the game runs. It only READS the screen
  (System.Drawing CopyFromScreen) and never sends input to anything. The game's own Screenshots folder is
  never read, copied or touched. Keeps the newest -Keep screen_*.png files it wrote itself.

  Why files used to come out empty: several watcher instances could capture in the same second and write the
  same screen_<second>.png at once (one truncates the other), and a capture taken on the lock screen or with
  no desktop came out blank. Now each capture
    * runs under a named mutex (one capture at a time across processes),
    * gets a unique name (milliseconds + process id),
    * is encoded in memory, checked (PNG signature, size, not one flat colour) and only then written to a
      .tmp file that is renamed into place, so a half-written or empty screen_*.png can never appear,
    * removes any empty / tiny screen_*.png (under 1 KB) left by older versions in -Out.

  .\phoenix_shots.ps1 [-Out C:\Users\Vorte\Phoenix_UI\bugs\shots] [-Keep 50] [-SelfTest]
  -SelfTest: capture once into -Out and print the checks (exit 1 on failure); touches nothing else.
#>
param(
    [string]$Out = 'C:\Users\Vorte\Phoenix_UI\bugs\shots',
    [int]$Keep = 50,
    [switch]$SelfTest
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
New-Item -ItemType Directory -Force $Out | Out-Null

# Per-monitor DPI awareness so the virtual screen is measured in real pixels (no cropped or scaled capture).
try {
    Add-Type -Namespace PuiShots -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
    [void][PuiShots.Dpi]::SetProcessDPIAware()
} catch { }

function Test-Png([byte[]]$bytes, [Drawing.Bitmap]$bmp) {
    if ($bytes.Length -lt 1024) { return "too small ($($bytes.Length) bytes)" }
    $sig = 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
    for ($k = 0; $k -lt 8; $k++) { if ($bytes[$k] -ne $sig[$k]) { return 'not a PNG' } }
    # blank check: 64 sample points across the image all the same colour = lock screen / no desktop
    $first = $null; $same = $true
    for ($y = 1; $y -le 8; $y++) {
        for ($x = 1; $x -le 8; $x++) {
            $c = $bmp.GetPixel([int]($bmp.Width * $x / 9), [int]($bmp.Height * $y / 9)).ToArgb()
            if ($null -eq $first) { $first = $c } elseif ($c -ne $first) { $same = $false }
        }
    }
    if ($same) { return 'blank (one flat colour: locked screen or no desktop)' }
    return $null
}

$mutex = New-Object Threading.Mutex($false, 'Local\PhoenixUI_Shots')
$saved = $null; $problem = $null
if (-not $mutex.WaitOne(15000)) { Write-Warning 'another capture is still running; skipped'; if ($SelfTest) { exit 1 }; return }
try {
    # leftovers from older versions: empty / tiny shots and stray temp files (only our own names)
    Get-ChildItem $Out -File -Filter 'screen_*.png' | Where-Object { $_.Length -lt 1024 } | Remove-Item -Force
    Get-ChildItem $Out -File -Filter 'screen_*.png.tmp' | Remove-Item -Force

    $b = [Windows.Forms.SystemInformation]::VirtualScreen
    $bmp = New-Object Drawing.Bitmap $b.Width, $b.Height
    $g = [Drawing.Graphics]::FromImage($bmp)
    $ms = New-Object IO.MemoryStream
    try {
        $g.CopyFromScreen($b.Left, $b.Top, 0, 0, $bmp.Size)
        $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Png)
        $bytes = $ms.ToArray()
        $problem = Test-Png $bytes $bmp
        if (-not $problem) {
            $name = 'screen_{0}_{1}.png' -f (Get-Date -Format 'yyyyMMdd_HHmmss_fff'), $PID
            $final = Join-Path $Out $name
            $tmp = "$final.tmp"
            [IO.File]::WriteAllBytes($tmp, $bytes)
            if ((Get-Item $tmp).Length -ne $bytes.Length) { Remove-Item $tmp -Force; $problem = 'short write' }
            else { Move-Item $tmp $final; $saved = $final }
        }
    } catch { $problem = "capture failed: $_" }
    finally { $ms.Dispose(); $g.Dispose(); $bmp.Dispose() }

    Get-ChildItem $Out -File -Filter 'screen_*.png' | Sort-Object LastWriteTime -Descending | Select-Object -Skip $Keep | Remove-Item -Force
} finally { $mutex.ReleaseMutex(); $mutex.Dispose() }

if ($problem) { Write-Warning "screen capture not saved: $problem" }
if ($SelfTest) {
    if ($saved) {
        $len = (Get-Item $saved).Length
        "selftest OK: $saved ($len bytes, $($b.Width)x$($b.Height))"
        exit 0
    }
    "selftest FAILED: $problem"
    exit 1
}
"shots: $((Get-ChildItem $Out -File -Filter 'screen_*.png').Count) kept in $Out"
