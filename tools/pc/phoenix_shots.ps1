<#
  Phoenix UI passive screen capture for the overnight self-test loop. Called by bugwatch.ps1 each time a
  Phoenix_UI SavedVariables file changes. It only READS the screen (System.Drawing CopyFromScreen) and
  never sends input to anything. The game's own Screenshots folder is never read, copied or touched.
  Keeps the newest -Keep screen_*.png files it wrote itself; nothing else in -Out is deleted.

  .\phoenix_shots.ps1 [-Out C:\Users\Vorte\Phoenix_UI\bugs\shots] [-Keep 50]
#>
param(
    [string]$Out = 'C:\Users\Vorte\Phoenix_UI\bugs\shots',
    [int]$Keep = 50
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing, System.Windows.Forms
New-Item -ItemType Directory -Force $Out | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'

$b = [Windows.Forms.SystemInformation]::VirtualScreen
$bmp = New-Object Drawing.Bitmap $b.Width, $b.Height
$g = [Drawing.Graphics]::FromImage($bmp)
try {
    $g.CopyFromScreen($b.Left, $b.Top, 0, 0, $bmp.Size)
    $bmp.Save((Join-Path $Out "screen_$stamp.png"), [Drawing.Imaging.ImageFormat]::Png)
} catch { Write-Warning "screen capture failed (locked or no desktop session): $_" }
finally { $g.Dispose(); $bmp.Dispose() }

Get-ChildItem $Out -File -Filter 'screen_*.png' | Sort-Object LastWriteTime -Descending | Select-Object -Skip $Keep | Remove-Item -Force
"shots: $((Get-ChildItem $Out -File -Filter 'screen_*.png').Count) kept in $Out"
