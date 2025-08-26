Release Readiness Checklist

This is a living document to track issues before tagging a release.

Status Legend: [ ] open, [~] in-progress, [x] done

1) Incorrect or Misleading Information
- README.md
  - [x] Quick Start: "mops install" + "dfx build" + "mops test" + "npm test" verified against current repo
  - [x] Examples paths match actual files (examples/user-management*.mo)
- docs/API.md
  - [x] Remove duplicate/legacy blocks and broken code fences
  - [x] Ensure ErasedValidator API matches src/core/inspector.mo exports
- docs/EXAMPLES.md
  - [x] Mark legacy examples clearly or update to current API
  - [x] Fix duplicated/garbled blocks (copy-paste artifacts)
  - [x] Remove fictional install-hooks/status and auto-running claims; document manual codegen only
- dfx.json
  - [x] Confirm only supported fields (root-level "scripts" is non-standard; keep npm scripts in package.json)
  - [x] Note: Motoko canisters do not support dfx prebuild hooks; use manual codegen
  - [x] Validate example canister path: examples/user-management.mo
- Dockerfile
  - [x] COPY did path typo: change "di[d]" to "did" or remove Dockerfiles if not needed for the library release (Docker removed for v0.1.0)
- LICENSE
  - [x] Owner/year: updated to "ICDevs, 2025"
- mops.toml
  - [x] Version/description/repository placeholders; set real package name and version; avoid path dep for "inspect-mo"

2) Missing Coverage / Gaps
- Docs
  - [x] Add CHANGELOG.md (semantic version entries)
  - [x] Add CONTRIBUTING.md (how to test/build, code style, PRs)
  - [x] Add SECURITY.md (reporting vulnerabilities)
  - [x] Add CODE_OF_CONDUCT.md (optional)
  - [x] Add docs for rate limiting status and RBAC limitations (rate limiting stubbed/non-functional; RBAC examples only)
- Tests
  - [x] Ensure pic/integration tests run green locally (npm test)
  - [ ] Add at least one guarded method end-to-end test using generated code
  - [ ] Smoke test examples compile (mops build or dfx build for example canisters)
- CI
  - [ ] Minimal GitHub Actions workflow: build + mops test + npm test

3) Files Likely Not Needed for Release (move to /dev or remove)
- Root
  - [ ] temp_test.mo (dev scratch)
  - [x] complex-generated.mo (generated sample) — removed
    - [x] plan.md (internal planning, superseded by RELEASE_PLAN.md) — not present
    - [x] EDUCATIONAL_SUMMARY.md (consider moving to docs/ or dev/) — not present
- Docker
  - [x] Dockerfile, Dockerfile.base, docker-compose.yml (keep only if supporting reproducible build flow; otherwise remove)
- .dfx/
  - [x] Entire .dfx folder should be in .gitignore and not committed (confirmed)
- tools/codegen/
  - [x] debug-*.js (dev helpers) — keep locally, ensure ignored (.gitignore set)
  - [x] generated-inspect*.mo (artifacts) — removed from repo and ignored
  - [x] node_modules/, dist/, package-lock.json — ensure ignored (.gitignore set)

4) Risks, TODOs, and Known Limitations
- Code TODOs
  - [ ] src/core/inspector.mo: "TODO: Implement rate limiting with environment" (either implement or document as deferred)
  - [x ] src/core/patterns.mo, src/utils/parser.mo contain TODOs; ensure not part of public API or mark experimental
- RBAC integration
  - [ ] Mark as example-only (docs already note this); consider moving to examples/ or integrations/examples/
- Version drift
  - [x] package.json name/description do not match project; align for release
  - [x] dfx.json root "scripts" field appears unused; verify and remove if not supported

5) Hygiene & Tooling
- .gitignore
  - [x] Add: .dfx/, target/, out/, node_modules/, dist/, coverage/, .DS_Store, src/generated/, pic/.jest-cache
- Prebuild hooks
  - [x] Ensure "npm run codegen" works fresh (no global deps)
- Formatting/Linting
  - [ ] mo-fmt or consistent Motoko formatting where applicable
  - [x] tsconfig/jest configs match installed versions (ts-jest deprecation resolved, esModuleInterop set)

6) Acceptance Criteria (Green Gates)
- [x] All tests pass locally (mops + npm)
 - [x] Docs coherent with working examples (EXAMPLES, ARCHITECTURE, API, README updated)
- [ ] Packaging dry-runs succeed (mops publish --dry-run; npm pack for codegen if publishing)
- [ ] Tag vX.Y.Z created and release notes drafted
