ARTIFACT_NAME := CSwiftTOMLEdit.xcframework
ARTIFACT := Artifacts/$(ARTIFACT_NAME)
DIST_DIR := dist
ARTIFACT_ZIP := $(DIST_DIR)/$(ARTIFACT_NAME).zip
RUST_MANIFEST := Rust/SwiftTOMLEdit/Cargo.toml

.DEFAULT_GOAL := help

# renovate: datasource=github-releases depName=gi8lino/dev-tools
DEV_TOOLS_VERSION ?= v0.7.0

include bin/dev-tools.mk
include $(call dev-tools-module,help)

VERSION_PREFIX ?= v
DEV_TAG := $(DEV_TOOLS_BIN)/dev-tag

$(DEV_TAG): | $(DEV_TOOLS_BIN)
	$(call download-dev-tool,dev-tag,$@)

.PHONY: \
	prepare artifact require-artifact test rust-test lint verify package checksum clean clean-all \
	release release-patch release-minor release-major version

prepare: artifact test rust-test lint ## Build everything required before the first commit.

artifact: ## Build the universal macOS XCFramework.
	@scripts/build-xcframework.sh

require-artifact:
	@test -d "$(ARTIFACT)" || { echo "Missing $(ARTIFACT); run 'make artifact' first." >&2; exit 1; }

test: require-artifact ## Build and run Swift tests.
	@SWIFT_TOML_EDIT_USE_LOCAL_ARTIFACT=1 swift test

rust-test: ## Run Rust bridge tests.
	@if [ -f Rust/SwiftTOMLEdit/Cargo.lock ]; then \
		cargo test --manifest-path "$(RUST_MANIFEST)" --locked; \
	else \
		cargo test --manifest-path "$(RUST_MANIFEST)"; \
	fi

lint: ## Check Swift and Rust formatting.
	@swift format lint --recursive --parallel --strict Package.swift Sources Tests
	@cargo fmt --manifest-path "$(RUST_MANIFEST)" -- --check

verify: artifact test rust-test lint ## Regenerate the artifact and run all tests.

package: require-artifact ## Create a ZIP of the generated XCFramework.
	@rm -rf "$(DIST_DIR)"
	@mkdir -p "$(DIST_DIR)"
	@ditto -c -k --sequesterRsrc --keepParent "$(ARTIFACT)" "$(ARTIFACT_ZIP)"
	@echo "Created $(ARTIFACT_ZIP)"

checksum: package ## Print the SwiftPM checksum of the XCFramework ZIP.
	@swift package compute-checksum "$(ARTIFACT_ZIP)"

clean: ## Remove transient build and distribution output.
	@rm -rf .build "$(DIST_DIR)" Rust/SwiftTOMLEdit/target

clean-all: clean ## Also remove the generated XCFramework.
	@rm -rf "$(ARTIFACT)"

##@ Releasing

release: ## Start a pipeline-owned release (usage: make release VERSION=0.1.0).
	@test -n "$(VERSION)" || { echo "VERSION is required, for example: make release VERSION=0.1.0" >&2; exit 1; }
	@gh workflow run release.yml --ref main --field version="$(VERSION)"
	@echo "Started release $(VERSION)"

release-patch: ## Start the next patch release.
release-minor: ## Start the next minor release.
release-major: ## Start the next major release.

release-patch release-minor release-major: $(DEV_TAG)
	@set -eu; current="$$($(DEV_TAG) --prefix "$(VERSION_PREFIX)" current)"; \
	version=$$(printf '%s\n' "$${current#$(VERSION_PREFIX)}" | \
		awk -F. -v bump="$(@:release-%=%)" '{ \
			if (bump == "major") print $$1+1 ".0.0"; \
			else if (bump == "minor") print $$1 "." $$2+1 ".0"; \
			else print $$1 "." $$2 "." $$3+1; \
		}'); \
	$(MAKE) release VERSION="$$version"

version: $(DEV_TAG) ## Show the latest released version.
	$(call run-tool,$(DEV_TAG),--prefix "$(VERSION_PREFIX)" current)

##@ Development tools

.PHONY: dev-tools
dev-tools: $(DEV_TAG) $(MAKE_HELP) ## Download the pinned development tools.
