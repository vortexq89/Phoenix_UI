# Installs Phoenix UI from this repo into the game's AddOns folder: Phoenix_UI plus every Phoenix_UI_* folder
# (settings, quest data and the plugins, docs/PLUGIN_SPLIT.md). Touches only Phoenix_UI* folders; never runs while
# the game is open.
#   powershell -File tools\pc\install.ps1 [-AddOns "<path to Interface\AddOns>"]
param([string]$AddOns = "D:\Games\ALL GAMES\World of Warcraft\_retail_\Interface\AddOns")
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (Get-Process Wow, WowClassic, WowT -ErrorAction SilentlyContinue) { "WOW RUNNING - not installed"; exit 1 }
if (-not (Test-Path $AddOns)) { "AddOns folder not found: $AddOns"; exit 1 }
$folders = Get-ChildItem $repo -Directory -Filter "Phoenix_UI_*" | ForEach-Object Name
$skip = @(".git", ".github", ".cursor", ".tools", ".luacheck", "docs", "tools", "uploader") + $folders
robocopy $repo "$AddOns\Phoenix_UI" /MIR /XD $skip /XF .gitignore .luacheckrc .pkgmeta AGENTS.md /NJH /NJS /NFL /NDL | Out-Null
if ($LASTEXITCODE -ge 8) { "copy failed: Phoenix_UI"; exit 1 }
foreach ($f in $folders) {
    robocopy (Join-Path $repo $f) "$AddOns\$f" /MIR /NJH /NJS /NFL /NDL | Out-Null
    if ($LASTEXITCODE -ge 8) { "copy failed: $f"; exit 1 }
}
"installed Phoenix_UI + $($folders.Count) folders: " + (git -C $repo log --oneline -1)
