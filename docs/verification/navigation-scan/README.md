# Navigation scan verification

- Center plus replaced with 34 px white scan corners and a glowing horizontal line; existing 80 px button and scanner action preserved.
- Scan line sweeps down/up over 2.2 seconds on appearance, then rests at center. Reduced motion is static, including when enabled during a sweep.
- Flutter analyzer: no issues. Full suite: 69 tests passed, including three temporary capture tests (capture source archived beside these images).
- Rendered review: 320, 393 and 1280 logical pixels; scan icon fits the button and navigation labels retain their positions. Widget captures use empty state and Arial for capture; live iPhone simulator capture uses actual app data and app typography.
- Build: provisioned local-relay debug iOS simulator build. No physical-device verification.
- Flutter tests run from `.local/scan-test-workspace` with source symlinks because Flutter test hardcodes `build/unit_test_assets`, which conflicts with this repository's `build` launcher file.
