#!/usr/bin/env bash
set -euo pipefail

if [ "$(uname -s)" != "Darwin" ]; then
  echo "SwiftTOMLEdit XCFramework generation requires macOS." >&2
  exit 1
fi

if command -v brew >/dev/null 2>&1; then
  rustup_prefix="$(brew --prefix rustup 2>/dev/null || true)"
  if [ -n "$rustup_prefix" ] && [ -x "$rustup_prefix/bin/cargo" ]; then
    export PATH="$rustup_prefix/bin:$PATH"
  fi
fi

for command_name in cargo lipo xcodebuild; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "$script_dir/.." && pwd -P)"
cd "$repo_root"

manifest="Rust/SwiftTOMLEdit/Cargo.toml"
header_dir="Sources/CSwiftTOMLEdit/include"
output="${SWIFT_TOML_EDIT_XCFRAMEWORK_OUTPUT:-Artifacts/CSwiftTOMLEdit.xcframework}"
build_root=".build/native-toml"
target_dir="$build_root/rust-target"
universal_dir="$build_root/universal"
universal_library="$universal_dir/libswift_toml_edit.a"

export CARGO_TARGET_DIR="$repo_root/$target_dir"
export MACOSX_DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-14.0}"

if command -v rustup >/dev/null 2>&1; then
  rustup target add aarch64-apple-darwin x86_64-apple-darwin
fi

cargo_arguments=(build --manifest-path "$manifest" --release)
if [ -f "Rust/SwiftTOMLEdit/Cargo.lock" ]; then
  cargo_arguments+=(--locked)
fi

cargo "${cargo_arguments[@]}" --target aarch64-apple-darwin
cargo "${cargo_arguments[@]}" --target x86_64-apple-darwin

mkdir -p "$universal_dir" "$(dirname "$output")"
lipo -create \
  "$target_dir/aarch64-apple-darwin/release/libswift_toml_edit.a" \
  "$target_dir/x86_64-apple-darwin/release/libswift_toml_edit.a" \
  -output "$universal_library"

rm -rf "$output"
xcodebuild -create-xcframework \
  -library "$universal_library" \
  -headers "$header_dir" \
  -output "$output"

printf 'Created %s\n' "$output"
lipo -info "$universal_library"
