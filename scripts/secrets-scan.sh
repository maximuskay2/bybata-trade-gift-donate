#!/usr/bin/env bash
# Fail when tracked files look like secrets. Run before every push.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

fail=0
# This repo is private. The release keystore, database backup, and API env
# files stay tracked on purpose. Do not fail the scan because of them.

# PEM headers only. Skip the tracked npm cache and docs, which quote library examples.
hits=$(git grep -I -l -E -- '-----BEGIN (RSA |OPENSSH |EC |DSA )?PRIVATE KEY-----' -- . ':!.npm-cache' ':!*.md' ':!scripts/secrets-scan.sh' || true)
if [[ -n "$hits" ]]; then
  echo "private key material is tracked:"
  echo "$hits"
  fail=1
fi

if [[ "$fail" -ne 0 ]]; then
  echo "Secrets scan failed. Remove the files from git before pushing."
  exit 1
fi

echo "Secrets scan passed."
