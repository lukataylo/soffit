#!/usr/bin/env bash
# Vendor KaTeX (math rendering) and marked.js (markdown→HTML) for the math
# preview shim. Run once after cloning.
# Usage: ./scripts/vendor-katex.sh
set -euo pipefail
RES="Sources/Soffit/Resources"
KATEX_VER="0.16.11"
MARKED_VER="13.0.3"

echo "Fetching katex@${KATEX_VER}…"
curl -fsSL "https://unpkg.com/katex@${KATEX_VER}/dist/katex.min.js"  -o "${RES}/katex.min.js"
curl -fsSL "https://unpkg.com/katex@${KATEX_VER}/dist/katex.min.css" -o "${RES}/katex.min.css"

# KaTeX needs its font files for Greek letters etc. Pull the woff2 set.
mkdir -p "${RES}/fonts"
for font in KaTeX_Main-Regular KaTeX_Math-Italic KaTeX_AMS-Regular KaTeX_Caligraphic-Regular KaTeX_Fraktur-Regular KaTeX_SansSerif-Regular KaTeX_Script-Regular KaTeX_Size1-Regular KaTeX_Size2-Regular KaTeX_Size3-Regular KaTeX_Size4-Regular KaTeX_Typewriter-Regular; do
  curl -fsSL "https://unpkg.com/katex@${KATEX_VER}/dist/fonts/${font}.woff2" -o "${RES}/fonts/${font}.woff2" || true
done

echo "Fetching marked@${MARKED_VER}…"
curl -fsSL "https://cdn.jsdelivr.net/npm/marked@${MARKED_VER}/marked.min.js" -o "${RES}/marked.min.js"

echo "Done. Math rendering will activate next launch."
ls -la "${RES}/katex.min.js" "${RES}/marked.min.js"
