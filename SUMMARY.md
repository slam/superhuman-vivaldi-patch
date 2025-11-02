# 🎉 Ready to Push to GitHub!

## What You Have

```
superhuman-vivaldi-patch/
├── patch-superhuman.sh  # Main script (Linux & macOS)
├── README.md           # Full documentation
├── .gitignore         # Git ignore file
└── SUMMARY.md         # This file
```

## How to Use

### 1. Push to GitHub

```bash
cd /tmp/superhuman-vivaldi-patch

# Initialize repo
git init
git add .
git commit -m "Initial commit: Superhuman Vivaldi compatibility patch"

# Create repo on GitHub, then:
git remote add origin https://github.com/slam/superhuman-vivaldi-patch.git
git branch -M main
git push -u origin main
```

### 2. Use on Any Machine

```bash
# Clone it
git clone https://github.com/slam/superhuman-vivaldi-patch
cd superhuman-vivaldi-patch

# Run it
./patch-superhuman.sh

# Follow instructions to load in Vivaldi
```

### 3. When Superhuman Updates

```bash
# Remove old patched version
rm -rf ~/superhuman-vivaldi-patched

# Re-run
./patch-superhuman.sh

# Reload in Vivaldi (vivaldi://extensions/ → reload button)
```

## What It Does

✅ **Auto-detects** Linux or macOS
✅ **Finds** installed Superhuman in Vivaldi (`~/.config/vivaldi/` or `~/Library/...`)
✅ **Copies** to `~/superhuman-vivaldi-patched/`
✅ **Patches** 6 functions to bypass broken offscreen API
✅ **Idempotent** - won't re-patch if already done

## Tested

- ✅ Linux (your current system)
- ⏳ macOS (should work, same logic)

## Files

- **patch-superhuman.sh** - 6.4 KB, executable
- **README.md** - 4.2 KB, documentation
- **.gitignore** - Excludes patched output from git

Ready to go! 🚀
