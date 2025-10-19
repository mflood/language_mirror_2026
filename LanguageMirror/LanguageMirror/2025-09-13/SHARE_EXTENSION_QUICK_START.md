# Share Extension Quick Start

## What Was Implemented

A Share Extension that allows users to import audio files directly from Voice Memos (and other apps) with a single tap on the Share button.

## Files Created

### Shared Infrastructure (used by both app and extension)
- `SharedImport/SharedImportModels.swift` - Data models for pending imports
- `SharedImport/SharedImportManager.swift` - File transfer manager via App Groups

### Share Extension
- `ShareExtension/ShareViewController.swift` - Extension UI and logic
- `ShareExtension/Info.plist` - Extension configuration

### Documentation
- `SHARE_EXTENSION_SETUP.md` - Complete setup instructions
- `SHARE_EXTENSION_QUICK_START.md` - This file

## Files Modified

- `Coordinators/AppCoordinator.swift` - Added pending import checking on launch
- `Screens/ImportViewController.swift` - Updated help text and descriptions

## Next Steps (Manual Xcode Configuration)

1. **Create Share Extension Target** in Xcode
   - File → New → Target → Share Extension
   - Name: `LanguageMirrorShare`

2. **Configure App Groups** for both targets
   - App Group ID: `group.com.sixwands.languagemirror` (adjust to match your bundle ID)

3. **Set Target Memberships**
   - SharedImport files → Both main app AND extension
   - ShareExtension files → Extension only

4. **Update Info.plist path** for extension target
   - Point to: `2025-09-13/ShareExtension/Info.plist`

5. **Build and test**
   - Build main app
   - Test sharing from Voice Memos

## User Experience Flow

### Before (Current)
1. Open LanguageMirror
2. Tap Import → Import from Files
3. Navigate: Files → On My iPhone → Voice Memos
4. Select file
5. Wait for import

### After (With Share Extension)
1. Open Voice Memos
2. Tap Share button on any recording
3. Select LanguageMirror
4. Done! ✨
5. Next time app opens, file is automatically imported

## Key Configuration Notes

- **App Group** is required for file transfer between extension and app
- **Both targets** must use the same App Group identifier
- **Test on physical device** for best results (simulators may have limitations)
- If you change the App Group identifier, update `SharedImportManager.appGroupIdentifier`

## Architecture

```
Voice Memos App
    ↓ [User taps Share]
Share Extension (ShareViewController)
    ↓ [Copies file to shared container]
App Group Shared Container
    ↓ [App checks on launch]
Main App (AppCoordinator)
    ↓ [Imports via ImportService]
Library (Track appears)
```

## Troubleshooting Quick Tips

- **Extension not showing?** → Check Info.plist activation rules
- **Files not importing?** → Verify App Group identifiers match exactly
- **Build errors?** → Check target memberships for SharedImport files
- **App Group errors?** → Free Apple Developer accounts may not support App Groups

See `SHARE_EXTENSION_SETUP.md` for complete troubleshooting guide.

