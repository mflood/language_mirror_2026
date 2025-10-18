# Embedded Packs Refactoring

## Overview
Refactored the embedded pack system to split the large `sample_bundle.json` file into individual pack files and added a user interface for selecting which pack to import.

## Problem
The original `sample_bundle.json` file contained all 4 packs (157 total tracks) in a single file:
- KBS Korean News (3 tracks)
- Korean Culture 1 (40 tracks)
- Vitamin 1 (93 tracks)
- Integrated Korean Beginning 1 (21 tracks)

This made the file huge and forced users to import all packs at once, even if they only wanted one.

## Solution

### 1. New File Structure
Created a new directory structure for embedded packs:
```
Resources/embedded_packs/
├── packs_manifest.json              # Lists all available packs
├── pack_kbs_news.json               # KBS News pack (3 tracks)
├── pack_culture_1.json              # Korean Culture pack (40 tracks)
├── pack_vitamin_1.json              # Vitamin 1 pack (93 tracks)
└── pack_integrated_korean_beg_1.json # Integrated Korean pack (21 tracks)
```

### 2. Pack Manifest Structure
The `packs_manifest.json` file contains minimal metadata about each pack:
```json
{
  "version": "1.0",
  "packs": [
    {
      "id": "urn:pack-app:com.six.wands.pack.kbs.news",
      "title": "Demo Pack - KBS Korean News",
      "description": "3 Korean news clips from KBS",
      "filename": "pack_kbs_news.json",
      "trackCount": 3,
      "languageCode": "ko"
    },
    ...
  ]
}
```

### 3. Individual Pack Structure
Each pack file contains the full pack data including tracks and segments:
```json
{
  "id": "urn:pack-app:com.six.wands.pack.kbs.news",
  "title": "Demo Pack - KBS Korean News",
  "audioSubdirectory": "audio_files/kbc",
  "tracks": [
    {
      "title": "8373739",
      "filename": "8373739.mp3",
      "segment_maps": [ ... ]
    },
    ...
  ]
}
```

### 4. New Data Structures
Added the following data structures:

**EmbeddedPacksManifest**: List of available packs
```swift
struct EmbeddedPacksManifest: Codable {
    let version: String
    let packs: [EmbeddedPackMetadata]
}
```

**EmbeddedPackMetadata**: Minimal metadata for displaying pack list
```swift
struct EmbeddedPackMetadata: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let filename: String
    let trackCount: Int
    let languageCode: String?
}
```

**EmbeddedBundlePack**: Added `audioSubdirectory` field
```swift
struct EmbeddedBundlePack: Codable {
    let id: String
    let title: String
    let author: String?
    let filename: String?
    let audioSubdirectory: String? // NEW: subdirectory where audio files are located
    let tracks: [EmbeddedBundleTrack]
}
```

### 5. Updated Protocol
Extended `EmbeddedBundleManifestLoader` protocol:
```swift
public protocol EmbeddedBundleManifestLoader: Sendable {
    /// Load the list of available embedded packs
    func loadAvailablePacks() async throws -> [EmbeddedPackMetadata]
    
    /// Load a specific pack by its ID
    func loadPack(packId: String) async throws -> EmbeddedBundlePack
    
    /// @deprecated Use loadAvailablePacks() and loadPack(packId:) instead
    func loadEmbeddedSample() async throws -> EmbeddedBundleManifest
}
```

### 6. New UI Component
Created `PackSelectionViewController`:
- Displays a list of available embedded packs
- Shows pack title, description, and track count
- Allows user to select a single pack to import
- Confirms selection before importing

### 7. Updated Import Flow
1. User taps "Install free sample bundle" in ImportViewController
2. PackSelectionViewController appears showing all available packs
3. User selects a pack
4. Confirmation dialog appears
5. Single pack is imported (not all packs)

### 8. Import Source Update
Added new import source case:
```swift
enum ImportSource {
    ...
    case embeddedSample  // @deprecated - imports all packs
    case embeddedPack(packId: String)  // NEW: import single pack
}
```

### 9. Refactored Import Driver
Split `ImportEmbeddedSampleDriver.run()` into reusable methods:
- `run()`: Import all packs (backward compatibility)
- `runSinglePack(packId:)`: Import a specific pack
- `importPack(_:library:)`: Private helper to import one pack

## Benefits

1. **Better UX**: Users can choose which pack to import instead of getting all packs
2. **Faster Imports**: Importing a single pack is much faster than all 4 packs
3. **Reduced Initial Load**: First-time users aren't overwhelmed with 157 tracks
4. **Better Organization**: Each pack is in its own file, easier to maintain
5. **Extensible**: Easy to add new packs without modifying existing files
6. **Backward Compatible**: Old `loadEmbeddedSample()` method still works

## Audio File Organization

Audio files are organized by subdirectory:
- `audio_files/kbc/` - KBS News audio files
- `audio_files/culture_1/` - Korean Culture audio files
- `audio_files/vitamin_1/` - Vitamin 1 audio files
- `audio_files/integrated_korean_beg_1_textbook/` - Integrated Korean audio files

The `audioSubdirectory` field in each pack ensures audio files are loaded from the correct location.

## Files Modified

### New Files
- `Resources/embedded_packs/packs_manifest.json`
- `Resources/embedded_packs/pack_kbs_news.json`
- `Resources/embedded_packs/pack_culture_1.json`
- `Resources/embedded_packs/pack_vitamin_1.json`
- `Resources/embedded_packs/pack_integrated_korean_beg_1.json`
- `Screens/PackSelectionViewController.swift`

### Modified Files
- `Services/ImportService.swift` - Added new data structures
- `Services/ImportServiceLite.swift` - Handle `.embeddedPack` case
- `Services/ImportServiceFeatures/ImportEmbeddedSample/EmbeddedBundleManifestLoader.swift` - New protocol methods
- `Services/ImportServiceFeatures/ImportEmbeddedSample/IOS18SampleImporter.swift` - Implement new methods
- `Services/ImportServiceFeatures/ImportEmbeddedSample/ImportEmbeddedSampleDriver.swift` - Refactored import logic
- `Services/ImportServiceFeatures/ImportEmbeddedSample/MockManifestLoader.swift` - Implement new methods
- `Screens/ImportViewController.swift` - Show pack selection UI

## Testing Considerations

When testing:
1. Verify pack selection screen appears with all 4 packs
2. Verify each pack can be imported individually
3. Verify audio files load correctly from subdirectories
4. Verify pack metadata (title, description, track count) displays correctly
5. Verify confirmation dialog appears before import
6. Verify import progress and completion messages work

## Future Enhancements

Possible future improvements:
1. Show pack download size in the selection screen
2. Allow importing multiple packs at once (checkboxes)
3. Add pack preview (show first few tracks)
4. Add pack categories/tags for filtering
5. Support for remote pack catalogs
6. Pack update mechanism for existing packs

