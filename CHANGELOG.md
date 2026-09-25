# Changelog

All notable changes to CampusID are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Versions before 0.7.0 below are a reconstructed milestone history from repository history and the implemented product state; they do not imply that matching Git tags or formal releases existed.

## [Unreleased]

### Changed

- Completed Designer v2 around a single stable element catalog for all text,
  media, shape, QR, and barcode tools. Toolbar creation, pointer resizing,
  numeric sizing, and canvas alignment now share the same millimetre geometry
  rules, including square and minimum-size guarantees for QR/Data Matrix and
  minimum printable dimensions for one-dimensional barcodes.
- Added a complete versioned design fixture that exercises every element type
  through document round-trip, binding resolution, Flutter layout, and the
  normalized vector-PDF adapter to guard renderer parity.

## [0.10.0] - 2026-09-14

### Added

- Added first-class teacher/staff card data resolution, personnel-safe Designer
  and machine-readable bindings, type-partitioned personnel Print Baskets and
  individual/bulk PDF export, plus typed custom fields and audited photo flows.
- Added reusable Teacher/Staff Excel import and employee-number bulk-photo
  workflows, including templates, mapping, preview, confirmation, errors, and
  completion summaries.
- Added a type-switchable personnel Excel Grid with search, active/inactive,
  department and designation filters, editable system/custom fields, dirty-row
  save/discard, and structured conflict feedback.
- Teacher and Staff lists now expose Excel Import, Bulk Photos, and Excel Grid
  actions for roles that can manage card data.
- Personnel Designer previews and machine-readable multi-field payloads now
  suppress student-only academic/identity bindings and offer type-appropriate
  employee fields and custom fields.

### Security

- Preserved backend-authorized school boundaries throughout Teacher/Staff CRUD,
  lifecycle, audit, import, grid, photo, card, and export workflows.

### Deferred

- Personnel signed/public credentials are not part of 0.10.0 and require a
  purpose-separated credential and disclosure design.
- Student signed/public credentials remain unchanged in this release.

## [0.9.0] - 2026-09-11

### Added

- Added optional two-sided card templates with independent Front/Back editing,
  undoable back-side creation/removal, and a per-card preview flip control.
- Added the first Advanced Print Production slice: a Print Basket that keeps
  selected cards across search and filter changes, supports review/removal/clear
  actions, and exports through the existing PDF preflight workflow.
- Added A4 and Letter sheet imposition with portrait/landscape orientation,
  configurable margins and spacing, exact-size automatic card grids, page-count
  review, non-fitting layout validation, and optional crop marks.
- Added duplex PDF output for individual cards and imposed sheets, with
  alternating front/back pages, long-edge or short-edge alignment, mirrored
  partial-sheet slots, and separate PDF-page/physical-sheet counts.
- Added independent front/back X/Y print calibration offsets, bounded to ±20 mm,
  plus printable front/duplex calibration targets for physical alignment checks.
- Added named, school-scoped print presets that persist page, layout, duplex,
  crop-mark, spacing, and calibration settings in the current browser or device.
- Added Code 128, Code 39, EAN-13, and Data Matrix elements with static,
  single-field, custom-field, or scoped multi-field payloads, matching Designer,
  Cards preview, and vector PDF rendering, optional 1D human-readable text, and
  format-specific bulk-export preflight validation.
- Added administrator-configurable credential validity, signed credential
  status/version/issue/expiry details, and a public cryptographic-signature
  verification indicator while retaining a compatible legacy-link display.

### Changed

- Canvas size and orientation changes keep both card sides physically aligned,
  and duplex preflight now validates content from both selected sides.
- Card selection is now available to print-capable roles even when they do not
  have student verification or print-lifecycle permissions.
- Individual-card printing can reuse a saved preset's side and flip-edge choices;
  filtered, selected, and Print Basket exports apply the complete preset.

## [0.8.0] - 2026-09-10

### Added

- Added Designer v2 with a millimetre-based visual canvas, element tools, layers, inspector, alignment, keyboard editing, and undo/redo.
- Added editable canvas presets, custom physical dimensions, orientation, background, grid, and snapping controls.
- Added QR-code elements with static, system-field, or custom-field content,
  configurable error correction and colours, shared preview/PDF rendering, and
  bulk-export preflight validation.
- Added multi-field QR selection for student, academic, school, and custom data,
  with stable scoped JSON or human-readable labeled-text payloads.
- Added a recommended verification-link QR source, a school-controlled public
  verification page, disclosure settings, and per-student revoke/regenerate controls.

### Security

- Verification QR codes encode opaque capability URLs instead of student PII;
  anonymous pages render only the backend-approved school disclosure response.

### Changed

- Legacy card templates now normalize safely to the v2 document format, shared by preview and PDF rendering.
- Improved constrained-width property-inspector spacing and made canvas fitting responsive to physical card size.

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
