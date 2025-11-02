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

# Find extension
EXTENSION_DIR="$VIVALDI_DIR/Default/Extensions/$EXTENSION_ID"

if [ ! -d "$EXTENSION_DIR" ]; then
    echo "❌ Superhuman extension not found at:"
    echo "   $EXTENSION_DIR"
    echo ""
    echo "Please install Superhuman in Vivaldi first:"
    echo "  1. Open Vivaldi"
    echo "  2. Go to https://superhuman.com"
    echo "  3. Install the extension"
    echo "  4. Run this script again"
    exit 1
fi

echo "✅ Found Superhuman extension"

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
BG_FILE="$BG_FILE" node << 'PATCHEOF'
const fs = require('fs');
const bgFile = process.env.BG_FILE;

let content = fs.readFileSync(bgFile, 'utf8');

console.log('   → Patching offscreen API calls...');

// Patch offscreen API cache operations
let patches = 0;

const offscreenPatches = [
    {
        pattern: /saveResponse:async e=>\{await Object\(([^)]+)\)\(\{type:"ForegroundCache:saveResponse",data:\{args:\[e\.url\]\}\}\)/,
        replacement: 'saveResponse:async e=>{console.log("[Vivaldi Patch] Bypassing offscreen saveResponse");return;}'
    },
    {
        pattern: /pruneFiles:async\(e=\[\],t\)=>await Object\(([^)]+)\)\(\{type:"ForegroundCache:pruneFiles",data:\{args:\[e,t\]\}\}\)/,
        replacement: 'pruneFiles:async(e=[],t)=>{console.log("[Vivaldi Patch] Bypassing offscreen pruneFiles");return false;}'
    },
    {
        pattern: /saveFile:async e=>\{await Object\(([^)]+)\)\(\{type:"ForegroundCache:saveFile",data:\{args:\[e\]\}\}\)/,
        replacement: 'saveFile:async e=>{console.log("[Vivaldi Patch] Bypassing offscreen saveFile");return;}'
    }
];

offscreenPatches.forEach(({pattern, replacement}) => {
    const newContent = content.replace(pattern, replacement);
    if (newContent !== content) {
        patches++;
        content = newContent;
    }
});

console.log('   → Patching iframe messaging...');

// Patch iframe version
const iframePatches = [
    {
        pattern: /return u=\{saveResponse:async e=>\{const t=e\.url,r=await e\.blob\(\),n=e\.headers\.get\("content-type"\),i=e\.headers\.get\("Content-Security-Policy"\)\|\|null;await sendMessageToIframe\(o,"writeToCache",\{url:t,file:r,contentType:n,contentSecurityPolicy:i\}\)\}/,
        replacement: 'return u={saveResponse:async e=>{console.log("[Vivaldi Patch] Bypassing iframe saveResponse");return;}'
    },
    {
        pattern: /pruneFiles:async\(e=\[\],t\)=>\{const r=await sendMessageToIframe\(o,"pruneCache",\{filesToKeep:e,timeout:t\}\);return null==r\?void 0:r\.didBankrupt\}/,
        replacement: 'pruneFiles:async(e=[],t)=>{console.log("[Vivaldi Patch] Bypassing iframe pruneFiles");return false;}'
    },
    {
        pattern: /saveFile:async e=>\{await sendMessageToIframe\(o,"writeToCache",e\)\}/,
        replacement: 'saveFile:async e=>{console.log("[Vivaldi Patch] Bypassing iframe saveFile");return;}'
    }
];

iframePatches.forEach(({pattern, replacement}) => {
    const newContent = content.replace(pattern, replacement);
    if (newContent !== content) {
        patches++;
        content = newContent;
    }
});

// Write patched file
fs.writeFileSync(bgFile, content);

console.log(`   ✅ Applied ${patches} patches`);

// Verify
const patchCount = (content.match(/\[Vivaldi Patch\]/g) || []).length;
if (patchCount === 0) {
    console.error('   ❌ Verification failed - no patches found in output!');
    process.exit(1);
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
