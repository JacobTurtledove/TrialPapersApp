# HSC Trial Revision App Handover

## Start Here

Project:

`/Users/jacob.turtledove/Library/CloudStorage/OneDrive-MoriahWarMemorialCollegeAssociation/Documents/Trial Practice App`

Open `TrialPracticeApp.xcodeproj` and use the `TrialPracticeApp` scheme.
`Package.swift` exists for command-line tests; it is not the primary app project.

Current window title: **HSC Trial Revision**.
The bundle display name and bundle name are also **HSC Trial Revision**. The app
uses the bundled `AppIcon` asset catalog for the app icon and applies the same
icon to `NSApplication.shared.applicationIconImage` at launch so the Dock uses it
even if Launch Services metadata is stale.

## Technology

- Native macOS SwiftUI app, macOS 14+
- SwiftData metadata
- PDFKit viewing, merging, page subsets, and capture
- Security-scoped bookmarks for the selected storage folder
- THSC network listing and PDF downloads

The school-managed Mac has restrictive permissions. For reliable command-line
Xcode verification, use `/tmp` for DerivedData and request elevated execution if
SwiftData macros fail through `sandbox-exec`.

Local unsigned builds are supported. The app does not require a paid Apple
developer account for local testing; the SwiftData store is local-only with
CloudKit disabled.

## Current Product Behaviour

### Storage Setup

First launch presents one action: `Choose Exam Papers Folder`.

- The selected folder becomes the app root.
- The app rejects the actual macOS Desktop, Documents, Downloads, Movies, Music,
  Pictures, Public, and home folders.
- Detection compares canonical filesystem URLs, not folder names. An unrelated
  folder named `Desktop` is valid.
- The app also rejects folders shaped like macOS home folders or sandbox
  container `Data` folders, such as folders containing several of `Desktop`,
  `Documents`, `Downloads`, `Library`, `SystemData`, and `tmp`.
- Nested dedicated folders such as `Documents/test10/test11` are valid.
- Security-scoped access is opened before bookmark creation and writes.

### File Structure

New exam PDFs:

`Papers/Subject/School/Subject_School_Year.pdf`

There is no year directory for exam PDFs.

Flagged-question images:

`Flagged Questions/Subject/Category/Year/files`

Existing records retain their previously stored relative paths and remain usable.

Paper PDFs, flagged question and solution images, subject and school folders,
the data root, and successful CSV/booklet exports expose
`Show in Finder` actions.

### Private App Storage

- Durable private app-managed data is resolved through `AppDirectories`.
- The SwiftData database is stored at
  `Application Support/<bundle id>/Database.sqlite`.
- CloudKit is disabled for the SwiftData store so local builds do not need
  Apple account or iCloud entitlements.
- If an older local build created SwiftData's default
  `Application Support/default.store`, the app copies it and its SQLite sidecar
  files into the bundle-id Application Support folder before opening SwiftData.
- Disposable or short-lived work uses the system temporary directory; no runtime
  data is written into the `.app` bundle.
- Settings contains a collapsed `Developer Tools` section with
  `Initialise All App Data`. It deletes all SwiftData records, clears app
  preferences/bookmarks, removes caches and the legacy
  `default.store`, deletes the contents of the selected app data folder, and
  returns the app to setup.

### Paper Imports

- Exactly one combined PDF is stored per exam.
- Student-work uploads and related model properties were removed.
- No mark is requested during import; new papers start with `mark == nil`.
- The Add Paper sheet accepts a chosen PDF or drag-and-drop.
- The drop area highlights blue and says `Release to add PDF` while targeted.
- `Solutions included in PDF` is checked initially.
- If unchecked, a separate solutions PDF may be selected and is merged into the
  one stored PDF.
- Leaving separate solutions empty records that the paper has no solutions.
- PDFs may also be dropped onto the main Papers page to open a prefilled import sheet.
- Papers have a persisted completed state. A checkbox is available on each paper
  card inside a school folder and in the PDF viewer toolbar.

### Solutions Boundary

`Paper` stores:

- `solutionsStartPage: Int?`
- `hasSolutions: Bool?`

When a paper with unknown solution metadata is first opened, a small alert asks:

- `Select First Solutions Page`
- `This Paper Has No Solutions`

The user scrolls and clicks the first solutions page. The 1-based page number is
saved. Questions, Solutions, and Both views use in-memory PDF page subsets while
the original combined PDF remains unchanged.

The solution boundary can be changed later. Papers marked as having no solutions
show only Questions.

### THSC

- `THSCImportService` exposes 26 verified trial-paper collections, including
  sciences, mathematics, English, HSIE, PDHPE, technology, agriculture,
  Studies of Religion, and Visual Arts.
- THSC titles containing `w. sol` are treated as having solutions.
- Titles without that marker are imported as no-solutions papers.
- Duplicate import history uses a source-scoped THSC identifier so the same
  school/year title from different THSC collections can be imported into
  different subjects. Older unscoped THSC records are still respected for the
  collection they were originally imported from.
- Up to ten selected papers may be imported.
- `THSCImportCoordinator` owns the import task and progress outside the page.
- Imports continue when the user navigates away from the THSC page.
- A fixed bottom progress bar remains visible throughout the app.
- The THSC action footer has a fixed height and one divider to prevent visual
  jumping while imported rows update.
- The first visit warns that THSC is often very slow.
- Paper lists no longer load automatically. Before loading, a large centered
  `Load Papers` button is shown; while fetching, a prominent centered loading
  panel explains that the website may take a while to respond.

### School Crests

- The Xcode app bundles the curated `School Crest Pack` resource containing 70
  verified 512-by-512 PNG files and `manifest.json`.
- School cards match the manifest's canonical names, official names, and unique
  aliases when the subject library opens.
- Matching images are displayed directly from the bundled pack without copying
  them into the user's data folder.
- User-selected replacement images are stored as externally managed SwiftData
  values. Manual choose, replace, and remove actions remain available.
- Existing `School Crests` cache files are migrated into SwiftData when needed,
  then the legacy cache folder is removed.

Important: `THSCImportCoordinator.swift` is included in both the Swift package
and the Xcode app target. If adding a new source file, also add it to
`TrialPracticeApp.xcodeproj/project.pbxproj`.

### Flagged Questions

- Flagging happens inline in the PDF viewer.
- `Include solution capture` starts checked when the paper has a saved solution
  boundary, and starts off when there are no solutions.
- Multi-page question and solution regions are supported.
- Captures are stored by subject, category, and year.
- Search, filters, completion state, deletion, and revision-booklet export remain.

## Important Files

- `Sources/TrialPracticeApp/Services/AppState.swift`
  Folder bookmark setup and standard-folder rejection.
- `Sources/TrialPracticeApp/Services/AppDirectories.swift`
  Bundle-id Application Support and Caches resolution, plus legacy SwiftData
  default-store migration.
- `Sources/TrialPracticeApp/Services/PaperImportService.swift`
  One-PDF import and flattened paper path.
- `Sources/TrialPracticeApp/Services/THSCImportService.swift`
  THSC scraping, title parsing, and downloading.
- `Sources/TrialPracticeApp/Services/THSCImportCoordinator.swift`
  Persistent background THSC import state.
- `Sources/TrialPracticeApp/Views/AddPaperView.swift`
  Simplified import and PDF drop target.
- `Sources/TrialPracticeApp/Views/PaperViewerScreen.swift`
  Solution setup, page modes, and flagged-question capture.
- `Sources/TrialPracticeApp/Views/THSCImportView.swift`
  THSC selection UI.
- `Sources/TrialPracticeApp/Views/MainNavigationView.swift`
  Shared coordinator and global progress bar.

## Verification

Current automated status:

- **41 Swift tests pass**
- **Xcode Debug and Release builds succeed**
- **An unsigned Release archive succeeds**

Run tests:

```bash
swift test
```

Run the Xcode build:

```bash
xcodebuild \
  -project TrialPracticeApp.xcodeproj \
  -scheme TrialPracticeApp \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath /tmp/TrialPracticeAppBuild \
  CODE_SIGNING_ALLOWED=NO \
  build
```

For a release verification build, change the configuration to `Release`. To
create an unsigned archive for local inspection:

```bash
xcodebuild \
  -project TrialPracticeApp.xcodeproj \
  -scheme TrialPracticeApp \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath /tmp/HSCTrialRevision.xcarchive \
  CODE_SIGNING_ALLOWED=NO \
  archive
```

Distribution still requires selecting the owner's Apple development team in
Xcode, then signing and notarizing the archive through Xcode Organizer.

If the build reports `sandbox-exec: sandbox_apply: Operation not permitted` or
malformed SwiftData macro responses, rerun the same build with elevated tool
permission. The most recent elevated build completed with `BUILD SUCCEEDED`.

## Manual Checks

1. Select a nested dedicated storage folder and confirm setup succeeds.
2. Confirm the actual Documents or Desktop folder is rejected.
3. Drag a PDF over Add Paper and confirm the drop zone highlights.
4. Import a combined PDF and choose its first solutions page.
5. Mark a paper as having no solutions and confirm solution modes disappear.
6. Import THSC papers, navigate elsewhere, and confirm progress continues at the bottom.
7. Return to THSC and confirm imported rows and completion status update cleanly.
8. Confirm the THSC list/footer dividers do not jump or duplicate during import.

## Working Rules

- Read the current code before assuming this handover is exhaustive.
- Preserve existing user changes and avoid unrelated refactors.
- Use `apply_patch` for manual edits.
- Add every new Swift source to the Xcode app target as well as the package.
- Run `swift test` and the Xcode build after changes.
- The app is currently a macOS app, although code should remain suitable for a
  later iOS adaptation where practical.

## Prompt For A New Agent

```text
Continue work on my HSC Trial Revision macOS app.

The repository is:
/Users/jacob.turtledove/Library/CloudStorage/OneDrive-MoriahWarMemorialCollegeAssociation/Documents/Trial Practice App

First read handover.md completely, then inspect the relevant current code before
making changes. Open and build TrialPracticeApp.xcodeproj using the
TrialPracticeApp scheme; Package.swift is only for command-line tests.

Important current facts:
- Each exam stores one combined PDF.
- Exam paths are Papers/Subject/School/file.pdf with no year folder.
- Flagged questions remain grouped under Subject/Category/Year.
- Solution presence and the first solutions page are recorded manually.
- THSC imports are owned by THSCImportCoordinator and must continue across navigation.
- New Swift source files must be added to the Xcode target/project file.
- The school-managed Mac may require /tmp DerivedData and elevated xcodebuild
  execution for SwiftData macros.

Please collaborate proactively: implement my next request end to end, preserve
unrelated work, run all tests, run the Xcode build, and clearly report what changed.
```
