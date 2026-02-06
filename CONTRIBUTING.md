# Contributing to MZ Packages

Thank you for your interest in contributing to the MZ packages!

## Getting Started

1. **Fork and clone the repository:**

   ```bash
   git clone https://github.com/YOUR_USERNAME/mz.git
   cd mz
   ```

2. **Install Melos:**

   ```bash
   dart pub global activate melos
   ```

3. **Bootstrap the workspace:**

   ```bash
   melos bootstrap
   ```

## Development Workflow

### Making Changes

1. Create a new branch:

   ```bash
   git checkout -b feature/my-feature
   ```

2. Make your changes in the relevant package under `packages/`

3. Run tests:

   ```bash
   melos run test
   ```

4. Check formatting and analysis:

   ```bash
   melos run format
   melos run analyze
   ```

5. Commit using [Conventional Commits](https://www.conventionalcommits.org/):

   ```bash
   git commit -m "feat(mz_core): add new feature"
   git commit -m "fix(mz_lints): fix rule detection"
   ```

### Commit Message Format

We follow the Conventional Commits specification:

```text
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**

- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code changes that neither fix bugs nor add features
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Scopes:**

- `mz_core`: Changes to mz_core package
- `mz_collection`: Changes to mz_collection package
- `mz_lints`: Changes to mz_lints package
- `repo`: Changes to repository configuration

### Pull Request Process

1. Ensure all tests pass
2. Update documentation if needed
3. Add a changelog entry if it's a user-facing change
4. Submit a PR to the `main` branch
5. Wait for review and address feedback

## Package-Specific Guidelines

### mz_core

- Maintain 100% test coverage
- Add documentation comments for all public APIs
- Include examples in documentation

### mz_collection

- Maintain 100% test coverage
- Add documentation comments for all public APIs
- Include examples in documentation
- Pure Dart package - no Flutter dependencies in main library

### mz_lints

- Add tests for all new lint rules
- Include both positive and negative test cases
- Document the rule's purpose and fix suggestions

## Code Style

- Follow the [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Use `very_good_analysis` lint rules
- Run `melos run format:fix` to fix formatting issues

## Questions?

Feel free to open an issue for questions or discussions.
