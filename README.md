# ID-Card Manager — Flutter Frontend

Flutter client for managing schools, academic structures, students, photos, ID-card layouts, and printable card PDFs. The web build talks to the FastAPI service; it does not connect directly to PostgreSQL.

## Architecture

```text
Flutter Web (Vercel)
        |
        | HTTPS / JSON + Bearer token
        v
FastAPI (Render) -> PostgreSQL + Supabase Storage
```

Source repository: `marvin101/idcard_flutter`

The current Vercel project/domain is a deployment detail. It does not change this repository or the application architecture.

## Current capabilities

- JWT login with persisted bearer sessions and centralized expired-session cleanup
- School selection based on active user assignments
- Multiple-school assignments
- Academic session, class, and section management
- Student ID-card entry and updates
- Student photo selection, cropping, and upload
- Individual and filtered bulk PDF generation
- Per-school Card Designer with an explicit `/card-designer` route
- Platform user and school-assignment management
- Responsive Flutter UI for web and supported Flutter targets

PDF files are assembled in the Flutter client from data authorized and returned by the backend.

## Roles and UI access

The Flutter UI reflects the backend permissions, but it is not the security boundary. The FastAPI service must authorize every request.

| Role | Intended frontend access |
| --- | --- |
| Platform Admin | All active schools, user administration, assignments, school setup, student/card workflows, and Card Designer |
| School Admin | Assigned schools; school setup, ordinary user assignments, student/card workflows, printing, and Card Designer |
| Card Operator | Assigned schools; add students through ID-card entry, update card data, and upload photos |
| Teacher / Staff | Assigned-school access only; no student/card-data workflow in the current policy |

An inactive, revoked, or unassigned account must not gain access merely because a route or button is reachable.

## Technology

- Flutter / Dart
- Provider for application state
- `http` for the REST API
- `shared_preferences` for local session persistence
- `image_picker` and `image` for photo workflows
- `pdf` and `printing` for card output
- `sqflite_common_ffi` remains in the project for legacy/local code; production web data flows through FastAPI

## Project structure

```text
lib/
  models/       API and authentication models
  providers/    authentication/session state
  screens/      login, dashboard, administration, cards, and designer UI
  sections/     reusable student-form sections
  services/     API, PDF, image, and legacy database services
  theme/        application theme
assets/         images, icons, and card templates
test/           widget and model tests
web/            Flutter web host files
```

## Prerequisites

- Flutter SDK compatible with Dart `^3.12.2`
- A running ID-Card Manager backend
- Chrome for local web development
- Vercel CLI only when deploying the production web build

Check the local toolchain:

```powershell
flutter doctor
```

## Local setup

```powershell
git clone https://github.com/marvin101/idcard_flutter.git
cd idcard_flutter
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

`API_BASE_URL` is compiled into the application with `--dart-define`. If omitted, it defaults to `http://127.0.0.1:8000`.

Do not place backend credentials, database passwords, Supabase service keys, or JWT secrets in the Flutter application. A web build is public and cannot protect embedded secrets.

The client stores the access token only; it does not persist a refresh token. If an authenticated API request returns `401`, the local token and selected school are cleared and the user is returned to sign-in with a session-expired message. A `403` remains an authorization error and does not sign the user out.

## Quality checks

Run these before committing Flutter changes:

```powershell
flutter analyze
flutter test
```

The current tests cover the application shell, authentication models, card-template models, and school user-assignment behavior.

## Production web build and deployment

The existing workflow builds locally and deploys the generated static site to Vercel:

```powershell
cd F:\Paul\Projects\idcard_flutter
flutter build web --release --dart-define=API_BASE_URL=https://id-card-backend-vcz5.onrender.com
cd .\build\web
vercel --prod
```

Current production frontend: `https://idcard-flutter-web.vercel.app`

After deployment, verify login, school switching, role-specific navigation, student/photo operations, Card Designer authorization, and PDF generation. If a browser appears to run an older bundle, hard-refresh it and confirm the deployed Vercel project/domain.

## Related service

Backend source: `https://github.com/marvin101/id_card_backend`

For local development, start the backend first and confirm `http://127.0.0.1:8000/health` before launching Flutter.
