# TrialPapersApp Codex Refactor Playbook

This document is written to be uploaded to Codex or committed into the repository as a working plan. It is intentionally explicit because the goal is not to ask Codex to "make the code better" in one huge step. The goal is to use Codex as a coding teammate: give it repeatable rules, split work into small pull-request-sized tasks, require tests/builds, and keep every change reviewable.

Repository: `JacobTurtledove/TrialPapersApp`

App: Native macOS SwiftUI / SwiftData / PDFKit app for organising HSC trial papers, importing PDFs, capturing flagged questions, and exporting revision materials.

---

## 1. How to use this document

Do not paste this entire file into a single Codex task and ask it to refactor the app.

Instead:

1. Add a short `AGENTS.md` file at the repository root with the standing instructions from section 3.
2. Add this file under `docs/CODEX_REFACTOR_PLAYBOOK.md`.
3. Start each Codex task from one of the task briefs in section 8.
4. Ask Codex to first inspect the relevant files and produce a plan.
5. Approve only one narrow task at a time.
6. Require tests/build commands after every code change.
7. Review the diff manually before merging.
8. Keep dangerous migrations, data deletion, filesystem changes, SwiftData model changes, and Xcode project changes isolated in their own tasks.

The core workflow is:

```text
Plan -> implement small change -> run tests/build -> review diff -> commit -> next task
```

If Codex gets stuck, ask it to stop, summarize what changed, list failing checks, and propose the next smallest fix. Do not ask it to keep expanding scope until "everything is done".

---

## 2. Current repo assessment

The app has a coherent product direction, but the code has several structural issues that make future Codex work riskier than it needs to be.

### 2.1 Good foundations

- The product scope is clear: local-first HSC trial paper library, PDF review, flagged questions, revision booklets, and exports.
- The README is unusually thorough.
- There is a Swift Package layout and an Xcode project.
- There are tests covering important pieces of the app, according to the README.
- File storage is mostly centralized under Application Support.
- Several services already exist for import, export, capture, CSV, Finder reveal, and THSC import.

### 2.2 Main problems to fix

1. **Destructive startup migration code**
   - `RootView.initializeApplicationSupportStorageIfNeeded()` can delete Application Support contents and SwiftData records based on a single app-storage flag.
   - This is risky and should become a versioned migration system or be removed if the migration is no longer needed.

2. **Stale folder-selection architecture**
   - The README says the app now uses Application Support only.
   - `AppState` still contains old security-scoped root folder selection code.
   - This creates confusion and increases the chance that Codex modifies the wrong storage path logic.

3. **Huge SwiftUI files**
   - `LibraryView.swift`, `PaperViewerScreen.swift`, `PDFViewerView.swift`, `FlaggedQuestionsView.swift`, and `THSCImportView.swift` mix UI, domain logic, persistence, filesystem code, and view components.
   - These need to be split by feature and responsibility.

4. **Weak domain modelling**
   - `Paper` and `FlaggedQuestion` store raw UUID references rather than SwiftData relationships.
   - String paths and string categories are passed around widely.
   - Filename normalization drops numbers, which can cause subject-name collisions.

5. **Model does not match current storage design**
   - Current app design stores one complete PDF per paper.
   - `Paper` still contains `questionPDFRelativePath`, `solutionsPDFRelativePath`, and `combinedPDFRelativePath`, often all pointing to the same file.
   - This should be simplified eventually, but it is a migration-sensitive change.

6. **Manual Xcode project synchronization**
   - New Swift files need to be added to both SwiftPM and `project.pbxproj`.
   - This is error-prone for Codex.
   - A generated project workflow or SwiftPM-first project should be considered later.

7. **Hard-coded external catalogues**
   - NESA course links and THSC sources are hard-coded in Swift files.
   - This is acceptable for now, but should eventually move to data/config files if the lists change often.

---

## 3. Suggested root `AGENTS.md`

Create this file at the repository root:

```md
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
```

If only documentation changed, no build is required unless the change touches project configuration.

If tests cannot run in the environment, clearly state:
- what command was attempted;
- why it failed;
- whether the failure appears related to the change.

## Commit expectations

For each task:
- keep the diff focused;
- include tests when changing behavior;
- do not mix refactor + feature + migration unless requested;
- leave the working tree clean;
- summarize changed files and test results.
```

---

## 4. Recommended Codex workflow

### 4.1 Use planning tasks before implementation tasks

For risky changes, start with a no-edit task:

```text
Read docs/CODEX_REFACTOR_PLAYBOOK.md and inspect the current storage and model code. Do not edit files. Produce a phased refactor plan with risk level, affected files, and suggested test commands.
```

Then use the plan to start one narrow implementation task.

### 4.2 Use one thread per task

Good task sizes:

- "Remove stale AppState folder-selection API after confirming nothing calls it."
- "Add tests for NameNormalizer preserving digits."
- "Extract PDFAnnotationSession into Infrastructure/PDF without behavior changes."
- "Move Library card views into separate files without changing behavior."
- "Introduce StorageMigrationService but do not change SwiftData models."

Bad task sizes:

- "Clean up the whole architecture."
- "Make all code professional."
- "Refactor storage and fix all bugs."
- "Reorganize every file and update the model."

### 4.3 Use worktrees for parallel Codex tasks

Worktrees are useful when two tasks touch different areas. Safe parallel examples:

- Task A: `NameNormalizer` tests and implementation.
- Task B: move NESA catalogue to its own feature/service file.
- Task C: split card subviews out of `LibraryView`.

Do not run parallel tasks that touch the same file. For this repo, avoid parallel edits to:

- `LibraryView.swift`
- `PaperViewerScreen.swift`
- `PDFViewerView.swift`
- `project.pbxproj`
- SwiftData model files
- storage/migration files

### 4.4 Use the review pane and inline comments

After Codex produces a diff, review it line-by-line. Use inline comments rather than another broad prompt.

Good follow-up:

```text
Address the inline comments only. Keep the scope minimal. Do not rename additional files or change behavior outside the commented lines. Re-run swift test.
```

Bad follow-up:

```text
Looks good, also make the rest of the code cleaner.
```

### 4.5 Use `/plan` or planning mode for major work

For each refactor phase, ask Codex to produce a plan before implementation.

Example:

```text
/plan Read docs/CODEX_REFACTOR_PLAYBOOK.md. Plan Task 04: extract storage migration logic from RootView. Do not edit files yet. Include the exact files you would change, the new types you would create, and how you would test this.
```

### 4.6 Use goal mode only for narrow measurable objectives

Goal mode can help when the task has many steps but a clear definition of done.

Good goal:

```text
/goal Extract PDF annotation persistence from PDFViewerView.swift into Infrastructure/PDF/PDFAnnotationSession.swift without changing behavior. The app must compile and existing tests must pass.
```

Bad goal:

```text
/goal Refactor the entire app architecture.
```

---

## 5. Target architecture

The repo does not need a perfect architecture immediately. The target is a pragmatic feature-based structure that lets Codex work safely.

Suggested final structure:

```text
Sources/TrialPracticeApp/
  App/
    TrialPracticeApp.swift
    AppState.swift
    AppNavigationCoordinator.swift
    AppBuild.swift

  Domain/
    Models/
      Subject.swift
      School.swift
      Paper.swift
      FlaggedQuestion.swift
      THSCImportRecord.swift
    ValueObjects/
      PaperIdentity.swift
      StoredFilePath.swift
      QuestionNumber.swift
      SubjectColor.swift
    Validation/
      NameNormalizer.swift
      PaperValidation.swift

  Infrastructure/
    Storage/
      AppDirectories.swift
      LocalFileStore.swift
      StorageMigrationService.swift
      StoredFilePathResolver.swift
    PDF/
      PDFDocumentLoader.swift
      PDFAnnotationSession.swift
      PDFCaptureRange.swift
      PDFCaptureService.swift
      PDFDrawingTypes.swift
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
      THSCSource.swift
      THSCPaperListing.swift
      THSCImportService.swift
      THSCImportCoordinator.swift

  Features/
    Library/
      LibraryView.swift
      SubjectLibraryView.swift
      SchoolLibraryView.swift
      LibraryViewModel.swift
      Components/
        LibraryFolderCard.swift
        SchoolFolderCard.swift
        PaperLibraryCard.swift
        SubjectEditor.swift
    PaperImport/
      AddPaperView.swift
      AddPaperViewModel.swift
      PaperImportService.swift
      PaperFileNames.swift
    PaperViewer/
      PaperViewerScreen.swift
      PaperViewerViewModel.swift
      PDFViewerView.swift
      PDFViewerController.swift
      CaptureToolbar.swift
      ViewerToolbar.swift
      SolutionsStartPagePickerSheet.swift
    FlaggedQuestions/
      FlaggedQuestionsView.swift
      SubjectFlaggedQuestionsView.swift
      FlaggedQuestionDetailView.swift
      Components/
    RevisionBooklets/
      RevisionBookletsView.swift
    Bin/
      SubjectBinView.swift
      BinDeletionService.swift
    Settings/
      SettingsView.swift
    NESA/
      NESAPastPapersView.swift
      NESAPastPaperCatalogue.swift
    THSCImport/
      THSCImportView.swift
      THSCImportViewModel.swift

Tests/TrialPracticeAppTests/
  Domain/
  Infrastructure/
  Features/
```

Do not try to move the whole repo to this layout in one task. Move gradually.

---

## 6. Priorities

### Priority 0: Protect user data

First fix anything that might delete or corrupt user data.

- Replace destructive first-run initialization.
- Make storage migrations versioned.
- Keep developer reset explicit and isolated.
- Add tests around path containment and deletion staging.

### Priority 1: Stabilize basic domain rules

- Fix filename normalization to preserve digits.
- Add tests for subject/school name collisions.
- Add typed value objects where cheap.

### Priority 2: Split giant files without changing behavior

- Extract subviews first.
- Extract view models second.
- Extract services/use cases third.
- Keep each extraction behavior-preserving.

### Priority 3: Simplify paper PDF model

This is migration-sensitive. Do it only after storage and tests are stable.

Target:
- one PDF path per paper;
- optional `solutionsStartPage`;
- explicit `hasSolutions`.

### Priority 4: Improve project generation

Consider XcodeGen, Tuist, or SwiftPM-first structure. This is useful but lower priority than data safety.

---

## 7. Definition of done for Codex tasks

Every implementation task should finish with:

1. Summary of changes.
2. Files changed.
3. Tests/builds run.
4. Any tests/builds that could not run and why.
5. Known risks or follow-up tasks.
6. A clean Git working tree if Codex is committing.

For behavior changes, Codex should add or update tests.

For pure file moves, Codex should avoid logic changes.

For SwiftData model changes, Codex must explain migration impact before editing.

---

## 8. Task queue

The tasks below are deliberately small. Give Codex one task at a time.

---

# Task 01 — Baseline build and architecture inventory

## Goal

Get a current baseline before changing code.

## Prompt for Codex

```text
Read docs/CODEX_REFACTOR_PLAYBOOK.md and inspect the repository. Do not edit files.

Please produce a baseline report covering:
1. current source-file layout;
2. largest Swift files by line count;
3. storage-related files and responsibilities;
4. SwiftData model files and relationships/IDs;
5. current test commands from README or Package.swift;
6. whether `swift test` runs in this environment;
7. whether the Xcode Debug build command runs in this environment.

Run read-only commands only, except test/build commands. Do not modify files. If a command fails, capture the failure and explain whether it is environment-related or code-related.
```

## Acceptance criteria

- No files changed.
- Report identifies risky files.
- Report records exact test/build command results.

---

# Task 02 — Add repository AGENTS.md

## Goal

Create persistent Codex project instructions.

## Prompt for Codex

```text
Create a repository-root AGENTS.md using the guidance in docs/CODEX_REFACTOR_PLAYBOOK.md section 3.

Keep it concise enough for Codex to load regularly. Do not change application code.

After creating the file, run no build unless you changed code. Show the final AGENTS.md content in your summary.
```

## Acceptance criteria

- `AGENTS.md` exists at repo root.
- It includes storage safety, testing commands, architecture preferences, and project context.
- No app code changed.

---

# Task 03 — Make destructive startup initialization safe

## Goal

Remove or quarantine the code path that can delete app data on startup.

## Background

`RootView.initializeApplicationSupportStorageIfNeeded()` currently deletes contents of the app storage folder and deletes SwiftData records based on `didInitializeApplicationSupportFileStorage`.

This is dangerous in production.

## Prompt for Codex

```text
Read docs/CODEX_REFACTOR_PLAYBOOK.md.

Task: Make startup storage initialization safe.

Scope:
- Inspect RootView.swift, AppState.swift, AppDirectories.swift, LocalFileStore.swift, and SettingsView.swift.
- Remove or quarantine the destructive startup data deletion in RootView.
- Preserve any necessary non-destructive legacy crest migration.
- If development reset functionality is needed, keep it only behind the explicit Settings developer action.
- Do not change SwiftData model schemas in this task.
- Do not change PDF import/export behavior.

Before editing, explain the current startup flow and the specific destructive path you will remove or isolate.

After editing:
- run `swift test`;
- run the README Xcode Debug build command if available in this environment;
- summarize exactly why user data is now safer.
```

## Acceptance criteria

- App launch no longer deletes Application Support contents automatically.
- App launch no longer deletes all SwiftData records automatically.
- Developer reset still exists only as an explicit Settings action.
- Existing tests pass, or failures are explained.
- No SwiftData schema changes.

---

# Task 04 — Introduce versioned storage migration service

## Goal

Move migration logic out of views and make future migrations explicit.

## Prompt for Codex

```text
Plan and implement a small StorageMigrationService.

Scope:
- Add a new file under an appropriate Storage/Infrastructure location.
- Move non-destructive startup migration behavior out of RootView where reasonable.
- Track migration version using UserDefaults with a clear key.
- Do not delete user files in a migration.
- Do not change SwiftData schemas.
- Keep the migration service small and tested where possible.

Before editing, propose the migration version enum and explain how RootView will call it.

After editing:
- run `swift test`;
- run the Xcode Debug build command if possible.
```

## Acceptance criteria

- RootView is simpler.
- Migration logic is not embedded in the SwiftUI view.
- Migrations are versioned.
- No automatic destructive reset exists.

---

# Task 05 — Remove stale AppState root-folder selection code

## Goal

Align `AppState` with current Application Support storage design.

## Prompt for Codex

```text
Inspect AppState.swift and all references to its public API.

The README says the app now uses Application Support and no longer asks the user to choose a root folder. Remove stale root-folder selection/bookmark/security-scoped code only if it is unused.

Scope:
- Keep `rootFolderURL` or rename it only if the change remains small.
- Preserve Settings developer reset behavior.
- Preserve Application Support folder setup.
- Do not change storage layout.
- Do not change SwiftData models.
- Add or update tests if any AppState helper behavior is tested.

Before editing, list all call sites of:
- createRootFolder
- selectRootFolder
- forgetRootFolder
- needsSetup
- restoreRootFolder
- rootFolderURL

After editing:
- run `swift test`;
- run the Xcode Debug build if possible.
```

## Acceptance criteria

- Stale APIs removed or clearly marked legacy/private.
- No UI references old setup flow.
- App still resolves Application Support `Files` folder.
- Tests/build pass or failures are explained.

---

# Task 06 — Fix filename normalization to preserve digits

## Goal

Prevent collisions for subjects/schools whose names differ by numbers.

## Background

Current `NameNormalizer.filenameValue` keeps letters only. This can collapse:
- Mathematics Extension 1 / Mathematics Extension 2
- Music 1 / Music 2
- Studies of Religion 1 / Studies of Religion 2

## Prompt for Codex

```text
Fix NameNormalizer.filenameValue so it preserves letters and digits while still producing safe folder/file tokens.

Requirements:
- Preserve digits.
- Remove punctuation and separators.
- Trim whitespace through displayName normalization.
- Keep existing behavior for ordinary names where possible.
- Add tests for:
  - "Mathematics Extension 1" -> contains "1"
  - "Mathematics Extension 2" -> distinct from Extension 1
  - "Music 1" and "Music 2" remain distinct
  - punctuation does not create slashes or unsafe path separators
  - blank or punctuation-only names still produce an empty filename token

Run `swift test`.
```

## Acceptance criteria

- Digit-differentiated course names no longer collide.
- Existing tests pass.
- New tests cover the behavior.

---

# Task 07 — Extract PaperValidation and PaperFileNames

## Goal

Move import-related helpers out of `PaperImportService.swift` if they are used by UI and service code.

## Prompt for Codex

```text
Refactor only: extract PaperValidation and PaperFileNames from PaperImportService.swift into separate files under a suitable Domain/Validation or PaperImport feature folder.

Do not change behavior. Do not change public API unless needed for file visibility.

Update Package.swift or Xcode project references if required by the current project structure.

Run `swift test` and the Xcode Debug build if possible.
```

## Acceptance criteria

- `PaperImportService.swift` is smaller.
- Behavior unchanged.
- Tests/build pass or failures are explained.

---

# Task 08 — Extract Library card components

## Goal

Reduce `LibraryView.swift` size with a behavior-preserving extraction.

## Prompt for Codex

```text
Refactor only: move private card/editor subviews from LibraryView.swift into separate Swift files under a Library/Components folder or the closest existing structure.

Candidates:
- LibraryFolderCard
- SchoolFolderCard
- PaperLibraryCard
- SubjectEditor

Do not change behavior.
Do not change storage logic.
Do not change SwiftData logic.
Update project references as needed.

Run `swift test` and the Xcode Debug build if possible.
```

## Acceptance criteria

- `LibraryView.swift` is shorter.
- UI behavior unchanged.
- New files are included in both SwiftPM and Xcode project if required.
- Tests/build pass or failures are explained.

---

# Task 09 — Extract Library mutation logic into a service

## Goal

Move subject create/rename/delete operations out of `LibraryView`.

## Prompt for Codex

```text
Plan first, then implement only if the plan is straightforward.

Extract subject library mutations from LibraryView into a small service or view model:
- create subject;
- rename subject;
- move subject to bin;
- path rewriting for subject folder rename.

Do not change UI layout.
Do not change SwiftData model schemas.
Do not change file storage layout.
Keep rollback behavior.
Add tests for any pure helper extracted, especially path rewriting.

Run `swift test` and Xcode Debug build if possible.
```

## Acceptance criteria

- `LibraryView` no longer owns all mutation details.
- Rename rollback behavior remains intact.
- Tests cover path rewriting if extracted.

---

# Task 10 — Extract PDFAnnotationSession from PDFViewerView

## Goal

Separate annotation persistence from the PDF view bridge.

## Prompt for Codex

```text
Refactor only: move PDFAnnotationSession and PDFAnnotationPersistenceError if present into an Infrastructure/PDF file.

Do not change annotation behavior.
Do not change PDF drawing behavior.
Do not change PaperViewerScreen behavior except imports/references.

Update project references as needed.

Run `swift test` and Xcode Debug build if possible.
```

## Acceptance criteria

- `PDFViewerView.swift` is smaller.
- Annotation session is reusable/testable.
- Behavior unchanged.

---

# Task 11 — Split PDF drawing types and helpers

## Goal

Make `PDFViewerView.swift` more maintainable without changing behavior.

## Prompt for Codex

```text
Refactor only: split drawing-related types/helpers out of PDFViewerView.swift.

Candidates:
- PDFDrawingTool
- PDFPenConfiguration
- PDFInkStroke
- smoothedPath
- decimatedPoints
- inkAnnotation hit testing helpers
- PDFInkOverlayProvider
- PDFInkOverlayView

Keep the public behavior unchanged.
Avoid changing algorithms unless required to compile.
Update project references as needed.

Run `swift test` and Xcode Debug build if possible.
```

## Acceptance criteria

- `PDFViewerView.swift` focuses more on NSViewRepresentable/PDFView bridge.
- Drawing logic is isolated.
- Tests/build pass or failures are explained.

---

# Task 12 — Extract PaperViewer view model/use case

## Goal

Reduce `PaperViewerScreen.swift` complexity.

## Prompt for Codex

```text
Plan only first.

Inspect PaperViewerScreen.swift and identify which logic can be moved to:
- PaperViewerViewModel
- FlaggedQuestionSaveService
- PDFExport use case
- SolutionBoundary use case

Do not edit files in the first response. Produce a staged plan with the smallest first implementation task.

The plan must avoid changing PDF drawing behavior and must preserve SwiftData save/rollback behavior.
```

## Acceptance criteria

- No files changed.
- Plan identifies safe extraction boundaries.
- Follow-up tasks are small.

---

# Task 13 — Implement FlaggedQuestionSaveService

## Goal

Move flagged-question image creation + SwiftData insertion coordination out of `PaperViewerScreen`.

## Prompt for Codex

```text
Implement the first safe extraction from the PaperViewer plan: create a small service/use case for saving a flagged question.

Scope:
- Move image capture/save + FlaggedQuestion model creation coordination out of PaperViewerScreen where possible.
- Keep UI state in the view.
- Keep duplicate warning behavior unchanged.
- Preserve rollback: if SwiftData save fails, newly created images must be removed.
- Add tests for any pure path/image save rollback helpers if feasible.

Run `swift test` and Xcode Debug build if possible.
```

## Acceptance criteria

- `PaperViewerScreen.saveFlaggedQuestion()` is shorter.
- Rollback behavior remains.
- Behavior unchanged from user perspective.

---

# Task 14 — Extract THSC sources to data-like file

## Goal

Make THSC source presets easier to maintain.

## Prompt for Codex

```text
Refactor THSCSource.presets into a dedicated file.

Do not change URLs or names.
Do not change THSC parsing or download behavior.
Add a lightweight test that the presets are non-empty and IDs are unique if appropriate.

Run `swift test`.
```

## Acceptance criteria

- THSCImportService.swift is smaller.
- Source list is isolated.
- Behavior unchanged.

---

# Task 15 — Extract NESA catalogue from view

## Goal

Keep `NESAPastPapersView` as a view, not a data catalogue.

## Prompt for Codex

```text
Move NESAPastPaperCourse and NESAPastPaperCatalogue out of NESAPastPapersView.swift into separate files under a NESA feature folder or current Views/Services structure.

Do not change course names, learning areas, or URLs.
Do not change UI behavior.
Add a simple test for unique slugs if feasible.

Run `swift test` and Xcode Debug build if possible.
```

## Acceptance criteria

- `NESAPastPapersView.swift` contains mostly UI.
- Catalogue remains unchanged.

---

# Task 16 — Create StoredFilePath value object

## Goal

Begin reducing raw string path risk without a large migration.

## Prompt for Codex

```text
Plan only first.

Explore introducing a StoredFilePath value object for new code while preserving existing SwiftData string properties.

The plan should cover:
- validation rules;
- containment checks;
- conversion to/from String;
- where to use it first;
- tests;
- what not to change yet.

Do not edit files.
```

## Acceptance criteria

- No files changed.
- Plan avoids SwiftData schema changes.
- Plan identifies one low-risk first adoption point.

---

# Task 17 — Adopt StoredFilePath in export/path helpers only

## Goal

Use typed path validation in infrastructure without changing models.

## Prompt for Codex

```text
Implement StoredFilePath only inside infrastructure helpers, not SwiftData models.

Scope:
- Add StoredFilePath type.
- Use it in LocalFileStore or LibraryExportService internal helper paths where low-risk.
- Do not change stored model properties.
- Add tests for rejecting absolute paths, `..`, path traversal, and accepting normal relative paths.

Run `swift test`.
```

## Acceptance criteria

- Path traversal protections are tested.
- Model schemas unchanged.
- Existing behavior preserved.

---

# Task 18 — Plan Paper model simplification

## Goal

Design the migration from three PDF path fields to one.

## Prompt for Codex

```text
Plan only.

The app currently stores one complete PDF per paper, but Paper still has questionPDFRelativePath, solutionsPDFRelativePath, and combinedPDFRelativePath.

Design a safe migration toward:
- pdfRelativePath
- solutionsStartPage
- hasSolutions

Do not edit files.

The plan must include:
- migration risk;
- SwiftData migration approach;
- temporary compatibility accessors;
- test strategy;
- UI impact;
- import/export impact;
- rollback strategy.
```

## Acceptance criteria

- No files changed.
- Plan is specific enough to implement in multiple small tasks.
- No destructive migration is proposed.

---

# Task 19 — Add compatibility accessor for Paper PDF path

## Goal

Prepare model simplification without schema changes.

## Prompt for Codex

```text
Add a computed property to Paper, such as `primaryPDFRelativePath`, that returns combinedPDFRelativePath ?? questionPDFRelativePath.

Replace repeated inline expressions where safe:
- paper.combinedPDFRelativePath ?? paper.questionPDFRelativePath

Do not remove existing stored fields.
Do not change import behavior.
Do not change SwiftData schema.
Add tests if there is a suitable model test file.

Run `swift test` and Xcode Debug build if possible.
```

## Acceptance criteria

- Repeated PDF path logic is centralized.
- No schema change.
- Behavior unchanged.

---

# Task 20 — Split Bin deletion logic into service

## Goal

Move permanent deletion transaction coordination out of `SubjectBinView`.

## Prompt for Codex

```text
Extract permanent deletion coordination from SubjectBinView into a BinDeletionService or similar.

Scope:
- subject permanent delete;
- paper permanent delete;
- flagged question permanent delete;
- LocalFileStore deletion transaction usage;
- SwiftData delete coordination.

Keep UI confirmation dialogs unchanged.
Preserve rollback behavior.
Do not change storage layout.

Run `swift test` and Xcode Debug build if possible.
```

## Acceptance criteria

- `SubjectBinView` is mostly UI.
- Deletion rollback behavior preserved.
- Tests/build pass or failures are explained.

---

# Task 21 — Project generation plan

## Goal

Reduce the risk of Codex forgetting `project.pbxproj`.

## Prompt for Codex

```text
Plan only.

Investigate whether this repo should move to:
1. SwiftPM-first Xcode workflow;
2. XcodeGen;
3. Tuist;
4. keep current manual pbxproj.

Do not edit files.

The plan should include:
- current project constraints;
- how resources/assets/entitlements are handled;
- how tests are run;
- impact on Codex file additions;
- recommended option;
- migration steps if recommended.
```

## Acceptance criteria

- No files changed.
- Recommendation is practical for this repo.
- Does not suggest project tooling just for elegance.

---

## 9. Prompt templates

### 9.1 Planning prompt

```text
Read AGENTS.md and docs/CODEX_REFACTOR_PLAYBOOK.md.

Plan the following task without editing files:

[TASK]

Return:
1. current behavior;
2. affected files;
3. proposed smallest safe change;
4. risks;
5. test/build commands;
6. whether this should be split smaller.
```

### 9.2 Implementation prompt

```text
Read AGENTS.md and docs/CODEX_REFACTOR_PLAYBOOK.md.

Implement this task only:

[TASK]

Constraints:
- keep the diff minimal;
- do not change unrelated behavior;
- do not perform destructive data operations;
- add/update tests for behavior changes;
- update Xcode project references if new Swift files are added.

Before editing, briefly state your plan.
After editing, run:
- swift test
- xcodebuild -project TrialPracticeApp.xcodeproj -scheme TrialPracticeApp -configuration Debug -destination 'platform=macOS' build

If a command cannot run in this environment, explain why.
```

### 9.3 Review prompt

```text
Review the current uncommitted diff.

Focus on:
- accidental behavior changes;
- data loss risk;
- SwiftData migration risk;
- missing tests;
- files not added to project.pbxproj;
- path traversal/security issues;
- over-broad refactors.

Do not edit files unless I explicitly ask.
```

### 9.4 Fix after review prompt

```text
Address only the inline review comments and keep the scope minimal.

Do not opportunistically refactor unrelated code.
Re-run the relevant tests/builds.
Summarize exactly what changed.
```

---

## 10. Specific warnings for this app

### 10.1 Never casually change storage deletion

The app stores user PDFs and captured revision images. Any code that removes files must be reviewed carefully.

Require a test or a clear manual verification plan for:
- permanent deletion;
- rollback;
- subject rename;
- migration;
- export;
- import failure cleanup.

### 10.2 SwiftData schema changes need extra caution

Changing model stored properties can break existing users' local databases.

Before any SwiftData schema change:
- ask Codex for a migration plan;
- back up sample local data;
- keep compatibility properties where possible;
- avoid renaming fields casually;
- test launch with an existing database if possible.

### 10.3 Do not mix file moves with logic changes

When splitting files:
- first move types unchanged;
- build;
- then make behavior changes in a later task.

### 10.4 Be careful with generated project files

If adding Swift files, Codex must update `TrialPracticeApp.xcodeproj/project.pbxproj` unless the project is migrated away from manual file lists.

### 10.5 Network-backed THSC behavior should be isolated

THSC can be slow and unreliable. Tests should prefer HTML parsing and URL construction units rather than live network calls.

---

## 11. A good first week of Codex tasks

If time is tight, do this sequence:

1. Task 01 — Baseline build and architecture inventory.
2. Task 02 — Add AGENTS.md.
3. Task 03 — Make destructive startup initialization safe.
4. Task 06 — Fix filename normalization to preserve digits.
5. Task 08 — Extract Library card components.
6. Task 10 — Extract PDFAnnotationSession.
7. Task 19 — Add `Paper.primaryPDFRelativePath`.
8. Task 21 — Project generation plan.

This sequence gives high safety value without attempting the risky full model migration.

---

## 12. Final instruction to Codex

When using this playbook, prefer boring, safe, incremental engineering over impressive rewrites. The app is for a student with limited time. The best result is not a perfect architecture in one pass; it is a codebase that becomes safer and easier to maintain after every small task.
