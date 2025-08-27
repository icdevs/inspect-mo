# InspectMo Codegen CLI

Generate InspectMo boilerplate from Candid (.did) files and integrate simple build hooks.

This is the CLI tool for InspectMo. It is separate from the Motoko library and can be installed globally or used via npx.

## Install

- Global (recommended):
  - `npm i -g @icdevs-org/inspectmo`
  - Then run: `inspectmo --help`

- One-off usage (no global install):
  - `npx @icdevs-org/inspectmo@latest --help`

Requirements: Node.js 18+.

## Usage

- Show help
  - `inspectmo --help`

- Generate code from a Candid file
  - `inspectmo generate path/to/service.did -o src/generated/service-inspect.mo`
  - Flags:
    - `--no-accessors`  Skip accessor functions
    - `--no-inspect`    Skip inspect template
    - `--no-guard`      Skip guard template
    - `--no-methods`    Skip method extraction
    - `--no-comments`   Skip documentation comments

- Analyze a Candid file (no code generation)
  - `inspectmo analyze path/to/service.did`

- Discover .did files in a project and optionally generate
  - `inspectmo discover . --output src/generated/ --generate`
  - Options:
    - `--include <patterns...>` defaults to `**/*.did` and `.dfx/**/*.did`
    - `--exclude <patterns...>` defaults to `node_modules/**` and `.git/**`
    - `--suggest` print integration suggestions

- Build system hooks (DFX only)
  - Install: `inspectmo install-hooks . --output src/generated/`
  - Status: `inspectmo status .`
  - Uninstall: `inspectmo uninstall-hooks .`
  - Note: mops.toml does not support prebuild hooks; only DFX integration is supported.

## Examples

- Minimal generate:
  - `inspectmo generate src/candid/main.did -o src/generated/main-inspect.mo`

- Analyze only:
  - `inspectmo analyze src/candid/user.did`

- Project-wide discover and generate:
  - `inspectmo discover . --generate --output src/generated/`

## Local development

From the repo root:

```bash
cd tools/codegen
npm ci
npm run build
node dist/cli.js --help
```

Optional: set up a local global link (may require writable npm prefix):

```bash
npm link
# If EACCES occurs, set a user prefix:
npm config set prefix ~/.npm-global
export PATH="$HOME/.npm-global/bin:$PATH"
npm link
```

## Troubleshooting

- EACCES on `npm link` or `npm i -g` on macOS: use `npx inspectmo@latest`, or set an npm user prefix as shown above.
- Not generating files: ensure the input `.did` path exists and the output directory is writable.

## License

MIT

## Issues

Report issues at: https://github.com/icdevsorg/inspect-mo/issues