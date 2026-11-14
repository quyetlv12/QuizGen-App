# Cá nhân — 14/11/2026

Reference: `references/profile-user-reference.png`, supplied by the user. This is the authoritative visual reference; no generated concept replaces it.

Direction: friendly study companion; white/mint background, green account avatar, existing robot above the account card, clear profile name/email/role, full-width logout, three navigation rows and draft-storage note. Retain existing `theme.dart` colors, platform typography, `BrandBar`, floating navigation and AI launcher. The phone frame/status bar in the supplied image belong to the device.

Layout: one scrollable column, existing 18 px horizontal insets and 720 px maximum width; 104 px illustrated heading, 24 px account-card corners and 48 px logout target. Long names/emails wrap and small screens scroll. Existing Material icons and robot asset substitute for illustration assets not supplied separately. No new image generation or dependencies.

Acceptance: actual account and counts render; document/quiz rows keep existing destinations; logout keeps existing account behavior; settings displays real connection state and refresh action; 320 px at 1.3 text scaling, 393 px and wide layout have no overflow. The reference's edit icon is omitted because profile editing has no API. Settings describes available behavior rather than advertising unsupported preferences.

Design review: installed `design-review` is a catalogue entry without the upstream audit runner; use manual inspection of rendered captures, alongside analyzer and focused widget tests. Capture uses Arial for available Vietnamese glyphs; platform font fidelity must be checked in the iOS build.

Verified: 16 focused profile/app widget tests passed, including all profile callbacks and layouts at 320 px (1.3 text scale), 393 px, and 1280 px. `flutter analyze --no-pub` and `git diff --check` passed. Captures: `../verification/profile/profile-{320,393,1280}.png`, using synthetic account details. Actual iPhone 17 simulator build launched successfully; inspected its profile screen with platform typography, navigation and AI launcher. Kept the hero illustration unclipped and reserved room beside the storage note for the launcher. The Simulator GUI application is unavailable in this Xcode installation, but the booted device runs and screenshots work.

Separate wider test run: three auth layout tests failed (320 px overflow and registration target scrolling at 393/1280 px). Auth implementation was outside this change; no claim of a fully passing auth suite.

Update requested by user: removed Settings and its sheet/callback. Logout now appears last, after the draft-storage note, with dark red text/icon (#B42318) on pale red (#FFEEEE). Account card contains only identity information. Verified all 16 focused tests and analyzer again; inspected refreshed captures.
