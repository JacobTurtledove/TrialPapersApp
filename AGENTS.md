# AGENTS.md

## Project Overview

This is a native macOS SwiftUI app called HSC Trial Revision / TrialPracticeApp.

The app is local-first: no accounts, server, or external database. SwiftData stores metadata locally, app-owned files live in Application Support, and THSC import is the main network-backed feature.

Core technologies: Swift 6, SwiftUI, SwiftData, PDFKit, and AppKit where needed for macOS panels, Finder reveal, and PDFKit integration.

## Golden Rule

Keep changes small, reviewable, and testable. Do not perform large rewrites unless the user explicitly asks for that specific task.

## Before Editing

Before changing files:

1. Inspect the relevant source files.
2. Summarize the current behavior.
3. Identify the smallest safe change.
4. List any data migration risk.
5. Avoid touching unrelated features.

## File Safety

Be extremely careful with:

- `RootView.swift`
- `AppState.swift`
- `AppDirectories.swift`
- `LocalFileStore.swift`
- SwiftData model files
- `TrialPracticeApp.xcodeproj/project.pbxproj`

Never add or retain startup code that deletes user data unless it is behind an explicit developer-only action and clearly confirmed by the user.

Never delete or overwrite stored PDFs, captured PNGs, or SwiftData records as part of a migration unless there is a tested rollback path and the user explicitly requested destructive cleanup.

## Architecture Preferences

Prefer feature folders over broad type folders, for example:

- `Features/Library/...`
- `Features/PaperImport/...`
- `Features/PaperViewer/...`
- `Features/FlaggedQuestions/...`
- `Features/RevisionBooklets/...`
- `Features/Bin/...`
- `Infrastructure/Storage/...`
- `Infrastructure/PDF/...`
- `Domain/Models/...`

Avoid putting business logic directly in SwiftUI views. New business logic should usually live in a service, view model, domain helper, migration type, or typed value object.

## Swift Style

- Keep SwiftUI views declarative where possible.
- Prefer small private subviews over very long `body` implementations.
- Avoid global helper functions unless they are clearly domain-neutral.
- Prefer typed values over raw strings for stored file paths, categories, identities, and migration versions.
- Keep AppKit/PDFKit bridge code isolated from feature screens when possible.
- Do not introduce third-party dependencies without explicit approval.

## Testing and Verification

After code changes, run the narrowest relevant checks first, then broader checks if possible.

Default checks:

```bash
swift test
xcodebuild \
  -project TrialPracticeApp.xcodeproj \
  -scheme TrialPracticeApp \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

If only documentation changed, no build is required unless the change touches project configuration.

If tests cannot run, clearly state the attempted command, why it failed, and whether the failure appears related to the change.

## Commit Expectations

For each task, keep the diff focused, include tests when changing behavior, do not mix refactor + feature + migration unless requested, leave the working tree clean, and summarize changed files and test results.
