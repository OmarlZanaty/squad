# Squad app version checker

The Squad app now uses the same version policy system as the player app.

## Backend endpoint

`GET /api/app/version-policy?platform=android|ios`

Expected response:

```json
{
  "latest_version": "1.0.16",
  "minimum_version": "1.0.14",
  "force_update": true,
  "maintenance_mode": false,
  "message": "Please update to continue.",
  "store_urls": {
    "android": "https://play.google.com/store/apps/details?id=com.mohamed_helicopter.squad",
    "ios": "https://apps.apple.com/app/id1234567890"
  }
}
```

## App behavior in Splash

1. If `maintenance_mode=true` → blocking maintenance dialog.
2. If current version `< minimum_version` → force update screen (cannot continue).
3. If current version `< latest_version` only → optional update dialog.
4. Continue to login/main auth flow.

## In-app QA screen

Open: `Settings -> Version check`

Shows current app version, backend latest/minimum, and computed status.
