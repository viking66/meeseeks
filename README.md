# Meeseeks

Project templates that do one job and do it well.

## Haskell

Create a new Haskell project with a single command:

```bash
nix run github:viking66/meeseeks#haskell -- myproject
```

This creates a `myproject/` directory with everything wired up and ready to go:

```bash
cd myproject
nix develop
just build
just run    # prints "Hello from myproject!"
just test   # runs hspec test suite
just fix    # formats with fourmolu + lints with hlint
```

### What's included

- **GHC 9.12** with **GHC2024** language standard
- **Nix flake** for reproducible builds and dev environment
- **HLS** (Haskell Language Server) for editor integration
- **fourmolu** for formatting
- **hlint** for linting
- **hspec** with hspec-discover for testing
- **ghciwatch** for fast feedback loops
- **justfile** with build, test, fix, and run targets
- **Hoogle** with local documentation

### Default extensions

- `DuplicateRecordFields`
- `NoFieldSelectors`
- `OverloadedRecordDot`

### Default warnings

Strict by default — `-Wall`, `-Werror`, `-Wincomplete-uni-patterns`, `-Wincomplete-record-updates`, `-Wmissing-export-lists`, and more.

### Project structure

```
myproject/
├── flake.nix          # Nix flake with dev shell
├── myproject.cabal    # Package definition
├── fourmolu.yaml      # Formatter config
├── justfile           # Build commands
├── src/
│   └── MyProject.hs   # Library module
├── app/
│   └── Main.hs        # Executable
└── test/
    ├── Spec.hs         # Test discovery entry point
    └── MyProject/
        └── MyProjectSpec.hs  # Tests
```

### Naming

The project name must start with a lowercase letter and contain only lowercase letters, digits, and hyphens. Hyphens are converted to camel case for module names:

| Project name | Module name |
|-------------|-------------|
| `myapp`     | `Myapp`     |
| `my-app`    | `MyApp`     |
| `cool-tool` | `CoolTool`  |

## Requirements

- [Nix](https://nixos.org/download/) with flakes enabled
