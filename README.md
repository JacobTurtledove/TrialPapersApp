# HSC Trial Revision

A local-first macOS app for organising HSC trial papers, reviewing PDFs,
capturing difficult questions, and exporting revision material.

The app is built for an HSC student who wants one place to:

- organise papers by subject, school, and year;
- import trial papers manually or from supported THSC collections;
- read complete PDFs inside the app;
- flag mistakes and unlearned-content questions;
- practise flagged questions with solutions hidden until needed;
- mark papers and questions as completed;
- export active library files, individual PDFs, flagged-question images, subject
  CSVs, and revision booklets; and
- keep all app data local.

There are no accounts, servers, external databases, or built-in cloud sync. THSC
import is the only network-backed feature.

## Project

Open `TrialPracticeApp.xcodeproj` and run the `TrialPracticeApp` scheme.
`Package.swift` exists for command-line tests; it is not the primary app
project.

Current app name, bundle display name, and window title:

```text
HSC Trial Revision
```

The app uses the bundled `AppIcon` asset catalog and applies the same icon to
`NSApplication.shared.applicationIconImage` at launch so the Dock icon stays
correct even if Launch Services metadata is stale.

## Requirements

- macOS 14 or later
- Xcode 16 or later
- Swift 6 toolchain

Local unsigned builds are supported. The SwiftData store is local-only with
CloudKit disabled, so local testing does not require iCloud entitlements.

## Build and Test

Run tests:

```bash
swift test
```

Run a Debug Xcode build:

```bash
xcodebuild \
  -project TrialPracticeApp.xcodeproj \
  -scheme TrialPracticeApp \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

For release verification, change the configuration to `Release`. To create an
unsigned archive for local inspection:

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

Before distributing a build:

1. Select the distributing Apple development team under Signing & Capabilities.
2. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.
3. Run `swift test`.
4. Archive the `TrialPracticeApp` scheme.
5. Sign and notarize with Developer ID, or validate and upload through App Store
   Connect.

The Release configuration enables the hardened runtime.

## Current Verification

Current automated status:

- 41 Swift tests pass.
- Xcode Debug builds succeed.

The test suite covers name normalisation, paper validation, filename generation,
folder creation and renaming, PDF import, duplicate-file protection, file
rollback, deletion staging, PDF capture, duplicate flagged-question filenames,
revision booklet generation, CSV export, Finder reveal safety, THSC parsing, and
school crest lookup.

## Architecture

- Native macOS SwiftUI app.
- SwiftData stores metadata.
- PDFKit handles PDF viewing, merging, page subsets, and image capture.
- App-owned files live in Application Support.
- Temporary downloads and short-lived work use the system temporary directory.
- CloudKit is disabled.

The Xcode project manually lists Swift source files. When adding a new Swift
source file, add it to both the Swift package layout and
`TrialPracticeApp.xcodeproj/project.pbxproj`.

## Storage

The app uses a single app-managed storage location:

```text
Application Support/<bundle id>/
  Database.sqlite
  Files/
    Papers/
    Flagged Questions/
```

`AppDirectories` resolves the bundle-id Application Support folder and Caches
folder. The SwiftData store is:

```text
Application Support/<bundle id>/Database.sqlite
```

Imported PDFs and captured PNGs are stored under:

```text
Application Support/<bundle id>/Files
```

The app no longer asks the user to choose a root data folder on first launch.
The first screen is the Library.

Because the app is still in development, the first run of the Application
Support storage system clears old development metadata and file contents from
the previous storage era, then records a marker so future launches do not wipe
new data.

If an older local build created SwiftData's default
`Application Support/default.store`, the app copies it and its SQLite sidecar
files into the bundle-id Application Support folder before opening SwiftData.

## File Layout

Each exam is stored as one complete PDF:

```text
Papers/<Subject>/<School>/<Subject>_<School>_<Year>.pdf
```

There is no year directory for exam PDFs.

Flagged-question images are stored by subject, category, and year:

```text
Flagged Questions/<Subject>/<Category>/<Year>/<files>
```

Categories are:

- `Mistakes`
- `Unlearned Content`

Files are addressed in SwiftData by relative paths below the Application Support
`Files` root.

## Data Models

### Subject

Stores:

- unique ID;
- display name;
- filename-safe name;
- selected folder colour as a hexadecimal RGB value;
- creation date; and
- optional deletion date.

Subjects are soft-deleted into the Bin.

### School

Stores:

- unique ID;
- display name;
- filename-safe name;
- optional crest image data;
- optional crest source metadata; and
- creation date.

Schools are reused globally and displayed inside subjects when they have active
papers for that subject.

### Paper

Stores:

- unique ID;
- subject ID;
- school ID;
- year;
- optional numeric mark;
- question PDF relative path;
- solutions PDF relative path;
- combined PDF relative path;
- optional first-solutions-page number;
- optional has-solutions flag;
- completion state;
- creation date; and
- optional deletion date.

The app treats a paper as logically unique by:

```text
Subject + School + Year
```

New imports refuse to overwrite existing destination files.

### Flagged Question

Stores:

- unique ID;
- source paper ID;
- subject ID;
- school ID;
- year;
- question number;
- category;
- completion status;
- question image relative path;
- optional solution image relative path;
- creation date; and
- optional deletion date.

Before saving a flagged question, the app warns when another active flagged
question already has the same subject, school, year, and question number.
Duplicates are allowed and receive filename suffixes instead of overwriting
existing images.

### THSC Import Record

Stores a source-scoped THSC identifier, listing title, source page URL, optional
paper ID, and import date. Source-scoped identifiers allow the same school/year
title from different THSC collections to be imported into different subjects.

## Navigation

The app uses a macOS sidebar with these destinations:

- Library
- Import from THSC
- NESA Past Papers
- Flagged Questions
- Revision Booklets
- Bin
- Settings

The Library is selected by default.

## Library

The Library is organised as:

```text
Subject > School > Paper
```

Subject cards use the subject colour and show the active paper count. Users can:

- create subjects;
- choose a subject colour;
- rename subjects;
- export a subject;
- export the full active library;
- move a subject to the Bin; and
- open subject folders.

Renaming a subject also renames its stored folders and updates every affected
paper and flagged-question relative path. If the operation fails, the app
attempts to roll folder and metadata changes back.

Opening a subject displays active school folders for that subject. School cards
can show curated or user-selected crest images. Users can:

- show the school papers folder in Finder;
- export the school folder;
- choose, replace, remove, or use curated crest images;
- view the curated crest source when available; and
- move the school's papers and flagged questions for that subject to the Bin.

Opening a school displays active paper cards. Users can:

- open a paper in the PDF viewer;
- mark a paper completed;
- show the PDF in Finder;
- export the PDF; and
- move the paper and its flagged questions to the Bin.

## Paper Import

The Add Paper sheet accepts a chosen PDF or drag-and-drop. The drop area
highlights while targeted.

The user selects:

- subject;
- school;
- year;
- whether solutions are included in the PDF;
- the paper PDF; and
- optionally a separate solutions PDF.

Year values must contain numbers only. Marks are optional in the model but are
not currently requested during import, so new papers start with `mark == nil`.

If `Solutions included in PDF` is checked, the selected PDF is stored unchanged
as the one complete paper PDF. If it is unchecked and a separate solutions PDF
is supplied, the question and solution PDFs are merged into one stored PDF. If
separate solutions are left empty, the paper is recorded as having no solutions.

If SwiftData persistence fails after file import, the app removes the newly
created PDF.

## PDF Viewer

The viewer provides:

- Questions mode;
- Solutions mode;
- Both mode;
- continuous vertical PDF scrolling;
- zoom in;
- zoom out;
- fit width, including recentering the divider in Both mode;
- persisted pen annotations;
- stroke erasing for PDF ink annotations;
- paper completion checkbox;
- PDF export;
- Finder reveal; and
- flagged-question capture.

Each imported exam remains one complete PDF. The first time a paper with unknown
solution metadata is opened, the app asks the user to either:

- select the first solutions page; or
- mark the paper as having no solutions.

The saved first-solutions-page number lets the viewer create in-memory page
subsets for Questions, Solutions, and Both modes without modifying the stored
PDF. The solution boundary can be changed later.

If a stored file has been manually moved or deleted, the viewer displays a
missing-file message instead of crashing.

## Flagged Questions

Flagging happens inline in the PDF viewer. The user enters:

- question number;
- category: Mistake or Unlearned Content; and
- whether to include a solution capture.

The capture UI places two horizontal draggable boundaries over the scrolling
PDF. The area outside the boundaries is dimmed; the selected area remains clear.
The capture always uses the full PDF width.

Multi-page captures are supported. The service crops the selected portion of
the first page, captures intermediate pages in full, crops the selected portion
of the final page, and stitches the fragments vertically into one PNG.

Question and solution captures are independent. A solution is optional.

The Flagged Questions section starts with subject folders. Opening a subject
shows active flagged questions for that subject only. Users can filter by:

- all categories;
- Mistakes;
- Unlearned Content;
- incomplete;
- completed; or
- both completion states.

Search supports school, year, and question number.

The detail screen shows the captured question, optional hidden solution,
completion state, export action, and delete action. Deleting a flagged question
moves it to the Bin while keeping images in Application Support.

## Revision Booklets

Revision Booklets exports a PDF from active flagged questions. The user selects:

- subject;
- category filter: Mistakes, Unlearned, or both; and
- completion filter: completed, incomplete, or both.

The default is incomplete questions.

The exported PDF contains:

- a title page with subject, generation date, total count, Mistake count, and
  Unlearned Content count;
- one question page per flagged question; and
- one solution page immediately after each question.

If a solution image does not exist, the solution page says:

```text
No solution provided
```

Booklet export uses the native macOS save panel.

## Subject CSV Export

Inside each subject folder, the user can export active papers for that subject.
The CSV columns are exactly:

```text
School,Year,Mark
```

Rules:

- marks are numeric and do not include `%`;
- missing marks produce empty cells; and
- commas, quotes, and line breaks in school names are correctly escaped.

## File and Folder Exports

Exports always exclude Bin items.

Supported exports:

- full active library;
- subject folder;
- school folder;
- single paper PDF;
- flagged-question image set;
- subject CSV; and
- revision booklet PDF.

Folder exports preserve the stored relative layout under the selected export
destination. Single PDF exports copy the active stored PDF to the destination
chosen in the save panel.

## Bin and Deletion

Normal delete actions are soft deletes. Files remain in Application Support and
metadata remains in SwiftData.

The Bin includes:

- subjects;
- papers; and
- flagged questions.

Moving a school folder to the Bin marks that subject/school's papers and related
flagged questions as deleted.

Users can restore Bin items. Restoring a paper also restores its related flagged
questions. A flagged question can only be restored when its subject and paper
are active.

The Bin also includes permanent delete actions. Permanent delete removes the
metadata and the related stored files from Application Support.

Physical deletion is staged first. If metadata saving fails, staged files are
rolled back to their original paths.

## THSC Import

The THSC importer supports predefined trial-paper collections for sciences,
mathematics, English, HSIE, PDHPE, technology, agriculture, Studies of Religion,
and Visual Arts.

The import flow:

1. Downloads and parses the selected THSC listing page.
2. Displays school and year metadata.
3. Detects whether titles include solutions.
4. Prevents previously imported papers for the selected collection from being
   selected again.
5. Downloads selected PDFs sequentially.
6. Stores each selected paper as one complete PDF.
7. Creates or reuses school records.
8. Creates paper and THSC import-history records.

The importer does not inspect, OCR, classify, or split solution pages.

Users may import up to 10 selected papers at a time.

`THSCImportCoordinator` owns the import task and progress outside the THSC page,
so imports continue if the user navigates elsewhere. A bottom progress bar is
visible throughout the app while importing.

The first visit warns that THSC is often slow. Paper lists do not load
automatically; the user clicks `Load Papers`.

Known THSC constraints:

- THSC page and download formats are not a documented stable API.
- Importing is limited to predefined source collections.

## NESA Past Papers

The NESA Past Papers section links to official NESA course pages and past-paper
resources. It is informational and does not import files into the local library.

## School Crests

The app bundles the curated `School Crest Pack` resource containing 70 verified
512-by-512 PNG files and `manifest.json`.

School cards match the manifest's canonical names, official names, and unique
aliases when a subject library opens. Matching images are displayed from the
bundled pack without copying them into Application Support.

User-selected replacement crest images are stored as externally managed
SwiftData values. Manual choose, replace, and remove actions remain available.

Legacy `School Crests` cache files are migrated into SwiftData when needed, then
the legacy cache folder is removed.

## Settings

Settings shows:

- the Application Support storage path;
- `Show Application Support Folder`;
- `Export Library`;
- privacy text; and
- collapsed Developer Tools.

Developer Tools includes `Initialise All App Data`, which removes SwiftData
records, preferences, caches, legacy SwiftData stores, and Application Support
file contents. This is for development testing only.

There is also a native macOS Settings scene in addition to the sidebar Settings
screen.

## Important Files

- `Sources/TrialPracticeApp/TrialPracticeApp.swift`
  App entry point, model container, Dock icon setup, and Settings scene.
- `Sources/TrialPracticeApp/Services/AppDirectories.swift`
  Bundle-id Application Support and Caches resolution, plus legacy SwiftData
  default-store migration.
- `Sources/TrialPracticeApp/Services/AppState.swift`
  Application Support file-root setup.
- `Sources/TrialPracticeApp/Services/LocalFileStore.swift`
  Folder preparation, subject folder renaming, and staged permanent deletion.
- `Sources/TrialPracticeApp/Services/LibraryExportService.swift`
  Active-file export logic for library, subject, school, paper, and flagged
  question exports.
- `Sources/TrialPracticeApp/Services/PaperImportService.swift`
  One-PDF import, PDF merge, duplicate destination protection, and rollback.
- `Sources/TrialPracticeApp/Services/FlaggedQuestionCaptureService.swift`
  PDF region capture, image stitching, and flagged-question image persistence.
- `Sources/TrialPracticeApp/Services/RevisionBookletService.swift`
  PDF booklet generation.
- `Sources/TrialPracticeApp/Services/THSCImportService.swift`
  THSC scraping, title parsing, and downloading.
- `Sources/TrialPracticeApp/Services/THSCImportCoordinator.swift`
  Persistent background THSC import state and progress.
- `Sources/TrialPracticeApp/Views/LibraryView.swift`
  Subject, school, and paper library UI.
- `Sources/TrialPracticeApp/Views/AddPaperView.swift`
  Manual paper import and PDF drop target.
- `Sources/TrialPracticeApp/Views/PaperViewerScreen.swift`
  PDF modes, solution boundary setup, export, and flagged-question capture.
- `Sources/TrialPracticeApp/Views/FlaggedQuestionsView.swift`
  Flagged question folders, filters, detail view, export, and soft delete.
- `Sources/TrialPracticeApp/Views/RevisionBookletsView.swift`
  Booklet filters and export UI.
- `Sources/TrialPracticeApp/Views/SubjectBinView.swift`
  Bin restore and permanent delete UI.
- `Sources/TrialPracticeApp/Views/THSCImportView.swift`
  THSC source picker, list UI, filtering, selection, and import controls.
- `Sources/TrialPracticeApp/Views/MainNavigationView.swift`
  Sidebar navigation, shared import coordinator, and global import progress bar.

## Consistency and Safety

The app includes several consistency protections:

- Subject renaming updates folders and stored relative paths.
- Paper import cleans up copied files if metadata saving fails.
- Flagged-question capture cleans up newly created images if metadata saving
  fails.
- Duplicate imports do not overwrite files.
- Duplicate captures receive new filenames.
- Stored relative paths are checked before permanent deletion to prevent
  escaping the storage root.
- Permanent deletion stages files, saves metadata deletion, then commits file
  removal.
- Exports are driven by active SwiftData records, so Bin files are excluded even
  though they remain on disk.

The filesystem and SwiftData do not share one atomic transaction. The code uses
rollback/staging where practical, but future hardening could further centralise
metadata and file operations.

## Known Constraints and Non-Features

- The app does not scan files manually placed in Application Support.
- Application Support files alone are not a complete portable backup without the
  SwiftData database.
- There is no cloud sync, collaboration, or multi-device workflow.
- There is no iPhone, iPad, Windows, or web version.
- There is no OCR or automatic question-number detection.
- There is no automatic mark extraction from PDFs.
- Schools are not managed as independent top-level entities.
- Paper uniqueness is primarily enforced by UI and destination files, not by a
  compound unique database constraint.
- PDF annotation changes are written back to the stored paper PDF when saved.
- Revision state is a completed/incomplete flag; there is no spaced repetition
  scheduler.

## Manual Acceptance Checklist

Important workflows still benefit from hands-on verification:

1. Launch fresh and confirm Library appears first.
2. Confirm Application Support folder creation.
3. Create, rename, recolour, export, delete, restore, and permanently delete a
   subject.
4. Add papers manually with solutions included, separate solutions, and no
   solutions.
5. Open a paper, choose the first solutions page, and switch between Questions,
   Solutions, and Both.
6. Export a single paper PDF.
7. Flag single-page and multi-page questions.
8. Export flagged-question images.
9. Generate a revision booklet with and without solution captures.
10. Import THSC papers, navigate away, and confirm progress continues.
11. Move school folders, papers, and flagged questions to the Bin and restore
    them.
12. Permanently delete Bin items and confirm files are removed.
13. Confirm full library, subject, and school exports exclude Bin items.
14. Confirm school crest matching, manual crest replacement, and crest removal.

## Working Rules for Future Agents

- Read this README first, then inspect the relevant current code before making
  changes.
- Preserve existing user changes and avoid unrelated refactors.
- Use `apply_patch` for manual edits.
- Add every new Swift source file to the Xcode app target as well as the package.
- Run `swift test` and an Xcode build after code changes.
- Prefer `/tmp` DerivedData for command-line Xcode verification on restrictive
  school-managed Macs if needed.
- The app is currently macOS-only, although code should remain suitable for a
  later iOS adaptation where practical.
