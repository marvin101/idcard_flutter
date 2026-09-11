# CampusID — Flutter Client

## Current release

**CampusID v0.9.0** is the print-production, barcode, and signed-credential release. The Flutter package version is `0.9.0+9`, where `+9` is the platform build number.

CampusID remains pre-1.0 while identity, collaboration, and Designer-fidelity work continues. Version 0.9.0 adds two-sided cards, Print Basket, A4/Letter imposition, duplex and calibrated PDF production, supported barcode formats, and signed time-bounded student verification.

## Overview

This repository contains the CampusID Flutter client, with Flutter Web deployed to Vercel. It provides the authenticated school-management, student, card-design, and PDF user interface plus anonymous Public Form, design-preview, and student-verification routes.

The Flutter application never connects directly to PostgreSQL and is not the security boundary. All protected data and authorization decisions flow through the FastAPI backend.

## Architecture

```text
Flutter Web
   (Vercel)
       |
       | HTTPS / JSON + JWT bearer token
       v
FastAPI API
   (Render)
       |
       +-------------------------+
       |                         |
       v                         v
Supabase PostgreSQL       Supabase Storage
schools, users, students,  school logos, student photos,
forms, templates, audits   and temporary bulk-photo objects
```

## Current capabilities

- JWT sign-in, persisted bearer session, bootstrap, logout, and centralized session-expiry handling
- Active school selection and restoration across multi-school assignments
- School profile and logo viewing/administration
- Academic session, class, and section workflows
- Student search, filtering, creation, editing, photos, and administrator deletion
- Dynamic school-scoped student fields
- Excel template download, upload, preview, validation feedback, and confirmed student import
- Bulk student-photo selection, upload, matching preview, progress, and commit
- Pending / Needs Correction / Verified lifecycle UI, audit history, and individual/batch printed/reprint actions
- Public Form administration plus a branded anonymous submission route with configured fields and photo policy
- Excel Grid filters, bounded paging, inline edits, custom fields, academic dropdowns, dirty-state tracking, conflict handling, and structured cell errors
- Current Card Designer at `/design`
- Card preview plus individual, filtered/bulk, and Print Basket PDF output, with
  exact-size A4/Letter sheet layouts, configurable margins/spacing, crop marks,
  duplex alignment, printer calibration sheets, and reusable school-scoped presets
- Platform user and school-assignment administration
- Signed, expiring, and revocable QR-based student verification with school-scoped disclosure and an anonymous `/verify/<token>` page
- Code 128, Code 39, EAN-13, and Data Matrix barcode elements with fixed,
  single-field, custom-field, or scoped multi-field payloads
- Clean web paths through `usePathUrlStrategy()` and Vercel SPA rewrites

PDFs are assembled in the Flutter client from data authorized and returned by the backend.

## Card Designer v2

Designer v2 uses a schema-versioned document, with millimetres as the canonical coordinate system:

```text
DesignDocument
  -> DesignBindings
  -> shared DesignRenderScene / DesignDocumentView
  -> Designer / Cards preview / PDF
```

The Designer and Cards preview consume the same document-driven rendering model, while PDF export consumes the same normalized render scene. This keeps content binding, geometry, stacking, visibility, styling, image selection, and machine-readable symbol output aligned across outputs and reduces parity drift. Templates may include an optional back document: Designer exposes independent Front/Back editing and Cards can flip each preview between sides. Both canvases keep matching physical dimensions. PDF export supports front-only or duplex output; duplex PDFs alternate front/back pages and mirror imposed back-side slots for the selected long-edge or short-edge printer setting. Sheet output supports independent front/back X/Y calibration offsets, a printable alignment target, and named print presets stored per school in the current browser or device. QR codes can contain fixed text, bind to one field, or combine up to 20 student, academic, school, and custom fields as structured JSON or labeled text, with configurable correction level, foreground/background colours, and quiet zone. Barcode elements support Code 128, Code 39, EAN-13, and Data Matrix with the same scoped binding modes; format-specific validation blocks invalid content before PDF export, and 1D formats can optionally print a human-readable value.

New QR elements default to **Verification link (recommended)**. This source encodes a signed `/verify/<credential>` URL instead of embedding student PII in the QR payload. Existing opaque links and QR modes remain available for rollout compatibility. The verification-link binding cannot be selected as visible bound text or mixed into a multi-field payload.

## Public student verification

- School and platform administrators use the shield action in Designer to enable verification, choose the fields disclosed after scanning, and set a 1–3650 day validity period for newly issued credentials.
- Eligible public fields are limited to full name, admission/roll number, stream, academic session, class, section, and photo. Contact details, address, Aadhaar, parent details, audit data, and internal IDs are not selectable.
- The student action menu exposes **Verification link** to copy, disable/re-enable, or regenerate an individual link. Regeneration invalidates the QR on previously printed cards, so the UI explicitly warns that the card must be reprinted.
- `/verify/<token>` is outside the authenticated shell and makes an anonymous API request without a bearer header. It shows school identity, signature verification and expiry, the current verification state, and only the school-approved fields.
- Invalid, disabled, revoked, and inactive links share the same generic unavailable state. The backend remains the authorization, disclosure, throttling, and revocation boundary.

### Editing capabilities

- Schema version 2 documents with portrait, landscape, CR80, and custom canvas sizes.
- Canvas resize/orientation strategies: **Keep positions**, **Scale proportionally**, and **Fit to canvas**. Keep positions may intentionally leave elements extending beyond the canvas.
- Element geometry editing with raw-pointer drag/resize input and zoom-correct movement.
- Undo/redo with each drag or resize stored as one gesture-level history entry.
- Smart alignment guides, numeric keyboard/wheel stepping, and shortcuts for save, undo/redo, duplicate, delete, deselect, and precise nudging.
- Colour palette fields with recent colours, plus a responsive warning before editing on small screens.
- An independent local duplicate working copy, reset to the canonical default, revert to the last successful save, and unsaved-change protection for both in-app navigation and browser/back-stack navigation.
- Dirty state is computed against a saved snapshot. After a successful save, the server-returned canonical template replaces both the working document and saved snapshot.

### Template persistence and safety

There is one stored template per school, loaded and saved through the existing `/schools/{school_uuid}/card-template` API. The required `design` is the front and optional `back_design` is the back; removing the back sends an explicit null. A `404` means no template exists and opens the canonical default. A successful save makes the server-returned representation authoritative; a failed save preserves the current working document, the last saved snapshot, and the dirty state.

Missing schema versions and explicit v1 documents remain readable through deterministic in-memory conversion. Malformed or corrupt v2 documents are reported as errors rather than silently replaced with defaults, and explicit unsupported schema versions are rejected.

### PDF fidelity

Flutter preview and PDF export share `DesignRenderScene`, including text bindings, stacking, visibility, image source/fit, colours and opacity, borders, corner radius, and portrait/landscape/custom page geometry. Card text uses the bundled `CardNotoSans` family at all nine weights (100–900); the PDF path also shares Flutter-measured wrapping, alignment, line positions, and clipping to improve text-layout fidelity. Image contain/cover behavior and centered cropping are normalized across renderers.

Devanagari PDF export is currently rejected with a descriptive error because the PDF renderer cannot provide reliable Indic shaping. The design and student data are not modified. See [PDF renderer parity](docs/pdf_renderer_parity.md) for the detailed rendering boundary.

### Client contract and current limits

The v2 client and API contract currently allows canvas width/height greater than 10 mm and at most 2000 mm; at most 250 elements; unique, nonblank element IDs of at most 80 characters; `x`/`y` from 0 to 2000; positive width/height at most 2000; rotation from -360 to 360 degrees; integer z-index with absolute value at most 10000; and template names from 1 to 120 characters after trimming. Element bounds are not required to remain inside the canvas so Keep positions can preserve out-of-canvas geometry.

Concurrent template saves use `updated_at` as an optimistic-concurrency token and return a conflict for stale editors. Rotation-aware visual bounds are not enforced, and background-image URI syntax or reachability is not deeply validated.

## Roles and UI access

| Role | Current UI access |
| --- | --- |
| Platform Admin | All active schools, users/assignments, school and academic setup, student/lifecycle/import/grid workflows, Public Forms, public-verification controls, Card Designer, cards, and printing |
| School Admin | Assigned school(s); school and academic setup, ordinary Teacher/Staff assignments, student/lifecycle/import/grid workflows, Public Forms, public-verification controls, Card Designer, cards, and printing |
| Card Operator | Assigned school(s); read-only school profile, students, imports, Excel Grid, cards, photos, and printing |
| Teacher / Staff | Assigned-school read access to school profile and academic structures; no current student/card workflow |

Legacy `admin` assignments are treated as School Admin in the permission helpers. Inactive, revoked, pending, or unassigned access must not be treated as active school access.

UI gating is not a security control. FastAPI must authorize every request even if the Flutter route, module, or action is hidden.

## Routing

Flutter calls `usePathUrlStrategy()` at startup, so web URLs use clean paths rather than `/#/` fragments. Static hosting must rewrite unknown application paths to `index.html`; this repository's `vercel.json` supplies that SPA rewrite.

Representative routes:

| Route | Module |
| --- | --- |
| `/dashboard` | Authenticated landing/dashboard |
| `/students` | Student list and lifecycle actions |
| `/students/grid` | Excel Grid |
| `/students/add` | Add student |
| `/students/fields` | Dynamic student-field administration |
| `/public-forms` | Authenticated Public Form management |
| `/public/forms/<token>` | Anonymous branded student submission |
| `/public/designs/<token>` | Anonymous read-only saved-design preview with sample student data |
| `/verify/<token>` | Anonymous school-controlled student verification |
| `/school-profile` | School profile and logo |
| `/academic-sessions` | Academic sessions |
| `/classes-sections` | Classes and sections |
| `/users` | Users, requests, and assignments |
| `/design` | Current Card Designer |
| `/cards` | Card preview and PDF workflows |

The `/public/forms/<token>`, `/public/designs/<token>`, and `/verify/<token>` routes are intentionally outside `AuthenticatedShell`. Public design links expose only the saved design and public school-profile bindings, rendered with local sample student values. Verification links expose only the backend-approved school/student verification response. Protected routes are resolved through the authenticated shell and role/module checks.

School and platform administrators can manage the revocable design-preview link from the Card Designer. The preview reuses `DesignDocumentView`, so it stays aligned with normal card rendering and never loads a real student record.

## Technology

- Flutter 3.44+ / Dart 3.12.2+
- Provider for application and session state
- `http` and `http_parser` for the FastAPI REST boundary
- `shared_preferences` for local token and selected-school persistence
- `file_picker`, `image_picker`, and `image` for import/photo workflows
- `pdf` and `printing` for card output
- `flutter_web_plugins` for clean-path web routing
- `sqflite_common_ffi` and local repository classes retained for legacy/local code; production web data flows through FastAPI

## Project structure

```text
lib/
  config/        compile-time/runtime launch configuration
  data/          legacy/local data implementations
  layouts/       shared layouts
  models/        API, authentication, grid, form, and card models
  navigation/    router, route stack, and module visibility
  providers/     session, profile, display, and form state
  repositories/  student data abstractions
  screens/       application modules and public routes
  sections/      reusable student-form sections
  services/      FastAPI client, PDF, and download services
  theme/         colors, dimensions, typography, and theme
  utils/         validation, formatting, constants, and text helpers
  widgets/       shared application widgets and authenticated shell
assets/          CampusID images
test/            widget, navigation, state, model, and API-client tests
web/             Flutter web host files
vercel.json      Vercel SPA rewrite
pubspec.yaml     package metadata and dependencies
```

## Prerequisites

- Flutter SDK 3.44 or newer, with Dart 3.12.2 or newer (matching `pubspec.yaml` and the resolved lockfile)
- Chrome for local web development
- A running CampusID FastAPI backend
- Vercel CLI only for the local-build production deployment workflow

Check the toolchain:

```powershell
flutter doctor
flutter --version
```

## Local setup

```powershell
git clone https://github.com/marvin101/idcard_flutter.git
cd idcard_flutter
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Start the backend first and verify `http://127.0.0.1:8000/health`.

## Environment configuration

The API origin is compiled into the app:

```powershell
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

If `API_BASE_URL` is omitted, the current default is `http://127.0.0.1:8000`.

Never embed database credentials, Supabase service keys, JWT signing secrets, or other backend secrets in a Dart define or Flutter source. Browser assets and compile-time values are public.

## Session behavior

The client persists the access token and selected/last-selected school; it does not persist a refresh token. An authenticated API response with status `401` triggers centralized invalidation: the active token, user, school list, assignments, and selected school are cleared, and the sign-in UI receives a session-expired message.

A `403` is treated as an authorization error and does not log the user out.

## Testing

The current suite covers application scaling/shell behavior, authentication bootstrap/login/autofill/session expiry/access revocation, navigation and module visibility, registration school selection, school profiles and assignments, dynamic student fields, bulk Excel import, bulk photos, lifecycle/history/print permissions, Public Forms, public design sharing, anonymous student verification, Card Designer models, and the Excel Grid.

```powershell
flutter analyze
flutter test
```

## Production web build and Vercel deployment

The project intentionally uses a local Flutter release build followed by Vercel CLI deployment; do not replace this with `vercel git connect`.

From the repository root:

```powershell
flutter build web --release --dart-define=API_BASE_URL=https://id-card-backend-vcz5.onrender.com
Copy-Item .\vercel.json .\build\web\vercel.json -Force
vercel .\build\web --prod
```

Copying `vercel.json` into `build/web` ensures the deployed static directory contains the SPA rewrite required by clean-path routing. Keep the root copy as the source-controlled configuration.

Current production alias: `https://idcard-flutter-web.vercel.app`

After deployment, verify direct navigation and browser refresh on protected and public clean paths, including `/verify/<token>`. Then smoke-test sign-in, school switching, role-specific navigation, students/photos, lifecycle, Public Forms, grid saves, Card Designer, verification disclosure/revocation, and PDFs.

Deploy the backend migration and API before publishing this Flutter build. Render must set `PUBLIC_APP_URL=https://idcard-flutter-web.vercel.app` (or the approved canonical alias), otherwise generated student QR links will point at the wrong frontend origin.

## Versioning

CampusID follows Semantic Versioning: `MAJOR.MINOR.PATCH`. Backend and Flutter currently share one product version. `pubspec.yaml` adds Flutter's platform build number after `+`.

The current Flutter value is `0.9.0+9`: product release `0.9.0`, build number `9`. The 0.6.x milestone represented Public Forms, 0.7.0 added the Excel Grid, 0.8.0 delivered Designer v2 and flexible QR payloads, and 0.9.0 adds production printing, supported barcode formats, two-sided cards, and signed time-bounded credentials. Pre-1.0 minor releases may still introduce substantial product changes.

## Roadmap

- Designer v2 remaining fidelity and contract hardening
- Teacher and non-teaching staff workflows
- School collaboration
- Photo Studio
- White-label and lanyard workflows
- AI OCR (deferred)

## Related service

FastAPI backend: `https://github.com/marvin101/id_card_backend`
