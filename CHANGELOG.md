# Changelog

All notable changes to CampusID are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Versions before 0.7.0 below are a reconstructed milestone history from repository history and the implemented product state; they do not imply that matching Git tags or formal releases existed.

## [Unreleased]

### Added

- Added Designer v2 with a millimetre-based visual canvas, element tools, layers, inspector, alignment, keyboard editing, and undo/redo.

### Changed

- Legacy card templates now normalize safely to the v2 document format, shared by preview and PDF rendering.

## [0.7.0] - 2026-09-02

### Added

- Excel-like student grid with session/class/section filters, search, paging, inline system/custom fields, and academic dropdowns.
- Dirty-row tracking, conflict feedback, structured cell errors, atomic bulk save, and saved-state feedback.

### Changed

- Adopted a shared CampusID Semantic Versioning policy across Flutter and backend.
- Enabled clean web paths with `usePathUrlStrategy()` and a Vercel SPA rewrite.
- Set the Flutter package version to `0.7.0+7`.

## [0.6.0]

### Added

- Public Form management UI and clean anonymous `/public/forms/<token>` route.
- School-branded configured forms with optional/required photo handling and pending-submission feedback.

## [0.5.0]

### Added

- Pending, Needs Correction, and Verified student lifecycle UI.
- Student history, lifecycle permissions, and printed/reprint actions and summaries.

## [0.4.0]

### Added

- Excel student template/download, upload, preview, validation, and commit UI.
- Bulk student-photo selection, matching preview, progress, and commit workflow.

## [0.3.0]

### Added

- Dynamic student-field configuration and rendering.
- School profile and logo management UI.

## [0.2.0]

### Added

- Core student/card management, Card Designer, photo handling, and individual/filtered PDF workflows.

## [0.1.0]

### Added

- Authentication/session, school selection, user/access foundations, application theme, and core form components.
