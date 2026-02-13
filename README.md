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

## Fullstack

Create a Haskell backend + PureScript frontend project:

```bash
nix run github:viking66/meeseeks#fullstack -- myproject
```

This creates a `myproject/` directory with a working full-stack hello world:

```bash
cd myproject
nix develop
just build
just run-backend          # Servant API on http://localhost:3000
just watch-frontend       # browser-sync + live reload on http://localhost:3001
just test                 # runs backend + frontend tests
just fix                  # formats with fourmolu + lints with hlint
```

### What's included

**Backend:**
- **GHC 9.12** with **GHC2024** language standard
- **Servant** with **NamedRoutes** for type-safe API definitions
- **HLS** (Haskell Language Server) for editor integration
- **fourmolu** for formatting, **hlint** for linting
- **hspec** with hspec-discover for testing
- **ghciwatch** for fast feedback loops
- Static file serving for production builds

**Frontend:**
- **PureScript** with **Halogen** for UI components
- **affjax** for HTTP requests
- **esbuild** for JS bundling
- **browser-sync** with API proxy for development
- **purescript-spec** for testing
- Three Layer Cake architecture (capabilities, pure functions, orchestration)

**Shared:**
- **Nix flake** for reproducible builds and dev environment
- **justfile** with build, test, fix, and run targets
- **Hoogle** with local documentation

### Project structure

```
myproject/
├── flake.nix                      # Nix flake with dev shell
├── justfile                       # Build commands
├── backend/
│   ├── myproject.cabal            # Package definition
│   ├── fourmolu.yaml              # Formatter config
│   ├── src/
│   │   └── MyProject.hs           # Library (API + server)
│   ├── app/
│   │   └── Main.hs                # Executable
│   └── test/
│       ├── Spec.hs                # Test discovery
│       └── MyProject/
│           └── MyProjectSpec.hs   # Tests
└── frontend/
    ├── spago.dhall                # PureScript dependencies
    ├── packages.dhall             # Package set (latest at init time)
    ├── package.json               # npm dependencies (browser-sync)
    ├── bs-config.js               # Browser-sync with API proxy
    ├── index.html                 # HTML entry point
    ├── src/
    │   ├── Main.purs              # App entry point
    │   └── App/
    │       ├── Root.purs          # Root component
    │       └── Capability/
    │           └── Api.purs       # API capability
    └── test/
        └── Main.purs              # Test runner
```

### Naming

Same naming rules as the Haskell template — project name becomes the backend package name and module name. Frontend modules use generic names (`App.Root`, `Main`).

## Requirements

- [Nix](https://nixos.org/download/) with flakes enabled
