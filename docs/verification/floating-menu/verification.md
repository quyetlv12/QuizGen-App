# Floating menu verification — 13/11/2026

Reference: `../../design/references/floating-menu.png`.

- White floating pill with side insets, curved center recess, raised scan button and mint selected tab. Existing scanner action, tab callbacks, scan animation and reduced-motion behavior retained.
- Manual visual review at 320×852, 393×852 and 1280×900; labels fit on one line, controls remain inside bounds. Widget captures enable real shadows; Arial and empty local state are capture-only substitutes.
- `iphone.png`: provisioned debug build installed and launched on iPhone 17 iOS Simulator. Actual app font and loaded data verified; soft green shadow and central recess reviewed against reference.
- `flutter analyze --no-pub`: no issues. Full suite: 73 passed including temporary capture cases. Shadow-enabled capture rerun: 3 passed. `git diff --check`: passed.
- Existing Material icons and app typography reused because source font/icon assets were not supplied. No physical-device camera verification or measured fidelity percentage.
- Capture test archived as `capture_test.dart.example`; tests ran via `.local/scan-test-workspace` because root `build` is an executable file.

## Shadow and outline refinement
- Replaced platform elevation shadow with two explicitly blurred shadows following the same custom path, and added a thin mint outline to reveal the U-shaped center recess on white.
- Updated widget captures at 320/393/1280 px, with real shadow rendering enabled. `iphone-shadow-refined.png` records the installed simulator build.
- Analyzer: no issues. Focused capture/navigation/app suite: 15 passed. Simulator debug build succeeded. Scan callback, animation, small-screen layout and scanner import flow remain covered.

## Transparent navigation backdrop — 14/11/2026
- `iphone-transparent-background.png`: provisioned debug build installed/launched on iPhone 17 Simulator; live data shows through the menu gaps and underneath the floating bar.
- Analyzer: no issues. Focused app/navigation suite: 13 passed, including viewport extension and final-content clearance. Results review action remains reachable after scrolling above the overlay; scanner/import tests pass.
- Existing small-phone/tablet layout checks pass. No new desktop screenshot or physical-device verification for this adjustment.
