# Default recipe to display help
default:
  @just --list

# Format the Rust sources with rustfmt
format:
  cargo fmt --all

# Check formatting without rewriting files
fmt-check:
  cargo fmt --all -- --check

# `.github/workflows/ci.yml` runs these two as separate jobs and exports
# `RUSTFLAGS: -Dwarnings`; `-D warnings` below is the same policy.
#
# Run the CI lint gate: rustfmt check plus clippy over every target
lint:
  cargo fmt --all -- --check
  cargo clippy --all --all-targets -- -D warnings

# Build every crate in the workspace
build:
  cargo build --all

# Type-check every crate and every target
check:
  cargo check --all --all-targets

# Run the test suites of the openssl and openssl-errors crates
test:
  cargo test -p real-openssl
  cargo test -p openssl-errors

# Run the openssl crate tests with bindgen-generated bindings
test-bindgen:
  cargo test -p real-openssl --features bindgen

# Run the openssl crate tests against the vendored OpenSSL sources
test-vendored:
  cargo test -p real-openssl --features vendored

# Run the ctest harness against the linked OpenSSL library
systest:
  cargo run -p systest

# Run the ctest harness against the vendored OpenSSL sources
systest-vendored:
  cargo run -p systest --features vendored

# Run the ctest harness with bindgen-generated bindings
systest-bindgen:
  cargo run -p systest --features bindgen

# The CI min-version job also drops the `systest` member from the workspace
# first, because `ctest 0.5` needs edition 2024, which cargo 1.70 cannot
# parse. Reproduce that `sed` step locally if the check trips over ctest.
#
# Check the openssl crate against the minimum supported Rust version
min-version:
  cargo +1.70.0 check -p real-openssl

# Run the full local gate (systest needs a working OpenSSL to link against)
ci: lint test build systest

# ============================================================
# Maintenance & Tools
# ============================================================

# Clean build artifacts
clean:
  cargo clean

# Install the toolchains and components the recipes need
setup:
  rustup component add rustfmt clippy
  rustup toolchain install 1.70.0 --profile minimal

# Generate documentation for the workspace
docs:
  cargo doc --no-deps --open

# Run security audit
audit:
  cargo audit

# Check for outdated dependencies
outdated:
  cargo outdated

# `--all-features` is never used here: `vendored`, `unstable_boringssl`,
# `aws-lc` and `aws-lc-fips` each select a different TLS backend.
#
# Run clippy with the pedantic and nursery lint groups
clippy-all:
  cargo clippy --all --all-targets -- -W clippy::pedantic -W clippy::nursery

# Update all dependencies
update-deps:
  cargo update

# Fail if Chinese characters are present in tracked files
check-cn:
  #!/usr/bin/env bash
  set -euo pipefail
  if rg --line-number --column "\p{Han}" . ; then
    echo "error: Chinese characters found" >&2
    exit 1
  fi
  echo "ok: no Chinese characters found"

# Full check (lint + test + build + audit)
full-check: lint test build audit
