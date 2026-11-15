<#
  Exports the developer diagnostics written by Phoenix UI's /pui dev mode (PhoenixUIDevDB.last) to
  <Out>\phoenix_diag.txt and <Out>\phoenix_diag.json. Called by bugwatch.ps1 whenever a SavedVariables file
  changes (it runs hidden); can also be run by hand. Read-only on the WoW folder.
  The addon stores the report pre-rendered as two strings (`text`, `json`), so no Lua parser is needed here.
#>
param(
    [string]$Wtf = "D:\Games\ALL GAMES\World of Warcraft\_retail_\WTF",
    [string]$Out = "C:\Users\Vorte\Phoenix_UI\bugs"
)

function Unescape-Lua([string]$s) {
    $sb = New-Object System.Text.StringBuilder
    $i = 0
    while ($i -lt $s.Length) {
        $c = $s[$i]
        if ($c -ne '\') { [void]$sb.Append($c); $i++; continue }
        $n = $s[$i + 1]
        switch -CaseSensitive ($n) {
            'n' { [void]$sb.Append("`n"); $i += 2 }
            't' { [void]$sb.Append("`t"); $i += 2 }
            'r' { [void]$sb.Append("`r"); $i += 2 }
            '"' { [void]$sb.Append('"'); $i += 2 }
            "'" { [void]$sb.Append("'"); $i += 2 }
            '\' { [void]$sb.Append('\'); $i += 2 }
            "`n" { [void]$sb.Append("`n"); $i += 2 }
            default {
                $m = [regex]::Match($s.Substring($i + 1), '^\d{1,3}')
                if ($m.Success) { [void]$sb.Append([char][int]$m.Value); $i += 1 + $m.Length }
                else { [void]$sb.Append($n); $i += 2 }
            }
        }
    }
    $sb.ToString()
}

function Get-LuaString([string]$block, [string]$key) {
    $m = [regex]::Match($block, '\["' + $key + '"\]\s*=\s*"((?:[^"\\]|\\.)*)"', 'Singleline')
    if ($m.Success) { return Unescape-Lua $m.Groups[1].Value }
    $null
}

$files = Get-ChildItem -Path (Join-Path $Wtf "Account") -Filter "Phoenix_UI.lua" -Recurse -EA SilentlyContinue |
    Where-Object { $_.DirectoryName -like "*\SavedVariables" -and $_.FullName -notlike "*\SavedVariables\*\*" } |
    Sort-Object LastWriteTime -Descending
if (-not $files) { "phoenix_diag: no Phoenix_UI.lua SavedVariables found"; return }
$raw = [IO.File]::ReadAllText($files[0].FullName, [Text.Encoding]::UTF8)
$start = $raw.IndexOf("PhoenixUIDevDB = {")
if ($start -lt 0) { "phoenix_diag: dev mode never ran (no PhoenixUIDevDB)"; return }
$next = [regex]::Match($raw.Substring($start + 18), '(?m)^[A-Za-z_][A-Za-z0-9_]* = ')
$block = if ($next.Success) { $raw.Substring($start, 18 + $next.Index) } else { $raw.Substring($start) }
$text = Get-LuaString $block "text"
$json = Get-LuaString $block "json"
if (-not $json) { "phoenix_diag: no report yet (turn on /pui dev, then /reload)"; return }
New-Item -ItemType Directory -Force -Path $Out | Out-Null
$stamp = $files[0].LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
Set-Content -Path (Join-Path $Out "phoenix_diag.json") -Value $json -Encoding UTF8
Set-Content -Path (Join-Path $Out "phoenix_diag.txt") -Value ("SavedVariables written $stamp`n" + $text) -Encoding UTF8
try {
    $s = ($json | ConvertFrom-Json).summary
    "phoenix_diag: critical $($s.critical) high $($s.high) medium $($s.medium) low $($s.low)"
} catch { "phoenix_diag: exported (json not parsed: $($_.Exception.Message))" }
