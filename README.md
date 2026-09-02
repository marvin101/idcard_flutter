# CampusID — Flutter Client

## Current release

**CampusID v0.7.0** is the Excel Grid release. The Flutter package version is `0.7.0+7`, where `+7` is the platform build number.

CampusID remains pre-1.0 while Designer v2, digital identity, advanced print production, and other roadmap modules are still in development.

## Overview

This repository contains the CampusID Flutter client, with Flutter Web deployed to Vercel. It provides the authenticated school-management, student, card-design, and PDF user interface plus the anonymous Public Form route.

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
- Card preview plus individual and filtered/bulk PDF output
- Platform user and school-assignment administration
- Clean web paths through `usePathUrlStrategy()` and Vercel SPA rewrites

PDFs are assembled in the Flutter client from data authorized and returned by the backend.

## Roles and UI access

| Role | Current UI access |
| --- | --- |
| Platform Admin | All active schools, users/assignments, school and academic setup, student/lifecycle/import/grid workflows, Public Forms, Card Designer, cards, and printing |
| School Admin | Assigned school(s); school and academic setup, ordinary Teacher/Staff assignments, student/lifecycle/import/grid workflows, Public Forms, Card Designer, cards, and printing |
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
| `/school-profile` | School profile and logo |
| `/academic-sessions` | Academic sessions |
| `/classes-sections` | Classes and sections |
| `/users` | Users, requests, and assignments |
| `/design` | Current Card Designer |
| `/cards` | Card preview and PDF workflows |

The `/public/forms/<token>` route is intentionally outside `AuthenticatedShell`. Protected routes are resolved through the authenticated shell and role/module checks.

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

The current suite covers application scaling/shell behavior, authentication bootstrap/login/autofill/session expiry/access revocation, navigation and module visibility, registration school selection, school profiles and assignments, dynamic student fields, bulk Excel import, bulk photos, lifecycle/history/print permissions, Public Forms, Card Designer models, and the Excel Grid.

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

After deployment, verify direct navigation and browser refresh on protected and public clean paths, then smoke-test sign-in, school switching, role-specific navigation, students/photos, lifecycle, Public Forms, grid saves, Card Designer, and PDFs.

## Versioning

CampusID follows Semantic Versioning: `MAJOR.MINOR.PATCH`. Backend and Flutter currently share one product version. `pubspec.yaml` adds Flutter's platform build number after `+`.

The current Flutter value is `0.7.0+7`: product release `0.7.0`, build number `7`. The 0.6.x milestone represented Public Forms; 0.7.0 is the Excel Grid release. Pre-1.0 minor releases may still introduce substantial product changes.

## Roadmap

- Designer v2
- QR/barcode and digital identity
- Advanced print production and Print Basket
- Teacher and non-teaching staff workflows
- School collaboration
- Photo Studio
- White-label and lanyard workflows
- AI OCR (deferred)

## Related service

FastAPI backend: `https://github.com/marvin101/id_card_backend`
