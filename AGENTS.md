# AGENTS.md

## Project overview

This is a native macOS SwiftUI app called HSC Trial Revision / TrialPracticeApp.

The app is local-first:
- no accounts;
- no server;
- no external database;
- SwiftData stores metadata locally;
- app-owned files live in Application Support;
- THSC import is the main network-backed feature.

Core technologies:
- Swift 6
- SwiftUI
- SwiftData
- PDFKit
- AppKit where necessary for macOS panels, Finder reveal, and PDFKit integration

## Golden rule

Keep changes small, reviewable, and testable. Do not perform large rewrites unless the user explicitly asks for that specific task.

## Before editing

Before changing files:
1. Inspect the relevant source files.
2. Summarize the current behavior.
3. Identify the smallest safe change.
4. List any data migration risk.
5. Avoid touching unrelated features.

## File safety

Be extremely careful with:
- `RootView.swift`
- `AppState.swift`
- `AppDirectories.swift`
- `LocalFileStore.swift`
- SwiftData model files
- `TrialPracticeApp.xcodeproj/project.pbxproj`

Never add or retain startup code that deletes user data unless it is behind an explicit developer-only action and clearly confirmed by the user.

Never delete or overwrite stored PDFs, captured PNGs, or SwiftData records as part of a migration unless there is a tested rollback path and the user explicitly requested destructive cleanup.

## Architecture preferences

Prefer feature folders over broad type folders.

Prefer:
- `Features/Library/...`
- `Features/PaperImport/...`
- `Features/PaperViewer/...`
- `Features/FlaggedQuestions/...`
- `Features/RevisionBooklets/...`
- `Features/Bin/...`
- `Infrastructure/Storage/...`
- `Infrastructure/PDF/...`
- `Domain/Models/...`

Avoid putting business logic directly in SwiftUI views. New business logic should usually live in:
- a service;
- a view model;
- a domain helper;
- a migration type;
- a typed value object.

## Swift style

- Keep SwiftUI views declarative where possible.
- Prefer small private subviews over very long `body` implementations.
- Avoid global helper functions unless they are clearly domain-neutral.
- Prefer typed values over raw strings for stored file paths, categories, identities, and migration versions.
- Keep AppKit/PDFKit bridge code isolated from feature screens when possible.
- Do not introduce third-party dependencies without explicit approval.

## Testing and verification

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
