# SwiftTOMLEdit

SwiftTOMLEdit is a Swift package for typed TOML parsing and lossless TOML editing on macOS.
It uses Rust's [`toml_edit`](https://crates.io/crates/toml_edit) internally and exposes a
small Swift API. Comments, whitespace, inline comments, and unrelated ordering are retained
when existing values are changed.

## Requirements

- macOS 14 or newer
- Xcode 16 or newer

Rust with `rustup` is only required when changing or testing the native Rust bridge.
Package consumers do not need Rust: SwiftPM downloads the checksummed XCFramework from
the corresponding GitHub Release.

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

Generated XCFrameworks in `Artifacts` and release ZIPs in `dist` are ignored by Git.
`make verify` builds a local XCFramework and explicitly tests against it, so native changes
are verified before release without committing generated binaries.

## Releases

The release pipeline owns artifact creation, checksums, the release commit, and the tag.
Start it from **Actions → Release → Run workflow**, or use one of:

```bash
make release-patch
make release-minor
make release-major

# Or choose an exact version:
make release VERSION=0.1.0
```

The workflow builds and tests the Rust and Swift code, packages the XCFramework, calculates
its SwiftPM checksum, updates `Package.swift` with the release URL metadata, creates the
final commit and tag, and publishes the GitHub Release. Do not create the release tag
locally—the pipeline creates it only after the artifact and checksum are ready.

## License

Apache License 2.0. See [LICENSE](LICENSE).
