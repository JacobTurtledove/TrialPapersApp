# HSC Trial Paper Revision

A local-first macOS app for organising HSC trial papers and building revision
booklets from flagged questions.

## Requirements

- macOS 14 or later
- Xcode 16 or later

## Build

Open `TrialPracticeApp.xcodeproj` in Xcode and run the `TrialPracticeApp` scheme.
This builds a normal macOS `.app` bundle that launches independently of
Terminal.

`Package.swift` is retained only for command-line unit tests. Do not use its
executable product to launch the app.

Before distributing a build:

1. Select the distributing Apple development team under Signing & Capabilities.
2. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` for the release.
3. Run `swift test`.
4. Choose Product > Archive using the `TrialPracticeApp` scheme.
5. Sign and notarize with Developer ID, or validate and upload through App Store Connect.

The app is sandboxed and uses a security-scoped bookmark for its user-selected
data folder. The Release configuration enables the hardened runtime.

## Storage

The first launch asks for a root folder. All paper and flagged-question files
remain inside that user-selected folder.

Each exam is stored as one PDF. The first time it is opened, the user clicks
the first solutions page; the app remembers that page and uses it to provide
Questions, Solutions, and Both viewing modes.

Paper PDFs use `Papers/Subject/School/Paper.pdf`. Flagged-question images use
`Flagged Questions/Subject/Category/Year/`.
