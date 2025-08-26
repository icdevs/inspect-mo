Inspect-Mo Release Plan (v0.1.0)

Purpose: Ship a clean, documented, and tested library release that’s easy to adopt.

Scope
- Library code: src/** (core, security, integrations, utils, migrations)
- Docs: README.md, docs/**
- Tests: test/** (Motoko), pic/** (PocketIC/Jest)
- Tooling: tools/codegen/** (TypeScript CLI)

Versioning & Targets
- Version: v0.1.0 (public preview)
- Toolchain support to verify: Motoko (moc) ≥ 0.14.x, dfx ≥ 0.14.x

Owners
- Tech lead: TBA
- Docs lead: TBA
- Release manager: TBA

Milestones
1) Readiness fixes (docs, config, repo hygiene)
2) Test pass (mops + PocketIC/Jest)
3) Packaging & tagging (mops package; no npm publish for codegen in v0.1.0)
4) Announcement & handoff

Pre-release Checklist (high level)
- Repo hygiene
  - [ ] Update .gitignore (exclude .dfx, target, out, node_modules, dist, coverage, etc.)
  - [ ] Remove or relocate dev-only files (see release_readiness.md)
- Documentation
  - [ ] Clean and consolidate docs/API.md (remove duplicate/legacy blocks)
  - [ ] Verify examples compile against current API (update examples/**)
  - [ ] Root README Quick Start uses only working commands
  - [ ] Add CHANGELOG.md and CONTRIBUTING.md
- Config & packaging
  - [x] mops.toml has real metadata (name, version=0.1.0, repo, license); no placeholders
  - [ ] package.json reflects project (name/description/license) and scripts work
  - [x] dfx.json contains only supported fields; manual codegen (no prebuild hooks)
  - [x] Dockerfiles removed (not used for this library release)
- Codegen CLI
  - [x] Decision: local usage only (ts-node) for v0.1.0; no npm publish now
  - [x] README updated with local codegen instructions (run `npm run codegen` before `dfx build`)
- Testing & quality
  - [ ] mops test green
  - [ ] npm test (PocketIC) green
  - [ ] Benchmarks compile (optional to execute)
  - [ ] Minimal CI (GitHub Actions) for build + tests
- Licensing & notices
  - [ ] LICENSE owner/year correct and consistent with package metadata
  - [ ] Third-party notices (if needed)

Release Gates
- Gate 1: Docs pass (README + API + Examples coherent; local codegen section present)
- Gate 2: Tests pass (mops + PocketIC core suites)
- Gate 3: Packaging sanity (mops publish dry-run)

Tagging & Distribution
- Git tag: vX.Y.Z
- Publish to mops (if applicable)
- Publish CLI to npm (optional)

Communications
- Draft announcement (what, why, how)
- Update docs badges/links

Post-release
- Open tracking issue for next minor
- Collect user feedback and bugs
