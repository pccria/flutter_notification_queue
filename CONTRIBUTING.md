# Contributing to Flutter Notification Queue

Thank you for your interest in contributing to `flutter_notification_queue`!
This document outlines our development process, code standards, and guidelines.

---

## 🛠️ Development Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/pccria/flutter_notification_queue.git
   cd flutter_notification_queue
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   (cd example && flutter pub get)
   ```

3. **Verify tests pass**:
   ```bash
   flutter test
   (cd example && flutter test)
   ```

---

## 📏 Code Style & Formatting Guidelines

We adhere strictly to official Dart & Flutter style guides:

- **Line Length**: All Dart source code and test files must strictly stay
  within **80 characters** per line.
- **Formatter**: Always format code using `dart format .` before submitting.
- **Analysis**: Run `flutter analyze --fatal-warnings` to ensure zero linter
  or analyzer warnings.
- **Docstrings**: All public APIs must include clear Dartdoc comments with
  code samples where appropriate. Preserve existing docstrings.
- **Sealed Hierarchies**: When adding new behaviors or events, extend sealed
  class hierarchies and provide exhaustive pattern matching.

---

## 🧪 Testing

Every bug fix, architectural adjustment, and feature addition must be accompanied
by automated tests:

- **Unit & Widget Tests**: Place tests in `test/src/` mirroring `lib/src/`.
- **Interaction Tests**: Test touch gestures, drag thresholds, timers, and
  relocation transitions.
- **Golden Tests**: For visual changes, run `flutter test test/golden/`. Note
  that golden comparators use a 0.5% tolerance threshold.

Run the test suite:
```bash
flutter test
```

---

## 📦 Pull Request Process

1. **Create a topic branch** from `master`:
   ```bash
   git checkout -b feat/your-feature-name
   ```
2. **Follow Conventional Commits**:
   - `feat(...)`: New user-facing capabilities
   - `fix(...)`: Bug fixes and resource leaks
   - `perf(...)`: Performance and layout memoizations
   - `docs(...)`: Documentation updates
   - `test(...)`: Adding or updating test suites
   - `chore(...)`: Tooling, dependency, or release updates
3. **Verify Pre-Publish Readiness**:
   ```bash
   flutter analyze --fatal-warnings
   dart format --output=none --set-exit-if-changed .
   flutter test
   flutter pub publish --dry-run
   ```
4. **Submit a Pull Request** describing the motivation, implementation details,
   and test coverage.

---

## 💬 Community & Questions

For bugs or feature proposals, please open an issue on GitHub:
https://github.com/pccria/flutter_notification_queue/issues
