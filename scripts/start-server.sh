#!/bin/zsh
set -eu
cd "$(dirname "$0")/.."
mkdir -p server/bin
if [[ ! -x server/bin/extract || server/extract.swift -nt server/bin/extract ]]; then
  xcrun swiftc server/extract.swift -o server/bin/extract
fi
exec python3 server/app.py
