# Contributing to flutter_touchless

Thank you for your interest in contributing to `flutter_touchless`! We welcome contributions from developers, accessibility researchers, and UI designers.

## Development Workflow

1. **Fork and Clone**
   ```bash
   git clone https://github.com/usmanahmad007/flutter_touchless.git
   cd flutter_touchless
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   cd example && flutter pub get && cd ..
   ```

3. **Run Code Analysis & Tests**
   Before submitting a Pull Request, verify that all static analysis rules and tests pass with zero warnings:
   ```bash
   flutter analyze
   flutter test
   ```

4. **Run Example App**
   Test your changes across real devices (Android, iOS) or Desktop:
   ```bash
   cd example
   flutter run
   ```

## Pull Request Guidelines

- Follow [Effective Dart](https://dart.dev/effective-dart) style guidelines.
- Add unit or widget tests for any new detectors, gestures, or widgets.
- Update `CHANGELOG.md` with a summary of your changes.
- Ensure all tests pass (`flutter test`).

## Reporting Issues

If you find a bug or have a feature suggestion, please open an issue on GitHub:
https://github.com/usmanahmad007/flutter_touchless/issues
