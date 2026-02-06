# MZ Packages

A collection of Dart and Flutter packages for building robust applications.

[![CI](https://github.com/koiralapankaj7/mz/actions/workflows/ci.yml/badge.svg)](https://github.com/koiralapankaj7/mz/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Packages

| Package | Version | Coverage | Description |
|---------|---------|----------|-------------|
| [mz_core](packages/mz_core/) | [![pub](https://img.shields.io/pub/v/mz_core.svg)](https://pub.dev/packages/mz_core) | [![codecov](https://codecov.io/gh/koiralapankaj7/mz/branch/main/graph/badge.svg?flag=mz_core)](https://codecov.io/gh/koiralapankaj7/mz) | Flutter utilities for state management, logging, collections, and rate limiting |
| [mz_collection](packages/mz_collection/) | [![pub](https://img.shields.io/pub/v/mz_collection.svg)](https://pub.dev/packages/mz_collection) | [![codecov](https://codecov.io/gh/koiralapankaj7/mz/branch/main/graph/badge.svg?flag=mz_collection)](https://codecov.io/gh/koiralapankaj7/mz) | Pure Dart collection state management with filtering, sorting, grouping, and more |
| [mz_lints](packages/mz_lints/) | [![pub](https://img.shields.io/pub/v/mz_lints.svg)](https://pub.dev/packages/mz_lints) | - | Custom Dart lint rules for Flutter apps |

## Quick Start

### mz_core

```yaml
dependencies:
  mz_core: ^1.3.2
```

```dart
import 'package:mz_core/mz_core.dart';

// State management with auto-disposal
final controller = StateController<int>(0);
controller.addListener(() => print(controller.state));
controller.state = 42;

// Logging
final logger = SimpleLogger('MyApp');
logger.info('Application started');
```

### mz_collection

```yaml
dependencies:
  mz_collection: ^0.0.1
```

```dart
import 'package:mz_collection/mz_collection.dart';

// Collection management with filtering, sorting, and more
final collection = ListController<User>(users);
collection.filter((user) => user.isActive);
collection.sort((a, b) => a.name.compareTo(b.name));
```

### mz_lints

```yaml
dev_dependencies:
  mz_lints: ^0.1.0
```

```yaml
# analysis_options.yaml
analyzer:
  plugins:
    - mz_lints
```

## Development

This repository uses [Melos](https://melos.invertase.dev/) for managing the monorepo.

### Setup

```bash
# Install Melos
dart pub global activate melos

# Bootstrap the workspace
melos bootstrap
```

### Common Commands

```bash
# Run analysis on all packages
melos run analyze

# Run tests on all packages
melos run test

# Format all packages
melos run format
```

### Package-Specific Commands

For packages not in the Dart workspace (mz_collection, mz_lints):

```bash
# mz_collection
cd packages/mz_collection
dart pub get
dart test

# mz_lints
cd packages/mz_lints
dart pub get
dart test
```

## Contributing

Contributions are welcome! Please read our [contributing guidelines](CONTRIBUTING.md) before submitting a pull request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feat/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feat/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
