# Version checker flow (squad_player)

This app checks version policy in `SplashScreen` before sending the user to login/main.

## API contract expected by the app

`GET /api/app/version-policy?platform=android|ios`

Example response:

```json
{
  "latest_version": "1.8.0",
  "minimum_version": "1.6.0",
  "force_update": false,
  "maintenance_mode": false,
  "message": "A new version is available.",
  "store_urls": {
    "android": "https://play.google.com/store/apps/details?id=com.mohamed_helicopter.squad_player",
    "ios": "https://apps.apple.com/app/id1234567890"
  }
}
```

## Decision logic

1. App requests policy from backend.
2. If `maintenance_mode = true`:
   - Show blocking maintenance dialog.
3. Else if `current < minimum_version`:
   - Redirect user to `ForceUpdateScreen`.
   - User cannot continue without tapping **Update Now**.
4. Else if `current < latest_version`:
   - Show optional soft update dialog.
   - If user taps update, app opens store and still allows continue.
5. Then app continues normal auth routing (token -> main/login).

## Where to set `current_version` and `minimum_version`

### `current_version` (you set it in the app build)

The app reads current version from Flutter package metadata via
`PackageInfo.fromPlatform()` in `SplashScreen`.

Set it in `squad_player/pubspec.yaml`:

```yaml
version: 1.8.0+12
```

- App version used by checker = `1.8.0`
- Build number = `12`

After changing it, rebuild/reinstall the app.

### `minimum_version` (you set it on backend response)

`minimum_version` is not hardcoded in app. You return it from:

`GET /api/app/version-policy?platform=android|ios`

Example backend response:

```json
{
  "latest_version": "1.8.0",
  "minimum_version": "1.6.0",
  "force_update": true,
  "maintenance_mode": false,
  "message": "Please update to continue."
}
```

- If app version is below `minimum_version`:
  user is blocked and redirected to update.
- If app version is below `latest_version` only:
  user sees optional update prompt.

### Backend files you edit

In this repository, the version policy backend is already implemented here:

- Route mount: `backend/index.js` → `app.use('/api/app', require('./routes/appVersion'));`
- Endpoint routes: `backend/routes/appVersion.js`
  - `GET /api/app/version-policy`
  - `PUT /api/app/version-policy` (admin)
- Logic + DB update code: `backend/controllers/appVersionController.js`
  - `getVersionPolicy`
  - `updateVersionPolicy`

### How to update `minimum_version` on backend

Use the admin endpoint:

`PUT /api/app/version-policy`

Headers:

- `Content-Type: application/json`
- `x-admin-key: <ADMIN_SECRET_KEY>`

Body example:

```json
{
  "platform": "android",
  "latest_version": "2.1.0",
  "minimum_version": "2.0.0",
  "force_update": true,
  "maintenance_mode": false,
  "message": "Please update to continue.",
  "android_store_url": "https://play.google.com/store/apps/details?id=com.mohamed_helicopter.squad_player"
}
```

Example cURL:

```bash
curl -X PUT "http://<YOUR_HOST>/api/app/version-policy" \
  -H "Content-Type: application/json" \
  -H "x-admin-key: <ADMIN_SECRET_KEY>" \
  -d '{
    "platform":"android",
    "latest_version":"2.1.0",
    "minimum_version":"2.0.0",
    "force_update":true,
    "maintenance_mode":false,
    "message":"Please update to continue."
  }'
```

### Important

Minimum-version blocking is now backend-driven in app logic:
- If installed app version is lower than `minimum_version`, app always blocks
  and opens force-update flow.
- This works even if `force_update` is false/missing (for backward compatibility).

## How users are notified

- **Force update**: full-screen blocking page with message and update button.
- **Soft update**: dismissible dialog from splash.

## How users are redirected to new version

- Update action launches store link via `url_launcher` using:
  - response-provided store URL when available
  - fallback URLs from `AppConfig`
