# LawLink CI/CD Pipeline

This README outlines the CI/CD setup for the **LawLink Flutter application**.

---

## Pipeline Overview

The pipeline currently handles:
- Code analysis (`flutter analyze`)
- Format check (`dart format`)
- Unit tests with coverage
- Triggered on pushes to `main`/`develop` and PRs to `main`

---

## Setup Summary

**Prerequisites:**
- GitHub repo
- Flutter project
- Basic test files

**Key Files:**
- `.github/workflows/ci-cd.yml`
- `test/widget_test.dart`
- `test/chat_storage_service_test.dart`

---

## Run Tests Locally

```bash
flutter pub get
flutter analyze
dart format --set-exit-if-changed .
flutter test
flutter test --coverage
