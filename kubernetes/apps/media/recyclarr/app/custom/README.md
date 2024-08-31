# Additional Custom Formats

<br >

## (CUSTOM) Language: Not Original or English

This custom format is designed to exclude any release that is not in the original or English language. It ensures that the release at least contains one of the desired tracks.

| Score   | Matches                  | Profile    |
|---------|--------------------------|------------|
| -10,000 | Not Original, Not English | Non-Anime  |

### JSON Configuration

```json
{
  "name": "(CUSTOM) Language: Not Original or English",
  "includeCustomFormatWhenRenaming": false,
  "specifications": [
    {
      "name": "Not Original",
      "implementation": "LanguageSpecification",
      "negate": true,
      "required": true,
      "fields": {
        "value": -2
      }
    },
    {
      "name": "Not English",
      "implementation": "LanguageSpecification",
      "negate": true,
      "required": true,
      "fields": {
        "value": 1
      }
    }
  ]
}
```

<br >

## (CUSTOM) Release Title: Dubbed

This custom format is intended to filter out releases that are dubbed, particularly those that include foreign audio tracks. It helps prevent the addition of bloated files with unnecessary foreign language tracks, which may also carry the "default" flag and cause playback issues.

| Score   | Matches          | Profile   |
|---------|------------------|-----------|
| -10,000 | Dubbed Releases  | Non-Anime |

### JSON Configuration

```json
{
  "name": "(CUSTOM) Release Title: Dubbed",
  "includeCustomFormatWhenRenaming": false,
  "specifications": [
    {
      "name": "(CUSTOM) Dubbed",
      "implementation": "ReleaseTitleSpecification",
      "negate": false,
      "required": true,
      "fields": {
        "value": "^(?!.*\\b(eng|english)\\b).*\\b(Dual|Multi|Dub|Dubbed)\\b.*"
      }
    }
  ]
}
```
