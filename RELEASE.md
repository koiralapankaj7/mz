# Release Checklist

This document outlines all steps required before releasing a new version of any package in the MZ monorepo.

## Packages

| Package | Tag Format | Publish Command |
| ------- | ---------- | --------------- |
| mz_core | `mz_core-vX.X.X` | `flutter pub publish` |
| mz_collection | `mz_collection-vX.X.X` | `dart pub publish` |
| mz_lints | `mz_lints-vX.X.X` | `dart pub publish` |

## Pre-Release Checklist

### 1. Version Updates

Update version in the following files for the package being released:

#### mz_core

| File | Location |
| ---- | -------- |
| `packages/mz_core/pubspec.yaml` | `version:` field |
| `packages/mz_core/CHANGELOG.md` | Add new version section at top |
| `packages/mz_core/README.md` | `mz_core: ^x.x.x` in Installation section |
| `packages/mz_core/doc/getting_started.md` | `mz_core: ^x.x.x` in Installation section |

#### mz_collection

| File | Location |
| ---- | -------- |
| `packages/mz_collection/pubspec.yaml` | `version:` field |
| `packages/mz_collection/CHANGELOG.md` | Add new version section at top |
| `packages/mz_collection/README.md` | `mz_collection: ^x.x.x` in Installation section |

#### mz_lints

| File | Location |
| ---- | -------- |
| `packages/mz_lints/pubspec.yaml` | `version:` field |
| `packages/mz_lints/CHANGELOG.md` | Add new version section at top |
| `packages/mz_lints/README.md` | `mz_lints: ^x.x.x` (2 occurrences: dev_dependencies and plugins sections) |
| `packages/mz_lints/example/lib/main.dart` | `mz_lints: ^x.x.x` in doc comment |

### 2. Update Documentation

Update documentation files to reflect new features and changes:

#### For New Features

| File | What to Update |
| ---- | -------------- |
| `doc/core_concepts.md` | Add new section explaining the feature concept, API, and usage patterns |
| `doc/getting_started.md` | Add quick start examples for the new feature |
| `doc/troubleshooting.md` | Add common issues and solutions for the new feature |
| `README.md` | Update Features table if adding major functionality |

#### Documentation Checklist

- [ ] Add feature to Table of Contents in each doc file
- [ ] Include code examples with comments
- [ ] Document common pitfalls and solutions
- [ ] Add to "Known Limitations" section if applicable
- [ ] Update "Tips" section with best practices

#### Example: Adding a New Feature Section

```markdown
## Feature Name

### Concept

Brief description of what the feature does and why it exists.

### Basic Usage

\`\`\`dart
// Code example
\`\`\`

### Advanced Usage

Additional examples for complex scenarios.

### When to Use

| Use Case | Example |
| -------- | ------- |
| **Case 1** | Description |
| **Case 2** | Description |
```

### 3. Update CHANGELOG

Follow [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format:

```markdown
## [x.x.x] - YYYY-MM-DD

### Added
- New features

### Changed
- Changes to existing functionality

### Deprecated
- Features to be removed in future

### Removed
- Removed features

### Fixed
- Bug fixes

### Improved
- Performance or quality improvements
```

Add version link at bottom of CHANGELOG:

```markdown
[x.x.x]: https://github.com/koiralapankaj7/mz/releases/tag/<package>-vx.x.x
```

### 4. Run Tests

```bash
# All packages (workspace)
melos run test

# mz_core only
cd packages/mz_core && flutter test

# mz_collection only (not in workspace)
cd packages/mz_collection && dart test

# mz_lints only (not in workspace)
cd packages/mz_lints && dart test
```

Ensure all tests pass before proceeding.

### 5. Verify Analysis

```bash
# All packages (workspace)
melos run analyze

# mz_core
cd packages/mz_core && dart analyze --fatal-infos

# mz_collection
cd packages/mz_collection && dart analyze --fatal-infos

# mz_lints
cd packages/mz_lints && dart analyze --fatal-infos
```

### 6. Run CI Locally

Run GitHub Actions workflows locally using [act](https://github.com/nektos/act) to verify CI will pass before pushing.

#### Prerequisites

Install `act`:

```bash
# macOS
brew install act

# Linux
curl -s https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
```

#### Running CI Locally

```bash
# Run full CI workflow
act -W .github/workflows/ci.yml --container-architecture linux/amd64

# Run specific jobs
act -W .github/workflows/ci.yml -j analyze-mz-core --container-architecture linux/amd64
act -W .github/workflows/ci.yml -j test-mz-core --container-architecture linux/amd64
act -W .github/workflows/ci.yml -j analyze-mz-collection --container-architecture linux/amd64
act -W .github/workflows/ci.yml -j test-mz-collection --container-architecture linux/amd64
act -W .github/workflows/ci.yml -j analyze-mz-lints --container-architecture linux/amd64
act -W .github/workflows/ci.yml -j test-mz-lints --container-architecture linux/amd64

# Run release workflow (dry run)
act -W .github/workflows/release.yml --container-architecture linux/amd64 -n
```

Fix any failures before proceeding. Post-step cache failures (e.g., "node not found") can be ignored.

#### Common act Issues

| Issue | Solution |
| ----- | -------- |
| Docker not running | Start Docker Desktop |
| Image pull timeout | Use `-P ubuntu-latest=catthehacker/ubuntu:act-latest` |
| Secrets not available | Use `-s SECRET_NAME=value` or `--secret-file .secrets` |
| Flutter SDK not found | The CI uses `subosito/flutter-action` which handles this |

### 7. Create Commit

```bash
git add .
git commit -m "chore(mz_core): release v1.3.3"
```

Use the package name as the scope:

```bash
git commit -m "chore(mz_core): release v1.3.3"
git commit -m "chore(mz_collection): release v0.1.0"
git commit -m "chore(mz_lints): release v0.2.0"
```

For multiple packages in one release:

```bash
git commit -m "chore: release mz_core v1.3.3, mz_lints v0.2.0"
```

### 8. Create Git Tags

Tags trigger the automated release workflow:

```bash
# mz_core
git tag -a mz_core-v1.3.3 -m "mz_core v1.3.3"

# mz_collection
git tag -a mz_collection-v0.1.0 -m "mz_collection v0.1.0"

# mz_lints
git tag -a mz_lints-v0.2.0 -m "mz_lints v0.2.0"
```

### 9. Push Changes

```bash
# Push commits
git push origin main

# Push tags (triggers release workflow)
git push origin --tags
```

### 10. Publish to pub.dev

The release workflow publishes automatically when tags are pushed. For manual publishing:

```bash
# Dry run first
cd packages/<package>
dart pub publish --dry-run

# Publish
dart pub publish
```

## Version Numbering

Follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html):

- **MAJOR** (x.0.0): Breaking API changes
- **MINOR** (0.x.0): New features, backward compatible
- **PATCH** (0.0.x): Bug fixes, backward compatible

### Pre-release Versions

For pre-release versions, use:

```
1.0.0-alpha.1
1.0.0-beta.1
1.0.0-rc.1
```

## Quick Search Commands

Find all version references:

```bash
# mz_core version references
grep -rn "mz_core:" packages/mz_core --include="*.yaml" --include="*.md"

# mz_collection version references
grep -rn "mz_collection:" packages/mz_collection --include="*.yaml" --include="*.md"

# mz_lints version references
grep -rn "mz_lints:" packages/mz_lints --include="*.yaml" --include="*.md" --include="*.dart"
```

## Release Workflow

The automated release workflow (`.github/workflows/release.yml`) handles:

1. Building release artifacts
2. Creating GitHub releases
3. Publishing to pub.dev (when configured)

It is triggered by tags matching:
- `mz_core-v*`
- `mz_collection-v*`
- `mz_lints-v*`

## Rollback Procedure

If a release needs to be rolled back:

1. **Retract from pub.dev** (if published):
   ```bash
   cd packages/<package>
   dart pub retract <version>
   ```

2. **Delete the tag**:
   ```bash
   git tag -d <package>-v<version>
   git push origin :refs/tags/<package>-v<version>
   ```

3. **Revert the commit** (if needed):
   ```bash
   git revert <commit-hash>
   git push origin main
   ```

## Checklist Summary

Before releasing, ensure:

- [ ] Version updated in pubspec.yaml
- [ ] Version updated in CHANGELOG.md
- [ ] Version updated in README.md
- [ ] Version updated in documentation files
- [ ] All tests pass
- [ ] No analysis errors
- [ ] CI passes locally (act)
- [ ] Changes committed with proper message
- [ ] Tag created with correct format
- [ ] Changes and tags pushed
