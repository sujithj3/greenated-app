# Flutter Environment Commands

This app chooses its environment at build time with `APP_ENV`.

In `lib/main.dart`, the app reads:

```dart
const appEnvironment = String.fromEnvironment(
  'APP_ENV',
  defaultValue: 'development',
);

await dotenv.load(fileName: '.env.$appEnvironment');
```

That means:

| Command value | Env file loaded |
| --- | --- |
| no `APP_ENV` passed | `.env.development` |
| `APP_ENV=development` | `.env.development` |
| `APP_ENV=staging` | `.env.staging` |
| `APP_ENV=production` | `.env.production` |

## Env Files

Real local env files:

```text
.env.development
.env.staging
.env.production
```

These files are used by the app and are ignored from git because they can contain real keys or private configuration.

Example/template files:

```text
.env.development.example
.env.staging.example
.env.production.example
```

These files are not used by the app. They only show which variables are required.

## Development Debug

Plain `flutter run` defaults to development:

```bash
flutter run
```

This is the same as:

```bash
flutter run --dart-define=APP_ENV=development
```

Use this for normal development with hot reload.

## Staging Debug

Use this when staging values are ready:

```bash
flutter run --dart-define=APP_ENV=staging
```

This loads:

```text
.env.staging
```

## Production Release Run

Use this to run the app on a connected device in release mode with production config:

```bash
flutter run --release --dart-define=APP_ENV=production
```

This loads:

```text
.env.production
```

## Android APK Release

Use this to create a production APK:

```bash
flutter clean
flutter pub get
flutter build apk --release --dart-define=APP_ENV=production
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Android release builds require local signing config:

```text
android/key.properties
```

That file is ignored from git. Use `android/key.properties.example` as the template.

## Android App Bundle Release

Use this for Play Store upload:

```bash
flutter clean
flutter pub get
flutter build appbundle --release --dart-define=APP_ENV=production
```

Output:

```text
build/app/outputs/bundle/release/app-release.aab
```

## iOS Release Build

Use this to create an iOS release build:

```bash
flutter clean
flutter pub get
flutter build ios --release --dart-define=APP_ENV=production
```

iOS signing is handled through Xcode and the Apple Developer account.

## iOS IPA Release

Use this for App Store or TestFlight distribution:

```bash
flutter clean
flutter pub get
flutter build ipa --release --dart-define=APP_ENV=production
```

## Debug vs Release

Debug mode:

```bash
flutter run
```

- Used during development.
- Supports hot reload.
- Not optimized for production.

Release mode:

```bash
flutter run --release
flutter build apk --release
flutter build ipa --release
```

- Used for production or final testing.
- Optimized for performance.
- Does not support hot reload.
- Uses release build behavior and release signing where applicable.

## Quick Command Reference

```bash
# Development debug
flutter run

# Development debug, explicit env
flutter run --dart-define=APP_ENV=development

# Staging debug
flutter run --dart-define=APP_ENV=staging

# Production release run
flutter run --release --dart-define=APP_ENV=production

# Android production APK
flutter build apk --release --dart-define=APP_ENV=production

# Android production App Bundle
flutter build appbundle --release --dart-define=APP_ENV=production

# iOS production build
flutter build ios --release --dart-define=APP_ENV=production

# iOS production IPA
flutter build ipa --release --dart-define=APP_ENV=production
```
