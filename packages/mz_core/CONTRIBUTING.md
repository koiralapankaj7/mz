# Contributing to mz_core

Thank you for your interest in contributing to mz_core!

**For general contribution guidelines, please see the [root CONTRIBUTING.md](../../CONTRIBUTING.md).**

This document covers mz_core-specific guidelines.

## Package Overview

mz_core is a Flutter package providing utilities for state management, logging, collections, and rate limiting. It requires Flutter SDK (>=3.0.0).

## Development Setup

```bash
# From the monorepo root
cd packages/mz_core

# Install dependencies
flutter pub get

# Run tests
flutter test

# Run tests with coverage
flutter test --coverage

# Check analysis
dart analyze --fatal-infos

# Format code
dart format .
```

## Testing Guidelines

- Maintain 100% test coverage
- Write unit tests for all utilities and logic
- Write widget tests for Flutter components
- Use descriptive test names: `'should [behavior] when [condition]'`

### Running Tests

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/src/controller_test.dart
```

## Code Style

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- All public APIs must have `///` doc comments
- Include code examples in documentation
- Pass `very_good_analysis` lint rules without warnings

## Project Structure

```
mz_core/
├── lib/
│   ├── mz_core.dart          # Main export file
│   └── src/                   # Implementation files
├── test/                      # Test files
├── example/                   # Example Flutter app
└── doc/                       # Documentation
    ├── getting_started.md
    ├── core_concepts.md
    └── troubleshooting.md
```

## Release Process

See the [root RELEASE.md](../../RELEASE.md) for release guidelines.

## Questions?

- Open a [GitHub Issue](https://github.com/koiralapankaj7/mz/issues)
- Review existing issues and discussions
