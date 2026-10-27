# Building PhoenixUploader

The source has no ingest key in it. The key is added only at build time with
`-ldflags -X main.defaultIngestKey=...`, taken from the `PHOENIX_INGEST_KEY`
environment variable. Never commit the key, a built exe, or `dist/`.

Requirements: Go 1.22+ (tested with 1.27). For the optional icon and version
resource: `go install github.com/tc-hib/go-winres@latest`.

    cd companion/uploader
    go vet ./... && go test ./...

    # Linux / macOS / WSL
    PHOENIX_INGEST_KEY="<from your secret store>" ./build.sh

    # Windows PowerShell
    $env:PHOENIX_INGEST_KEY = "<from your secret store>"; ./build.ps1

Outputs: `dist/PhoenixUploader.exe` (Windows x64, no console window),
`dist/phoenix-uploader-linux-amd64` (for testing) and `dist/SHA256SUMS`.
If you build without the key, the exe needs a `config.json` that sets
`"ingestKey"` (see `config.example.json`). `PHOENIX_ENDPOINT` overrides the
ingest URL, which defaults to https://vq8s.com/phoenix/api/ingest.

The version comes from `version` in `config.go`. To release: bump it, build,
then replace the `PhoenixUploader.exe` asset on the GitHub release with
`gh release upload <tag> dist/PhoenixUploader.exe --clobber`, and note the
version and SHA-256 in the release notes.
