#!/bin/sh
# Sync the iCloud working copy into this repo, then commit and push.
# Usage: ./sync-from-icloud.sh ["commit message"]
set -e

SRC="$HOME/Library/Mobile Documents/com~apple~CloudDocs/Documents/סימולטור שחפים.html"
REPO="$(cd "$(dirname "$0")" && pwd)"
DEST="$REPO/index.html"

[ -f "$SRC" ] || { echo "iCloud file not found:"; echo "  $SRC"; exit 1; }

if cmp -s "$SRC" "$DEST"; then
  echo "Already in sync — nothing to do."
  exit 0
fi

echo "Changes to bring in:"
diff -u "$DEST" "$SRC" | grep -cE '^\+[^+]' | sed 's/^/  added lines:   /'
diff -u "$DEST" "$SRC" | grep -cE '^-[^-]' | sed 's/^/  removed lines: /'

# Refuse to publish broken JavaScript.
if command -v node >/dev/null 2>&1; then
  node -e '
    const fs = require("fs"), vm = require("vm");
    const html = fs.readFileSync(process.argv[1], "utf8");
    const re = /<script\b([^>]*)>([\s\S]*?)<\/script>/gi;
    let m, bad = 0;
    while ((m = re.exec(html))) {
      if (/\bsrc=/.test(m[1])) continue;
      try { new vm.Script(m[2]); }
      catch (e) { bad++; console.error("SYNTAX ERROR: " + e.message); }
    }
    process.exit(bad ? 1 : 0);
  ' "$SRC" || { echo "Aborted: the iCloud file has a JavaScript syntax error."; exit 1; }
  echo "  JS syntax: OK"
fi

cp "$SRC" "$DEST"
git -C "$REPO" add index.html
git -C "$REPO" commit -q -m "${1:-Update simulator from iCloud working copy}"
# This machine's DNS resolver wedges intermittently (the router's primary
# nameserver is dead). If the push cannot resolve github.com, retry once with
# the address pinned, asking a nameserver that is known to answer.
if ! git -C "$REPO" push -q origin main 2>/dev/null; then
  echo "Push failed — retrying with the address pinned (DNS looks wedged)..."
  ip=$(dig +short +time=3 +tries=2 @96.45.46.46 github.com | grep -E '^[0-9.]+$' | head -1)
  [ -n "$ip" ] || { echo "Could not resolve github.com at all. Check the network."; exit 1; }
  git -C "$REPO" -c http.curloptResolve="github.com:443:$ip" push -q origin main
fi
echo "Pushed. Live in ~30s: https://moatpsyc.github.io/shachafim-simulator/"
