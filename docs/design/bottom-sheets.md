# Bottom sheets

Reference: `references/bottom-sheet-reference.png` supplied by the user.

Direction: calm white/mint surfaces for configuring quizzes and replacing source documents. Keep the existing green brand tokens and platform typography. Rounded top corners (28), centered gray handle, subtle mint waves clipped inside the top right, 24px bold headings, bordered option cards with mint icon tiles, selected green check, and the existing gradient action component match the reference's hierarchy.

All modal sheets use `showAppSheet` and `AppSheetBody`; maximum width 640, safe-area padding, scrollable content, keyboard inset, native modal dismissal and focus behavior. Cards wrap explanatory text rather than clipping it on narrow screens or at larger text scales. No added motion or dependencies. Difficulty and mode stage a choice and commit only through “Áp dụng”; dismissing preserves the previous value. Document scan/upload actions open immediately and retain existing confirmation and source-preservation behavior.

Acceptance: all existing modal bottom-sheet call sites use the shared surface; selection apply/cancel and generated payload remain correct; document replacement still works; no layout exceptions at 320 and 1280 widths. Visual comparison also includes 393px width.

Visual review: installed design-review skill is a catalog entry without upstream scripts, so review uses actual Flutter render captures against the supplied reference. Capture harness uses Arial for readable test glyphs; runtime typography remains the existing platform font. Native icons approximate the reference artwork; gradients reuse the app's existing brand palette. No measured fidelity percentage is claimed.

Verification: 28 focused application tests plus a render-capture test passed. Analyzer found no issues in the changed Dart files; `git diff --check` passed. Render captures are saved under `docs/verification/bottom-sheets/` at 320, 393 and 1280 logical pixels. Review found readable hierarchy, contained decoration, visible primary actions and no overflow in the captured layouts.
