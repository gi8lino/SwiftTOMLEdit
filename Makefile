PACKAGE_NAME := SwiftTOMLEdit
ARTIFACT_NAME := CSwiftTOMLEdit.xcframework
ARTIFACT := Artifacts/$(ARTIFACT_NAME)
DIST_DIR := dist
ARTIFACT_ZIP := $(DIST_DIR)/$(ARTIFACT_NAME).zip
RUST_MANIFEST := Rust/SwiftTOMLEdit/Cargo.toml

VERSION_PREFIX ?= v
LATEST_TAG := $(shell git tag --list '$(VERSION_PREFIX)*' --sort=-v:refname | head -n 1)
CURRENT_VERSION := $(if $(LATEST_TAG),$(patsubst $(VERSION_PREFIX)%,%,$(LATEST_TAG)),0.0.0)
CURRENT_CORE_VERSION := $(firstword $(subst -, ,$(CURRENT_VERSION)))

NEXT_PATCH := $(shell python3 -c 'm,n,p=map(int,"$(CURRENT_CORE_VERSION)".split(".")); print(f"{m}.{n}.{p+1}")')
NEXT_MINOR := $(shell python3 -c 'm,n,p=map(int,"$(CURRENT_CORE_VERSION)".split(".")); print(f"{m}.{n+1}.0")')
NEXT_MAJOR := $(shell python3 -c 'm,n,p=map(int,"$(CURRENT_CORE_VERSION)".split(".")); print(f"{m+1}.0.0")')

.DEFAULT_GOAL := help

LOCALBIN ?= bin

$(LOCALBIN):
	@mkdir -p "$@"

## Tool Versions
# renovate: datasource=github-releases depName=gi8lino/dev-tools
DEV_TOOLS_VERSION ?= v0.5.0

## Tool Binaries
DEV_TOOL_NAMES := dev-port open-browser dev-tag make-help go-install-tool
DEV_TOOL_TARGETS := $(addprefix $(LOCALBIN)/,$(DEV_TOOL_NAMES))
DEV_TOOL_VERSIONED := $(addsuffix -$(DEV_TOOLS_VERSION),$(DEV_TOOL_TARGETS))

DEV_PORT := $(LOCALBIN)/dev-port
OPEN_BROWSER := $(LOCALBIN)/open-browser
DEV_TAG := $(LOCALBIN)/dev-tag
MAKE_HELP := $(LOCALBIN)/make-help
GO_INSTALL_TOOL := $(LOCALBIN)/go-install-tool

# Run a local tool while displaying only its executable name.
define run-tool
@printf '%s\n' '$(notdir $(1)) $(2)'
@$(1) $(2)
endef


.PHONY: help \
	prepare artifact require-artifact test rust-test lint verify package checksum clean clean-all \
	release release-patch release-minor release-major version

help: $(MAKE_HELP) ## Display this help.
	@$(MAKE_HELP) $(MAKEFILE_LIST)

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

release-patch: VERSION := $(NEXT_PATCH)
release-patch: release ## Start the next patch release.

release-minor: VERSION := $(NEXT_MINOR)
release-minor: release ## Start the next minor release.

release-major: VERSION := $(NEXT_MAJOR)
release-major: release ## Start the next major release.

version: ## Show the latest released version.
	@echo "Latest version: $(LATEST_TAG)"

##@ Development tools

.PHONY: dev-tools
dev-tools: $(DEV_TOOL_TARGETS) ## Download the pinned development tools.

$(DEV_TOOL_TARGETS): $(LOCALBIN)/%: $(LOCALBIN)/%-$(DEV_TOOLS_VERSION)
	@ln -sf "$(notdir $<)" "$@"

$(DEV_TOOL_VERSIONED): $(LOCALBIN)/%-$(DEV_TOOLS_VERSION): | $(LOCALBIN)
	$(call download-dev-tool,$*,$@)

# download-dev-tool downloads a versioned tool from gi8lino/dev-tools.
# $1 - release asset name
# $2 - versioned destination path
define download-dev-tool
	@set -eu; \
	tmp="$(2).tmp"; \
	trap 'rm -f "$$tmp"' EXIT INT TERM; \
	echo "Downloading gi8lino/dev-tools $(DEV_TOOLS_VERSION) $(1)"; \
	curl --fail --silent --show-error --location \
		"https://github.com/gi8lino/dev-tools/releases/download/$(DEV_TOOLS_VERSION)/$(1)" \
		-o "$$tmp"; \
	chmod +x "$$tmp"; \
	mv "$$tmp" "$(2)"; \
	trap - EXIT INT TERM
endef
