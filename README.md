# ClipboardMac

A macOS clipboard preview tool for real-time monitoring and previewing clipboard content.

## Features

- **Real-time Monitoring**: Automatically detects clipboard changes and updates content in real-time
- **Multi-type Support**: Supports text, images, HTML, PDF, file paths, and more
- **Sidebar List**: Displays clipboard item types and timestamps with color-coded labels for easy identification
- **Content Preview**: Preview selected items on the right panel
  - Text: Display content directly
  - Images: Show image preview
  - HTML: Display both rendered webpage and source code
  - Files: Show file paths
- **Smart Selection**: Maintains current selection when copying new content, automatically selects first item if selection no longer exists

## Supported Types

| Type | Description |
|------|-------------|
| Plain Text | Plain text content |
| HTML Document | HTML documents (preview + source) |
| Rich Text (RTF) | Rich text format |
| PNG/TIFF/Image | Image files |
| PDF Document | PDF documents |
| Web URL | Web links |
| File Reference | File references |
| JSON/XML | Data formats |
| Source Code | Source code |
| Video/Audio | Audio/video files |
| Others | Dynamic types, internal data, etc. |

## How to Run

### Using Script (Recommended)

```bash
cd /Users/congduan/Desktop/code/_vibe_coding_/ClipboardMac
./run.sh
```

### Using Xcode

1. Open `ClipboardMac.xcodeproj`
2. Select target device (My Mac)
3. Click Run button (Cmd+R)

### Manual Build

```bash
xcodebuild -project ClipboardMac.xcodeproj -scheme ClipboardMac -configuration Debug build
open ~/Library/Developer/Xcode/DerivedData/ClipboardMac-*/Build/Products/Debug/ClipboardMac.app
```

## Project Structure

```
ClipboardMac/
├── ClipboardMac.xcodeproj      # Xcode project
├── ClipboardMac/
│   ├── AppDelegate.swift       # App entry point
│   ├── ContentView.swift       # Main UI implementation
│   ├── Assets.xcassets/        # Asset files
│   └── Info.plist             # App configuration
├── project.yml                 # XcodeGen configuration
├── run.sh                      # Build and run script
└── .gitignore                  # Git ignore file
```

## Tech Stack

- **Swift 5.9**
- **SwiftUI** - User interface
- **AppKit** - macOS native features (NSPasteboard, NSImage)
- **WebKit** - HTML preview
- **XcodeGen** - Project generation

## Usage

1. After launching the app, the left sidebar displays all current clipboard items
2. Click any item to preview its content on the right
3. The list automatically updates when copying new content
4. Selection is maintained and preview content refreshes automatically

## Notes

- Requires macOS 13.0 or later
- First launch may require allowing the app in System Settings
- Some internal types (e.g., CorePasteboard) display placeholder information only
