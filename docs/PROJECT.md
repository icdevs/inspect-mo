# Inspect-Mo: Project Overview & Specifications

## Mission Statement

Create a comprehensive, easy-to-use helper library for implementing secure `inspect_message` functions in Motoko canisters on the Internet Computer.

## Problem Statement

Developers often leave their canisters vulnerable to free ingress message attacks where malicious actors can force canisters to pay for message processing costs. The `inspect_message` system function provides boundary-level protection, but implementing it securely requires boilerplate code and security expertise that many developers lack.

## Solution

A declarative, type-safe library that makes implementing robust message inspection as simple as configuration, using a dual-pattern approach with user-defined accessor functions for flexible field validation.

## Design Principles

- **Declarative over Imperative**: Users describe WHAT they want to allow/deny, not HOW to implement the logic
- **Secure by Default**: Common attack vectors blocked automatically
- **Zero Runtime Overhead**: All inspection logic compiles to efficient code
- **Type Safety**: Leverage Motoko's type system to prevent configuration errors
- **Composable**: Allow combining multiple inspection rules and strategies
- **User-Controlled**: Developers write simple accessor functions for field extraction

## Core Features

### MVP Security Features
- **Caller Validation**: Dynamic permission checking via runtime functions with full call context
- **Text Size Limits**: Validate Text argument sizes using user-defined accessor functions
- **Blob Size Limits**: Validate Blob argument sizes using user-defined accessor functions  
- **Nat Value Validation**: Min/max value constraints for Nat arguments using user-defined accessor functions
- **Int Value Validation**: Min/max value constraints for Int arguments using user-defined accessor functions
- **Ingress Blocking**: Block ingress calls at boundary (inspect only handles ingress)
- **Dynamic Runtime Validation**: Custom functions with typed arguments and call context (caller, cycles, deadline)
- **✅ ICRC16 CandyShared Integration**: Complete metadata validation with 15 rule variants (Production Ready v0.1.1)
- **✅ Efficient Argument Size Checking**: O(1) `inspectOnlyArgSize` function for pre-filtering and monitoring (v0.1.1)

### Performance & Efficiency Features (✅ Complete v0.1.1)
- **inspectOnlyArgSize Function**: Direct blob size access without parsing overhead
  - O(1) complexity for maximum performance in high-throughput scenarios
  - Pre-filtering capability to reject oversized requests before expensive validation
  - Monitoring and analytics support for argument size tracking
  - Seamless integration with existing validation pipeline
- **Early Rejection Patterns**: Filter requests by size before resource-intensive operations
- **Performance Monitoring**: Built-in argument size analytics and rejection rate tracking

### ICRC16 Features (✅ Complete)
- **CandyShared Validation**: Full support for ICRC16 metadata structures
- **Type Validation**: candyType, candySize, candyDepth validation rules
- **Structure Validation**: propertyExists, arrayLength, classStructure validation
- **Value Validation**: boolValue, intRange, natRange, floatRange validation
- **Pattern Validation**: textPattern, valueSet validation
- **Custom Logic**: icrc16CustomCandyCheck for domain-specific validation
- **Mixed Pipelines**: Seamless combination of traditional + ICRC16 validation rules
- **Production Tested**: 15/15 PIC.js tests passing with real canister deployment

### Architecture Features
- **Dual Pattern**: 
  - **Inspect**: Boundary validation registration at canister init (protects from first call)
  - **Guard**: Runtime validation configuration outside functions with typed `guardCheck<T>()` inside
- **Early Registration**: Both `InspectMo.inspect()` and `InspectMo.guard()` calls happen at canister initialization

- **Typed Guard Context**: Guards receive full call context with typed arguments, caller, cycles, and deadline
- **Error Propagation**: Runtime guards return detailed error messages through Result type
- **Global Defaults**: Set project-wide defaults with method-level overrides
- **Dynamic Validation**: Support for runtime functions that access current canister state
- **Composable Rules**: Combine multiple validation rules per method

### Developer Experience Features
- **Runtime Method Registration**: Guards register methods dynamically at runtime
- **Pre-built Rule Templates**: Common security patterns as validation functions
- **Development Mode**: Relaxed rules for local testing
- **Audit Logging**: Track rejected calls for security monitoring
- **Code Generation Tool**: TypeScript-based tool for automated boilerplate generation
- **Auto-Discovery**: Intelligent .did file discovery with `src/declarations` prioritization  
- **Build System Integration**: Automated hooks for mops.toml and dfx.json
- **Project Analysis**: Comprehensive analysis of existing InspectMo usage patterns

## Target API Design

**ACHIEVED:** This API design has been implemented and is working!

#### Build System Integration

DFX and Mops do not provide prebuild hooks for Motoko canisters. The supported and recommended workflow in v0.1.0 is manual code generation before building or testing.

- DFX: Run codegen manually, then build: `npm run codegen && dfx build`
- Mops: Run codegen manually before tests: `npm run codegen && mops test`

Notes:
- dfx.json does not support a root-level scripts field nor canister-level prebuild hooks for Motoko. Keep build scripts in package.json and invoke them manually.
- Generated Motoko files live under `src/generated/` and are not committed to version control; re-run codegen when interfaces change.

Manual usage examples:
```bash
# From repo root
# Discover .did files and generate helpers into src/generated/
npm run codegen

# Or invoke the CLI directly
npx ts-node tools/codegen/src/cli.ts discover . --generate --output src/generated/

# Generate for a specific .did file
npx ts-node tools/codegen/src/cli.ts <path/to/file.did> --output src/generated/<name>-inspect.mo
```
    method_name : Text;
    arg : Blob;
    msg : MessageAccessor;
  }) : Bool {
    let args : InspectMo.InspectArgs<MessageAccessor> = {
      methodName = method_name;
      caller = caller;
      arg = arg;
      isQuery = false;
      cycles = null;
      deadline = null;
      isInspect = true;
      msg = msg;
    };
    
    switch (inspector.inspectCheck(args)) {
      case (#ok) true;
      case (#err(_)) false;
    }
  };
}
```

### Key Achievements ✅

- **ErasedValidator Pattern**: Solves type erasure elegantly with function generators ✅
- **Type Safety**: Full compile-time type checking during registration ✅
- **Performance**: Zero runtime type resolution - validation logic "baked in" ✅
- **Flexibility**: Each method can have completely different parameter types ✅
- **Simplicity**: Same BTree stores all methods regardless of their types ✅
- **Code Generation Tool**: TypeScript-based tool with didc integration ✅
- **Dynamic Type Aliases**: Only imports types that actually exist ✅
- **Actor Class Support**: Handles both regular services and actor class patterns ✅
- **Clean Naming**: CamelCase function names and clean API ✅
- **DFX Integration**: Motoko canisters do not support prebuild hooks; use manual codegen before builds
- **Build System Status**: DFX supported ✅, mops limitation confirmed ❌
      case (#err(msg)) { throw Error.reject(msg) };
    };
    
    // Implementation
  };

  // User-defined accessor functions in Types module
  // public func getBio(bio: Text, displayName: Text): Text { bio };
  // public func getDisplayName(bio: Text, displayName: Text): Text { displayName };
}
```

## Expected Challenges & Solutions

### Challenge 1: Dual Pattern Complexity
**Problem**: Managing both boundary (inspect) and runtime (guard) validation patterns
**Solutions**:
- Clear separation of concerns with dedicated APIs for each pattern
- Code generation tools to reduce boilerplate
- Comprehensive documentation on when to use each pattern
- Default configurations that work for most use cases

### Challenge 2: Dynamic State Access in Boundary Validation  
**Problem**: `inspect_message` cannot access canister state for dynamic validations
**Solutions**:
- Clear API distinction between static boundary rules and dynamic runtime rules
- Runtime validation pattern for state-dependent checks
- Documentation on performance implications of each approach
- Hybrid approach using both patterns where appropriate

### Challenge 3: Argument Value Parsing Performance
**Problem**: Parsing Nat/Int values from Candid for range validation could be slow
**Solutions**:
- User-defined accessor functions eliminate complex parsing in library
- Fast estimation algorithms for common cases
- Early termination for values clearly outside bounds
- Optional strict vs fast parsing modes

### Challenge 4: Source Detection (Ingress vs Canister)
**Problem**: Detecting whether call originated from ingress or another canister
**Solutions**:
- Use caller principal analysis (anonymous = ingress, principal = canister)
- Message context analysis where available
- Documentation on limitations and edge cases
- Fallback strategies when detection is uncertain

### Challenge 5: Developer Adoption
**Problem**: Developers might find configuration complex
**Solutions**:
- Provide sensible secure defaults
- Create configuration wizard/generator
- Extensive examples and templates
- Integration with popular canister frameworks

### Challenge 6: Build System Integration
**Problem**: Seamless integration with existing build processes
**Solutions**:
- ✅ **DFX Integration**: Manual codegen workflow documented (no prebuild hooks for Motoko)
- ❌ **Mops Limitation**: mops.toml doesn't support prebuild hooks (confirmed limitation)
- ✅ **Standalone CLI Tool**: TypeScript-based code generation tool
- 🔄 **IDE Extensions**: Future enhancement for configuration assistance

## Success Metrics

### Technical Metrics
- **Security Coverage**: Block 99%+ of common attack vectors
- **Performance Impact**: <5ms additional latency per call
- **Type Safety**: 100% compile-time validation of configurations
- **Integration**: Support for 90%+ of existing canister patterns

### Adoption Metrics
- **Community Usage**: 100+ canisters using the library within 6 months
- **Developer Satisfaction**: >4.5/5 rating in community surveys
- **Security Improvements**: Measurable reduction in canister vulnerabilities
- **Documentation Quality**: <2 average support requests per user

## Code Generation Tool

### Overview
The project includes a sophisticated TypeScript-based code generation tool (`tools/codegen/`) that automates the creation of type-safe validation boilerplate from Candid interface files.

### Key Features

#### Intelligent Auto-Discovery
- **Primary Source Detection**: Automatically prioritizes `src/declarations/` directory (created by `dfx generate`)
- **Smart Filtering**: Excludes build artifacts (`.dfx/local/lsp/`, `constructor.did`, package manager folders)
- **Project-Aware**: Reads `dfx.json` to understand canister structure
- **Comprehensive Analysis**: Discovers .did files, analyzes existing InspectMo usage, suggests integrations

#### Delegated Accessor Pattern
- **Type-Safe Field Extraction**: Users provide extraction functions instead of error-prone automatic parsing
- **Complex Type Support**: Handles recursive types, variants, records through user-controlled delegation
- **Performance Optimized**: No runtime parsing overhead, all extraction happens at compile time

#### Build System Integration
- **⚠️ Mops Limitation**: mops.toml does not support prebuild hooks or build scripts
- **ℹ️ DFX**: `dfx.json` does not provide prebuild hooks for Motoko canisters; run codegen manually
- **Automated Workflow**: `npm run codegen` seamlessly integrates with DFX build process
- **Watch Mode Support**: Automatic regeneration when interface files change (via DFX prebuild hooks)

### Build System Integration Details

#### DFX Integration (✅ Fully Supported)

The code generation tool provides seamless integration with DFX build systems:

**Automatic Setup:**
```bash
# Install DFX build hooks
# No install-hooks for Motoko canisters; use manual codegen before builds
```

**Integration Results:**
- ✅ Adds `codegen` script to `dfx.json` 
- ✅ Provides codegen scripts; developers run manually before dfx build
- ✅ Automatic code generation before every `dfx build`
- ✅ Generated files placed in `src/generated/` directory

**dfx.json Configuration:**
```json
{
  "scripts": {
  "codegen": "cd tools/codegen && npx ts-node src/cli.ts discover ../../ --generate"
  },
  "canisters": {
    "main": {
      "main": "./src/main.mo",
      "type": "motoko",
  # No prebuild hooks; run manually before build:
  # npm run codegen
    },
    "test_canister": {
      "main": "./src/test_canister.mo", 
      "type": "motoko",
  # No prebuild hooks; run manually before build:
  # npm run codegen
    }
  }
}
```

#### Mops Integration (❌ Not Supported)

**Limitation**: mops.toml configuration format does not support build hooks or prebuild scripts according to the [official mops documentation](https://docs.mops.one/).

**Valid mops.toml sections:**
- `[package]` - Package metadata
- `[dependencies]` - Runtime dependencies  
- `[dev-dependencies]` - Development dependencies
- `[toolchain]` - Motoko compiler versions
- `[requirements]` - Package requirements

**No support for:**
- ❌ `[build]` section 
- ❌ `pre-build` hooks
- ❌ `post-build` scripts
- ❌ Custom build commands

**Workaround**: Use DFX integration instead, or run `npm run codegen` manually before `mops test`.

#### Manual Integration

For projects not using DFX or requiring custom workflows:

```bash
# Generate code for specific .did file
npx ts-node tools/codegen/src/cli.ts canister.did --output src/generated/generated-inspect.mo

# Auto-discover and generate for entire project
npx ts-node tools/codegen/src/cli.ts discover . --generate --output src/generated/

# Project analysis and suggestions
npx ts-node tools/codegen/src/cli.ts discover . --suggest
```

### Generated Code Structure
```motoko
// Generated validation module with delegated accessors
public func validateMethod<T>(
  getField1: T -> Text,
  getField2: T -> Blob
) : [InspectMo.ValidationRule<MessageAccessor, T>] {
  [
    InspectMo.textSize<MessageAccessor, T>(getField1, ?1, ?100),
    InspectMo.blobSize<MessageAccessor, T>(getField2, null, ?1_000_000)
  ]
};
```

### CLI Commands
```bash
# Auto-discovery with project analysis (optional)
npx ts-node tools/codegen/src/cli.ts discover <project> --suggest

# Single file generation
npx ts-node tools/codegen/src/cli.ts <canister.did> --output <output.mo>

# Generate for all discovered files
npx ts-node tools/codegen/src/cli.ts discover <project> --generate --output src/generated/
```

### Discovery Output Example
```
🔍 Auto-discovering project structure in: ./
📁 Found src/declarations - using as primary source for .did files

📊 Project Analysis:
   • 7 .did file(s) found
   • 277 .mo file(s) found
   • 84 InspectMo usage(s) detected

� Candid Files:
   • src/declarations/test_canister/test_canister.did
   • src/declarations/main/main.did
   • src/declarations/complex_test_canister/complex_test_canister.did

�💡 Integration Status:
   ℹ️  mops.toml does not support prebuild hooks - integration not available
   ✅ dfx.json has inspect-mo codegen script
   ✅ 5/5 Motoko canisters have prebuild hooks

Overall Status:
   Mops Integration: ❌ Not Supported (mops.toml doesn't support prebuild hooks)
   DFX Integration: ✅ Installed

� Generating boilerplate for discovered .did files...
   ✅ Generated: src/generated/test_canister-inspect.mo
   ✅ Generated: src/generated/main-inspect.mo
   ✅ Generated: src/generated/complex_test_canister-inspect.mo
```

### Integration Workflow

#### Recommended Setup
1. Run code generation when interfaces change: `npm run codegen`
2. Build canisters: `dfx build`
3. Run Motoko tests: `mops test`
4. Run integration tests: `npm test`

#### Continuous Integration (optional)
Even without hooks, you can ensure consistency by invoking codegen explicitly in CI before builds:

```yaml
- name: Generate helpers
  run: npm run codegen
- name: Build canisters
  run: dfx build
```

## Risk Mitigation

### Security Risks
- **Bypass Vulnerabilities**: Comprehensive security testing and audits
- **Configuration Errors**: Extensive validation and safe defaults
- **Performance Attacks**: Built-in rate limiting and resource controls

### Technical Risks
- **Type System Limitations**: Multiple fallback strategies for type handling
- **Build Integration Issues**: Support for multiple build systems
- **Breaking Changes**: Semantic versioning and migration guides

### Adoption Risks
- **Complexity Concerns**: Focus on simple, declarative API design
- **Competition**: Emphasize unique features and superior DX
- **Maintenance Burden**: Establish clear contribution guidelines and governance

## Future Enhancements

### Advanced Security Features
- **Machine Learning-based Anomaly Detection**: Identify unusual call patterns
- **Cross-canister Coordination**: Share threat intelligence between canisters
- **Formal Verification**: Mathematical proofs of security properties
- **Zero-knowledge Proofs**: Privacy-preserving authentication

### Developer Experience
- **Visual Configuration Builder**: GUI tool for complex rule configuration
- **Real-time Monitoring Dashboard**: Live view of inspection decisions
- **IDE Extensions**: VS Code integration with syntax highlighting
- **Auto-updating Security Rules**: Crowd-sourced threat intelligence

### Ecosystem Integration
- **Principal-based Authentication**: Leverages IC's built-in authentication
- **RBAC Examples**: Demonstration RBAC adapters (⚠️ not production-ready)
- **ICRC Standards Compliance**: Support for token and NFT standards
- **Multi-language Support**: Rust and TypeScript versions
- **Cloud Services Integration**: AWS/GCP security service connectors

## Important Limitations

**⚠️ RBAC Implementation Notice**: The current RBAC adapters provided with InspectMo are **example implementations only** and are **not suitable for production use**. They demonstrate integration patterns but have significant performance and security limitations including O(n) lookups, no caching, and missing role hierarchy support. Production deployments should implement proper hash-based storage, caching mechanisms, and comprehensive security features.

## Getting Started (Future)

Once development is complete, developers will be able to:

1. **Install**: `mops add inspect-mo`
2. **Configure**: Add declarative inspection rules to their canister
3. **Generate**: Run the local codegen tool to create type-safe helpers (optional)
4. **Deploy**: Secure canister with minimal code changes

This library will make Internet Computer canisters more secure by default while maintaining the developer experience that makes Motoko great for IC development.
