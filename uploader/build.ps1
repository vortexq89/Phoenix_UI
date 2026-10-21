# Windows build of dist\PhoenixUploader.exe. Same flags as build.sh.
#   .\build.ps1                       # placeholder key (the exe then needs config.json next to it)
#   $env:PHOENIX_INGEST_KEY="xxxx"; .\build.ps1
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
$version = (Select-String -Path config.go -Pattern 'version\s*=\s*"([^"]+)"').Matches[0].Groups[1].Value
$ld = "-s -w -X main.version=$version -H windowsgui"
if ($env:PHOENIX_INGEST_KEY) { $ld += " -X main.defaultIngestKey=$($env:PHOENIX_INGEST_KEY)" }
if ($env:PHOENIX_ENDPOINT)   { $ld += " -X main.defaultEndpoint=$($env:PHOENIX_ENDPOINT)" }
if (Get-Command go-winres -ErrorAction SilentlyContinue) { go-winres make --arch amd64 --in winres/winres.json --product-version "$version.0" --file-version "$version.0" }
go test ./...
New-Item -ItemType Directory -Force dist | Out-Null
$env:CGO_ENABLED = "0"; $env:GOOS = "windows"; $env:GOARCH = "amd64"
go build -trimpath -ldflags $ld -o dist\PhoenixUploader.exe .
Get-FileHash dist\PhoenixUploader.exe -Algorithm SHA256
