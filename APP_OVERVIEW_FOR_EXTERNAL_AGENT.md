# HSC Trial Revision App: Full Product and Technical Overview

## 1. Executive Summary

The HSC Trial Revision App is a native macOS application for students to organise
HSC trial examination papers, review their performance, capture difficult
questions, and generate revision material.

The app is designed around a simple workflow:

1. Add subjects.
2. Import trial papers and solutions from different schools and years.
3. Read the PDFs inside the app.
4. Capture questions that were mistakes or contain unlearned content.
5. Practise those questions without immediately seeing the solutions.
6. Mark questions as completed.
7. Export revision booklets or paper-mark data.

The app is completely local-first:

- There are no accounts.
- There is no login system.
- There is no server or external database.
- There is no network requirement.
- There is no built-in cloud synchronisation.
- The student chooses the folder in which PDFs and captured images are stored.

The current app version is **Iteration 13**. The original core specification is
feature-complete and the project is now in release acceptance and packaging.

## 2. Intended User

The primary user is an HSC student who has accumulated trial papers from multiple
schools and wants one place to:

- organise papers by subject, school, and year;
- store question papers, solutions, and optional completed work;
- record marks;
- isolate questions requiring more practice;
- avoid mixing revision questions from unrelated subjects;
- generate printable revision booklets; and
- keep complete control of their local files.

## 3. Platform and Technology

- Platform: macOS
- Minimum supported version: macOS 14
- UI framework: SwiftUI
- PDF display and processing: PDFKit
- Metadata database: SwiftData
- Local file access: security-scoped macOS bookmarks
- Language: Swift 6
- Distribution target: standalone macOS application

The Xcode project is `TrialPracticeApp.xcodeproj`, using the
`TrialPracticeApp` scheme.

## 4. Main Navigation

The app uses a macOS sidebar with five destinations:

1. **Library**
2. **Flagged Questions**
3. **Revision Booklets**
4. **Bin**
5. **Settings**

The Library is the default screen.

## 5. First Launch and Data Folder

On first launch, the student must either:

- create a new data folder in a chosen location; or
- connect an existing folder.

The default proposed folder name is `HSC Trial Revision`.

The app stores a security-scoped bookmark in `UserDefaults`, allowing it to
reconnect to the selected location after relaunching. It verifies that it can
create the required directories and write to the selected location.

Settings allows the student to disconnect the current folder and choose another
one. Disconnecting does not move or delete existing files.

## 6. Important Storage Architecture

The app has two separate forms of storage.

### 6.1 User-Visible Files

PDFs and captured PNG images are stored in the student-selected data folder.

The structure is:

```text
Papers/
  Subject/
    School/
      Year/
        Subject_School_Year.pdf
        Subject_School_Year_sols.pdf
        Subject_School_Year_work.pdf

Flagged Questions/
  Subject/
    Mistakes/
      captured question and solution images
    Unlearned Content/
      captured question and solution images
```

The student-work PDF is optional.

### 6.2 SwiftData Metadata

The app uses SwiftData as its index. It records subjects, schools, papers,
marks, relative file paths, flagged-question details, completion status, and
other metadata.

The database is not currently stored as a portable index file inside the
student-selected folder. It is managed in the app's local container.

This distinction is important:

- Manually placing a PDF in the data folder does not make it appear in the app.
- The app only displays files that have corresponding SwiftData records.
- Selecting a folder containing files from another installation does not
  automatically reconstruct the metadata.
- The visible file folder alone is not currently a complete portable backup of
  the app's database state.

This is likely the most important architectural constraint for future backup,
migration, synchronisation, or multi-device discussions.

## 7. Data Models

### Subject

A subject stores:

- unique ID;
- display name;
- filename-safe name;
- selected folder colour as a hexadecimal RGB value;
- creation date; and
- optional deletion date.

Subjects are soft-deleted into the Bin.

### School

A school stores:

- unique ID;
- display name;
- filename-safe name; and
- creation date.

Schools are remembered globally and reused as suggestions when importing papers.
They are not independently displayed as top-level entities.

### Paper

A paper stores:

- unique ID;
- subject ID;
- school ID;
- year;
- optional numeric mark;
- question PDF relative path;
- solutions PDF relative path;
- optional student-work PDF relative path; and
- creation date.

A paper is logically unique by:

```text
Subject + School + Year
```

The UI prevents importing a duplicate combination. The file importer also
refuses to overwrite existing destination files.

### Flagged Question

A flagged question stores:

- unique ID;
- source paper ID;
- subject ID;
- school ID;
- year;
- question number;
- category;
- completion status;
- question image relative path;
- optional solution image relative path; and
- creation date.

Categories are:

- Mistake
- Unlearned Content

## 8. Name Normalisation

User-entered subject and school names are normalised.

Example:

```text
noRTH SyDNey boys
```

becomes the display name:

```text
North Sydney Boys
```

The filename-safe value removes spaces, punctuation, and non-letter characters:

```text
NorthSydneyBoys
```

This value is used in folder and file names.

## 9. Library Organisation

The Library uses a Finder-like hierarchy:

```text
Subject > School > Year Paper
```

### Subject Level

Subjects appear as coloured folder cards. Each card displays the number of
papers in that subject.

Students can:

- create a subject;
- select any folder colour using the macOS colour wheel;
- rename a subject;
- change its colour;
- open the subject;
- move it to the Bin; and
- export all paper results for that subject as CSV.

Renaming a subject also renames its folders and updates every affected relative
path in paper and flagged-question metadata. If the operation fails, the app
attempts to roll the folder and metadata changes back.

### School Level

Opening a subject displays only schools that contain papers for that subject.

Each school appears as a folder card and inherits the colour of its parent
subject. Therefore, the same school may appear in two subjects with different
folder colours.

Students can add a paper from this screen with the subject preselected.

### Paper Level

Opening a school displays paper cards labelled by year.

A paper card shows:

- year;
- mark, if recorded;
- flagged-question count;
- availability of question, solution, and student-work PDFs.

Opening a paper launches the PDF viewer.

Papers can be deleted through a context menu. Deleting a paper permanently
removes:

- its question PDF;
- its solutions PDF;
- its optional student-work PDF;
- its flagged-question images;
- its `Paper` record; and
- its related `FlaggedQuestion` records.

## 10. Subject Colours

Every subject has a student-selected colour.

The colour is used for:

- its main Library folder;
- every school folder inside that subject; and
- its folder in Flagged Questions.

Existing subjects created before this feature default to blue.

## 11. Paper Import

The Add Paper workflow collects:

- subject;
- school;
- year;
- optional mark;
- PDF upload format;
- required PDFs; and
- optional student-work PDF.

### School Entry

Previously used schools are suggested while typing. Selecting a suggestion
reuses the existing school record.

### Year Validation

Year is free text but must contain numbers only.

Examples:

- `2023`
- `2024`
- `2025`

### Mark Validation

Marks are optional and support decimals.

Valid:

```text
84.5
```

Invalid:

```text
84.5%
```

Marks must be between 0 and 100. They are stored internally as numeric values,
not strings containing percent signs.

### Import Mode A: Separate PDFs

The student selects:

- question paper PDF;
- solutions PDF; and
- optional student-work PDF.

### Import Mode B: Combined PDF

The student selects:

- one combined question-and-solution PDF;
- the page on which solutions begin; and
- optional student-work PDF.

The app splits the combined PDF into separate question and solution files.
There must be at least one question page and one solution page.

### Import Safety

The importer:

- verifies that selected files are readable PDFs;
- prevents destination overwriting;
- removes partially created files if an import operation fails; and
- removes copied PDFs and an empty year folder if SwiftData persistence fails
  after the file import.

## 12. PDF Viewer

The viewer provides three modes:

1. Questions
2. Solutions
3. Both

Both mode uses a side-by-side split view.

The PDF viewer supports:

- continuous vertical scrolling;
- single-page vertical layout;
- smooth PDFKit scrolling;
- zoom in;
- zoom out; and
- fit width.

If a stored file has been manually moved or deleted, the viewer displays a
missing-file message rather than crashing.

## 13. Flagging a Question

Students flag questions directly inside the paper viewer.

Flagging does not open a separate capture window. Instead, the displayed PDF
enters inline capture mode.

The student enters:

- question number;
- category: Mistake or Unlearned Content; and
- whether a solution capture should be included.

Question numbers may contain letters and numbers, such as:

- `14a`
- `12b`
- `14aii`
- `Q7`

## 14. Capture Interface

The capture interface displays two horizontal draggable boundaries over the
scrolling PDF:

- Top
- Bottom

The area outside the boundaries is darkened. The selected area remains clear.

When capture begins, the boundaries are positioned at:

- one-third down the currently visible PDF area; and
- two-thirds down the currently visible PDF area.

This initially selects the middle third of what is visible.

The boundaries are attached to the PDF document view, so they move with the PDF
when the student scrolls.

The capture always uses the full width of the PDF. There is no freeform
rectangular crop.

## 15. Multi-Page Capture

A question or solution may span multiple pages.

The top boundary may be near the bottom of an earlier page while the bottom
boundary is near the top of a later page. Boundary percentages are only compared
when both boundaries are on the same page.

The capture service:

1. crops the selected portion of the first page;
2. captures all intermediate pages in full;
3. crops the selected portion of the final page; and
4. stitches all fragments vertically into one PNG image.

The result is one image, not multiple image fragments.

Question and solution selections are independent. A solution is optional.

## 16. Duplicate Flagged Questions

Before saving, the app checks for an existing flagged question with the same:

- subject;
- school;
- year; and
- question number.

The app warns the student but allows saving a duplicate.

Files are never overwritten. Duplicate filenames receive increasing numeric
suffixes such as:

```text
MathsAdvanced_NorthSydneyBoys_2025_Q14a.png
MathsAdvanced_NorthSydneyBoys_2025_Q14a_2.png
MathsAdvanced_NorthSydneyBoys_2025_Q14a_3.png
```

Solutions use `_sol`:

```text
MathsAdvanced_NorthSydneyBoys_2025_Q14a_sol.png
```

If metadata saving fails after image creation, the app removes the newly created
images.

## 17. Flagged Questions Library

The Flagged Questions screen begins with subject folders rather than one mixed
list.

Each folder:

- uses the subject colour;
- displays the total number of flagged questions; and
- displays the incomplete count.

Opening a subject folder permanently scopes the list to that subject. A Maths
folder cannot show Physics questions.

Inside a subject, students can filter by:

- all categories;
- Mistakes;
- Unlearned Content;
- incomplete;
- completed; or
- both completion states.

The default completion filter is Incomplete.

Search supports:

- school;
- year; and
- question number.

Each row includes a thumbnail, question number, category, school, year, and
completion status.

## 18. Reviewing a Flagged Question

The detail screen shows:

- question number;
- subject;
- school;
- year;
- category;
- completion checkbox;
- question image; and
- optional solution image.

Solutions are hidden by default. The student must enable `Show Solution` after
attempting the question.

Students can:

- mark the question completed or incomplete; and
- permanently delete the flagged question and its images.

Completed questions remain available when the corresponding filter is selected.

## 19. Revision Booklet Export

The Revision Booklets screen generates a PDF from flagged questions.

The student selects:

- subject;
- category filter: Mistakes, Unlearned, or both; and
- completion filter: completed, incomplete, or both.

The default is incomplete questions.

The screen previews the questions that will be included.

The exported PDF contains:

### Title Page

- subject;
- generation date;
- total question count;
- Mistake count; and
- Unlearned Content count.

### Question Pages

Each question starts on a new page and displays:

- subject;
- school;
- year;
- question number; and
- captured question image.

### Solution Pages

The solution page immediately follows its question.

If a solution image exists, it is displayed. Otherwise, the page says:

```text
No solution provided
```

The export uses the native macOS PDF save panel.

## 20. Subject Paper CSV Export

Inside each subject folder, the student can export all papers for that subject.

The CSV columns are exactly:

```text
School,Year,Mark
```

Rules:

- marks are numeric and do not include `%`;
- missing marks produce empty cells;
- commas, quotes, and line breaks in school names are correctly escaped; and
- export uses the native macOS save panel.

## 21. Subject Deletion and Bin

Moving a subject to the Bin is a soft deletion.

While a subject is in the Bin:

- it disappears from the Library;
- its papers are hidden;
- its flagged questions are hidden; and
- its files and metadata remain intact.

The Bin only applies to subjects.

Students can:

- restore a subject; or
- permanently delete it.

Restoring saves immediately. If persistence fails, the app returns the subject
to its deleted state and displays an error.

Permanent deletion removes:

- the subject record;
- all related paper records;
- all related flagged-question records;
- the subject's Papers folder; and
- the subject's Flagged Questions folder.

## 22. Settings and Privacy

Settings currently contains:

- the connected data folder name;
- a control to reconnect or choose another folder; and
- a privacy statement.

The privacy statement confirms:

- no accounts;
- no cloud storage;
- no internet connection.

Temporary developer reset controls used during development have been removed.

There is also a native macOS Settings scene in addition to the sidebar Settings
screen.

## 23. File and Metadata Consistency

The app includes several consistency protections:

- Subject renaming updates both folders and stored relative paths.
- Paper import cleans up copied files if metadata saving fails.
- Flagged-question capture cleans up images if metadata saving fails.
- Duplicate imports do not overwrite files.
- Duplicate captures receive new filenames.
- Stored relative paths are checked before paper deletion to prevent escaping
  the root folder.

However, filesystem and SwiftData changes do not use one shared atomic
transaction. Some deletion workflows remove files before saving metadata.
A rare database failure after file deletion could therefore leave metadata
pointing to missing files. This is a possible future hardening area.

## 24. Known Constraints and Non-Features

The following are current constraints rather than bugs in the implemented
specification:

1. The app does not scan or import files that are manually placed in the data
   folder.
2. The selected folder does not contain a complete portable SwiftData database.
3. Connecting the same folder on another Mac does not automatically reproduce
   the Library.
4. There is no backup, restore, archive, or migration workflow.
5. There is no cloud synchronisation or collaboration.
6. There is no iPhone, iPad, Windows, or web version.
7. There is no OCR or automatic question-number detection.
8. There is no automatic mark extraction from PDFs.
9. Schools cannot be managed or deleted independently.
10. There is no school-wide mass deletion, by design.
11. Paper uniqueness is primarily enforced by the UI and destination files,
    rather than a compound unique database constraint.
12. The PDF viewer does not edit or annotate the original PDFs.
13. Revision state consists of a completed/incomplete flag; there is no spaced
    repetition scheduler.
14. Visual interaction still requires final manual acceptance testing.

## 25. Current Verification

Automated verification currently includes **19 tests across 3 suites**.

Coverage includes:

- subject and school name normalisation;
- year and mark validation;
- specification-compliant PDF filenames;
- root and subject folder creation;
- subject folder renaming;
- separate PDF import;
- combined PDF splitting;
- optional student-work import;
- duplicate destination protection;
- imported-file rollback;
- paper file deletion;
- multi-page capture and image stitching;
- cross-page boundary handling;
- duplicate flagged-question filenames;
- revision booklet structure;
- missing-solution pages; and
- CSV formatting and escaping.

The Xcode Debug build also succeeds.

## 26. Manual Acceptance Items

Important workflows still benefit from hands-on verification:

- first-launch folder selection;
- security-scoped folder restoration after relaunch;
- Settings opening from both sidebar and macOS menu;
- subject rename with existing content;
- colour-wheel selection;
- folder-colour inheritance;
- PDF navigation and zoom;
- inline capture boundary dragging;
- scrolling while capture is active;
- multi-page question and solution capture;
- hidden-solution review behavior;
- booklet rendering in Preview;
- CSV opening in Numbers or Excel;
- Bin restoration across relaunch; and
- permanent deletion behavior.

## 27. Current Development Status

The original 15-page product specification is implemented.

The project is no longer waiting on a core feature. The next phase is one of:

- investigating a newly identified problem;
- release acceptance testing;
- improving data portability and recovery;
- packaging and code signing;
- UI polish;
- accessibility improvements;
- additional revision features; or
- expanding to another platform.

When discussing a proposed change, it is important to establish whether it
affects:

- the SwiftData metadata index;
- the student-visible file structure;
- both stores together;
- security-scoped access;
- existing relative paths;
- migration of current users; or
- behavior after reconnecting or moving the data folder.

Those boundaries determine the safest implementation approach.
