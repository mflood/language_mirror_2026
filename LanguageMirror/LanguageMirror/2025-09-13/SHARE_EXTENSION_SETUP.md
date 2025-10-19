# Share Extension Setup Guide

## Overview
This guide will walk you through the Xcode configuration steps needed to enable the Share Extension for LanguageMirror.

## Prerequisites
All code files have been created. You now need to configure the Xcode project to build and run the Share Extension.

---

## Step 1: Create Share Extension Target

1. **Open your Xcode project**
   - Open the `.xcodeproj` file in Xcode

2. **Add Share Extension Target**
   - In Xcode, go to **File → New → Target**
   - Select **Share Extension** (under iOS → Application Extension)
   - Click **Next**
   
3. **Configure Target**
   - **Product Name**: `LanguageMirrorShare`
   - **Language**: Swift
   - **Project**: Your LanguageMirror project
   - Click **Finish**
   
4. **Activate Scheme** (if prompted)
   - Click **Activate** when Xcode asks if you want to activate the scheme

5. **Delete Default Files**
   - Xcode will create `ShareViewController.swift` and `MainInterface.storyboard`
   - **Delete both files** (Move to Trash)
   - We're using the programmatic UI files already created

---

## Step 2: Add Custom Files to Targets

### Add SharedImport Files to BOTH Targets

1. **Locate the SharedImport folder** in your project navigator
   - It contains `SharedImportManager.swift` and `SharedImportModels.swift`

2. **For each file**, select it and check **Target Membership** in File Inspector (right sidebar):
   - ☑️ LanguageMirror (main app)
   - ☑️ LanguageMirrorShare (extension)

### Add ShareExtension Files to Extension Target

1. **Locate the ShareExtension folder** in your project navigator
   - It contains `ShareViewController.swift` and `Info.plist`

2. **For ShareViewController.swift**:
   - Target Membership: ☑️ LanguageMirrorShare ONLY

3. **Replace Extension's Info.plist**:
   - Select the LanguageMirrorShare target in Project Settings
   - Under "Build Settings", search for "Info.plist File"
   - Update the path to: `2025-09-13/ShareExtension/Info.plist`

---

## Step 3: Configure App Groups

### Main App Target

1. **Select LanguageMirror target** in Project Settings
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups**
5. Click **+** under App Groups
6. Enter: `group.com.sixwands.languagemirror`
   - ⚠️ **IMPORTANT**: Adjust the group identifier to match your bundle ID pattern
   - If your bundle ID is `com.yourcompany.languagemirror`, use `group.com.yourcompany.languagemirror`
7. ☑️ Check the box next to the group to enable it

### Share Extension Target

1. **Select LanguageMirrorShare target** in Project Settings
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Add **App Groups**
5. Click **+** under App Groups
6. Enter the **SAME** group identifier: `group.com.sixwands.languagemirror`
7. ☑️ Check the box next to the group to enable it

### Update Code if Necessary

If you used a different App Group identifier, update this line in `SharedImport/SharedImportManager.swift`:

```swift
static let appGroupIdentifier = "group.com.sixwands.languagemirror"
```

Change it to match your chosen identifier.

---

## Step 4: Configure Signing

### Main App
1. Select **LanguageMirror target**
2. **Signing & Capabilities** tab
3. Ensure **Team** is selected
4. **Bundle Identifier** should be set (e.g., `com.sixwands.languagemirror`)

### Share Extension
1. Select **LanguageMirrorShare target**
2. **Signing & Capabilities** tab
3. Ensure **Team** is selected (same as main app)
4. **Bundle Identifier** will be auto-generated as `com.sixwands.languagemirror.LanguageMirrorShare`

---

## Step 5: Verify Build Settings

### LanguageMirrorShare Target

1. Select target, go to **Build Settings**
2. Search for **"iOS Deployment Target"**
   - Ensure it matches your main app (iOS 16.0 or later recommended)

---

## Step 6: Build and Run

### Build Main App

1. Select **LanguageMirror scheme** at the top
2. Select your device or simulator
3. Click **Build** (⌘B) to verify no errors
4. Click **Run** (⌘R) to install on device/simulator

### Build Share Extension

The extension is automatically included when you build the main app. No separate build needed!

---

## Step 7: Testing

### Test on Physical Device (Recommended)

Share Extensions work best on physical devices. Simulators may have limitations.

1. **Install the app** on your physical iPhone/iPad
2. **Open Voice Memos app**
3. **Tap a voice memo**
4. **Tap the Share button** (square with arrow)
5. **Look for "LanguageMirror"** in the share sheet
   - If not visible, tap **More** and enable it
6. **Tap LanguageMirror**
7. You should see the import progress UI
8. The file should be queued for import
9. **Open LanguageMirror app**
10. The app should automatically import the file and show it in the Library

### Test from Files App

1. Open **Files app**
2. Navigate to any audio file
3. Tap **Share button**
4. Select **LanguageMirror**
5. Verify import works

---

## Troubleshooting

### "No such module" errors
- Ensure SharedImport files are added to both target memberships
- Clean build folder: **Product → Clean Build Folder** (⇧⌘K)
- Rebuild

### App Group not working
- Verify both targets have the **exact same** App Group identifier
- Verify the group is **checked/enabled** in both targets
- If using a free Apple Developer account, App Groups might not be supported

### Share sheet doesn't show LanguageMirror
- Ensure Info.plist activation rules are correct
- Try scrolling in the share sheet or tapping "More"
- Rebuild and reinstall the app

### Extension crashes immediately
- Check Console app for crash logs
- Verify ShareViewController is set as NSExtensionPrincipalClass in Info.plist
- Ensure all imports (UIKit, UniformTypeIdentifiers) are available

### Files not importing
- Check that main app has proper file system permissions
- Verify SharedImportManager.appGroupIdentifier matches your App Group
- Check Console app for error messages

---

## Architecture Notes

### How It Works

1. **User shares audio file** → Share Extension receives it
2. **Extension copies file** → App Group shared container
3. **Extension adds metadata** → Pending imports queue (JSON)
4. **Extension completes** → User returns to home screen
5. **User opens main app** → AppCoordinator checks for pending imports
6. **App imports files** → Using normal ImportService
7. **App cleans up** → Removes files from shared container
8. **User sees tracks** → Library is automatically selected

### File Locations

- **Main App Data**: `Application Support/LanguageMirror/`
- **Shared Container**: `Shared/AppGroup/group.com.sixwands.languagemirror/`
- **Pending Queue**: `SharedContainer/pending_imports.json`
- **Shared Files**: `SharedContainer/SharedFiles/*.m4a`

---

## What's Next?

After completing this setup:

1. ✅ Users can share from Voice Memos with one tap
2. ✅ Users can share from Files, Safari, or other apps
3. ✅ Files are automatically imported when app launches
4. ✅ No manual navigation to Files → Voice Memos needed

The Share Extension provides a much better UX than the document picker approach!

---

## Questions or Issues?

If you encounter issues:
1. Check Xcode console for error messages
2. Verify all steps in this guide were completed
3. Ensure App Group identifiers match exactly
4. Test on a physical device if possible

