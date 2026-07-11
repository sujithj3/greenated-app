# Flutter Environment Commands

This app now uses two build-time switches:

- `--flavor` selects the native Android/iOS app id and launcher name.
- `--dart-define=APP_ENV=...` selects the Flutter `.env.<environment>` file.

Always keep the flavor and `APP_ENV` value matched.

## Environments

| Environment | Flavor | APP_ENV | Env file | Native app id / bundle id | App name |
| --- | --- | --- | --- | --- | --- |
| Development | `development` | `development` | `.env.development` | `com.dev.greenated.app` | `Greenated-Debug` |
| Staging | `staging` | `staging` | `.env.staging` | `com.staging.greenated.app` | `Greenated-Staging` |
| Production | `production` | `production` | `.env.production` | `com.greenated.app` | `Greenated` |

In `lib/main.dart`, the app still reads:

```dart
const appEnvironment = String.fromEnvironment(
  'APP_ENV',
  defaultValue: 'development',
);

await dotenv.load(fileName: '.env.$appEnvironment');
```

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

## Flutter Clean Logs
```
flutter logs | sed -E 's/^I\/flutter \([0-9]+\): //'
```

## Development Debug

Use this for normal development with hot reload:

```bash
flutter run --flavor development --dart-define=APP_ENV=development
```

## Staging Debug

Use this when staging values are ready:

```bash
flutter run --flavor staging --dart-define=APP_ENV=staging
```

## Production Debug
```bash
flutter run --flavor production --dart-define=APP_ENV=production
```

## Android Debug APKs

Use these to create installable debug APKs for each flavor:

```bash
# Development debug APK
flutter build apk --flavor development --debug --dart-define=APP_ENV=development

flutter build apk --flavor development --release --dart-define=APP_ENV=development

flutter build apk --flavor development --debug --dart-define=APP_ENV=development --split-per-abi

# Staging debug APK
flutter build apk --flavor staging --debug --dart-define=APP_ENV=staging

# Production debug APK
flutter build apk --flavor production --debug --dart-define=APP_ENV=production
```

Outputs:

```text
build/app/outputs/flutter-apk/app-development-debug.apk
build/app/outputs/flutter-apk/app-staging-debug.apk
build/app/outputs/flutter-apk/app-production-debug.apk
```

## Production Release Run

Use this to run the app on a connected device in release mode with production config:

```bash
flutter run --flavor production --release --dart-define=APP_ENV=production
```

## Android APK Release

Use this to create a production APK:

```bash
flutter clean
flutter pub get
flutter build apk --flavor production --release --dart-define=APP_ENV=production
```

Output:

```text
build/app/outputs/flutter-apk/app-production-release.apk
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
flutter build appbundle --flavor production --release --dart-define=APP_ENV=production
```

Output:

```text
build/app/outputs/bundle/productionRelease/app-production-release.aab
```

## iOS Release Build

Use this to create an iOS release build:

```bash
flutter clean
flutter pub get
flutter build ios --flavor production --release --dart-define=APP_ENV=production
```

iOS signing is handled through Xcode and the Apple Developer account. The bundle ids `com.dev.greenated.app`, `com.staging.greenated.app`, and `com.greenated.app` must exist in the Apple Developer account for device, TestFlight, or App Store builds.

## iOS Debug Builds

Use these to create debug iOS app builds without codesigning:

```bash
# Development debug iOS app
flutter build ios --flavor development --debug --no-codesign --dart-define=APP_ENV=development

# Staging debug iOS app
flutter build ios --flavor staging --debug --no-codesign --dart-define=APP_ENV=staging

# Production debug iOS app
flutter build ios --flavor production --debug --no-codesign --dart-define=APP_ENV=production
```

Output:

```text
build/ios/iphoneos/Runner.app
```

## iOS Debug IPAs

Use these when you need signed debug IPAs for registered development devices:

```bash
# Development debug IPA
flutter build ipa --flavor development --debug --export-method development --dart-define=APP_ENV=development

# Staging debug IPA
flutter build ipa --flavor staging --debug --export-method development --dart-define=APP_ENV=staging

# Production debug IPA
flutter build ipa --flavor production --debug --export-method development --dart-define=APP_ENV=production
```

Output:

```text
build/ios/ipa/*.ipa
```

## iOS IPA Release

Use this for App Store or TestFlight distribution:

```bash
flutter clean
flutter pub get
flutter build ipa --flavor production --release --dart-define=APP_ENV=production
```

## Quick Command Reference

```bash
# Development debug
flutter run --flavor development --dart-define=APP_ENV=development

# Staging debug
flutter run --flavor staging --dart-define=APP_ENV=staging

# Android development debug APK
flutter build apk --flavor development --debug --dart-define=APP_ENV=development

# Android staging debug APK
flutter build apk --flavor staging --debug --dart-define=APP_ENV=staging

# Android production debug APK
flutter build apk --flavor production --debug --dart-define=APP_ENV=production

# Production release run
flutter run --flavor production --release --dart-define=APP_ENV=production

# Android production APK
flutter build apk --flavor production --release --dart-define=APP_ENV=production

# Android production App Bundle
flutter build appbundle --flavor production --release --dart-define=APP_ENV=production

# iOS production build
flutter build ios --flavor production --release --dart-define=APP_ENV=production

# iOS development debug app
flutter build ios --flavor development --debug --no-codesign --dart-define=APP_ENV=development

# iOS staging debug app
flutter build ios --flavor staging --debug --no-codesign --dart-define=APP_ENV=staging

# iOS production debug app
flutter build ios --flavor production --debug --no-codesign --dart-define=APP_ENV=production

# iOS development debug IPA
flutter build ipa --flavor development --debug --export-method development --dart-define=APP_ENV=development

# iOS staging debug IPA
flutter build ipa --flavor staging --debug --export-method development --dart-define=APP_ENV=staging

# iOS production debug IPA
flutter build ipa --flavor production --debug --export-method development --dart-define=APP_ENV=production

# iOS production IPA
flutter build ipa --flavor production --release --dart-define=APP_ENV=production
```
