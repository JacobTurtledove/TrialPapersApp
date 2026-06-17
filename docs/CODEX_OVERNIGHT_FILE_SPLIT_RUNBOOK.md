# TrialPapersApp Overnight Codex File-Splitting Runbook

Repository: `JacobTurtledove/TrialPapersApp`
Purpose: split the remaining large Swift files into smaller, feature-based files while preserving behavior.

This runbook is designed for one long Codex run. Codex should keep returning to this file, follow the checklist in order, update the progress log as it works, and stop safely if it hits a risky or ambiguous situation.

---

## 0. Mission

Refactor the codebase by splitting large Swift files into smaller files.

This is primarily a **file organization and component extraction** task, not a behavior rewrite.

The main goals are:

1. Make large files easier to read.
2. Move complete private views/components into their own files.
3. Move PDF infrastructure types into focused files.
4. Improve feature folder organization.
5. Keep the app compiling after every batch.
6. Avoid data-loss risk, SwiftData schema changes, storage path changes, and project-generation changes.

---

## 1. Non-negotiable rules

Do not violate these rules.

### 1.1 Do not change data model schemas

Do not add, remove, or rename stored properties on:

- `Subject`
- `School`
- `Paper`
- `FlaggedQuestion`
- `THSCImportRecord`

Do not change `@Model`, `@Attribute`, or SwiftData persistence behavior.

Computed properties are okay only if needed for compilation, but this run should not need them.

### 1.2 Do not change storage behavior

Do not change:

- Application Support folder layout
- stored PDF paths
- flagged question image paths
- deletion staging behavior
- migration versions
- root folder logic
- export path behavior
- import path behavior

Do not add any automatic destructive cleanup.

### 1.3 Do not change app behavior intentionally

This run is refactor-only.

Allowed:

- moving types into new files;
- changing access level from `private` to internal when needed because a type moved files;
- extracting pure subviews/components;
- extracting helper functions with identical behavior;
- fixing compile errors caused by extraction.

Not allowed:

- redesigning UI;
- changing wording except if required by compile issue;
- changing business rules;
- changing import/export behavior;
- changing PDF annotation behavior;
- changing capture/flagging behavior;
- changing THSC behavior.

### 1.4 Do not do Task 21 / project-generation migration

Do not introduce:

- XcodeGen
- Tuist
- a generated project workflow
- a SwiftPM-only migration
- a new package layout requiring project generation changes

Keep the current manual `.xcodeproj`.

### 1.5 Update the Xcode project for every new Swift file

Whenever a new Swift file is created:

1. Add a `PBXFileReference`.
2. Add a `PBXBuildFile`.
3. Add the file to the correct Xcode group.
4. Add the file to the `TrialPracticeApp` target `PBXSourcesBuildPhase`.

If unsure, inspect existing entries and follow the same style.

### 1.6 Do not commit automatically

Do not commit unless the user explicitly asks.

At the end, provide a suggested commit message only.

---

## 2. Required checks

Run these at the start and after each phase:

```bash
swift test
xcodebuild -project TrialPracticeApp.xcodeproj -scheme TrialPracticeApp -configuration Debug -destination 'platform=macOS' clean build
```

If either command fails:

1. Try to fix extraction-related compile errors.
2. Do not rewrite behavior to make tests pass.
3. If the same command still fails after two focused attempts, stop.
4. Update the progress log with:
   - command attempted;
   - exact failure summary;
   - likely cause;
   - files touched;
   - safest next step.

---

## 3. Stop conditions

Stop immediately and report if any of these happen:

- A SwiftData model schema change seems necessary.
- A storage path or migration change seems necessary.
- `project.pbxproj` becomes confusing or inconsistent.
- Xcode build fails after two focused extraction-related fixes.
- A moved type creates circular dependencies that require architecture changes.
- A change would alter PDF rendering, annotation persistence, capture behavior, import behavior, export behavior, or deletion behavior.
- More than one feature area appears broken at once.
- You are tempted to do a broad cleanup not listed in this runbook.

---

## 4. Working method

For each step:

1. Inspect the source file and identify the exact type/function to move.
2. Create the new destination file.
3. Move the type/function with minimal edits.
4. Adjust access control only as required.
5. Update `TrialPracticeApp.xcodeproj/project.pbxproj`.
6. Run `swift test`.
7. Run the Xcode build command.
8. Update the progress log.
9. Continue only if both checks pass or if failure is clearly unrelated to the extraction.

Prefer one moved type per commit-sized unit, but this overnight run may do a small batch before testing when the moves are extremely mechanical. Do not batch risky PDF/AppKit moves.

---

## 5. Target folder structure

Aim toward this structure gradually. Do not force the entire structure if it causes large diffs.

```text
Sources/TrialPracticeApp/
  App/
    TrialPracticeApp.swift
    RootView.swift
    MainNavigationView.swift
    AppNavigationCoordinator.swift
    AppState.swift

  Models/
    Subject.swift
    School.swift
    Paper.swift
    FlaggedQuestion.swift
    THSCImportRecord.swift

  Features/
    Library/
      LibraryView.swift
      SubjectLibraryView.swift
      SchoolLibraryView.swift
      LibraryMutationService.swift
      LibraryExportFolderPicker.swift
      Components/
        LibraryFolderCard.swift
        SchoolFolderCard.swift
        PaperLibraryCard.swift
        SubjectEditor.swift

    PaperImport/
      AddPaperView.swift
      PDFPickerTarget.swift
      PDFSelectionRow.swift
      SecurityScopedURLAccess.swift
      PaperImportService.swift
      PaperValidation.swift
      PaperFileNames.swift

    PaperViewer/
      PaperViewerScreen.swift
      PaperViewingMode.swift
      PaperViewerPenPalette.swift
      PaperViewerToolbar.swift
      PaperViewerPenControls.swift
      PaperViewerCaptureToolbar.swift
      PaperViewerDocumentContent.swift
      SolutionsStartPagePickerSheet.swift
      PenCircle.swift
      FlaggedQuestionSaveService.swift

    FlaggedQuestions/
      FlaggedQuestionsView.swift
      SubjectFlaggedQuestionsView.swift
      FlaggedQuestionDetailView.swift
      FlaggedQuestionFilters.swift
      FlaggedQuestionExportFolderPicker.swift
      Components/
        FlaggedSubjectFolderCard.swift
        FlaggedQuestionRow.swift
        StoredImage.swift

    THSCImport/
      THSCImportView.swift
      THSCImportFilters.swift
      THSCSchoolPaperGroup.swift
      THSCImportControls.swift
      THSCPaperListView.swift
      THSCSchoolGroupRow.swift
      THSCPaperRow.swift
      THSCImportBar.swift

    RevisionBooklets/
      RevisionBookletsView.swift
      RevisionBookletFilters.swift
      RevisionBookletControls.swift
      RevisionBookletQuestionRow.swift

    Bin/
      SubjectBinView.swift
      BinRow.swift
      BinRestoreService.swift
      BinDeletionService.swift

    Settings/
      SettingsView.swift

    NESA/
      NESAPastPapersView.swift
      NESAPastPaperCatalogue.swift

  Infrastructure/
    Storage/
      AppDirectories.swift
      LocalFileStore.swift
      StoredFilePath.swift
      StorageMigrationService.swift

    PDF/
      PDFPageSelection.swift
      PDFDocumentLoader.swift
      PDFAnnotationSession.swift
      PDFViewerController.swift
      PDFViewerView.swift
      PDFPagePreviewView.swift
      SelectablePDFView.swift
      PDFCaptureOverlayView.swift
      PDFAnnotationEditing.swift
      PDFDrawingTypes.swift
      PDFInkOverlayProvider.swift
      PDFInkOverlayView.swift
      PDFInkGeometry.swift
      NSColor+Hex.swift

    Export/
      LibraryExportService.swift
      RevisionBookletService.swift
      SubjectPaperCSVService.swift

    Finder/
      FinderRevealService.swift

    SchoolCrests/
      SchoolCrestService.swift
      SchoolCrestLookupService.swift

    THSC/
      THSCImportService.swift
      THSCImportCoordinator.swift
      THSCSourcePresets.swift
```

The structure above is a target. If moving existing service files would create too much project-file churn, leave service files where they are for this run and focus on splitting large files first.

---

## 6. Baseline step

Before editing:

```bash
git status
find Sources/TrialPracticeApp -name '*.swift' -print
swift test
xcodebuild -project TrialPracticeApp.xcodeproj -scheme TrialPracticeApp -configuration Debug -destination 'platform=macOS' clean build
```

Record the baseline in the progress log.

If the working tree is not clean, continue only if the existing changes are clearly from previous accepted refactor tasks. Do not overwrite untracked user work.

---

## 7. Phase A — Split `LibraryView.swift`

Current issue: `LibraryView.swift` still contains three screens in one file.

### A1. Move `SubjectLibraryView`

Move:

```text
private struct SubjectLibraryView
```

from:

```text
Sources/TrialPracticeApp/Views/LibraryView.swift
```

to:

```text
Sources/TrialPracticeApp/Features/Library/SubjectLibraryView.swift
```

Required adjustments:

- Remove `private` if needed.
- Preserve all functions and behavior.
- Keep imports required by the moved file.
- Update Xcode project.

Run tests/build.

### A2. Move `SchoolLibraryView`

Move:

```text
private struct SchoolLibraryView
```

to:

```text
Sources/TrialPracticeApp/Features/Library/SchoolLibraryView.swift
```

Required adjustments:

- Remove `private` if needed.
- Preserve all functions and behavior.
- Keep imports required by the moved file.
- Update Xcode project.

Run tests/build.

### A3. Move `chooseExportFolder`

There may be repeated private `chooseExportFolder()` helpers in multiple files. For now, only move the Library version if it is clean.

Preferred destination:

```text
Sources/TrialPracticeApp/Features/Library/LibraryExportFolderPicker.swift
```

Allowed alternative:

- leave it in `LibraryView.swift` if moving it would require broader cross-feature changes.

Run tests/build.

---

## 8. Phase B — Split `FlaggedQuestionsView.swift`

Current issue: one file contains root view, subject view, detail view, row/card components, image component, filters, and export picker.

### B1. Move filters

Move:

```text
CategoryFilter
CompletionFilter
```

to:

```text
Sources/TrialPracticeApp/Features/FlaggedQuestions/FlaggedQuestionFilters.swift
```

If these names conflict with other filters, use:

```text
FlaggedQuestionCategoryFilter
FlaggedQuestionCompletionFilter
```

Only rename if necessary. If renamed, update references mechanically.

Run tests/build.

### B2. Move `FlaggedSubjectFolderCard`

Move to:

```text
Sources/TrialPracticeApp/Features/FlaggedQuestions/Components/FlaggedSubjectFolderCard.swift
```

Run tests/build.

### B3. Move `FlaggedQuestionRow`

Move to:

```text
Sources/TrialPracticeApp/Features/FlaggedQuestions/Components/FlaggedQuestionRow.swift
```

Run tests/build.

### B4. Move `StoredImage`

Move to:

```text
Sources/TrialPracticeApp/Features/FlaggedQuestions/Components/StoredImage.swift
```

Run tests/build.

### B5. Move `FlaggedQuestionDetailView`

Move to:

```text
Sources/TrialPracticeApp/Features/FlaggedQuestions/FlaggedQuestionDetailView.swift
```

Required:

- preserve image display;
- preserve completion toggle behavior;
- preserve soft-delete behavior;
- preserve export behavior;
- preserve Finder reveal behavior.

Run tests/build.

### B6. Move `SubjectFlaggedQuestionsView`

Move to:

```text
Sources/TrialPracticeApp/Features/FlaggedQuestions/SubjectFlaggedQuestionsView.swift
```

Run tests/build.

---

## 9. Phase C — Split `PaperViewerScreen.swift`

Current issue: the paper viewer still includes main screen, toolbar, pen controls, capture toolbar, document content, solution picker, and small components.

Do not change PDFKit behavior. Do not change annotation/capture logic.

### C1. Move `PaperViewingMode`

Move to:

```text
Sources/TrialPracticeApp/Features/PaperViewer/PaperViewingMode.swift
```

Run tests/build.

### C2. Move pen palette types/constants

Move:

```text
PDFPenColorChoice
pdfPenColorChoices
```

to:

```text
Sources/TrialPracticeApp/Features/PaperViewer/PaperViewerPenPalette.swift
```

Required:

- remove `private` only as needed;
- preserve existing color values exactly.

Run tests/build.

### C3. Move `PenCircle`

Move to:

```text
Sources/TrialPracticeApp/Features/PaperViewer/PenCircle.swift
```

Run tests/build.

### C4. Move `SolutionsStartPagePickerSheet`

Move to:

```text
Sources/TrialPracticeApp/Features/PaperViewer/SolutionsStartPagePickerSheet.swift
```

Required:

- preserve keyboard navigation;
- preserve slider/text field behavior;
- preserve cancel/no-solutions/confirm callbacks.

Run tests/build.

### C5. Extract toolbar into extension file

Move toolbar-related computed properties and helper functions into an extension file:

```text
Sources/TrialPracticeApp/Features/PaperViewer/PaperViewerToolbar.swift
```

Candidates:

- `viewerToolbar`
- `penToolControls`
- `penPresetControl`
- `penOptionsMenu`
- `colorBinding(for:)`

Use an extension:

```swift
extension PaperViewerScreen {
    ...
}
```

If `private` access causes issues, use `fileprivate` carefully or keep the properties in the original file. Prefer minimal access changes.

Run tests/build.

### C6. Extract capture toolbar into extension file

Move:

```text
captureToolbar
beginFlagging
finishFlagging
attemptSaveFlaggedQuestion
saveFlaggedQuestion
```

to:

```text
Sources/TrialPracticeApp/Features/PaperViewer/PaperViewerCapture.swift
```

Only do this if access-control changes stay minimal. If it becomes messy, stop after moving just the `captureToolbar` computed view.

Run tests/build.

### C7. Extract document content into extension file

Move:

```text
viewerContent
labeledDocumentView
documentView
```

to:

```text
Sources/TrialPracticeApp/Features/PaperViewer/PaperViewerDocumentContent.swift
```

Run tests/build.

---

## 10. Phase D — Split `PDFViewerView.swift`

This phase is riskier because it touches AppKit/PDFKit infrastructure. Do one move at a time and build after each move.

### D1. Move `PDFPageSelection`

Move:

```text
PDFPageSelection
extension PDFPageSelection
```

to:

```text
Sources/TrialPracticeApp/Infrastructure/PDF/PDFPageSelection.swift
```

Run tests/build.

### D2. Move PDF document loading helpers

Move:

```text
loadPDFDocument(url:selection:)
loadPDFDocument(from:selection:)
```

to:

```text
Sources/TrialPracticeApp/Infrastructure/PDF/PDFDocumentLoader.swift
```

Run tests/build.

### D3. Move `PDFAnnotationSession` and persistence error

Move:

```text
PDFAnnotationSession
PDFAnnotationPersistenceError
```

to:

```text
Sources/TrialPracticeApp/Infrastructure/PDF/PDFAnnotationSession.swift
```

If `PDFAnnotationPersistenceError` is also used by `SelectablePDFView`, either:

- make it internal in the new file; or
- move it to `PDFAnnotationPersistenceError.swift`.

Run tests/build.

### D4. Move `PDFViewerController`

Move to:

```text
Sources/TrialPracticeApp/Infrastructure/PDF/PDFViewerController.swift
```

Run tests/build.

### D5. Move `PDFPagePreviewView`

Move to:

```text
Sources/TrialPracticeApp/Infrastructure/PDF/PDFPagePreviewView.swift
```

Run tests/build.

### D6. Move `PDFCaptureOverlayView`

Move to:

```text
Sources/TrialPracticeApp/Infrastructure/PDF/PDFCaptureOverlayView.swift
```

Run tests/build.

### D7. Move `SelectablePDFView`

Move to:

```text
Sources/TrialPracticeApp/Infrastructure/PDF/SelectablePDFView.swift
```

Required:

- preserve annotation commit behavior;
- preserve eraser behavior;
- preserve page selection behavior;
- preserve drawing mode behavior.

Run tests/build.

### D8. Split annotation editing helpers if clean

Move these methods/helpers out only if clean:

```text
makeInkAnnotation
isInkAnnotation
commitInkStroke
eraseInkAnnotation
NSRect.distance(to:)
```

Possible destination:

```text
Sources/TrialPracticeApp/Infrastructure/PDF/PDFAnnotationEditing.swift
```

This may require an extension on `SelectablePDFView`.

If this causes access-control problems, skip this step.

Run tests/build.

---

## 11. Phase E — Split `PDFDrawingSupport.swift`

Current issue: this file contains drawing types, overlay provider, overlay view, geometry helpers, ink hit testing, and `NSColor` hex conversion.

### E1. Move drawing types

Move:

```text
PDFDrawingTool
PDFPenConfiguration
PDFInkStroke
```

to:

```text
Sources/TrialPracticeApp/Infrastructure/PDF/PDFDrawingTypes.swift
```

Run tests/build.

### E2. Move `PDFInkOverlayProvider`

Move to:

```text
Sources/TrialPracticeApp/Infrastructure/PDF/PDFInkOverlayProvider.swift
```

Run tests/build.

### E3. Move `PDFInkOverlayView`

Move to:

```text
Sources/TrialPracticeApp/Infrastructure/PDF/PDFInkOverlayView.swift
```

If it is private and only used by `PDFInkOverlayProvider`, either:

- keep it in provider file; or
- make it internal only if necessary.

Run tests/build.

### E4. Move geometry helpers

Move:

```text
smoothedPath
decimatedPoints
inkAnnotation
approximatePoints
cubicBezierPoint
distanceFromPointToSegment
```

to:

```text
Sources/TrialPracticeApp/Infrastructure/PDF/PDFInkGeometry.swift
```

Run tests/build.

### E5. Move `NSColor` hex extension

Move:

```text
extension NSColor
```

to:

```text
Sources/TrialPracticeApp/Infrastructure/PDF/NSColor+Hex.swift
```

Run tests/build.

---

## 12. Phase F — Split `THSCImportView.swift`

Current issue: the THSC import view contains filters, grouping models, controls, list rows, import bar, loading, selection, conflict detection, and import start logic.

Do not change network behavior. Do not change import behavior.

### F1. Move filters/group models

Move:

```text
THSCSolutionsFilter
THSCSchoolPaperGroup
String.normalizedTHSCSchoolGroupID
```

to:

```text
Sources/TrialPracticeApp/Features/THSCImport/THSCImportModels.swift
```

Run tests/build.

### F2. Extract controls

Move:

```text
controls
```

to extension file:

```text
Sources/TrialPracticeApp/Features/THSCImport/THSCImportControls.swift
```

Run tests/build.

### F3. Extract paper list

Move:

```text
paperList
schoolGroupRow(_:)
paperRow(_:)
```

to:

```text
Sources/TrialPracticeApp/Features/THSCImport/THSCPaperListView.swift
```

Use an extension on `THSCImportView` unless a standalone subview is easy.

Run tests/build.

### F4. Extract import bar

Move:

```text
importBar
```

to:

```text
Sources/TrialPracticeApp/Features/THSCImport/THSCImportBar.swift
```

Run tests/build.

Only after these compile, consider extracting selection logic. If extracting selection logic requires broader architecture work, skip it.

---

## 13. Phase G — Split `RevisionBookletsView.swift`

Current issue: not huge, but it contains filters, controls, row display, export orchestration.

### G1. Move filters

Move:

```text
BookletCategoryFilter
BookletCompletionFilter
```

to:

```text
Sources/TrialPracticeApp/Features/RevisionBooklets/RevisionBookletFilters.swift
```

Run tests/build.

### G2. Extract controls

Move:

```text
exportControls
```

to extension file:

```text
Sources/TrialPracticeApp/Features/RevisionBooklets/RevisionBookletControls.swift
```

Run tests/build.

### G3. Extract row

Move the row UI inside `List(filteredQuestions)` to a small component:

```text
Sources/TrialPracticeApp/Features/RevisionBooklets/RevisionBookletQuestionRow.swift
```

Run tests/build.

---

## 14. Phase H — Split `AddPaperView.swift`

Do this only if all previous phases pass and there is still time.

### H1. Move `PDFPickerTarget`

Move to:

```text
Sources/TrialPracticeApp/Features/PaperImport/PDFPickerTarget.swift
```

Run tests/build.

### H2. Move `PDFSelectionRow`

Move to:

```text
Sources/TrialPracticeApp/Features/PaperImport/PDFSelectionRow.swift
```

Run tests/build.

### H3. Move security scoped helper

Move:

```text
withSecurityScopedAccess
```

to:

```text
Sources/TrialPracticeApp/Features/PaperImport/SecurityScopedURLAccess.swift
```

Run tests/build.

Do not extract `importPaper()` in this overnight run unless every previous phase passed and the extraction is very small. It coordinates SwiftData, file import, duplicate checks, and rollback, so it is higher risk.

---

## 15. Phase I — Small cleanup only if everything passes

Only do these if all previous phases pass.

### I1. Fix leading import whitespace

Fix the leading whitespace before `import SwiftData` in:

```text
Sources/TrialPracticeApp/Views/SubjectBinView.swift
```

Run tests/build.

### I2. Move `THSCImportProgressBar`

Move from `MainNavigationView.swift` to:

```text
Sources/TrialPracticeApp/Features/THSCImport/THSCImportProgressBar.swift
```

Run tests/build.

Do not do additional cleanup.

---

## 16. Progress log

Codex must update this section after each completed step.

Use this format:

```md
### Step A1 — Move SubjectLibraryView
Status: Completed / Skipped / Failed
Files changed:
- ...
Project file updated: yes/no
Checks:
- swift test: passed/failed/not run
- xcodebuild: passed/failed/not run
Notes:
- ...
```

### Baseline
Status: Completed
Files changed:
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: no
Checks:
- git status: untracked docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md only
- find Sources/TrialPracticeApp -name '*.swift' -print: completed
- swift test: passed
- xcodebuild: passed
Notes:
- Baseline tree is otherwise clean on main before refactor edits.

### Step A1 — Move SubjectLibraryView
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/Library/SubjectLibraryView.swift
- Sources/TrialPracticeApp/Views/LibraryView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved SubjectLibraryView without behavior changes.
- Renamed the library export picker helper to chooseLibraryExportFolder() to avoid colliding with another feature's file-private helper after cross-file access became necessary.

### Step A2 — Move SchoolLibraryView
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/Library/SchoolLibraryView.swift
- Sources/TrialPracticeApp/Views/LibraryView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved SchoolLibraryView without changing paper completion, soft-delete, Finder reveal, or export behavior.

### Step A3 — Move Library chooseExportFolder
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/Library/LibraryExportFolderPicker.swift
- Sources/TrialPracticeApp/Views/LibraryView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved the library export folder picker as chooseLibraryExportFolder(), preserving the folder-only NSOpenPanel behavior.
- swift test initially hit a .build/build.db disk I/O error; swift package clean cleared generated SwiftPM build state, then swift test passed.

### Step B1 — Move flagged question filters
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/FlaggedQuestions/FlaggedQuestionFilters.swift
- Sources/TrialPracticeApp/Views/FlaggedQuestionsView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved CategoryFilter and CompletionFilter without renaming because there were no conflicts.

### Step B2 — Move FlaggedSubjectFolderCard
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/FlaggedQuestions/Components/FlaggedSubjectFolderCard.swift
- Sources/TrialPracticeApp/Views/FlaggedQuestionsView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved the folder card component without changing the displayed counts or styling.

### Step B3 — Move FlaggedQuestionRow
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/FlaggedQuestions/Components/FlaggedQuestionRow.swift
- Sources/TrialPracticeApp/Views/FlaggedQuestionsView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved the row component without changing thumbnail, category badge, or completion display behavior.
- Temporarily made StoredImage internal while it remained in FlaggedQuestionsView.swift; B4 moves it into its own component file.

### Step B4 — Move StoredImage
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/FlaggedQuestions/Components/StoredImage.swift
- Sources/TrialPracticeApp/Views/FlaggedQuestionsView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved the stored image component without changing the NSImage loading path or missing-image fallback.

### Step B5 — Move FlaggedQuestionDetailView
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/FlaggedQuestions/FlaggedQuestionDetailView.swift
- Sources/TrialPracticeApp/Features/FlaggedQuestions/FlaggedQuestionExportFolderPicker.swift
- Sources/TrialPracticeApp/Views/FlaggedQuestionsView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved the detail view without changing image display, completion rollback, soft-delete, Finder reveal, or flagged-question export behavior.
- Moved the flagged-question export picker into its own feature file and renamed the helper to avoid colliding with other export picker helpers.

### Step B6 — Move SubjectFlaggedQuestionsView
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/FlaggedQuestions/SubjectFlaggedQuestionsView.swift
- Sources/TrialPracticeApp/Views/FlaggedQuestionsView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved the subject flagged-questions list without changing active-paper filtering, search/filter logic, context-menu reveal, or export behavior.
- The original FlaggedQuestionsView.swift now contains only the root subject-folder grid/navigation surface.

### Step C1 — Move PaperViewingMode
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/PaperViewer/PaperViewingMode.swift
- Sources/TrialPracticeApp/Views/PaperViewerScreen.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved the viewing mode enum without changing cases, raw values, or Identifiable behavior.

### Step C2 — Move pen palette
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/PaperViewer/PaperViewerPenPalette.swift
- Sources/TrialPracticeApp/Views/PaperViewerScreen.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved PDFPenColorChoice and pdfPenColorChoices without changing any pen color names or hex values.

### Step C3 — Move PenCircle
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/PaperViewer/PenCircle.swift
- Sources/TrialPracticeApp/Views/PaperViewerScreen.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved the pen swatch view without changing color rendering, diameter clamping, or layout dimensions.

### Step C4 — Move SolutionsStartPagePickerSheet
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/PaperViewer/SolutionsStartPagePickerSheet.swift
- Sources/TrialPracticeApp/Views/PaperViewerScreen.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved the solutions start page picker sheet without changing keyboard navigation, slider/text field clamping, preview rendering, or cancel/no-solutions/confirm callbacks.

### Step C5 — Extract PaperViewer toolbar
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/PaperViewer/PaperViewerToolbar.swift
- Sources/TrialPracticeApp/Views/PaperViewerScreen.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved viewerToolbar, penToolControls, penPresetControl, penOptionsMenu, and colorBinding into a PaperViewerScreen extension.
- Access changes were limited to toolbar-facing state and helper methods; save, reveal, export, and capture behavior stayed unchanged.

### Step C6 — Extract PaperViewer capture
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/PaperViewer/PaperViewerCapture.swift
- Sources/TrialPracticeApp/Views/PaperViewerScreen.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Used the runbook fallback and moved only captureToolbar into a PaperViewerScreen extension.
- Kept beginFlagging, finishFlagging, validation, and saveFlaggedQuestion in the original file to avoid broad access changes around PDF capture and SwiftData persistence.

### Step C7 — Extract PaperViewer document content
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/PaperViewer/PaperViewerDocumentContent.swift
- Sources/TrialPracticeApp/Views/PaperViewerScreen.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved viewerContent, labeledDocumentView, and documentView into a PaperViewerScreen extension.
- PDFViewerView construction, annotation dirty marking, and annotation error propagation remain unchanged.

### Step D1 — Move PDFPageSelection
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Infrastructure/PDF/PDFPageSelection.swift
- Sources/TrialPracticeApp/Views/PDFViewerView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved PDFPageSelection and its displayed-page to source-page mapping extension into Infrastructure/PDF.
- No PDF loading, rendering, annotation, or capture behavior changed.

### Step D2 — Move PDF document loading helpers
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Infrastructure/PDF/PDFDocumentLoader.swift
- Sources/TrialPracticeApp/Views/PDFViewerView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved loadPDFDocument(url:selection:) and loadPDFDocument(from:selection:) into Infrastructure/PDF.
- Preserved the existing page range calculations and PDFDocument page insertion behavior.

### Step D3 — Move PDFAnnotationSession
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Infrastructure/PDF/PDFAnnotationSession.swift
- Sources/TrialPracticeApp/Views/PDFViewerView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved PDFAnnotationSession into Infrastructure/PDF.
- Moved PDFAnnotationPersistenceError with the session and made it internal so SelectablePDFView can continue reporting the same annotation-open failure.

### Step D4 — Move PDFViewerController
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Infrastructure/PDF/PDFViewerController.swift
- Sources/TrialPracticeApp/Views/PDFViewerView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved PDFViewerController into Infrastructure/PDF.
- Made PDFCaptureOverlayView internal while it remains in PDFViewerView.swift so the moved controller can continue owning the overlay without changing capture behavior.

### Step D5 — Move PDFPagePreviewView
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Infrastructure/PDF/PDFPagePreviewView.swift
- Sources/TrialPracticeApp/Views/PDFViewerView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved PDFPagePreviewView and its Coordinator into Infrastructure/PDF.
- Preserved its PDF loading, page clamping, and auto-scaling behavior.

### Step D6 — Move PDFCaptureOverlayView
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Infrastructure/PDF/PDFCaptureOverlayView.swift
- Sources/TrialPracticeApp/Views/PDFViewerView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed after `swift package clean` cleared an unrelated `.build/build.db` disk I/O error
- xcodebuild: passed
Notes:
- Moved PDFCaptureOverlayView and its private drag/page-location helpers into Infrastructure/PDF.
- Preserved capture boundary defaults, drag spacing, cursor hit tolerance, and normalized page-range calculations.

### Step D7 — Move SelectablePDFView
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Infrastructure/PDF/SelectablePDFView.swift
- Sources/TrialPracticeApp/Views/PDFViewerView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved SelectablePDFView into Infrastructure/PDF.
- Preserved annotation commit, eraser, page selection, drawing mode, and overlay provider linkage.

### Step D8 — Split annotation editing helpers
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Infrastructure/PDF/PDFAnnotationEditing.swift
- Sources/TrialPracticeApp/Infrastructure/PDF/SelectablePDFView.swift
- Sources/TrialPracticeApp/Views/PDFViewerView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved SelectablePDFView annotation commit, eraser, ink annotation construction, and ink detection helpers into PDFAnnotationEditing.swift.
- Moved the existing NSRect.distance(to:) helper into the same annotation editing file without changing behavior.

### Step E1 — Move drawing types
Status: Stopped - xcodebuild blocked
Files changed:
- Sources/TrialPracticeApp/Infrastructure/PDF/PDFDrawingTypes.swift
- Sources/TrialPracticeApp/Infrastructure/PDF/PDFDrawingSupport.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: blocked; the required clean build hung repeatedly after printing only the command invocation, before destination selection or compilation
Failure summary:
- Attempted the required xcodebuild clean build, interrupted after it stayed silent for several minutes.
- Retried the same command, also hung at the same point.
- `xcodebuild -project TrialPracticeApp.xcodeproj -list` also hung after printing only the command invocation.
- `plutil -lint TrialPracticeApp.xcodeproj/project.pbxproj` passed, and the new PBX entries were present in file references, the PDF group, and target sources.
- An explicit escalated retry of the required build command also hung at the same point and was interrupted.
Likely cause:
- External Xcode/project service or workspace filesystem hang, not a Swift compile error from the extraction.
Safest next step:
- Reopen/restart Xcode build services or the workspace sync provider, then rerun the required xcodebuild command before continuing with E2.

### Step E2 — Move PDFInkOverlayProvider
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Infrastructure/PDF/PDFInkOverlayProvider.swift
- Sources/TrialPracticeApp/Infrastructure/PDF/PDFDrawingSupport.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed after `swift package clean`
- xcodebuild: passed
Notes:
- Moved PDFInkOverlayProvider into its own PDF infrastructure file.
- Changed PDFInkOverlayView from private to internal so the moved provider can keep using the existing overlay view until E3.
- The first `swift test` attempt hit an unrelated SwiftPM/OneDrive I/O timeout reading `.build/plugin-tools.yaml`; `swift package clean` cleared the generated cache and the rerun passed.

### Step E3 — Move PDFInkOverlayView
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Infrastructure/PDF/PDFInkOverlayView.swift
- Sources/TrialPracticeApp/Infrastructure/PDF/PDFDrawingSupport.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved PDFInkOverlayView into its own PDF infrastructure file.
- Preserved mouse handling, stroke decimation, eraser callback, and drawing behavior.

### Step E4 — Move geometry helpers
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Infrastructure/PDF/PDFInkGeometry.swift
- Sources/TrialPracticeApp/Infrastructure/PDF/PDFDrawingSupport.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved smoothedPath, decimatedPoints, inkAnnotation, approximatePoints, cubicBezierPoint, and distanceFromPointToSegment into PDFInkGeometry.swift.
- Kept the helper visibility the same where possible: public-to-module entry points remain internal, approximation helpers remain private within the new file.

### Step E5 — Move NSColor hex extension
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Infrastructure/PDF/NSColor+Hex.swift
- Sources/TrialPracticeApp/Infrastructure/PDF/PDFDrawingSupport.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved the NSColor hex initializer and hexRGBString computed property to NSColor+Hex.swift.
- Removed the now-empty PDFDrawingSupport.swift from the filesystem, PDF group, and target sources build phase.

### Step F1 — Move THSC filters/group models
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/THSCImport/THSCImportModels.swift
- Sources/TrialPracticeApp/Views/THSCImportView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved THSCSolutionsFilter, THSCSchoolPaperGroup, and String.normalizedTHSCSchoolGroupID into THSCImportModels.swift.
- Removed private access from the moved group/string helper as required by file extraction.

### Step F2 — Extract THSC controls
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/THSCImport/THSCImportControls.swift
- Sources/TrialPracticeApp/Views/THSCImportView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved the THSC import controls view builder into THSCImportControls.swift.
- Kept controls as an extension on THSCImportView so bindings and existing loading actions are preserved.
- Removed private access only from state/computed helpers needed by the extracted controls extension.
- The first xcodebuild attempt failed with an unrelated DerivedData build database disk I/O error; rerunning the exact command passed.

### Step F3 — Extract THSC paper list
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/THSCImport/THSCPaperListView.swift
- Sources/TrialPracticeApp/Views/THSCImportView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed on retry
Notes:
- Moved paperList, schoolGroupRow(_:), and paperRow(_:) into THSCPaperListView.swift.
- Kept the list builders as an extension on THSCImportView so existing selection, import-state, and conflict helpers are reused unchanged.
- The first xcodebuild attempt compiled Swift successfully but failed at final link output with a DerivedData `ld: open() failed, errno=2`; rerunning the exact command passed.

### Step F4 — Extract THSC import bar
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/THSCImport/THSCImportBar.swift
- Sources/TrialPracticeApp/Views/THSCImportView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved the bottom THSC import bar into THSCImportBar.swift as a THSCImportView extension.
- Preserved the existing show-already-imported toggle, status message display, and import button enablement.
- Kept importSelectedPapers() and import identifier logic in THSCImportView; only the view builder moved.

### Step G1 — Move revision booklet filters
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/RevisionBooklets/RevisionBookletFilters.swift
- Sources/TrialPracticeApp/Views/RevisionBookletsView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed after removing the sync-resurrected legacy PDFDrawingSupport.swift file and running `swift package clean`
- xcodebuild: passed
Notes:
- Moved BookletCategoryFilter and BookletCompletionFilter out of RevisionBookletsView.swift.
- Preserved the existing raw values and Identifiable behavior.
- SwiftPM initially kept discovering the deleted PDFDrawingSupport.swift after it reappeared on disk; removing it again restored the intended split-file state.
- No SwiftData model, storage, export, or migration behavior changed.

### Step G2 — Extract revision booklet controls
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/RevisionBooklets/RevisionBookletControls.swift
- Sources/TrialPracticeApp/Views/RevisionBookletsView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: first attempt failed because DerivedData build.db was locked; immediate retry passed
Notes:
- Moved exportControls into a RevisionBookletsView extension.
- Preserved the subject, category, completion, count, progress, and Export PDF controls.
- Kept exportBooklet() and export path behavior in RevisionBookletsView; only the view builder moved.
- No SwiftData model, storage, export, or migration behavior changed.

### Step G3 — Extract revision booklet row
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/RevisionBooklets/RevisionBookletQuestionRow.swift
- Sources/TrialPracticeApp/Views/RevisionBookletsView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved the inline filtered question row UI into RevisionBookletQuestionRow.
- Preserved the category icon/color, school/year subtitle, category label, solution indicator, and row padding.
- No SwiftData model, storage, export, or migration behavior changed.

### Step H1 — Move PDFPickerTarget
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/PaperImport/PDFPickerTarget.swift
- Sources/TrialPracticeApp/Views/AddPaperView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved PDFPickerTarget into the PaperImport feature folder.
- Preserved the question and solutions picker target cases.
- No SwiftData model, import, storage, migration, or deletion behavior changed.

### Step H2 — Move PDFSelectionRow
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/PaperImport/PDFSelectionRow.swift
- Sources/TrialPracticeApp/Views/AddPaperView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved the PDF selection row UI into the PaperImport feature folder.
- Preserved the selected filename fallback text, choose/replace labels, line limit, and button action.
- No SwiftData model, import, storage, migration, or deletion behavior changed.

### Step H3 — Move security scoped helper
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/PaperImport/SecurityScopedURLAccess.swift
- Sources/TrialPracticeApp/Views/AddPaperView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved the single-URL withSecurityScopedAccess helper into the PaperImport feature folder.
- Preserved the startAccessingSecurityScopedResource/defer/stop behavior exactly.
- Left the multi-URL import scoped-access block in AddPaperView unchanged.
- No SwiftData model, import, storage, migration, or deletion behavior changed.

### Step I1 — Fix leading import whitespace
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Views/SubjectBinView.swift
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: no
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Removed the leading whitespace before import SwiftData.
- No behavior, SwiftData model, storage, migration, import/export, PDF, capture, or deletion behavior changed.

### Step I2 — Move THSCImportProgressBar
Status: Completed
Files changed:
- Sources/TrialPracticeApp/Features/THSCImport/THSCImportProgressBar.swift
- Sources/TrialPracticeApp/Views/MainNavigationView.swift
- TrialPracticeApp.xcodeproj/project.pbxproj
- docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md
Project file updated: yes
Checks:
- swift test: passed
- xcodebuild: passed
Notes:
- Moved THSCImportProgressBar into the THSCImport feature folder.
- Preserved the import-in-progress condition, progress values, text, sizing, bar background, and divider.
- No SwiftData model, import, storage, migration, export, PDF, capture, or deletion behavior changed.

---

## 17. Final response required from Codex

At the end, whether successful or stopped early, provide:

1. Summary of completed phases.
2. Summary of skipped phases and why.
3. Files changed.
4. Whether `project.pbxproj` was updated.
5. Final `swift test` result.
6. Final Xcode build result.
7. Any known risks.
8. Any manual review areas.
9. Suggested commit message.
10. Suggested next Codex task.

Do not commit automatically.

---

# Starter prompt to paste into Codex

```text
Read `AGENTS.md` and `docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md`.

I want you to work through the overnight runbook sequentially.

Goal:
Split the remaining large Swift files into smaller feature/infrastructure files while preserving behavior.

Important:
- This is a refactor-only file-splitting task.
- Do not change SwiftData model schemas.
- Do not change storage paths, migrations, import/export behavior, PDF annotation behavior, capture behavior, or deletion behavior.
- Do not do project-generation migration work.
- Do not introduce XcodeGen, Tuist, or SwiftPM-only project changes.
- Keep the current manual `.xcodeproj`.
- For every new Swift file, update `TrialPracticeApp.xcodeproj/project.pbxproj` so the file is in the `TrialPracticeApp` target sources build phase.
- Do not commit automatically.

Working method:
1. Start with the baseline step in the runbook.
2. Work through the checklist in order.
3. After each step or small batch, run:
   - `swift test`
   - `xcodebuild -project TrialPracticeApp.xcodeproj -scheme TrialPracticeApp -configuration Debug -destination 'platform=macOS' clean build`
4. Update the progress log inside `docs/CODEX_OVERNIGHT_FILE_SPLIT_RUNBOOK.md`.
5. Continue only if the checks pass, or if a failure is clearly unrelated to the extraction.
6. If the same build/test command fails after two focused extraction-related fixes, stop and report.
7. If a step becomes risky or requires behavior changes, skip that step, record why, and continue to the next safe step.

Start now with the baseline step, then proceed through the runbook.
```
