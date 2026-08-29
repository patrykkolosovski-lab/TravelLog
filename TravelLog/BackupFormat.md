# TravelLog Archive Format

TravelLog archives use the `.travellog` extension and contain UTF-8 JSON.

## Version 1

The top-level object contains:

- `format`: `com.patrykkolosovski.TravelLog.archive`
- `version`: integer schema version, currently `1`
- `exportedAt`: ISO 8601 creation date
- `locations`: personal country, territory, and city records

Each location stores its UUID, optional bundled reference identifier, location
fields, creation date, journal entries, and photo records. Journal and photo UUIDs
and creation dates are preserved. Photo bytes are encoded by JSON as Base64 data.
The original and managed filenames are metadata only; import always generates a
new collision-safe managed filename inside TravelLog's Application Support folder.

Import validates the format identifier, version, UUID uniqueness, bundled
reference identifiers, location fields, journal bodies, and image data before any
existing records are modified. Future format changes must increment `version` and
add a migration path before accepting the archive.
