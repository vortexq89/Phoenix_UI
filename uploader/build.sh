#!/usr/bin/env bash
# Builds dist/PhoenixUploader.exe (Windows x64, one self-contained file, no console window) and, for testing,
# dist/phoenix-uploader-linux-amd64.
#
#   ./build.sh                                  # placeholder key: the exe then needs a config.json with "ingestKey"
#   PHOENIX_INGEST_KEY=xxxx ./build.sh          # bake the release key in (never commit it)
#   PHOENIX_ENDPOINT=https://... ./build.sh     # another ingest URL (default https://vq8s.com/phoenix/api/ingest)
#
# Needs Go 1.22+. The icon / version resource (rsrc_windows_amd64.syso) is made with go-winres when it is installed
# (go install github.com/tc-hib/go-winres@latest); without it the exe simply has no icon in Explorer.
set -euo pipefail
cd "$(dirname "$0")"
VERSION=$(sed -n 's/^\s*version\s*=\s*"\(.*\)"/\1/p' config.go | head -1)
LDFLAGS="-s -w -X main.version=${VERSION}"
[ -n "${PHOENIX_INGEST_KEY:-}" ] && LDFLAGS="$LDFLAGS -X main.defaultIngestKey=${PHOENIX_INGEST_KEY}"
[ -n "${PHOENIX_ENDPOINT:-}" ] && LDFLAGS="$LDFLAGS -X main.defaultEndpoint=${PHOENIX_ENDPOINT}"
WINRES=$(command -v go-winres || echo "$(go env GOPATH)/bin/go-winres")
if [ -x "$WINRES" ]; then
  "$WINRES" make --arch amd64 --in winres/winres.json --product-version "$VERSION.0" --file-version "$VERSION.0"
fi
go test ./...
mkdir -p dist
CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -trimpath -ldflags "$LDFLAGS -H windowsgui" -o dist/PhoenixUploader.exe .
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags "$LDFLAGS" -o dist/phoenix-uploader-linux-amd64 .
( cd dist && sha256sum PhoenixUploader.exe phoenix-uploader-linux-amd64 > SHA256SUMS )
ls -l dist
