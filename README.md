# MZ Packages

A monorepo containing production-ready Flutter and Dart packages.

[![CI](https://github.com/koiralapankaj7/mz/workflows/CI/badge.svg)](https://github.com/koiralapankaj7/mz/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Packages

| Package | Description | pub.dev |
|---------|-------------|---------|
| [mz_core](packages/mz_core) | Flutter utilities for state management, logging, collections, and rate limiting | [![pub package](https://img.shields.io/pub/v/mz_core.svg)](https://pub.dev/packages/mz_core) |
| [mz_lints](packages/mz_lints) | Custom Dart lint rules for Flutter apps | [![pub package](https://img.shields.io/pub/v/mz_lints.svg)](https://pub.dev/packages/mz_lints) |

## Getting Started

### Prerequisites

- [Flutter](https://flutter.dev/docs/get-started/install) >= 3.22.0
- [Dart](https://dart.dev/get-dart) >= 3.5.0
- [Melos](https://melos.invertase.dev/) >= 7.0.0

### Setup

1. **Install Melos globally:**

   ```bash
   dart pub global activate melos
   ```

2. **Clone the repository:**

   ```bash
   git clone https://github.com/koiralapankaj7/mz.git
   cd mz
   ```

3. **Bootstrap the workspace:**

   ```bash
   melos bootstrap
   ```

   This installs dependencies for all packages and links local packages together.

## Common Commands

| Command | Description |
|---------|-------------|
| `melos bootstrap` | Install dependencies and link packages |
| `melos run analyze` | Run static analysis on all packages |
| `melos run format` | Check formatting in all packages |
| `melos run format:fix` | Fix formatting in all packages |
| `melos run test` | Run tests in all packages |
| `melos run test:coverage` | Run tests with coverage |
| `melos run clean` | Clean all packages |
| `melos run publish:check` | Dry-run publish check |
| `melos run publish` | Publish packages to pub.dev |

## Development Workflow

### Working on a package

1. Make changes in `packages/<package_name>/`
2. Run tests: `melos run test`
3. Check analysis: `melos run analyze`
4. Commit with [Conventional Commits](https://www.conventionalcommits.org/)

### Versioning and Publishing

This monorepo uses **independent versioning** - each package has its own version.

```bash
# Check what would be published
melos run publish:check

# Publish all changed packages
melos run publish
```

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) before submitting a PR.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
