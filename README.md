# Superhuman for Vivaldi - Compatibility Patch

A simple script to patch the [Superhuman](https://superhuman.com) Chrome extension to work in Vivaldi browser on Linux and macOS.

## The Problem

Superhuman uses Chrome's offscreen API for caching, which doesn't work correctly in Vivaldi. This causes timeout errors:
```
Offscreen Error: Timeout sending to FCM pruneCache
```

This patch bypasses the broken caching operations, making the extension fully functional in Vivaldi.

## Requirements

- **Vivaldi browser** with Superhuman extension installed
- **Node.js** (for applying the patch)
- **Linux** or **macOS**

## Quick Start

```bash
# 1. Clone this repo
git clone https://github.com/slam/superhuman-vivaldi-patch
cd superhuman-vivaldi-patch

# 2. Run the patch script
./patch-superhuman.sh

# 3. Follow the instructions to load the patched extension in Vivaldi
```

## What It Does

The script:

1. ✅ **Finds** your installed Superhuman extension in Vivaldi
2. ✅ **Copies** it to `~/superhuman-vivaldi-patched/`
3. ✅ **Patches** the background script to bypass broken offscreen operations
4. ✅ **Gives instructions** to load the patched version

## Loading the Patched Extension

After running the script:

1. Open `vivaldi://extensions/`
2. **Disable** the built-in Superhuman extension (toggle it off)
3. Enable **Developer mode** (toggle in top right)
4. Click **Load unpacked**
5. Select: `~/superhuman-vivaldi-patched/`

You should now see `[Vivaldi Patch]` messages in the service worker console confirming it's working!

## Updating

When Superhuman releases a new version:

1. The built-in extension in Vivaldi will auto-update
2. Just run `./patch-superhuman.sh` again
3. Reload the patched extension in Vivaldi

## How the Patch Works

Six cache functions across two layers (Chrome offscreen API + iframe messaging) are replaced with no-op bypasses:

**Before (broken in Vivaldi):**
```javascript
pruneFiles: async (e=[], t) => await (0,p.Aq)({
  type: "ForegroundCache:pruneFiles",
  data: { args: [e, t] }
})
```

**After (patched):**
```javascript
pruneFiles: async (e=[], t) => {
  console.log("[Vivaldi Patch] Bypassing offscreen pruneFiles");
  return false;
}
```

This bypasses Vivaldi's broken offscreen iframe messaging while keeping the extension fully functional.

### Why string-anchored, brace-counted matching?

Earlier versions of this patch used a single regex per function body. That broke whenever Superhuman's webpack output drifted: variable renames (`o` → `h`), webpack call-form changes (`Object(n.b)(...)` → `(0,p.Aq)(...)`), or whitespace differences flipped the regex from matching to silently failing. On Superhuman `3.1.60512.2240` the regex-based approach matched **0/6** functions.

The current matcher is more robust:

1. **Locate the function header** by property name (e.g. `pruneFiles:async`) with a parameter-aware regex that balances `(...)` so default values like `e=[]` don't break header detection.
2. **Brace-match the body**, skipping over string literals. Both block bodies (`=>{...}`) and expression bodies (`=>await foo()`) are supported.
3. **Verify a stable string anchor** is inside the body (e.g. `"ForegroundCache:pruneFiles"`, `"pruneCache"`) — these message-type literals form a de-facto API contract between background and the offscreen/iframe cache layers, so they survive minifier drift.

The patch should now only break if Superhuman renames its cache message types or restructures the cache architecture, rather than every time a webpack release changes minified output.

## Trade-offs

✅ **Extension works perfectly**
⚠️ Some resources won't be cached between sessions (minimal impact)
⚠️ Slightly more network requests (not noticeable)

This is a reasonable trade-off for a fully working extension!

## Technical Details

**Extension ID:** `dcgcnpooblobhncpnddnhoendgbnglpn`

**Vivaldi Extension Locations:**
- Linux: `~/.config/vivaldi/Default/Extensions/dcgcnpooblobhncpnddnhoendgbnglpn/`
- macOS: `~/Library/Application Support/Vivaldi/Default/Extensions/dcgcnpooblobhncpnddnhoendgbnglpn/`

**Patched Functions:**
- `saveResponse()` - Offscreen & iframe versions
- `pruneFiles()` - Offscreen & iframe versions
- `saveFile()` - Offscreen & iframe versions

## Troubleshooting

**Extension not found:**
```
❌ Superhuman extension not found
```
→ Install Superhuman in Vivaldi first from [superhuman.com](https://superhuman.com)

**Still seeing timeout errors:**
1. Check service worker console (vivaldi://extensions/ → click "service worker")
2. Look for `[Vivaldi Patch]` messages
3. If missing, the patch didn't apply - file an issue!

**Patched version won't load:**
- Make sure you disabled the built-in version first
- Check vivaldi://extensions/ for error messages
- Verify `~/superhuman-vivaldi-patched/` exists

## Why This Happens

Vivaldi's Chromium fork has a different implementation of offscreen documents where `postMessage` from cross-origin iframes doesn't properly deliver messages back to the extension. This is likely a bug in Vivaldi's security model or message routing.

The issue has been reported to Vivaldi but there's no timeline for a fix.

## Contributing

Found a bug? Have a suggestion? [Open an issue](https://github.com/slam/superhuman-vivaldi-patch/issues)!

## License

MIT

## Disclaimer

This is an unofficial patch. Superhuman and Vivaldi are trademarks of their respective owners.

---

**Made with ❤️ for Vivaldi users who want Superhuman**


---
Annotations: 0,5454 SHA-256 ad53818dbe4e704a510b305423b17b90ff6281e3ba452b18e957fbf9d17947e2
&Claude: 0,5454
...