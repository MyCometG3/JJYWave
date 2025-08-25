# JJYWave — Copilot Instructions

JJYWave is an experimental macOS Cocoa application written in Swift that generates JJY time signal waves (40/60 kHz) and test tones (13.333 / 15.000 / 20.000 kHz). This is an educational/verification project.

Always reference these instructions first and fall back to searching only when you encounter unexpected information that does not match the info here.

## Critical Requirements

- macOS only
- Xcode required (build via Xcode IDE)
- Do not add SPM or command-line build flows for this project

## Prerequisites
- macOS (Apple Silicon or Intel)
- Latest Xcode installed
- No external package managers required

## Building and Running
Steps:
1) Open Xcode
2) File → Open → select `JJYWave.xcodeproj`
3) Wait for indexing to finish
4) Set Signing if prompted
5) Select target device “My Mac”
6) Build: ⌘B
7) Run: ⌘R

Notes:
- Use the Xcode IDE; command-line builds (`swift build`, `xcodebuild`) are not supported for this project.

## Common Xcode Shortcuts
- Clean Build Folder: ⌘⇧K
- Build: ⌘B
- Run: ⌘R
- Stop: ⌘.
- Show Console: ⌘⇧Y
- Show Navigator: ⌘1
- Show Inspector: ⌘⌥1

## Project Structure (root)
```
JJYWave/
├── .github/                 # This file
├── App/                     # UI layer
├── JJYKit/                  # Core audio + frame builder logic
├── Assets.xcassets/
├── Base.lproj/              # Interface (Main.storyboard)
├── mul.lproj/               # Strings Catalog locale (managed by Xcode)
├── JJYWave.xcodeproj/
├── JJYWave.entitlements
├── Localizable.xcstrings
├── Tests/                   # Test docs and notes
├── JJYWaveTests/            # Unit/integration tests
├── JJYWaveTests.xctestplan
├── LICENSE.txt
├── README.md
├── .gitignore
└── validate_project.py
```

## Testing and Validation

Automated tests exist and must pass.

1) Build Verification
- Clean: ⌘⇧K → Build: ⌘B
- Fix compiler errors before proceeding

2) Automated Tests (mandatory)
- Run all tests with ⌘U
- Target: JJYWaveTests (uses `JJYWaveTests.xctestplan`)
- See `Tests/README.md` for coverage details (frame structure, symbol duty cycle, frequency accuracy, scheduler timing, audio engine behavior, performance)

3) Manual Functional Testing
- Launch with ⌘R
- UI: all controls render and update state correctly
- Audio:
  - “Start Generation” toggles to “Generating”
  - Switch among 13.333 / 15.000 / 20.000 / 40.000 / 60.000 kHz
  - 40/60 kHz switching is blocked while generating
  - “Stop Generation” halts output
- Localization: verify English and Japanese
- Time label: ticks once per second

4) Optional Audio Hardware Check
- Verify audible output and analyze frequencies with appropriate tools
- Keep volume at safe levels

Validation requirements:
- Always test start/stop cycle
- Always test frequency switching both directions
- Ensure UI reflects engine state

## Localization
- Managed in `Localizable.xcstrings` (Strings Catalog)
- Supports English (en) and Japanese (ja)
- Test both languages after changes
- `mul.lproj/` is Xcode-managed for the Strings Catalog locale data

## Key Areas (by directory)
- App/: Application UI, controllers, lifecycle
- JJYKit/: Core audio generation and JJY time code frame building
- Base.lproj/: Interface (Main.storyboard)
- JJYWaveTests/: Unit and integration tests
- Tests/: Test documentation and guidance

## Audio Generation Details
- Uses AVFoundation/CoreAudio
- Sine wave generation at specified frequencies
- JJY signals use amplitude modulation for time code
- Typical sample rate: 96 kHz (per project settings)

## Common Development Tasks

Adding features
1. Modify appropriate Swift files (UI in App/, core in JJYKit/)
2. Add localized strings if UI changes
3. Build (⌘B), run tests (⌘U), then manual validation (⌘R)

Debugging audio
1. Check Xcode console and Console.app logs
2. Verify audio permissions
3. Try different output devices (Audio MIDI Setup)
4. Confirm system sample rate configuration

Code style
- Follow existing Swift conventions
- Use meaningful names consistent with current code
- Comment complex audio generation logic
- Keep UI and audio concerns separated

## Limitations
- macOS only
- Requires Xcode
- Some validations require audio output devices

## Performance Notes
- Audio runs in real time; avoid blocking on audio threads
- UI updates must be on main queue
- Buffer generation runs on background queues
- Monitor resource usage during extended runs

## Troubleshooting

Build
- Update Xcode
- Clean build folder (⌘⇧K)
- Check code signing
- Ensure files are in the correct targets

Runtime
- Check audio permissions
- Ensure no other app monopolizes audio output
- Use built-in output for baseline tests
- Review logs in Console.app

Localization
- Rebuild after editing `Localizable.xcstrings`
- Test language switching in System Settings
- Ensure string keys match