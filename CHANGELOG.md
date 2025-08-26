# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2025-08-25
- Initial public preview release
- Local-only code generation workflow (ts-node; `npm run codegen`)
- dfx.json cleaned (no unsupported hooks)
- Docker assets removed from repo
- Docs: added Local code generation section to README
 - Tooling: modernized Jest/ts-jest config (removed deprecated globals); TypeScript esModuleInterop enabled
 - Docs sweep: removed inaccurate "DFX prebuild hooks" claims; documented manual codegen and CI example (`npm run codegen && dfx build`)
 - Tests: PocketIC/Jest integration suites passing locally (13 suites, 133 tests)
 - Limitations: Rate limiting is stubbed, not functional in 0.1.0; RBAC examples are illustrative only
