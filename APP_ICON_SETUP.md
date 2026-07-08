# macOS SwiftPM App Icon Setup

How to add a custom app icon to a macOS application built with SwiftPM.

## Prerequisites

- A PNG file for your icon (e.g., `logo.png`)
- A SwiftPM project with `Scripts/bundle.sh` that creates the `.app` bundle
- macOS command-line tools (sips, iconutil)

## Steps

### 1. Create the iconset directory

```bash
mkdir -p /tmp/AppIcon.iconset
cd /tmp/AppIcon.iconset
```

### 2. Generate icon sizes using sips

Replace `logo.png` with your actual icon file path:

```bash
sips -z 16 16 /path/to/logo.png --out icon_16x16.png
sips -z 32 32 /path/to/logo.png --out icon_16x16@2x.png
sips -z 32 32 /path/to/logo.png --out icon_32x32.png
sips -z 64 64 /path/to/logo.png --out icon_32x32@2x.png
sips -z 128 128 /path/to/logo.png --out icon_128x128.png
sips -z 256 256 /path/to/logo.png --out icon_128x128@2x.png
sips -z 256 256 /path/to/logo.png --out icon_256x256.png
sips -z 512 512 /path/to/logo.png --out icon_256x256@2x.png
sips -z 512 512 /path/to/logo.png --out icon_512x512.png
sips -z 1024 1024 /path/to/logo.png --out icon_512x512@2x.png
```

### 3. Convert iconset to .icns format

```bash
iconutil -c icns . -o /path/to/your/project/Sources/YourApp/Resources/AppIcon.icns
```

This creates an `AppIcon.icns` file. You can verify it:

```bash
ls -lh /path/to/your/project/Sources/YourApp/Resources/AppIcon.icns
```

### 4. Update `Scripts/bundle.sh`

In your bundle script, find the section where `Info.plist` is created and change:

**Before:**
```bash
    <key>CFBundleIconName</key>          <string>AppIcon</string>
```

**After:**
```bash
    <key>CFBundleIconFile</key>          <string>AppIcon</string>
```

Then add this section after the binary is copied (after the `cp "$BIN" "$CONTENTS/MacOS/YourApp"` line):

```bash
# Copy icon to the app bundle
if [ -f "$ROOT/Sources/YourApp/Resources/AppIcon.icns" ]; then
  cp "$ROOT/Sources/YourApp/Resources/AppIcon.icns" "$CONTENTS/Resources/"
fi
```

### 5. Build and install

```bash
./Scripts/bundle.sh release
./Scripts/install.sh
```

Or if you use a different build script:

```bash
swift build -c release
```

### 6. Clear macOS icon cache

```bash
rm -rf ~/Library/Caches/com.apple.bird ~/Library/Caches/Finder && killall Finder
```

## File Structure

After these steps, your project should have:

```
Sources/YourApp/
├── Resources/
│   └── AppIcon.icns
├── TimekeepApp.swift
├── ... other files ...
```

And the final app bundle will have:

```
YourApp.app/Contents/
├── MacOS/
│   └── YourApp
├── Resources/
│   └── AppIcon.icns
└── Info.plist
```

## Notes

- The `.icns` format is required for macOS; plain PNGs won't work as app icons
- Use `CFBundleIconFile` (not `CFBundleIconName`) in `Info.plist` when pointing to an `.icns` file
- The icon name in `Info.plist` should match the filename without the `.icns` extension (e.g., `AppIcon` for `AppIcon.icns`)
- Clear the Finder cache if the icon doesn't update immediately
