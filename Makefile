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

.PHONY: help \
	prepare artifact require-artifact test rust-test lint verify package checksum clean clean-all \
	tag-patch tag-minor tag-major push-tags tag


help: ## Display available targets.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

prepare: artifact test rust-test lint ## Build everything required before the first commit.

artifact: ## Build the universal macOS XCFramework.
	@scripts/build-xcframework.sh

require-artifact:
	@test -d "$(ARTIFACT)" || { echo "Missing $(ARTIFACT); run 'make artifact' first." >&2; exit 1; }

test: require-artifact ## Build and run Swift tests.
	@swift test

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

##@ Tagging

tag-patch: ## Create the next patch tag locally.
	@git tag -a "$(VERSION_PREFIX)$(NEXT_PATCH)" -m "Release $(VERSION_PREFIX)$(NEXT_PATCH)"
	@echo "Created tag $(VERSION_PREFIX)$(NEXT_PATCH)"

tag-minor: ## Create the next minor tag locally.
	@git tag -a "$(VERSION_PREFIX)$(NEXT_MINOR)" -m "Release $(VERSION_PREFIX)$(NEXT_MINOR)"
	@echo "Created tag $(VERSION_PREFIX)$(NEXT_MINOR)"

tag-major: ## Create the next major tag locally.
	@git tag -a "$(VERSION_PREFIX)$(NEXT_MAJOR)" -m "Release $(VERSION_PREFIX)$(NEXT_MAJOR)"
	@echo "Created tag $(VERSION_PREFIX)$(NEXT_MAJOR)"

push-tags: ## Push commits and tags to origin.
	@git push --follow-tags

tag: ## Show latest tag.
	@echo "Latest version: $(LATEST_TAG)"
