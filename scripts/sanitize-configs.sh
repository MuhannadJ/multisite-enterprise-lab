#!/usr/bin/env bash
# Redact secrets from Cisco IOS config exports before publishing.
# Usage: scripts/sanitize-configs.sh <raw-export-dir> <output-dir>
# The raw directory is never modified. Output files keep their names.
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <raw-export-dir> <output-dir>" >&2
  exit 2
fi
in_dir=$1
out_dir=$2
[ -d "$in_dir" ] || { echo "no such directory: $in_dir" >&2; exit 2; }
mkdir -p "$out_dir"

count=0
for f in "$in_dir"/*.txt; do
  [ -e "$f" ] || { echo "no .txt files in $in_dir" >&2; exit 2; }
  sed -E \
    -e 's/^(crypto isakmp key )[^ ]+( address .*)$/\1<REDACTED>\2/' \
    -e 's/^( *tacacs-server (host [^ ]+ )?key )[^ ]+.*$/\1<REDACTED>/' \
    -e 's/^( *radius-server (host [^ ]+ )?key )[^ ]+.*$/\1<REDACTED>/' \
    -e 's/^(snmp-server community )[^ ]+( .*)$/\1<REDACTED>\2/' \
    -e 's/^(enable secret )[0-9] [^ ]+.*$/\1<REDACTED>/' \
    -e 's/^(enable password )(7 |0 )?[^ ]+.*$/\1<REDACTED>/' \
    -e 's/^(username [^ ]+( privilege [0-9]+)? (secret|password) )[0-9] [^ ]+.*$/\1<REDACTED>/' \
    "$f" > "$out_dir/$(basename "$f")"
  count=$((count + 1))
done

# Fail loudly if anything that looks like a secret survived.
leaks=$(grep -nEi 'isakmp key [^<]|key [0-9]? ?[A-Za-z0-9]{6,}$|community [^<]|secret [0-9] \$|password [0-9] ' "$out_dir"/*.txt || true)
if [ -n "$leaks" ]; then
  echo "WARNING: possible secrets remain:" >&2
  echo "$leaks" >&2
  exit 1
fi
echo "Sanitized $count file(s) into $out_dir"
