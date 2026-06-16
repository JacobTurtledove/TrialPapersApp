# School Crest Pack Specification

Create a folder named:

`School Crest Pack`

Use this structure:

```text
School Crest Pack/
  manifest.json
  images/
    Abbotsleigh.png
    Ascham.png
    ...
```

## Images

- Supply exactly one image for each name in `SCHOOL_CRESTS_NEEDED.txt`.
- Use the exact school label from that file as the filename.
- Every file must be a PNG, for example `North Sydney Boys.png`.
- Use a transparent background where possible.
- Keep the complete crest or emblem visible, with no cropping.
- Use a square canvas, preferably 512 by 512 pixels.
- A minimum of 256 by 256 pixels is acceptable.
- Do not use photographs of school buildings, students, uniforms, signs, or
  unofficial recreations.
- Do not add shadows, frames, labels, or other decoration.

## Manifest

Create `manifest.json` using this structure:

```json
{
  "version": 1,
  "schools": [
    {
      "name": "North Sydney Boys",
      "file": "images/North Sydney Boys.png",
      "officialName": "North Sydney Boys High School",
      "sourceURL": "https://example.edu.au/official-crest-page",
      "aliases": [
        "North Sydney Boys High School"
      ]
    }
  ]
}
```

Requirements:

- `name` must exactly match a line in `SCHOOL_CRESTS_NEEDED.txt`.
- `file` must be the relative path to the corresponding PNG.
- `officialName` should contain the school's full official name.
- `sourceURL` should identify where the image was obtained.
- `aliases` should include useful full-name or abbreviation variants.
- Prefer official school websites and official school publications as sources.
- If a crest cannot be verified confidently, omit its image and manifest entry
  instead of guessing.

## Delivery Location

Place the completed `School Crest Pack` folder directly inside the repository:

```text
/Users/jacob.turtledove/Library/CloudStorage/OneDrive-MoriahWarMemorialCollegeAssociation/Documents/Trial Practice App/School Crest Pack
```

Do not place it inside the app's existing `School Crests` data folder. That
folder currently contains UUID-named cache files. The app import step will map
the curated pack's school names to the correct database records.
