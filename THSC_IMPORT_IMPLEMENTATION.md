# THSC Paper Import Implementation

## Overview

The app imports up to 10 trial papers at a time from the supported THSC
collections. It:

1. Downloads and parses the selected THSC listing page.
2. Displays papers with school and year metadata.
3. Prevents previously imported papers from being selected again.
4. Downloads selected PDFs sequentially.
5. Stores each downloaded paper unchanged as one complete PDF.
6. On first open, asks the user to click the first solutions page and saves the
   1-based page number.

The importer does not inspect, OCR, classify, or split solution pages.

## Main Components

- `Views/THSCImportView.swift`
  - Provides collection selection, search, progress, and import controls.
  - Enforces the maximum of 10 selected papers.
  - Creates the SwiftData paper, school, and import-history records.

- `Services/THSCImportService.swift`
  - Fetches THSC listing pages.
  - Parses titles, school names, years, and THSC content IDs.
  - Reproduces THSC's download request and decodes its base64 PDF response.

- `Services/PaperImportService.swift`
  - Stores combined inputs intact.
  - Merges manually supplied separate question and solution PDFs into one file.
  - Removes partially created files if an import fails.

- `Models/THSCImportRecord.swift`
  - Stores the stable THSC source identifier and import metadata.
  - Remains after a paper is deleted, preventing duplicate downloads.

## Storage

```text
Papers/<Subject>/<School>/<Year>/
    <Subject>_<School>_<Year>.pdf
```

Paper metadata and THSC import history are stored in SwiftData.

## Current Limitations

- THSC page and download formats are not a documented stable API.
- Importing is limited to the predefined THSC collections in the source picker.
