# LawLink CI/CD Pipeline

This document describes the CI/CD pipeline for the LawLink Flutter application.

## Pipeline Steps

**Step 1: Test & Analyze**
- Code analysis with `flutter analyze` (non-blocking warnings)
- Code formatting check with `dart format` (non-blocking for now)
- Unit tests with coverage reporting
- Triggered on pushes to `main`/`develop` and PRs to `main`

**Step 2: Build APK** 
- Debug APK build
- Release APK build
- Android App Bundle (AAB) build
- Upload artifacts with retention policies
- Dynamic build numbering
- Uses Flutter 3.29.3 (Dart 3.7.2)

## Local Testing

```bash
flutter pub get
flutter analyze --no-fatal-infos
dart format --set-exit-if-changed .
flutter test
flutter test --coverage
```

## Important Notes

**Analysis Warnings**: The pipeline currently shows ~240 info/warning messages during analysis. These are non-blocking and include:
- Deprecated API usage (e.g., `withOpacity`, `Share` package)
- Code style suggestions (print statements, BuildContext usage)
- File naming conventions

These warnings don't prevent builds from succeeding and can be addressed gradually during development.

## Build Commands

```bash
flutter build apk --debug
flutter build apk --release
flutter build appbundle --release
```

## Artifacts

- Debug APK: 30 days retention
- Release APK: 90 days retention
- Release AAB: 90 days retention

## Next Steps

Future enhancements:
- Firebase App Distribution deployment
- Google Play Store integration
- iOS build support
