# SwiftTOMLEdit

SwiftTOMLEdit is a Swift package for typed TOML parsing and lossless TOML editing on macOS.
It uses Rust's [`toml_edit`](https://crates.io/crates/toml_edit) internally and exposes a
small Swift API. Comments, whitespace, inline comments, and unrelated ordering are retained
when existing values are changed.

## Requirements

- macOS 14 or newer
- Xcode 16 or newer

Rust with `rustup` is only required when changing or testing the native Rust bridge.

Release builds use a universal macOS XCFramework published as a GitHub release asset.
SwiftPM downloads that artifact automatically; package users and release maintainers do
not need to build or commit it locally.

## Add the package

In Xcode, add `https://github.com/gi8lino/SwiftTOMLEdit` as a package dependency, or add
it to `Package.swift`:

```swift
.package(
  url: "https://github.com/gi8lino/SwiftTOMLEdit.git",
  from: "0.1.0"
)
```

Add the library product to a target:

```swift
.product(name: "SwiftTOMLEdit", package: "SwiftTOMLEdit")
```

Then import it:

```swift
import SwiftTOMLEdit
```

## Parse TOML

```swift
let table = try TOMLTable(
  string: """
    title = "Example"
    enabled = true

    [window]
    width = 800
    """
)

let title = table["title"]?.string
let enabled = table["enabled"]?.bool
let width = table["window"]?.table?["width"]?.int
```

`TOMLDocument.parse(_:)` provides the same root-table result:

```swift
let table = try TOMLDocument.parse(source)
```

## Edit TOML losslessly

```swift
let source = """
  # User configuration
  [calendar]
  mode   = "month" # Keep this comment
  """

let edited = try TOMLDocument.edit(
  source,
  edits: [
    TOMLEdit(
      path: ["calendar", "mode"],
      value: .string("upcoming")
    )
  ]
)
```

The output changes only the value:

```toml
# User configuration
[calendar]
mode   = "upcoming" # Keep this comment
```

Supported edit values are:

- strings
- integers
- doubles
- booleans
- string arrays

Missing tables in an edit path are created automatically.

## Configuration reader

`TOMLConfigReader` provides default-backed, type-checked access for application settings:

```swift
enum ConfigError: Error {
  case invalidType(path: String, expected: String, actual: String)
  case invalidValue(path: String, message: String)
}

let reader = TOMLConfigReader<ConfigError>(
  table: table,
  path: "",
  makeInvalidTypeError: { .invalidType(path: $0, expected: $1, actual: $2) },
  makeInvalidValueError: { .invalidValue(path: $0, message: $1) }
)

let calendar = try reader.section("calendar")
let enabled = try calendar.bool("enabled", fallback: true)
```

## Development

Rust bridge changes can be built and tested locally:

```bash
make artifact
```

Run all checks:

```bash
make verify
```

Create the release ZIP:

```bash
make package
```

Print its SwiftPM checksum:

```bash
make checksum
```

The generated `Artifacts/CSwiftTOMLEdit.xcframework` directory and release ZIP are ignored
by Git. When the local XCFramework exists, `Package.swift` uses it automatically; otherwise
it uses the XCFramework from the latest release.

## Releases

Releases are created entirely by GitHub Actions:

1. Open **Actions → Release → Run workflow**.
2. Select the `main` branch.
3. Enter a semantic version such as `0.1.0` and run the workflow.

The workflow builds and tests the Rust and Swift code, packages the XCFramework, computes
its checksum, updates `Package.swift`, creates the release commit and tag, and publishes
the ZIP with SHA-256 and SwiftPM checksum files. No local artifact preparation is needed.

## License

Apache License 2.0. See [LICENSE](LICENSE).
