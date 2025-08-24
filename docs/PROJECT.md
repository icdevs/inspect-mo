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

## Target API Design

**ACHIEVED:** This API design has been implemented and is working!

```motoko
## Target API Design

**ACHIEVED:** This API design has been implemented using the ErasedValidator pattern! 🎉

```motoko
// Current working API - ErasedValidator pattern with type-safe validation
import InspectMo "mo:inspect-mo";
import Debug "mo:core/Debug";
import Error "mo:core/Error";

actor MyCanister {
  type MessageAccessor = {
    #update_profile : (Text, Text); // (bio, displayName)
    #transfer : (Principal, Nat);   // (to, amount)
  };

  private let inspector = inspectMo.createInspector<MessageAccessor>();

  // Register validation using ErasedValidator pattern - types "baked in" at registration
  let inspectInfo = inspector.createMethodGuardInfo<(Text, Text)>(
    "update_profile",
    false, // isQuery
    [
      InspectMo.textSize<MessageAccessor, (Text, Text)>(func(args: (Text, Text)): Text { args.0 }, null, ?5000), // bio max 5KB
      InspectMo.textSize<MessageAccessor, (Text, Text)>(func(args: (Text, Text)): Text { args.1 }, ?1, ?100),   // name 1-100 chars
      InspectMo.requireAuth<MessageAccessor, (Text, Text)>()
    ],
    func(msg: MessageAccessor) : (Text, Text) = switch(msg) {
      case (#update_profile(bio, displayName)) (bio, displayName);
      case (_) Debug.trap("Wrong message type");
    }
  );
  inspector.inspect(inspectInfo);

  // Guard validation with business logic
  let guardInfo = inspector.createMethodGuardInfo<(Text, Text)>(
    "update_profile", 
    false,
    [
      InspectMo.customCheck<MessageAccessor, (Text, Text)>(func(args: InspectMo.CustomCheckArgs<MessageAccessor>): InspectMo.GuardResult {
        switch (args.args) {
          case (#update_profile(bio, displayName)) {
            if (permissions.owns(args.caller, displayName)) { #ok }
            else { #err("You can only update your own profile") }
          };
          case (_) #err("Invalid message variant");
        }
      })
    ],
    func(msg: MessageAccessor) : (Text, Text) = switch(msg) {
      case (#update_profile(bio, displayName)) (bio, displayName);
      case (_) Debug.trap("Wrong message type");
    }
  );
  inspector.guard(guardInfo);

  public shared(msg) func update_profile(bio: Text, displayName: Text): async () {
    let args : InspectMo.InspectArgs<MessageAccessor> = {
      methodName = "update_profile";
      caller = msg.caller;
      arg = to_candid(bio, displayName);
      isQuery = false;
      cycles = null;
      deadline = null;
      isInspect = false;
      msg = #update_profile(bio, displayName);
    };
    
    switch (inspector.guardCheck(args)) {
      case (#ok) { /* implementation */ };
      case (#err(errMsg)) { throw Error.reject(errMsg) };
    }
  };

  system func inspect({
    caller : Principal;
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

- **ErasedValidator Pattern**: Solves type erasure elegantly with function generators
- **Type Safety**: Full compile-time type checking during registration  
- **Performance**: Zero runtime type resolution - validation logic "baked in"
- **Flexibility**: Each method can have completely different parameter types
- **Simplicity**: Same BTree stores all methods regardless of their types
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
- Native mops integration
- dfx hook system
- Standalone CLI tool option
- IDE extensions for configuration assistance

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
- **Internet Identity Integration**: Simplified principal type detection (user vs canister)
- **ICRC Standards Compliance**: Support for token and NFT standards
- **Multi-language Support**: Rust and TypeScript versions
- **Cloud Services Integration**: AWS/GCP security service connectors

## Getting Started (Future)

Once development is complete, developers will be able to:

1. **Install**: `mops add inspect-mo`
2. **Configure**: Add declarative inspection rules to their canister
3. **Generate**: Run `inspect-mo-generate` to create type-safe helpers (optional)
4. **Deploy**: Secure canister with minimal code changes

This library will make Internet Computer canisters more secure by default while maintaining the developer experience that makes Motoko great for IC development.
