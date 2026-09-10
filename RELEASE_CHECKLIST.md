# CampusID Flutter release checklist

Use this checklist with the backend release checklist. Record the release owner,
backend and Flutter commit IDs, Alembic revision, deployment identifiers, UTC
verification time, and evidence in the approved release record. Never record
tokens, capability URLs, or secrets.

## Candidate validation

- [ ] Backend reports `0.8.0`, Flutter reports `0.8.0+8`, and both changelogs contain the dated `0.8.0` release notes.
- [ ] `flutter pub get`, `flutter analyze`, and `flutter test` pass.
- [ ] A production build succeeds with the approved API origin:

  ```powershell
  flutter build web --release --dart-define=API_BASE_URL=https://id-card-backend-vcz5.onrender.com
  ```

- [ ] The generated browser bundle contains no database credentials, Supabase service key, JWT secret, or test token.
- [ ] `vercel.json` is copied into `build/web` so clean-path SPA rewrites are deployed.

## Backend dependency

- [ ] Backend revision `a1d4e7f9b2c5` is reviewed and applied before this Flutter build is deployed.
- [ ] Render sets `PUBLIC_APP_URL` to the exact canonical Vercel HTTPS origin.
- [ ] Render includes the approved public-verification rate limit and production CORS origin.
- [ ] Backend health and database-readiness checks pass after deployment.

## Verification-link smoke tests

- [ ] A new Designer QR element defaults to **Verification link (recommended)**; existing static, single-field, custom-field, and multi-field templates still load.
- [ ] The saved QR resolves to a student-specific `/verify/<token>` URL in Cards preview and exported PDF.
- [ ] An administrator can enable school-wide verification and select an intentionally minimal disclosure set.
- [ ] Scanning the QR opens `/verify/<token>` without sign-in and shows only school-approved fields.
- [ ] Direct navigation and browser refresh on `/verify/<token>` work through Vercel's SPA rewrite.
- [ ] The public request sends no bearer token and the page does not expose student/internal UUIDs or non-selected PII.
- [ ] A school administrator can copy, disable, re-enable, and regenerate an individual student's verification link.
- [ ] Disabling a student or school shows the same generic unavailable state; regeneration invalidates the prior printed QR/link.
- [ ] A regenerated link is placed on a newly exported/reprinted card before physical use.
- [ ] Card Operator, Teacher, Staff, anonymous, and cross-school callers cannot manage verification settings or student links.

## Regression and deployment

- [ ] Sign-in, school switching, students, photos, lifecycle/history, Public Forms, Excel Grid, Designer save/conflict handling, Cards preview, and single/bulk PDF export still pass smoke testing.
- [ ] The exact locally built `build/web` directory is deployed with Vercel CLI, and the production deployment ID is recorded.
- [ ] Rollback artifacts for the prior frontend/backend commits are known. Application rollback is handled separately from database recovery; the production migration is not casually downgraded.
