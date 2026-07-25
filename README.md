# SwiftTOMLEdit

SwiftTOMLEdit is a Swift package for typed TOML parsing and lossless TOML editing on macOS.
It uses Rust's [`toml_edit`](https://crates.io/crates/toml_edit) internally and exposes a
small Swift API. Comments, whitespace, inline comments, and unrelated ordering are retained
when existing values are changed.

## Requirements

- macOS 14 or newer
- Xcode 16 or newer
- Rust with `rustup`

The package contains a generated universal macOS XCFramework. The XCFramework must be
committed because SwiftPM resolves binary targets before it can run project build scripts.
CI regenerates the artifact and fails when the committed copy is stale.

## Initial repository setup

Extract the project, then run:

```bash
make prepare
```

This builds the native library, generates `Cargo.lock`, runs the Swift and Rust tests,
and creates:

```text
Artifacts/CSwiftTOMLEdit.xcframework
```

Commit both `Cargo.lock` and the generated XCFramework with the source before pushing or
tagging the repository:

```bash
git init
git add .
git commit -m "feat: initialize SwiftTOMLEdit"
git branch -M main
git remote add origin git@github.com:gi8lino/SwiftTOMLEdit.git
git push -u origin main
```

## Add the package

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

Build the native artifact:

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

## Releases

Before creating a tag, regenerate the artifact and commit any change:

```bash
make verify
git diff --exit-code -- Artifacts/CSwiftTOMLEdit.xcframework
git tag -a v0.1.0 -m "Release v0.1.0"
git push --follow-tags
```

The release workflow rebuilds and verifies the XCFramework, runs Swift and Rust tests,
and publishes the zipped XCFramework with SHA-256 and SwiftPM checksum files.

## License

Apache License 2.0. See [LICENSE](LICENSE).
