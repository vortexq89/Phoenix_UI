<#
  Phoenix UI passive screen capture for the overnight self-test loop. Called by bugwatch.ps1 each time a
  Phoenix_UI SavedVariables file changes. It only READS the screen (System.Drawing CopyFromScreen) and
  never sends input to anything. It also copies in-game screenshots that the self-test took
  (/pui dev selftest shots on) from the game's Screenshots folders. Keeps the newest -Keep files.

  .\phoenix_shots.ps1 [-Out C:\Users\Vorte\Phoenix_UI\bugs\shots] [-Keep 50]
#>
param(
    [string]$Out = 'C:\Users\Vorte\Phoenix_UI\bugs\shots',
    [string]$GameRoot = 'D:\Games\ALL GAMES\World of Warcraft',
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

# in-game screenshots the self-test asked the client for (read-only on the game folder)
$since = (Get-Date).AddHours(-12)
foreach ($fl in '_retail_', '_forever_', '_classic_era_') {
    $dir = Join-Path $GameRoot "$fl\Screenshots"
    if (-not (Test-Path $dir)) { continue }
    Get-ChildItem $dir -File | Where-Object { $_.LastWriteTime -gt $since } | ForEach-Object {
        $dst = Join-Path $Out ("game_" + $_.Name)
        if (-not (Test-Path $dst)) { Copy-Item $_.FullName $dst }
    }
}

Get-ChildItem $Out -File | Sort-Object LastWriteTime -Descending | Select-Object -Skip $Keep | Remove-Item -Force
"shots: $((Get-ChildItem $Out -File).Count) kept in $Out"
