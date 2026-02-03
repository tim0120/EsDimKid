# EsDimKid

A macOS menu bar utility that dims inactive windows, helping you focus on your current task.

## Features

### Core Features
- Auto-dim inactive windows with adjustable intensity (0-100%)
- Customizable dimming color
- Menu bar control with quick access to settings
- Global keyboard shortcut (default: ⌃⌥⌘D)
- Launch at login support

### Highlight Modes
- **Single Window**: Only the frontmost window is visible
- **All App Windows**: All windows of the active app are visible

### Multi-Display Support
- **Highlight on each display**: Each monitor shows its frontmost window undimmed
- **Dim secondary displays**: Only the display with focus is active

### Advanced Features
- **fn key temporary disable**: Hold fn to temporarily reveal all windows (great for drag & drop)
- **Desktop auto-reveal**: Dimming disables when clicking on desktop
- **App exceptions**: Whitelist apps that shouldn't trigger dimming
- **Light/Dark mode settings**: Different intensity/color per appearance
- **Reduce Motion support**: Respects accessibility settings

### macOS Integration
- **Shortcuts app**: Toggle, enable, disable, set intensity/color
- **Focus Filters**: Auto-configure based on Focus mode
- **Smooth animations**: Configurable fade duration

## Requirements

- macOS 14.0 (Sonoma) or later
- Accessibility permission (System Settings → Privacy & Security → Accessibility)

## Building

1. Open `EsDimKid.xcodeproj` in Xcode
2. Build and run (⌘R)
3. Grant Accessibility permissions when prompted

## Project Structure

```
EsDimKid/
├── EsDimKid.xcodeproj/
└── EsDimKid/
    ├── App/
    │   ├── EsDimKidApp.swift      # Main app entry point
    │   ├── AppDelegate.swift       # App lifecycle, coordinator
    │   └── AppIntents.swift        # Shortcuts & Focus Filters
    ├── Views/
    │   ├── MenuBarView.swift       # Menu bar popover UI
    │   └── SettingsView.swift      # Settings window (tabs)
    ├── Managers/
    │   ├── DimmingManager.swift    # Central state coordinator
    │   ├── WindowObserver.swift    # Accessibility API tracking
    │   ├── OverlayWindowController.swift  # Dimming overlay windows
    │   ├── HotkeyManager.swift     # Global shortcuts & fn key
    │   └── DesktopObserver.swift   # Desktop click detection
    ├── Models/
    │   └── Settings.swift          # Data models & enums
    ├── Resources/
    │   └── Assets.xcassets/        # App icons
    ├── Info.plist
    └── EsDimKid.entitlements
```

## Architecture

- **SwiftUI** for UI (MenuBarExtra, Settings window)
- **AppKit** for overlay windows and Accessibility API
- **Combine** for reactive state management
- **App Intents** for Shortcuts/Focus Filters integration

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌃⌥⌘D | Toggle dimming |
| fn (hold) | Temporarily disable dimming |

## Known Limitations

- Overlay appears in screenshots (macOS limitation)
- Some Electron apps may report incorrect window bounds
- Fullscreen apps require special handling

## License

Personal use. Contact for commercial licensing.

---

*Name inspired by [EsDeeKid](https://www.youtube.com/watch?v=UTHLV3zYFJ4) - Chicago drill legend. RIP.*
