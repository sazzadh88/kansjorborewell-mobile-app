# OTA Update — Plan (deferred)

> Self-hosted OTA for sideloaded APK + desktop zips. Shorebird not used (no desktop support, vendor lock-in). Fits current `release.yml` tag → GitHub Release flow.

## Goal
Check for newer build on `SplashScreen` (before auth), show update dialog, let user update without Play Store. `taste.md:8` splash resolves auth state first — OTA check runs alongside it.

## Backend (Laravel)

1. **Migration** `2026_08_26_020000_create_app_versions_table.php`
   - `id`, `platform enum('android','windows','macos')`, `version string` (e.g. `1.0.2`), `build_number uint`, `download_url string(2048)`, `force_update bool default false`, `changelog text nullable`, `is_active bool default true`, `timestamps`
   - `index [platform, is_active]`, `unique [platform, version]`

2. **Model** `backend/app/Models/AppVersion.php` — fillable + casts.

3. **Permissions** `backend/app/Support/PermissionCatalog.php:13`
   - Add `app.view` (View available app updates, group Administration, sort 29, roles [admin,manager,operator,accountant])
   - Add `app.manage` (Manage app versions/releases, group Administration, sort 30, roles [admin])
   - Run `PermissionSeeder`

4. **Controller** `backend/app/Http/Controllers/Api/AppVersionController.php`
   - `GET /api/app-version?platform=android|windows|macos` — **public** (no `auth:sanctum`), returns latest `is_active` row for platform: `{platform, version, build_number, download_url, force_update, changelog, updated_at}`. 204 if no row.
   - `GET /api/app-versions` — public, list latest per platform (or all active).
   - Admin CRUD under `auth:sanctum` + `perm:app.manage`: `POST /api/app-versions`, `PATCH /api/app-versions/{id}`, `DELETE ...`
   - List/detail under `perm:app.view` for authenticated admin UI.

5. **Routes** `backend/routes/api.php:7`
   - Public routes **outside** `auth:sanctum` group.
   - Admin routes inside `middleware('perm:app.manage')`.

6. **Seeder** `backend/database/seeders/AppVersionSeeder.php` — seed one row per platform from current `pubspec.yaml:19` versions (`1.0.1+2`) with GitHub Release URLs (`release.yml:137`).

## Shared Package `packages/core`

- `lib/models.dart` — add `AppVersion` with `version`, `buildNumber`, `downloadUrl`, `forceUpdate`, `changelog`, `compare` helper (`isNewerThan(currentVersion, currentBuild)` using semver split).
- `lib/api_client.dart:30` — add `Future<AppVersion?> getAppVersion(String platform)` → `dio.get('/app-version', queryParameters: {'platform': platform})`, unauthenticated dio instance helper or `Dio` without token.
- `lib/providers.dart` — optional `appVersionProvider` family by platform.

Keep `packages/core` free of platform plugins (`taste.md:47`) — comparison is pure Dart.

## Mobile `mobile/`

- **Deps** `mobile/pubspec.yaml:30`: add `package_info_plus`, `open_filex`, `path_provider`, `url_launcher` (or `permission_handler` not needed for `REQUEST_INSTALL_PACKAGES`).
- **Android** `mobile/android/app/src/main/AndroidManifest.xml`: add `<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />` (remove not needed — `taste.md:38` keep only used).
- **API client** `mobile/lib/core/api_client.dart:37` already uses env `API_BASE_URL`.
- **Service** `mobile/lib/core/app_update_service.dart` — `checkAndPrompt(context)`:
  1. Get `PackageInfo` version/build.
  2. Call `core.ApiClient.getAppVersion('android')` with unauth Dio (or reuse authenticated but catch 401).
  3. If `isNewerThan` and `forceUpdate` → non-dismissible dialog; else dismissible.
  4. On Update: `dio.download(downloadUrl, savePath, onReceiveProgress)` to `getTemporaryDirectory()/kansjor-update.apk` or Downloads via `MethodChannel` (`mobile/lib/core/api_client.dart:24`), then `OpenFilex.open(path)`.
  5. Error: surface `apiErrorMessage` (`packages/core/lib/api_client.dart:402`) — "could not be saved" vs "API request failed" (`taste.md:63`).
- **Hook** `mobile/lib/features/auth/splash_screen.dart:1` → convert to `ConsumerStatefulWidget`, call `app_update_service` in `initState` alongside `authProvider` bootstrap. Or create `splash_provider` that runs both. Show dialog via `go_router` overlay without breaking `mobile/lib/core/router.dart:58` redirect (stay on `/splash` until check done).
- **Settings**: optional "Check for updates" button in `mobile/lib/features/profile/profile_screen.dart`.

## Desktop `desktop/`

- **Deps** `desktop/pubspec.yaml:30`: add `package_info_plus`, `url_launcher`.
- **Service** `desktop/lib/core/app_update_service.dart` — same check but `platform = macos|windows` (`Platform.isMacOS ? 'macos' : 'windows'`).
  - Download flow differs: desktop zips can't self-replace running exe. MVP: dialog with changelog + "Download" button → `launchUrlString(downloadUrl)` opening GitHub Release (`release.yml:137` zips). User replaces `kansjor-desktop-*.zip` contents.
  - Future: `updater` package or Sparkle/WinSparkle for auto-replace (needs signing/notarization).
- **Hook** `desktop/lib/router.dart` or `desktop/lib/main.dart:13` window init — check after `windowManager` ready.
- Uses `desktop/lib/core/api_client.dart:10` `desktopApiBaseUrl()` env define.

## Release / CI

- Keep `release.yml:1` tag-triggered builds for `build-apk:10`, `build-windows:55`, `build-macos:85` → `artifacts/app-release.apk` etc.
- After creating Release, backend operator creates/updates `app_versions` row via admin screen or `curl -X POST /api/app-versions` with new `download_url` = GitHub Release asset URL (`https://github.com/<org>/jp-bricks/releases/download/v1.0.2/app-release.apk`).
- Optional automation: GitHub Action job that `POST`s to `app.kansjorborewell.in/api/app-versions` using `GITHUB_TOKEN` + secret API token.

## Validation

- `php artisan migrate --pretend` + `php artisan test` (add `tests/Feature/AppVersionTest.php` for public endpoint 204/200 + perm gate).
- Real DB curl: `curl https://app.kansjorborewell.in/api/app-version?platform=android`
- `flutter analyze` in `mobile/`, `desktop/`, `packages/core` (`taste.md:35`).
- Manual: bump `version: 1.0.1+2` → `1.0.2+3` in both pubspecs (`taste.md:89` lockstep), push tag, verify dialog appears on old install.

## Deferred

All todos remain `pending` in `TodoWrite`. When ready, flip first pending to `in_progress` and implement in order: Backend → Core → Mobile → Desktop → Validate.
