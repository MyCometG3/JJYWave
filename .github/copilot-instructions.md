# JJYWave

JJYWave is an experimental macOS Cocoa application written in Swift that generates JJY time signal waves (40/60 kHz) and test tones (13.333/15.000/20.000 kHz). This is an educational/verification tool for understanding JJY long-wave time signals.

**Always reference these instructions first and fallback to search or bash commands only when you encounter unexpected information that does not match the info here.**

## Critical Requirements

**⚠️ MACOS ONLY**: This application REQUIRES macOS and Xcode. It CANNOT be built on Linux, Windows, or without Xcode installed.

## Working Effectively

### Prerequisites
- macOS (Apple Silicon or Intel)
- Latest version of Xcode installed
- No additional dependencies or package managers required

### Building and Running
- **NEVER CANCEL**: Initial Xcode build may take 5-10 minutes depending on system. NEVER CANCEL builds. Set timeout to 20+ minutes.
- **EXACT STEPS**:
  1. Open Xcode application
  2. File → Open → Select `JJYWave.xcodeproj`
  3. Wait for project to load (may take 1-2 minutes)
  4. Select appropriate development team in Signing & Capabilities if prompted
  5. Choose target device (typically "My Mac")
  6. Build: ⌘B (Cmd+B) - takes 2-10 minutes, NEVER CANCEL
  7. Run: ⌘R (Cmd+R) - builds and launches application
- **Build time estimate**: 2-10 minutes for clean build. NEVER CANCEL builds in progress.
- **CRITICAL**: No command-line alternatives exist. Must use Xcode IDE.

### Common Xcode Commands (Keyboard Shortcuts)
- Clean Build Folder: ⌘⇧K (Cmd+Shift+K)
- Build: ⌘B (Cmd+B)
- Run: ⌘R (Cmd+R)
- Stop: ⌘. (Cmd+Period)
- Show Console: ⌘⇧Y (Cmd+Shift+Y)
- Show Navigator: ⌘1 (Cmd+1)
- Show Inspector: ⌘⌥1 (Cmd+Option+1)

### Project Structure
```
JJYWave/
├── .github/                    # GitHub configuration (this file)
├── Assets.xcassets/           # App icons and images
├── Base.lproj/                # Base localization (English)
├── ja.lproj/                  # Japanese localization
├── source/                    # Swift source code
│   ├── AppDelegate.swift      # App lifecycle
│   ├── ViewController.swift   # Main UI controller
│   ├── JJYAudioGenerator.swift # Core audio generation
│   └── JJYAudioGenerator+*.swift # Extensions for audio generation
├── JJYWave.xcodeproj/         # Xcode project file
├── JJYWave.entitlements       # App sandbox entitlements
├── Localizable.xcstrings      # Localization strings catalog
├── LICENSE.txt                # MIT License
└── README.md                  # Project documentation
```

### Testing and Validation Scenarios

**CRITICAL**: Since there are no automated tests, you MUST manually validate changes by running the application and testing functionality.

#### After Making Code Changes:
1. **Build Validation**: 
   - Clean build: ⌘⇧K (Cmd+Shift+K) then ⌘B (Cmd+B)
   - NEVER CANCEL: Allow 5-15 minutes for build completion
   - Fix any compiler errors before proceeding

2. **Functional Testing** (MANDATORY after any changes):
   - Launch the app: ⌘R (Cmd+R)
   - **UI Testing**: Verify all UI elements display correctly
   - **Audio Generation Testing**:
     - Click "Start Generation" button
     - Verify status changes to "Generating"
     - Test frequency switching (13.333, 15.000, 20.000, 40.000, 60.000 kHz)
     - Verify that 40/60 kHz switching is blocked while generating
     - Click "Stop Generation" and verify it stops
   - **Localization Testing**: Test both English and Japanese localizations
   - **Time Display**: Verify current time updates every second

3. **Audio Hardware Testing** (if possible):
   - Connect audio output to verify signal generation
   - Use audio analysis tools to confirm correct frequencies
   - **⚠️ CAUTION**: Use appropriate volume levels for hearing safety

#### Validation Requirements:
- **ALWAYS** test the complete start/stop cycle
- **ALWAYS** test frequency switching in both directions
- **ALWAYS** verify UI updates correctly reflect application state
- Take screenshots of the running application to document changes

### No Command-Line Building
- **DO NOT** attempt to use `swift build`, `xcodebuild`, or other command-line tools
- **DO NOT** try to create Package.swift or other non-Xcode build files
- This project is Xcode-only and must be built through the Xcode IDE

### Localization
- Strings are managed in `Localizable.xcstrings` (Xcode Strings Catalog)
- Supports English (en) and Japanese (ja)
- When adding new UI text, always add localization entries
- Test both language variants after string changes

### Key Source Files
- `ViewController.swift`: Main UI logic and user interactions
- `JJYAudioGenerator.swift`: Core audio generation and JJY signal creation
- `JJYAudioGenerator+FrameBuilder.swift`: JJY time code frame construction
- `JJYAudioGenerator+Configuration.swift`: Audio configuration management
- `AppDelegate.swift`: Application lifecycle management

### Audio Generation Details
- Uses AVFoundation and CoreAudio frameworks
- Generates sine waves at specified frequencies
- JJY signals include amplitude modulation for time codes
- Test tones are pure sine waves
- Audio engine runs at 96 kHz sample rate by default

### Common Development Tasks

#### Adding New Features:
1. Make changes in appropriate Swift files
2. Update localization strings if UI text is added
3. Build and test thoroughly using validation scenarios above
4. **NEVER** skip the manual testing phase

#### Debugging Audio Issues:
1. Check Console.app for audio-related log messages
2. Verify audio permissions in System Preferences
3. Test with different audio output devices
4. Use Audio MIDI Setup to verify system audio configuration

#### Code Style:
- Follow existing Swift code style in the project
- Use meaningful variable names consistent with existing code
- Comment complex audio generation algorithms
- Maintain separation between UI logic and audio generation

### Specific Implementation Details

#### Audio Generation Architecture:
- Core audio generation in `JJYAudioGenerator.swift` using AVFoundation
- Real-time audio buffer generation with 96 kHz sample rate
- Time-synchronized frame building for JJY time code
- BCD encoding for time/date information in JJY frames

#### UI Implementation:
- Main interface in `Main.storyboard` (Interface Builder)
- Dynamic segmented control creation in `ViewController.swift`
- Localized strings managed through `Localizable.xcstrings` Strings Catalog
- Auto Layout constraints for responsive design

#### Important Code Patterns:
- Audio operations use dispatch queues for thread safety
- UI updates must be dispatched to main queue: `DispatchQueue.main.async { ... }`
- Audio engine lifecycle managed through start/stop methods
- Configuration changes validated before application

### Limitations
- **macOS Only**: Cannot build or run on other platforms
- **No Automated Tests**: Manual validation is required for all changes
- **Audio Hardware Dependent**: Some features require audio output devices
- **Xcode Required**: IDE-based development only

### Performance Notes
- Audio generation is real-time and CPU-intensive
- UI updates must be dispatched to main queue
- Audio buffer generation happens on background queues
- Monitor system resources during extended audio generation

## Troubleshooting

### Build Failures:
- Ensure Xcode is up to date
- Clean build folder: ⌘⇧K (Cmd+Shift+K)
- Check code signing configuration
- Verify all source files are included in target

### Runtime Issues:
- Check audio permissions in System Preferences
- Verify no other audio applications are blocking exclusive access
- Monitor Console.app for error messages
- Test with built-in audio output first

### Localization Issues:
- Rebuild after changing Localizable.xcstrings
- Test switching system language in System Preferences
- Verify string keys match between code and catalog

Remember: This is an experimental project focused on JJY time signal generation. Always follow local regulations regarding radio frequency generation and audio output levels.

## Common Tasks - Quick Reference

The following are outputs from frequently run commands and commonly needed information. Reference them instead of running bash commands to save time.

### Repository Root Structure
```
ls -la [repo-root]
total 56
drwxr-xr-x 8 runner docker 4096 Aug 23 12:04 .
drwxr-xr-x 3 runner docker 4096 Aug 23 12:03 ..
drwxr-xr-x 7 runner docker 4096 Aug 23 12:04 .git
-rw-r--r-- 1 runner docker  518 Aug 23 12:04 .gitignore
drwxr-xr-x 4 runner docker 4096 Aug 23 12:04 Assets.xcassets
drwxr-xr-x 2 runner docker 4096 Aug 23 12:04 Base.lproj
-rw-r--r-- 1 runner docker  310 Aug 23 12:04 JJYWave.entitlements
drwxr-xr-x 3 runner docker 4096 Aug 23 12:04 JJYWave.xcodeproj
-rw-r--r-- 1 runner docker 1066 Aug 23 12:04 LICENSE.txt
-rw-r--r-- 1 runner docker 6603 Aug 23 12:04 Localizable.xcstrings
-rw-r--r-- 1 runner docker 2285 Aug 23 12:04 README.md
drwxr-xr-x 2 runner docker 4096 Aug 23 12:04 ja.lproj
drwxr-xr-x 2 runner docker 4096 Aug 23 12:04 source
```

### Source Directory Contents
```
ls source/
AppDelegate.swift
JJYAudioGenerator+AudioBufferFactory.swift
JJYAudioGenerator+Configuration.swift
JJYAudioGenerator+FrameBuilder.swift
JJYAudioGenerator+Index.swift
JJYAudioGenerator+Morse.swift
JJYAudioGenerator.swift
ViewController.swift
```

### Key Configuration Files
- **Project**: `JJYWave.xcodeproj/project.pbxproj` (Xcode project settings)
- **Entitlements**: `JJYWave.entitlements` (App sandbox permissions)
- **Localization**: `Localizable.xcstrings` (String translations)
- **Assets**: `Assets.xcassets/` (App icons and images)
- **Interface**: `Base.lproj/Main.storyboard` (UI layout)

### System Requirements Check
- macOS required (cannot build on Linux/Windows)
- Xcode required (cannot use command-line tools)
- No Package.swift (not a Swift Package Manager project)
- No Makefile or build scripts (Xcode-only project)