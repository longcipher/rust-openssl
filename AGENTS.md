# rust-openssl Agent Instructions

## Non-negotiables

- Surgical edits only: every changed line must trace to the request. No drive-by refactors, no reformatting untouched code, no deleting pre-existing dead code (mention it instead).
- Fix root causes. Never silence a warning, weaken a check, or patch a symptom to make a gate pass.
- Never report completion while any `just` gate below fails. Report the failure verbatim and stop.
- Stop and ask when a request is ambiguous, conflicts with existing conventions, or requires credentials, publishing, or destructive operations.
- When a correction reveals a missing rule, add one specific rule here ("always X for Y", never "be careful with Y"); delete rules that never catch real errors.

## Scope

- This is a fork of upstream `rust-openssl` (`github.com/rust-openssl/rust-openssl`) that renames the two published crates: package `openssl` is now `real-openssl` (directory `openssl/`, library `openssl`) and package `openssl-sys` is now `real-openssl-sys` (directory `openssl-sys/`, library `openssl_sys`).
- `openssl-errors` (custom OpenSSL error stack; the `ossl300` cfg gates the OpenSSL 3.0 error-data accessor), `openssl-macros` (the `#[corresponds]` doc-link attribute) and `systest` (a `ctest` harness that compiles and runs C against the linked OpenSSL) keep their upstream names.
- `openssl-sys` declares `links = "real_openssl"`, so its build-script metadata is exported as `DEP_REAL_OPENSSL_*` instead of upstream's `DEP_OPENSSL_*`. `openssl/build.rs`, `openssl-errors/build.rs` and `systest/build.rs` all read the `DEP_REAL_OPENSSL_*` names; never "fix" them back to `DEP_OPENSSL_*`.
- This fork has no crates.io publish flow; do not add `cargo publish` recipes or version-bump chores for upstream releases.
- `THIRD_PARTY` carries the OpenSSL license for the code borrowed from the OpenSSL project; keep it in sync when vendoring OpenSSL sources.
- English only in code, comments, docs, and commit messages.

## Execution

- Parallelize aggressively: dispatch subagents for independent research, exploration, and implementation.
- NEVER run two `cargo` commands concurrently, and never overlap file edits with a running `cargo` command (`target/` file lock): finish edits, wait, then run.
- NEVER use `git worktree`. Edit the current branch in place.
- TDD for behavior changes: failing test first, smallest change to pass, then run `just test` again and fix the failures it exposes.

## Verification loop

After each feature or bug fix, in order; any failure means the task is not done:

```bash
just format
just lint
just test
```

`just lint` mirrors the CI lint job: `cargo fmt --all -- --check` plus `cargo clippy --all --all-targets -- -D warnings` (CI sets `RUSTFLAGS: -Dwarnings`). `just systest` is the Unix-only CI step that needs a working OpenSSL to link against.

## Rust workspace rules

- Workspace members are the five crate directories; there is no `[workspace.lints]` table here, edition is 2021 (except `systest`, which is 2018) and the resolver is 2.
- The published crate names are `real-openssl` and `real-openssl-sys`. `cargo -p openssl` and `cargo -p openssl-sys` do not resolve — use `-p real-openssl` / `-p real-openssl-sys`. `.github/workflows/ci.yml` still selects `cargo test -p openssl`, which the rename broke; report that gap instead of working around it in the Justfile.
- Minimum supported Rust is 1.70.0 for `openssl`, `openssl-errors`, `openssl-macros` and `openssl-sys`; `systest` needs 1.88.0 because `ctest 0.5` uses edition 2024. The CI min-version job drops `systest` from the workspace before running `cargo +1.70.0 check -p real-openssl`.
- The `vendored`, `unstable_boringssl`, `aws-lc` and `aws-lc-fips` features each select a different TLS backend. They are not combinable: never build this workspace with `--all-features`.
- `openssl-sys/build/cfgs.rs` is the single source of truth for the `ossl300`..`ossl350`, `libressl*`, `boringssl`, `awslc` and `awslc_fips` cfgs; `systest/build.rs` reuses that file through `#[path = "../openssl-sys/build/cfgs.rs"]`. Add a new cfg in one place only.
- Version-gate every new OpenSSL API call on the right `ossl*`/`libressl*` cfg, otherwise the Linux CI matrix (OpenSSL 1.1.0 through 3.6, LibreSSL 3.5.3 through 4.2.1, BoringSSL, aws-lc) breaks.
- `.rustfmt.toml` states that this project uses the default rustfmt settings; do not add unstable options. `clippy.toml` forbids `std::slice::from_raw_parts` and `std::slice::from_raw_parts_mut` — use `util::from_raw_parts` and `util::from_raw_parts_mut` from `openssl/src/util.rs`, which tolerate a null pointer.
- `openssl-sys` finds the library through `pkg-config` (or `vcpkg` on Windows, `OPENSSL_DIR` on Unix, or the vendored `openssl-src`); the `bindgen` feature additionally needs libclang.

## Dependency choices

- `openssl` depends on `bitflags`, `cfg-if`, `foreign-types`, `libc` and `once_cell`; `openssl-errors` depends on `cfg-if` and `libc`; `openssl-macros` on `proc-macro2`, `quote` and `syn`.
- `openssl-sys` build dependencies are `bindgen`, `cc`, `openssl-src`, `pkg-config` and `vcpkg`. Keep that set; do not add a second TLS backend crate.
- Error handling uses `std::io::Error` and `openssl::error::ErrorStack`; there is no `thiserror`/`anyhow` in this workspace.

## Code conventions

- `openssl` is the safe wrapper and `openssl-sys` is the raw FFI layer: new FFI surface goes into `openssl-sys/src/`, the safe wrapper into `openssl/src/`, and the two must land in the same change.
- Owned OpenSSL types go through the `foreign_types::foreign_type!` macro (wrapped by `foreign_type_and_impl_send_sync` in `openssl/src/macros.rs`); use it instead of hand-writing `Drop`/`Clone` boilerplate.
- Use `#[corresponds]` from `openssl-macros` on public wrappers so the doc link and `doc(alias)` point at the matching `man3` page.
- Test fixtures live in `openssl/test/` (PEM/DER material); add new fixtures there rather than generating them inline, and keep the `openssl/src/x509/tests.rs` style of colocated unit tests.
- The `openssl` crate ships an `examples/mk_certs.rs` generator; extend it instead of adding one-off certificate generation to tests.
