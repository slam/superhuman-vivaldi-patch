#!/bin/bash

# Superhuman for Vivaldi - Compatibility Patch
# Patches the installed Superhuman extension to work in Vivaldi browser
# Works on Linux and macOS

set -e

EXTENSION_ID="dcgcnpooblobhncpnddnhoendgbnglpn"
OUTPUT_DIR="$HOME/superhuman-vivaldi-patched"

echo "🚀 Superhuman for Vivaldi - Patch Script"
echo "=========================================="
echo ""

# Check dependencies
for cmd in node; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌ Error: $cmd is required but not installed"
        exit 1
    fi
done

# Detect OS and find Vivaldi extension directory
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    VIVALDI_DIR="$HOME/Library/Application Support/Vivaldi"
    echo "🍎 Detected macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    VIVALDI_DIR="$HOME/.config/vivaldi"
    echo "🐧 Detected Linux"
else
    echo "❌ Unsupported OS: $OSTYPE"
    exit 1
fi

# Find extension - check Default first, then Profile 1-10
EXTENSION_DIR=""
PROFILE_NAME=""

# Check Default profile first
if [ -d "$VIVALDI_DIR/Default/Extensions/$EXTENSION_ID" ]; then
    EXTENSION_DIR="$VIVALDI_DIR/Default/Extensions/$EXTENSION_ID"
    PROFILE_NAME="Default"
fi

# If not found, check Profile 1 through Profile 10
if [ -z "$EXTENSION_DIR" ]; then
    for i in {1..10}; do
        if [ -d "$VIVALDI_DIR/Profile $i/Extensions/$EXTENSION_ID" ]; then
            EXTENSION_DIR="$VIVALDI_DIR/Profile $i/Extensions/$EXTENSION_ID"
            PROFILE_NAME="Profile $i"
            break
        fi
    done
fi

if [ -z "$EXTENSION_DIR" ]; then
    echo "❌ Superhuman extension not found in any Vivaldi profile"
    echo ""
    echo "Searched in:"
    echo "   - $VIVALDI_DIR/Default/Extensions/$EXTENSION_ID"
    echo "   - $VIVALDI_DIR/Profile 1-10/Extensions/$EXTENSION_ID"
    echo ""
    echo "Please install Superhuman in Vivaldi first:"
    echo "  1. Open Vivaldi"
    echo "  2. Go to https://superhuman.com"
    echo "  3. Install the extension"
    echo "  4. Run this script again"
    exit 1
fi

echo "✅ Found Superhuman extension in: $PROFILE_NAME"

# Find the latest version directory
VERSION_DIR=$(ls -1 "$EXTENSION_DIR" | grep -E '^[0-9]' | sort -V | tail -1)

if [ -z "$VERSION_DIR" ]; then
    echo "❌ No version directory found in $EXTENSION_DIR"
    exit 1
fi

SOURCE_DIR="$EXTENSION_DIR/$VERSION_DIR"
VERSION=$(echo "$VERSION_DIR" | sed 's/_0$//')

echo "📌 Version: $VERSION"
echo "📂 Source: $SOURCE_DIR"
echo ""

# Check if output already exists and is patched
if [ -d "$OUTPUT_DIR" ]; then
    EXISTING_BG="$OUTPUT_DIR/background/background_page.js"
    if [ -f "$EXISTING_BG" ] && grep -q "\[Vivaldi Patch\]" "$EXISTING_BG"; then
        echo "✅ Already patched! Using existing patched version."
        echo ""
        echo "📍 Patched extension location: $OUTPUT_DIR"
        echo ""
        echo "To re-patch (if Superhuman updated): rm -rf $OUTPUT_DIR && ./patch-superhuman.sh"
        echo ""
        echo "Load in Vivaldi:"
        echo "  1. Go to vivaldi://extensions/"
        echo "  2. Disable the built-in Superhuman extension (toggle it off)"
        echo "  3. Enable 'Developer mode' (top right)"
        echo "  4. Click 'Load unpacked'"
        echo "  5. Select: $OUTPUT_DIR"
        exit 0
    fi
fi

# Copy to output directory
echo "📋 Copying extension to: $OUTPUT_DIR"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"
cp -r "$SOURCE_DIR"/* "$OUTPUT_DIR/"

# Verify background script exists
BG_FILE="$OUTPUT_DIR/background/background_page.js"

if [ ! -f "$BG_FILE" ]; then
    echo "❌ Background script not found at: $BG_FILE"
    exit 1
fi

echo "🔧 Applying Vivaldi compatibility patch..."

# Backup original
cp "$BG_FILE" "$BG_FILE.original"

# Apply patch using Node.js
#
# Strategy: instead of matching the entire minified function body with a single
# regex (fragile across Superhuman releases — variable names like `o`/`h` and
# webpack call shapes like `Object(n.b)(...)` vs `(0,p.Aq)(...)` drift between
# builds), we:
#   1. Locate each function header by property name (e.g. `pruneFiles:async`).
#   2. Brace-match the body so default params like `e=[]` and nested `{...}`
#      objects don't trip the matcher. Both block bodies (`=>{...}`) and
#      expression bodies (`=>await foo()`) are supported.
#   3. Confirm the body contains a STABLE string anchor (e.g.
#      "ForegroundCache:pruneFiles", "pruneCache") — these are message-type
#      string literals that form a de-facto API contract between background
#      and the offscreen/iframe layers, so they survive minify drift.
#
# This makes the patch resilient to property/variable renames, whitespace
# changes, and arrow-body style flips. It only breaks if Superhuman renames
# the offscreen cache message types or restructures the cache layer.

BG_FILE="$BG_FILE" node << 'PATCHEOF'
const fs = require('fs');
const bgFile = process.env.BG_FILE;
let content = fs.readFileSync(bgFile, 'utf8');

// [property name, stable string anchor inside body, replacement body, label]
const PATCHES = [
    ['saveResponse', '"ForegroundCache:saveResponse"', 'console.log("[Vivaldi Patch] Bypassing offscreen saveResponse");return;',  'offscreen saveResponse'],
    ['pruneFiles',   '"ForegroundCache:pruneFiles"',   'console.log("[Vivaldi Patch] Bypassing offscreen pruneFiles");return false;', 'offscreen pruneFiles'],
    ['saveFile',     '"ForegroundCache:saveFile"',     'console.log("[Vivaldi Patch] Bypassing offscreen saveFile");return;',      'offscreen saveFile'],
    ['saveResponse', '"Content-Security-Policy"',      'console.log("[Vivaldi Patch] Bypassing iframe saveResponse");return;',     'iframe saveResponse'],
    ['pruneFiles',   '"pruneCache"',                   'console.log("[Vivaldi Patch] Bypassing iframe pruneFiles");return false;',    'iframe pruneFiles'],
    ['saveFile',     'sendMessageToIframe',            'console.log("[Vivaldi Patch] Bypassing iframe saveFile");return;',         'iframe saveFile'],
];

function patchProperty(src, propName, anchor, newBody) {
    // Header: `<prop>:async <param-list> =>`
    // Parameter list is either a balanced `(...)` (so defaults like `e=[]`
    // don't break us) or a single identifier.
    const headerRe = new RegExp(
        '\\b' + propName + ':async\\s*(?:\\([^()]*(?:\\([^()]*\\)[^()]*)*\\)|[a-zA-Z_$][\\w$]*)\\s*=>\\s*',
        'g'
    );

    let result = '';
    let lastEnd = 0;
    let applied = 0;
    let m;

    while ((m = headerRe.exec(src)) !== null) {
        const afterArrow = m.index + m[0].length;
        let bodyStart, bodyEnd, isBlock;

        if (src[afterArrow] === '{') {
            // Block body — brace-match, skipping string literals
            isBlock = true;
            bodyStart = afterArrow + 1;
            let depth = 1, i = bodyStart;
            while (i < src.length && depth > 0) {
                const c = src[i];
                if (c === '{') depth++;
                else if (c === '}') depth--;
                else if (c === '"' || c === "'" || c === '`') {
                    const q = c; i++;
                    while (i < src.length && src[i] !== q) {
                        if (src[i] === '\\') i++;
                        i++;
                    }
                }
                i++;
            }
            if (depth !== 0) continue;
            bodyEnd = i - 1; // points at closing '}'
        } else {
            // Expression body — scan until top-level comma, semicolon, or unmatched ')'/'}'/']'
            isBlock = false;
            bodyStart = afterArrow;
            let paren = 0, brace = 0, bracket = 0, i = bodyStart;
            while (i < src.length) {
                const c = src[i];
                if (c === '"' || c === "'" || c === '`') {
                    const q = c; i++;
                    while (i < src.length && src[i] !== q) {
                        if (src[i] === '\\') i++;
                        i++;
                    }
                } else if (c === '(') paren++;
                else if (c === ')') { if (paren === 0) break; paren--; }
                else if (c === '{') brace++;
                else if (c === '}') { if (brace === 0) break; brace--; }
                else if (c === '[') bracket++;
                else if (c === ']') { if (bracket === 0) break; bracket--; }
                else if ((c === ',' || c === ';') && paren === 0 && brace === 0 && bracket === 0) break;
                i++;
            }
            bodyEnd = i;
        }

        const body = src.substring(bodyStart, bodyEnd);
        if (body.includes(anchor) && !body.includes('[Vivaldi Patch]')) {
            if (isBlock) {
                result += src.substring(lastEnd, bodyStart) + newBody;
                lastEnd = bodyEnd;
            } else {
                // Wrap synthesized body in braces so the original function becomes a block-body arrow
                result += src.substring(lastEnd, afterArrow) + '{' + newBody + '}';
                lastEnd = bodyEnd;
            }
            headerRe.lastIndex = bodyEnd;
            applied++;
        }
    }
    result += src.substring(lastEnd);
    return { content: result, applied };
}

console.log('   → Applying patches (string-anchored, brace-counted)...');

let total = 0;
for (const [prop, anchor, replacement, label] of PATCHES) {
    const r = patchProperty(content, prop, anchor, replacement);
    if (r.applied > 0) {
        content = r.content;
        total += r.applied;
        console.log(`       ✅ ${label}`);
    } else {
        console.log(`       ❌ ${label}  (anchor ${anchor} not found in any ${prop} body)`);
    }
}

fs.writeFileSync(bgFile, content);

const markerCount = (content.match(/\[Vivaldi Patch\]/g) || []).length;
console.log(`   Applied ${total}/6 patches  (verify: ${markerCount} markers in output)`);

if (total !== 6 || markerCount !== 6) {
    console.error('   ⚠️  Not all patches were applied — Superhuman extension internals may have changed.');
    console.error('       Original file kept at: ' + bgFile + '.original');
    if (total === 0) process.exit(1);
}
PATCHEOF

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Patch applied successfully!"
    echo ""
    echo "📍 Patched extension location: $OUTPUT_DIR"
    echo ""
    echo "Next steps:"
    echo "  1. Go to vivaldi://extensions/"
    echo "  2. Disable the built-in Superhuman extension (toggle it off)"
    echo "  3. Enable 'Developer mode' (toggle in top right)"
    echo "  4. Click 'Load unpacked'"
    echo "  5. Select: $OUTPUT_DIR"
    echo ""
    echo "💡 Re-run this script anytime Superhuman updates to re-patch"
else
    echo ""
    echo "❌ Patch failed!"
    exit 1
fi
