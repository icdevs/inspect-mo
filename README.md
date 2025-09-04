# Inspect-Mo

> **Secure, type-safe validation and authorization for every Motoko canister.**

---

## 🚀 Overview

Inspect-Mo is a comprehensive validation and authorization framework for Motoko canisters on the Internet Computer. It enables developers to declaratively secure canister methods using a dual-pattern system (inspect/guard), with type-safe rules, minimal boilerplate, and production-grade features.

**Key Features:**
- Type-safe validation for all canister method arguments
- **✅ ValidationRule Array Utilities** - Modular validation with builder patterns and predefined rule sets (v0.1.1)
- **✅ ICRC16 CandyShared Integration** - Complete metadata validation (v0.1.1)
- **✅ Efficient Argument Size Checking** - O(1) `inspectOnlyArgSize` for pre-filtering (v0.1.1)
- Dual-pattern: boundary (inspect) and runtime (guard) validation
- Authentication, authorization, and rate limiting out of the box
- Code generation tool for automatic type-safe accessors and validation helpers
- Production-ready: fully tested, with real-world examples and benchmarks

**🎉 NEW in v0.1.1**: ValidationRule Array Utilities with builder patterns, predefined rule sets, and modular validation architecture + Complete ICRC16 integration with 15 validation rule variants + efficient argument size checking, tested through real canister deployment with 46/46 Motoko + 24/24 PIC integration tests passing.

---

## 🧭 Quick Start

1. **Install dependencies:**
   ```bash
   mops install
   ```
2. **Build the project:**
   ```bash
   dfx build
   ```
3. **Run tests:**
   ```bash
   mops test
   # or for integration tests
   npm test
   ```
4. **Explore examples:**
   - See [`examples/user-management.mo`](examples/user-management.mo) for a full InspectMo integration pattern
   - Browse the `examples/` and `canisters/` folders for more

---

## 🧰 ValidationRule Array Utilities

> **✅ Production Ready**: Modular validation rule management with predefined rule sets and builder patterns.

**New in Latest Release**: Complete ValidationRule Array Utilities providing powerful tools for building, combining, and managing validation rule arrays with type safety and excellent performance.

### Quick Start Example

```motoko
import ValidationUtils "mo:inspect-mo/utils/validation_utils";

// Use predefined rule sets for instant validation
let basicRules = ValidationUtils.basicValidation<MyMessage, Text>();
// Returns: [authenticatedCheck, blockIngressCheck, rateLimitCheck]

let icrc16Rules = ValidationUtils.icrc16MetadataValidation<MyMessage, CandyShared>();
// Returns: [authenticatedCheck, candySizeCheck, candyDepthCheck, propertyExistsCheck]

// Combine multiple rule sets
let allRules = ValidationUtils.combineValidationRules([basicRules, icrc16Rules]);

// Add individual rules
let extendedRules = ValidationUtils.appendValidationRule(allRules, myCustomRule);

// Or use the fluent builder pattern
let complexRules = ValidationUtils.ValidationRuleBuilder<MyMessage, CandyShared>()
  .addRules(ValidationUtils.basicValidation<MyMessage, CandyShared>())
  .addRule(customTimestampValidation)
  .addRules(ValidationUtils.icrc16MetadataValidation<MyMessage, CandyShared>())
  .addRule(businessLogicRule)
  .build();
```

### Key Features

**🏗️ Builder Pattern**: Fluent interface for complex validation pipelines
```motoko
ValidationRuleBuilder<Msg, Data>()
  .addRule(rule1)
  .addRules([rule2, rule3])
  .build()
```

**📦 Predefined Rule Sets**: Battle-tested validation configurations
- `basicValidation()` - Authentication, ingress blocking, rate limiting
- `icrc16MetadataValidation()` - ICRC16 CandyShared validation  
- `comprehensiveValidation()` - Complete validation suite

**🔗 Array Manipulation**: Type-safe rule composition
- `appendValidationRule()` - Add single rule to existing array
- `combineValidationRules()` - Merge multiple rule arrays

**⚡ Performance Validated**:
- **Linear Scaling**: O(n) complexity confirmed up to 1000 rules
- **Memory Efficient**: Consistent 272B heap usage across all array sizes
- **Production Ready**: 18/18 PocketIC tests passing with real canister deployment

### Use Cases

**Modular Validation Architecture**:
```motoko
// Start with basic security
let securityRules = ValidationUtils.basicValidation<MyMsg, Text>();

// Add domain-specific rules
let domainRules = [timestampValidation, formatValidation];

// Combine for complete validation
let finalRules = ValidationUtils.combineValidationRules([securityRules, domainRules]);
```

**Conditional Rule Building**:
```motoko
let builder = ValidationUtils.ValidationRuleBuilder<MyMsg, Data>()
  .addRules(ValidationUtils.basicValidation<MyMsg, Data>());

if (enableMetadataValidation) {
  builder.addRules(ValidationUtils.icrc16MetadataValidation<MyMsg, Data>());
};

if (strictMode) {
  builder.addRule(strictBusinessLogicRule);
};

let rules = builder.build();
```

**Testing & Development**:
```motoko
// Quick validation setup for testing
let testRules = ValidationUtils.basicValidation<TestMsg, Text>();

// Production validation with full rule set
let prodRules = ValidationUtils.comprehensiveValidation<ProdMsg, CandyShared>();
```

### Documentation

- **Complete API Reference**: [`docs/API.md#validationrule-array-utilities`](docs/API.md#validationrule-array-utilities)
- **Detailed Examples**: [`docs/EXAMPLES.md#example-3-validationrule-array-utilities`](docs/EXAMPLES.md#example-3-validationrule-array-utilities) 
- **Architecture Guide**: [`docs/ARCHITECTURE.md#validationrule-array-utilities-architecture`](docs/ARCHITECTURE.md#validationrule-array-utilities-architecture)
- **Testing Strategy**: [`docs/TESTING_STRATEGY.md#validationrule-array-utilities-testing-strategy`](docs/TESTING_STRATEGY.md#validationrule-array-utilities-testing-strategy)

---

## 🔧 Code generation (CLI)

Use the InspectMo Codegen CLI to generate boilerplate from your Candid (.did) files. Re-run after any interface changes.

Install options:
- One-off (no install):
   ```bash
   npx @icdevs-org/inspectmo@latest --help
   ```
- Global install (optional):
   ```bash
   npm i -g @icdevs-org/inspectmo
   inspectmo --help
   ```

Common commands:
- Generate from a specific .did file:
   ```bash
   inspectmo generate path/to/service.did -o src/generated/service-inspect.mo
   ```
- Discover .did files and generate into `src/generated/`:
   ```bash
   inspectmo discover . --generate --output src/generated/
   ```
- Analyze (no code output):
   ```bash
   inspectmo analyze path/to/service.did
   ```
- DFX build hooks (DFX only):
   ```bash
   inspectmo install-hooks . --output src/generated/
   inspectmo status .
   ```

Notes:
- `mops.toml` does not support prebuild hooks; only DFX integration is supported.
- Generated Motoko modules are not committed; re-run codegen after pulling changes that affect interfaces.

## Limitations in v0.1.0

- Rate limiting is stubbed and not functional. The intended design places update-call checks in `canister_inspect_message` and query checks in guards; see `docs/ARCHITECTURE.md` for details. This will land in a future release.
- RBAC is example-only and not a built-in framework. Examples demonstrate patterns; production apps should implement their own roles/permissions.
Notes:
- `dfx` does not support a root-level `scripts` field or a per-canister `prebuild` hook in `dfx.json`. We intentionally run codegen manually instead of wiring it into `dfx.json`.
- The generated Motoko modules are ignored from version control; re-run codegen after pulling changes that affect interfaces.

---

## 📚 Documentation & Learning Path

All documentation is in [`docs/`](docs/). Start with [`docs/README.md`](docs/README.md) for a map of:

- **API Reference:** [`docs/API.md`](docs/API.md) — All public types, functions, and usage patterns
- **Architecture:** [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — Core design, patterns, and implementation
- **Examples:** [`docs/EXAMPLES.md`](docs/EXAMPLES.md) — Real-world code and integration patterns
- **Project Vision:** [`docs/PROJECT.md`](docs/PROJECT.md) — Goals, philosophy, and context
- **Testing:** [`docs/TESTING_STRATEGY.md`](docs/TESTING_STRATEGY.md) — Unit, integration, and end-to-end testing
- **Security Philosophy:** [`docs/AUTHENTICATION_PHILOSOPHY.md`](docs/AUTHENTICATION_PHILOSOPHY.md) — Authentication and authorization best practices
- **Roadmap:** [`docs/WORKPLAN.md`](docs/WORKPLAN.md) — Milestones, phases, and progress

**For new users:**
- Start with [`docs/API.md`](docs/API.md) and [`docs/EXAMPLES.md`](docs/EXAMPLES.md)
- Try the `examples/user-management.mo` canister for a working template

**For advanced users:**
- Dive into [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and [`src/`]
- Explore the codegen tool in [`tools/codegen/`](tools/codegen/)

---

## 🏗️ Project Structure

- `src/` — Core library source code (see `core/`, `security/`, `integrations/`)
- `canisters/` — Example and integration canisters
- `examples/` — Standalone Motoko example files
- `test/` — Unit and integration tests (Motoko)
- `pic/` — PocketIC/Jest integration tests (TypeScript)
- `bench/` — Performance benchmarks
- `tools/codegen/` — TypeScript code generation tool for .did files
- `docs/` — All documentation and learning resources

---

## 🛡️ Core Concepts

### Dual-Pattern Validation
- **Inspect Pattern:** Secure boundary validation at the `system inspect` level (protects from first call)
- **Guard Pattern:** Runtime validation with full call context (typed arguments, caller, cycles, etc.)

### ErasedValidator Architecture
- Type erasure solved via function generator pattern
- All validation logic "baked in" at registration for type safety and performance

### Security Philosophy
- Trust the IC for authentication (`msg.caller`)
- Focus on business logic authorization and role-based access
- See [`docs/AUTHENTICATION_PHILOSOPHY.md`](docs/AUTHENTICATION_PHILOSOPHY.md)

### Code Generation Tool
- Auto-generates type-safe accessors and validation helpers from .did files
- See [`tools/codegen/`](tools/codegen/) and [`docs/PROJECT.md`](docs/PROJECT.md)

### ICRC16 CandyShared Integration ✅
- **Production Ready**: Complete ICRC16 metadata validation with 15 rule variants
- **Type Safety**: Full CandyShared structure validation with compile-time safety
- **Mixed Pipelines**: Seamless integration of traditional + ICRC16 validation rules
- **Real Testing**: Validated through 15/15 PIC.js tests with actual canister deployment
- **Rich Validation**: candyType, candySize, candyDepth, propertyExists, arrayLength, customCandyCheck, and more
- See `examples/simple-icrc16.mo` and `examples/icrc16-user-management.mo` for working examples

---

## 🧪 Testing & Quality

- **Motoko unit tests:** in `test/` (run with `mops test`)
- **Integration tests:** in `pic/` (run with `npm test`)
- **Performance benchmarks:** in `bench/`
- See [`docs/TESTING_STRATEGY.md`](docs/TESTING_STRATEGY.md) for details

### Note on orthogonal upgrades (PIC.js)
- Until PIC.js exposes a first-class orthogonal upgrade API, tests use a local helper to call `install_code` with `mode = upgrade`, `wasm_memory_persistence = keep`, and `skip_pre_upgrade = None`. Track progress here: https://github.com/dfinity/pic-js/issues/146. If unavailable, simulate upgrade cadence via stop/start and validate weekly timers post-restart.

---

## 🤝 Contributing & Support

- See [`docs/PROJECT.md`](docs/PROJECT.md) for contribution guidelines
- Open issues or discussions on GitHub for help or suggestions
- All docs are Markdown and easy to browse/search

---

**Inspect-Mo: Secure, type-safe validation for every Motoko canister.**

## OVS Default Behavior

This motoko class has a default OVS behavior that sends cycles to the developer to provide funding for maintenance and continued development. In accordance with the OVS specification and ICRC85, this behavior may be overridden by another OVS sharing heuristic or turned off. We encourage all users to implement some form of OVS sharing as it helps us provide quality software and support to the community.

Default behavior: 1 XDR per month for up to 10,000 actions; 0.2 additional XDR per month for each additional 10,000 guards. Max of 10 XDR per month per canister.

Default Beneficiary: ICDevs.org