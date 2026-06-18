# TrialPracticeApp Documentation

This document is the concise maintainer map for HSC Trial Revision, a local-first
macOS SwiftUI app for organising HSC trial papers, viewing PDFs, capturing
flagged questions, importing supported THSC papers, and exporting revision
material.

## Project Shape

- Primary app project: `TrialPracticeApp.xcodeproj`
- CLI test/build manifest: `Package.swift`
- App source root: `Sources/TrialPracticeApp`
- Test root: `Tests/TrialPracticeAppTests`
- App-owned data location: `Application Support/<bundle id>/`
- SwiftData store: `Application Support/<bundle id>/Database.sqlite`
- Stored PDFs/images root: `Application Support/<bundle id>/Files`
- Main technologies: Swift 6, SwiftUI, SwiftData, PDFKit, AppKit.
- Network-backed feature: THSC import only.

The Xcode project is maintained manually. When adding a Swift source file, add
the file to `TrialPracticeApp.xcodeproj/project.pbxproj` and the
`TrialPracticeApp` target sources build phase. Do not migrate this project to
XcodeGen, Tuist, or SwiftPM-only project generation unless that is explicitly
requested.

## Build And Test

Run tests:

```bash
swift test
```

Run the app build:

```bash
xcodebuild \
  -project TrialPracticeApp.xcodeproj \
  -scheme TrialPracticeApp \
  -configuration Debug \
  -destination 'platform=macOS' \
  clean build
```

Open the app in Xcode with the `TrialPracticeApp` scheme. `Package.swift`
exists so the same source tree can be tested from the command line; the manual
`.xcodeproj` remains the app build source of truth.

For documentation-only changes, no build is normally required. For source,
model, storage, PDF, import/export, deletion, or project-file changes, run
`swift test` and the Xcode build above.

## Data And Storage Rules

The app is local-first. There are no accounts, server database, or CloudKit
sync. SwiftData stores metadata. PDFs and captured PNGs are stored as ordinary
files under the app-owned `Files` folder.

Stored layout:

```text
Application Support/<bundle id>/
  Database.sqlite
  Files/
    Papers/<Subject>/<School>/<Subject>_<School>_<Year>.pdf
    Flagged Questions/<Subject>/<Category>/<Year>/<images>.png
```

Important invariants:

- `Paper.primaryPDFRelativePath` is the path used for viewing/exporting.
- Imported exams are stored as one complete PDF.
- Relative paths are stored below the `Files` root; never store absolute paths
  in SwiftData models.
- `Subject`, `Paper`, and `FlaggedQuestion` use `deletedAt` for soft deletion.
- Permanent deletion stages files first, saves metadata deletion second, then
  commits or rolls back the staged files.
- Storage migrations must never delete user PDFs/images or SwiftData rows
  without an explicit, tested rollback path.

## Main User Flows

### Launch

`TrialPracticeApp.swift` creates the SwiftData `ModelContainer`, points it at
`AppDirectories.swiftDataStoreURL`, disables CloudKit, installs the app icon,
and opens `RootView`.

`RootView` shows `MainNavigationView` and runs storage migrations after
`AppState` resolves the app-owned file storage root.

### Library

Users create subjects, navigate `Subject > School > Paper`, open PDFs, export
files, reveal files in Finder, mark completion, edit subject names/colors, and
soft-delete subjects/papers/questions into the Bin.

### Manual Paper Import

`AddPaperView` collects subject, school, year, solutions mode, and PDF URLs.
`PaperImportService` validates PDFs, copies or merges PDFs into the stored
paper path, and rolls back created files if persistence fails.

### PDF Viewing And Annotation

`PaperViewerScreen` coordinates paper display, question/solution page modes,
annotation tools, export/reveal actions, and flagged-question capture.
Pen strokes are stored as PDF ink annotations, and the eraser removes whole ink
strokes from the annotatable PDF document.
Dirty annotation sessions autosave after a short idle delay. Closing a dirty
viewer queues any remaining PDF write through the app-wide annotation save
coordinator and dismisses immediately; save failures are reported from the main
navigation shell with a retry option. Reopening a PDF with a pending annotation
write shows an in-view saving state until the file is ready, avoiding a
simultaneous PDFKit read/write of the same file. Flows that immediately depend
on the stored PDF, such as flagged-question capture, still force a synchronous
annotation save before continuing.
The viewer persists the user's last visible PDF position separately for the
questions and solutions panes, so switching between Questions, Solutions, and
Both views or reopening the app restores the last viewed location for each side.
Viewport positions are app settings stored in `UserDefaults` under
`pdfViewer.viewportPositions.v1`; they are not SwiftData model state and do not
require a database migration. Changing the first solutions page clears the saved
viewport positions for that paper because the displayed page mapping changes.
Question/solution subset documents are built with copied `PDFPage` instances for
display, avoiding shared PDFKit page ownership across the Questions and
Solutions panes while preserving annotation writes through the source document.
PDFKit bridge code lives under `Infrastructure/PDF`.

### Flagged Questions

The viewer captures question and optional solution images from selected PDF
page ranges. Captures are saved as PNGs and recorded as `FlaggedQuestion`
models. Flagged-question screens support filtering, search, completion,
export, and soft deletion.

### Revision Booklets

`RevisionBookletsView` filters active flagged questions and
`RevisionBookletService` exports a PDF containing a title page, each question,
and each solution or a "No solution provided" page.

### THSC Import

`THSCImportService` parses predefined THSC listing pages and downloads PDFs.
`THSCImportCoordinator` owns the long-running import task and progress state so
imports continue while the user navigates elsewhere. Imported THSC papers are
stored through the same `PaperImportService` path as manual imports.

### Bin And Permanent Deletion

`SubjectBinView` restores or permanently deletes soft-deleted subjects, papers,
and flagged questions. `BinDeletionService` coordinates model deletion and
staged file deletion.

## Source File Map

### App Root

| File | Purpose |
| --- | --- |
| `TrialPracticeApp.swift` | App entry point, SwiftData container setup, Dock icon setup, window title helper. |
| `TrialPracticeApp.entitlements` | macOS app entitlements used by the Xcode target. |
| `Assets.xcassets` | App icon asset catalog. |

### Models

| File | Purpose |
| --- | --- |
| `Models/Subject.swift` | SwiftData subject model, folder color hex handling, soft-delete timestamp. |
| `Models/School.swift` | SwiftData school model, filename value, embedded crest image data, crest metadata. |
| `Models/Paper.swift` | SwiftData paper model, subject/school IDs, year, paths, solution metadata, completion, soft delete. |
| `Models/FlaggedQuestion.swift` | SwiftData flagged-question model and `QuestionCategory` enum. |
| `Models/THSCImportRecord.swift` | SwiftData record of imported THSC listing identifiers and linked paper IDs. |

Do not change model properties casually. Schema changes can require migrations
and can break existing local data.

### Top-Level Views

| File | Purpose |
| --- | --- |
| `Views/RootView.swift` | Hosts navigation and runs storage migrations. |
| `Views/MainNavigationView.swift` | Sidebar destinations, navigation coordinator, shared environment objects, app-wide PDF viewport store, and annotation save coordinator alerts. |
| `Views/LibraryView.swift` | Top-level library screen for subjects and full-library export. |
| `Views/AddPaperView.swift` | Manual paper import sheet and SwiftData insertion/rollback coordination. |
| `Views/PaperViewerScreen.swift` | Main PDF viewer workflow, annotation save lifecycle, and per-paper viewport persistence/reset coordination. |
| `Views/PDFViewerView.swift` | SwiftUI wrapper around PDFKit view/controller integration, including viewport capture/restore. |
| `Views/THSCImportView.swift` | THSC importer screen state and import selection flow. |
| `Views/FlaggedQuestionsView.swift` | Flagged-question subject overview. |
| `Views/RevisionBookletsView.swift` | Revision booklet filter/export screen state. |
| `Views/NESAPastPapersView.swift` | Informational NESA course/past-paper links. |
| `Views/SubjectBinView.swift` | Bin restore and permanent-delete UI. |
| `Views/SettingsView.swift` | Settings and developer maintenance actions. |

### Services

| File | Purpose |
| --- | --- |
| `Services/AppState.swift` | Resolves app-owned file storage root and development reset. |
| `Services/AppDirectories.swift` | Application Support/Caches paths and legacy SwiftData store copy. |
| `Services/LocalFileStore.swift` | Folder creation, subject folder rename, write checks, staged deletion transactions. |
| `Services/NameNormalizer.swift` | Display-name and filename-safe value normalization. |
| `Services/PaperImportService.swift` | Manual/THSC paper PDF copy or merge into stored complete PDF. |
| `Services/LibraryMutationService.swift` | Subject creation, rename, folder/path updates, soft delete. |
| `Services/LibraryExportService.swift` | Active library, subject, school, paper, and flagged-question exports. |
| `Services/SubjectPaperCSVService.swift` | Subject paper CSV row generation and escaping. |
| `Services/FinderRevealService.swift` | Safe Finder reveal support for stored relative paths. |
| `Services/FlaggedQuestionCaptureService.swift` | PDF page-range capture, PNG stitching, image save/delete. |
| `Services/FlaggedQuestionSaveService.swift` | Captures images, creates `FlaggedQuestion`, rolls back images on save failure. |
| `Services/RevisionBookletService.swift` | Revision booklet PDF rendering. |
| `Services/THSCImportService.swift` | THSC listing parsing, PDF download, source/listing types. |
| `Services/THSCImportCoordinator.swift` | App-wide THSC import task, progress, school reuse, persistence rollback. |
| `Services/THSCSourcePresets.swift` | Predefined THSC source collections. |
| `Services/SchoolCrestLookupService.swift` | Looks up curated school crest metadata from bundled pack. |
| `Services/SchoolCrestService.swift` | Converts and stores school crest image data. |

### Infrastructure

| File | Purpose |
| --- | --- |
| `Infrastructure/Storage/StoredFilePath.swift` | Validates stored relative paths and resolves them safely under a root URL. |
| `Infrastructure/Storage/StorageMigrationService.swift` | Versioned storage migrations; currently embeds legacy crest files as model data. |
| `Infrastructure/PDF/PDFViewerController.swift` | Imperative PDF view control: zoom, fit width, capture overlay, and `UserDefaults`-backed viewport position storage. |
| `Infrastructure/PDF/SelectablePDFView.swift` | PDFKit view subclass used by the SwiftUI bridge. |
| `Infrastructure/PDF/PDFAnnotationSession.swift` | Loads annotatable PDF documents, tracks dirty state, creates deferred save requests, and coordinates queued annotation saves. |
| `Infrastructure/PDF/PDFAnnotationEditing.swift` | Annotation editing behavior on the selectable PDF view. |
| `Infrastructure/PDF/PDFDrawingTypes.swift` | Drawing tool, pen configuration, and ink stroke value types. |
| `Infrastructure/PDF/PDFInkOverlayProvider.swift` | PDFKit page overlay provider for ink drawing. |
| `Infrastructure/PDF/PDFInkOverlayView.swift` | AppKit overlay view for collecting/rendering ink strokes. |
| `Infrastructure/PDF/PDFInkGeometry.swift` | Coordinate conversion helpers for PDF ink geometry. |
| `Infrastructure/PDF/PDFCaptureOverlayView.swift` | Draggable PDF capture boundary overlay. |
| `Infrastructure/PDF/PDFDocumentLoader.swift` | PDF document loading and copied derived page subsets for safe multi-pane display. |
| `Infrastructure/PDF/PDFPageSelection.swift` | Page selection value type for page-subset display. |
| `Infrastructure/PDF/PDFPagePreviewView.swift` | SwiftUI/AppKit page preview bridge. |
| `Infrastructure/PDF/NSColor+Hex.swift` | Hex color conversion for AppKit colors. |

### Feature: Library

| File | Purpose |
| --- | --- |
| `Features/Library/SubjectLibraryView.swift` | Subject-specific school folder view, subject export, CSV export. |
| `Features/Library/SchoolLibraryView.swift` | School-specific paper list and actions. |
| `Features/Library/LibraryExportFolderPicker.swift` | macOS folder picker for library exports. |
| `Features/Library/Components/LibraryFolderCard.swift` | Generic folder card UI. |
| `Features/Library/Components/SubjectEditor.swift` | Subject name/color editor. |
| `Features/Library/Components/SchoolFolderCard.swift` | School folder card UI and crest display. |
| `Features/Library/Components/PaperLibraryCard.swift` | Paper card UI and paper actions. |

### Feature: Paper Import

| File | Purpose |
| --- | --- |
| `Features/PaperImport/PaperValidation.swift` | Year/mark validation helpers. |
| `Features/PaperImport/PaperFileNames.swift` | Stored paper filename generation. |
| `Features/PaperImport/PDFPickerTarget.swift` | Picker target enum for question or solutions PDF. |
| `Features/PaperImport/PDFSelectionRow.swift` | Reusable PDF selection row UI. |
| `Features/PaperImport/SecurityScopedURLAccess.swift` | Security-scoped URL access wrapper. |

### Feature: Paper Viewer

| File | Purpose |
| --- | --- |
| `Features/PaperViewer/PaperViewingMode.swift` | Questions/Solutions/Both mode enum. |
| `Features/PaperViewer/PaperViewerToolbar.swift` | Viewer toolbar controls. |
| `Features/PaperViewer/PaperViewerPenPalette.swift` | Pen color/width choices. |
| `Features/PaperViewer/PenCircle.swift` | Pen color indicator UI. |
| `Features/PaperViewer/SolutionsStartPagePickerSheet.swift` | Sheet for setting first solutions page or no-solutions state. |
| `Features/PaperViewer/PaperViewerDocumentContent.swift` | Main document display extension for `PaperViewerScreen`. |
| `Features/PaperViewer/PaperViewerCapture.swift` | Flagged-question capture UI and save flow extension. |

### Feature: Flagged Questions

| File | Purpose |
| --- | --- |
| `Features/FlaggedQuestions/FlaggedQuestionFilters.swift` | Category and completion filter enums. |
| `Features/FlaggedQuestions/SubjectFlaggedQuestionsView.swift` | Flagged-question list for one subject. |
| `Features/FlaggedQuestions/FlaggedQuestionDetailView.swift` | Captured question/solution detail screen. |
| `Features/FlaggedQuestions/FlaggedQuestionExportFolderPicker.swift` | Folder picker for flagged-question export. |
| `Features/FlaggedQuestions/Components/FlaggedSubjectFolderCard.swift` | Subject card in flagged-question overview. |
| `Features/FlaggedQuestions/Components/FlaggedQuestionRow.swift` | Row UI for a flagged question. |
| `Features/FlaggedQuestions/Components/StoredImage.swift` | Stored image loading/display helper. |

### Feature: THSC Import

| File | Purpose |
| --- | --- |
| `Features/THSCImport/THSCImportModels.swift` | UI filters, grouped paper view model, normalized search helper. |
| `Features/THSCImport/THSCImportControls.swift` | THSC source/subject/filter/search controls extension. |
| `Features/THSCImport/THSCPaperListView.swift` | Grouped THSC listing UI extension. |
| `Features/THSCImport/THSCImportBar.swift` | THSC import action/status bar extension. |
| `Features/THSCImport/THSCImportProgressBar.swift` | App-wide bottom import progress bar. |

### Feature: Revision Booklets

| File | Purpose |
| --- | --- |
| `Features/RevisionBooklets/RevisionBookletFilters.swift` | Category and completion filters for booklet export. |
| `Features/RevisionBooklets/RevisionBookletControls.swift` | Booklet filter/export control extension. |
| `Features/RevisionBooklets/RevisionBookletQuestionRow.swift` | Preview row for a booklet question. |

### Feature: Bin

| File | Purpose |
| --- | --- |
| `Features/Bin/BinDeletionService.swift` | Permanent delete orchestration and file rollback support. |

### Feature: NESA

| File | Purpose |
| --- | --- |
| `Features/NESA/NESAPastPaperCatalogue.swift` | Static catalogue of official NESA course/past-paper links. |

## Test File Map

| File | Purpose |
| --- | --- |
| `PaperValidationTests.swift` | Year/mark validation and paper filename behavior. |
| `NameNormalizerTests.swift` | Display and filename normalization rules. |
| `StoredFilePathTests.swift` | Relative path validation and root containment. |
| `FinderRevealServiceTests.swift` | Finder reveal path safety. |
| `AppStateTests.swift` | Application Support storage setup and development reset behavior. |
| `FileWorkflowTests.swift` | Import, export, capture, rollback, storage migration, CSV, and booklet workflows. |
| `BinDeletionServiceTests.swift` | Permanent deletion, related rows/files, and rollback. |
| `LibraryMutationServiceTests.swift` | Subject create/rename/delete behavior and path rewrites. |
| `THSCImportServiceTests.swift` | THSC parsing, source-scoped identifiers, solution detection, school reuse. |
| `NESAPastPaperCatalogueTests.swift` | NESA catalogue coverage and link uniqueness. |
| `SchoolCrestLookupServiceTests.swift` | Bundled crest pack lookup and image readability. |

## Non-Source Files And Assets

| Path | Purpose |
| --- | --- |
| `README.md` | User/developer overview, behavior notes, and build commands. |
| `AGENTS.md` | Agent/coding instructions and project safety rules. |
| `Package.swift` | Swift package manifest for command-line tests. |
| `TrialPracticeApp.xcodeproj/project.pbxproj` | Manual Xcode project source/build settings. |
| `TrialPracticeApp.xcodeproj/xcshareddata/xcschemes/TrialPracticeApp.xcscheme` | Shared Xcode scheme. |
| `TrialPracticeApp.xcodeproj/project.xcworkspace/...` | Xcode workspace metadata. |
| `Artwork/AppIcon.png` | Source artwork for the app icon. |
| `Sources/TrialPracticeApp/Assets.xcassets/...` | App icon asset catalog. |
| `School Crest Pack/manifest.json` | Metadata for curated school crest images. |
| `School Crest Pack/images/*.png` | Bundled curated school crest image files. |
| `docs/CODEX_REFACTOR_PLAYBOOK.md` | Refactor planning and safety notes. |
| `docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md` | Historical file-splitting runbook and progress log. |
| `docs/DOCUMENTATION.md` | This maintainer documentation. |

## Process Notes For Future Changes

### Adding A Swift File

1. Place the file in the appropriate feature or infrastructure folder.
2. Add the file to `TrialPracticeApp.xcodeproj/project.pbxproj`.
3. Ensure it appears in the `TrialPracticeApp` target sources build phase.
4. Run `swift test`.
5. Run the Xcode build command.

### Changing Storage Or File Paths

Treat these as high-risk changes. Inspect and update:

- SwiftData model path properties.
- `AppDirectories`
- `AppState`
- `LocalFileStore`
- `StoredFilePath`
- `PaperImportService`
- `LibraryExportService`
- `FlaggedQuestionCaptureService`
- `BinDeletionService`
- migration tests and rollback tests.

Do not change stored path formats without a migration that is covered by tests.

### Changing SwiftData Models

Schema changes affect existing local users. Before changing model properties:

- decide whether a migration is required;
- preserve existing stored paths and files;
- add or update tests;
- run both CLI tests and Xcode build.

### Changing Import Or Export

Manual import and THSC import both flow through `PaperImportService`. Preserve
the invariant that each paper has one complete stored PDF. Export code should
only export active, non-Bin items unless the UI explicitly says otherwise.

### Changing PDF Annotation Or Capture

PDF viewing spans SwiftUI, PDFKit, and AppKit. Keep bridge code in
`Infrastructure/PDF` when possible. Capture behavior must preserve:

- full-width captures;
- multi-page stitching;
- question and solution capture independence;
- rollback of saved images if SwiftData persistence fails.

### Changing Deletion

Soft deletion uses `deletedAt`. Permanent deletion must stage file moves before
metadata deletion and roll them back if saving fails. Avoid direct file removal
from views.

### Changing THSC Import

THSC is an external page format, not a stable API. Keep parsing and downloading
inside `THSCImportService`, and keep long-running task/progress ownership in
`THSCImportCoordinator`.
