# Inspect-Mo: Technical Architecture

## ErasedValidator Pattern - Core Innovation

The InspectMo library solves a fundamental type erasure challenge using an innovative **function generator** pattern.

### The Type Erasure Problem

```motoko
// ❌ This won't work - each method has different M types
private var methodRules = BTree.empty<Text, MethodGuardInfo<M, T>>();

// Method1: update_profile(Text, Text) 
// Method2: transfer(Principal, Nat)
// Method3: upload_file(Blob)
// Can't store different M types in same BTree!
```

### The ErasedValidator Solution

```motoko
// ✅ Function Generator Pattern
public type ErasedValidator<T> = (InspectArgs<T>) -> Result<(), Text>;

public func createMethodGuardInfo<M>(
  methodName: Text, 
  isQuery: Bool,
  rules: [ValidationRule<T,M>], 
  msgAccessor: (T) -> M
) : MethodGuardInfo<T> {
  {
    methodName = methodName;
    isQuery = isQuery;
    validator = func(msg: InspectArgs<T>) : Result<(), Text> {
      // "Bake" the validation logic with full type information
      let typedArgs: M = msgAccessor(msg.msg);
      
      // Apply each rule with typed context
      for (rule in rules.vals()) {
        switch (validateSingleRule<M>(rule, msg, typedArgs)) {
          case (#ok) { /* continue */ };
          case (#err(errMsg)) { return #err(errMsg) };
        }
      };
      #ok
    };
  }
}
```

### Benefits

- **Type Safety**: Full compile-time type checking during registration
- **Performance**: No runtime type resolution - validation logic "baked in"
- **Storage Efficiency**: Single BTree stores all methods regardless of types  
- **Flexibility**: Each method can have completely different parameter types


## Module Structure

```
src/
├── lib.mo                 # Main public inspector Class 
├── core/
│   ├── types.mo          # Core type definitions
│   ├── inspector.mo      # Main inspection logic
│   ├── rules.mo          # Rule definition matching
│   └── size_validator.mo # Size validation for Nat/Text/Blob
├── security/
│   ├── rate_limiter.mo   # Rate limiting implementation
│   ├── auth.mo           # Authentication helpers
│   ├── permissions.mo    # Permission module integration
│   └── common_rules.mo   # Pre-built security rules
├── integrations/
│   ├── permission_systems/ # Permission system integrations
│   │   ├── rbac_adapter.mo    # RBAC integration adapter (⚠️ EXAMPLE ONLY)
│   │   └── custom_auth.mo     # Custom authentication provider interface
└── utils/
    ├── parser.mo         # Argument parsing utilities
    ├── size_analyzer.mo  # Type-aware size calculation
    └── logger.mo         # Audit logging

### Rate limiting (deferred)

Status: Stubbed in v0.1.0; not functional.

Intent:
- Apply per-principal and per-method limits to protect update paths.
- Placement: block updates in `canister_inspect_message` before execution; apply query limits via guard checks.
- Likely approach: token bucket per key (principal+method) with global caps. Persist minimal counters in stable state and rotate/compact.

Out of scope for 0.1.0:
- Cross-canister distributed limits, multi-canister coordination, and advanced analytics—these will be considered in a future release.
```

## Core Types

```motoko
// Core configuration types
public type InspectConfig = {
  allowAnonymous: ?Bool;         // Global default for anonymous access
  defaultMaxArgSize: ?Nat;       // Global default argument size limit
  authProvider: ?AuthProvider;   // Permission system integration
  rateLimit: ?RateLimitConfig;   // Global rate limiting
  
  // Query vs Update specific defaults
  inspectDefaults: ?InspectConfig;   // Defaults for inspect checks
  guardDefaults: ?GuardConfig; // Defaults for guard checks
  
  developmentMode: Bool;         // Enable relaxed rules for testing
  auditLog: Bool;               // Enable audit logging
};

public type InspectConfig = {
  allowAnonymous: ?Bool;
  maxArgSize: ?Nat;
  rateLimit: ?RateLimitConfig;
};

public type GuardConfig = {
  allowAnonymous: ?Bool;
  maxArgSize: ?Nat;
  rateLimit: ?RateLimitConfig;
};

public type ValidationRule = {
  // MVP Core Rules for boundary validation with typed accessor functions
  #textSize: <T>(accessor: T -> Text, min: ?Nat, max: ?Nat);     // Text size validation with typed accessor
  #blobSize: <T>(accessor: T -> Blob, min: ?Nat, max: ?Nat);     // Blob size validation with typed accessor
  #natValue: <T>(accessor: T -> Nat, min: ?Nat, max: ?Nat);      // Nat value range validation with typed accessor
  #intValue: <T>(accessor: T -> Int, min: ?Int, max: ?Int);      // Int value range validation with typed accessor
  #requirePermission: Text;                                       // Require specific permission
  #blockIngress;                                                  // Block all ingress calls at boundary
  #blockAll;                                                     // Block all calls at boundary
  
  // Additional rules (post-MVP)
  #allowedCallers: [Principal];                                   // Static whitelist of allowed principals
  #blockedCallers: [Principal];                                   // Static blacklist of blocked principals
  #requireAuth;                                                   // Require authenticated caller
  #requireRole: Text;                                             // Require specific role
  #rateLimit: RateLimitRule;                                     // Method-specific rate limiting
    #dynamicAuth: (DynamicAuthArgs<T>) -> GuardResult;    // Dynamic authorization with typed context
  #customCheck: (CustomCheckArgs<T>) -> GuardResult;   // Custom business logic with typed context
};


// Typed context for guard functions
public type CustomCheckArgs<T> = {
  args: T;
  caller: Principal;
  cycles: ?Nat;
  deadline: ?Nat;
};

public type DynamicAuthArgs<T> = {
  args: T;
  caller: ?Principal;
  permissions: AuthProvider; // Reference to permission system
};

public type SourceType = {
  #ingressOnly;      // Only allow ingress calls (block canister-to-canister)
  #canisterOnly;     // Only allow canister-to-canister calls (block ingress)
  #any;              // Allow both ingress and canister calls
};

public type GuardResult = {
  #ok;
  #err: Text;
}; // Standard result type for guard operations

public type RateLimitRule = {
  maxPerMinute: ?Nat;
  maxPerHour: ?Nat;
  maxPerDay: ?Nat;
  exemptRoles: ?[Text];
};

public type AuthProvider = {
  checkRole: (Principal, Text) -> Bool;
  checkPermission: (Principal, Text) -> Bool;
  isAuthenticated: Principal -> Bool;
};

// Method registration for dual guard/inspect pattern
public type MethodGuardInfo<T> = {
  methodName: Text;
  isQuery: Bool;                   // Distinguish query vs update calls
  boundaryRules: [ValidationRule<T>]; // Rules for inspect_message boundary validation
  runtimeRules: [ValidationRule<T>];  // Typed runtime validation rules
  msgAccessor: ?Any;              // Type-erased message accessor for boundary validation
  registeredAt: Int;              // Timestamp for audit
};

// Enhanced inspect arguments with method context and parsing
// ✅ Actual InspectArgs type (simple and working)
public type InspectArgs<T> = {
  methodName: Text;
  caller: Principal;
  arg: Blob;
  isQuery: Bool;
  cycles: ?Nat;
  deadline: ?Nat;
  isInspect: Bool;
  msg: T;                         // Typed message variant (e.g., MessageAccessor)
};

// ✅ Actual Args union type pattern (generated by our tool)
public type Args = {
  #update_profile: (Text, Text);  // (bio, displayName)
  #transfer: (Principal, Nat);    // (to, amount)
  #get_balance: (Principal);      // (account)
  #None: ();                      // Default case
};

// ✅ Simple accessor functions (generated by our tool)
public func getUpdateProfileBio(args: Args): Text {
  switch (args) {
    case (#update_profile(bio, _)) bio;
    case (_) "";
  };
};

public func getTransferAmount(args: Args): Nat {
  switch (args) {
    case (#transfer(_, amount)) amount;
    case (_) 0;
  };
};
```

## Size Validation for Large Data Types

One of the most critical security concerns is preventing DoS attacks via oversized arguments. The Internet Computer allows up to 2MB of data in ingress messages, making size validation essential.

### Key Challenges:
- **Nat Serialization**: Nats can be arbitrarily large when serialized, consuming significant memory
- **Text Encoding**: UTF-8 text size calculation needs to account for multi-byte characters  
- **Blob Analysis**: Direct blob size checking is straightforward but needs efficient parsing
- **Composite Types**: Records and arrays containing these types need recursive size calculation

### Size Validation Strategies:

```motoko
// Example size validation implementations
module SizeValidator {
  
  // Fast blob size check - O(1)
  public func validateBlobSize(blob: Blob, min: Nat, max: Nat): Bool {
    let size = blob.size();
    size >= min and size <= max
  };
  
  // Text size validation - accounts for UTF-8 encoding
  public func validateTextSize(text: Text, min: Nat, max: Nat): Bool {
    let byteSize = Text.encodeUtf8(text).size();
    byteSize >= min and byteSize <= max
  };
  
  // Nat serialization size estimation - without full serialization
  public func estimateNatSize(n: Nat): Nat {
    // Fast estimation based on bit length
    if (n == 0) 1
    else (Nat.bitLength(n) + 7) / 8 + 1 // LEB128 overhead estimation
  };
  
  // Composite argument size parsing from blob
  public func parseArgumentSizes(argBlob: Blob, methodSig: [TypeInfo]): [Nat] {
    // Parse Candid-encoded arguments to extract individual sizes
    // without full deserialization for performance
  };
}
```

### Performance Optimizations:
- **Lazy Evaluation**: Only validate sizes for methods that have size rules
- **Early Termination**: Stop parsing once size limits are exceeded
- **Size Caching**: Cache size calculations for repeated argument patterns
- **Estimation**: Use fast size estimation for complex types when exact size isn't critical

## Permission System Integration

**⚠️ IMPORTANT: Example Implementation Only ⚠️**

The permission system integrations provided with InspectMo are **demonstration examples** and are **NOT production-ready**. They are designed to show integration patterns and API usage, but have significant performance and scalability limitations.

**Known Limitations:**
- Uses array-based storage with O(n) lookups
- No efficient caching mechanisms
- Missing role hierarchy support
- Limited session management
- No bulk operations or optimizations

**For Production Use:**
- Implement hash-based data structures (HashMap/Set)
- Add proper permission caching with TTL
- Implement role inheritance and conflict resolution
- Add monitoring, metrics, and audit logging
- Consider external RBAC services for scale

Authorization is critical for protecting sensitive canister operations. The library should integrate seamlessly with existing permission systems.

### Common Permission Patterns:

```motoko
// Integration with various permission systems
// ⚠️ NOTE: These are simplified examples for demonstration
module PermissionIntegration {
  
  // Basic RBAC (Role-Based Access Control) - EXAMPLE ONLY
  public func withBasicRBAC(roles: RoleManager): AuthProvider {
    {
      checkPermission = func(caller: Principal, permission: Text): Bool {
        roles.hasPermission(caller, permission)
      };
      checkRole = func(caller: Principal, role: Text): Bool {
        roles.hasRole(caller, role)
      };
      isAuthenticated = func(caller: Principal): Bool {
        not Principal.isAnonymous(caller) and roles.isRegistered(caller)
      };
    }
  };
  
  // Principal-based authentication - IC handles cryptography
  public func withPrincipalAuth(): AuthProvider {
    {
      checkPermission = func(caller: Principal, permission: Text): Bool {
        // Check against your permission system
        // IC has already authenticated the principal
        hasPermissionInSystem(caller, permission)
      };
      checkRole = func(caller: Principal, role: Text): Bool {
        // Role checks based on your business logic
        hasRoleInSystem(caller, role)
      };
      isAuthenticated = func(caller: Principal): Bool {
        // Simply check if not anonymous - IC handles the rest
        not Principal.isAnonymous(caller)
      };
    }
  };
  
  // Custom permission module integration
  public func withCustomAuth<T>(module: T, adapter: AuthAdapter<T>): AuthProvider {
    {
      checkPermission = func(caller: Principal, permission: Text): Bool {
        adapter.checkPermission(module, caller, permission)
      };
      // ... other methods
    }
  };
}
```

### Authorization Features:
- **Multiple Auth Systems**: Support for RBAC, ABAC, custom systems
- **Permission Caching**: Cache permission checks to reduce latency
- **Session Management**: Optional session-based authentication
- **Principal-based Auth**: Trust IC's authentication, focus on authorization
- **Emergency Override**: Admin override for emergency access

## Dual Pattern Implementation: Inspect + Guard

The library uses a dual approach with clear separation of concerns and typed guard context:

### Boundary Validation (Inspect Registration)
- Happens at canister initialization with `InspectMo.inspect()` calls
- Protects canister from the very first call
- Fast validation with limited context in `inspect_message`
- Can access: caller, raw arguments, method name
- Cannot access: canister state, dynamic data
- Best for: size limits, static auth, ingress blocking

### Runtime Validation (Guard Configuration + Check)  
- **Configuration**: `InspectMo.guard()` calls outside functions register typed validation rules
- **Execution**: `InspectMo.guardCheck<T>()` calls inside functions with full typed context
- Returns `GuardResult` for detailed error messages
- Full context with typed arguments: `caller`, `cycles`, `deadline`
- Can access: all canister variables, maps, dynamic data
- Best for: dynamic permissions, business logic, state checks

## Method Name Extraction Strategy:

```motoko
// Option 1: Explicit method names (most reliable)
public func upload(data: Blob): async () { 
  InspectMo.guard(inspector, "upload", [
    InspectMo.blobSize(min = ?1, max = ?2_000_000)
  ]);
  // Implementation
};

// Option 2: Pattern matching in inspect function
system func inspect({
  caller : Principal;
  arg : Blob;
  msg : {
    #upload : Blob -> ();
    #set : Nat -> ();
    // ... other methods
  }
}) : Bool {
  
  // Extract method name from variant
  let methodName = switch (msg) {
    case (#upload _) { "upload" };
    case (#set _) { "set" };
    // ... other cases
  };
  
  let args : InspectMo.InspectArgs = {
    caller = caller;
    arg = arg;
    methodName = methodName;
    isQuery = false; // Would be determined by method type
    msg = msg;
    parsedArgs = ?parseArguments(arg, msg);
    argSizes = calculateArgSizes(arg);
    argTypes = []; // Would be populated by parsing
  };
  
  inspector.inspect(args)
};

// Option 3: Code generation for variant parsing
// Generated by the local codegen tool:
module MethodExtractor {
  public func extractMethodInfo(msg: Any): (Text, Bool) {
    let msgText = debug_show(msg);
    if (Text.startsWith(msgText, "#upload")) { ("upload", false) }
    else if (Text.startsWith(msgText, "#read")) { ("read", true) }
    else if (Text.startsWith(msgText, "#search")) { ("search", true) }
    // ... other generated cases
    else { ("unknown", false) }
  };
}
```

## Addressing the Type Inspection Challenge

Since Motoko doesn't have runtime type inspection, we'll use multiple strategies:

### Strategy 1: Code Generation Tool ✅ IMPLEMENTED
- **TypeScript/Node.js Parser**: Analyze `.did` files and extract method signatures  
- **Generated Types**: Create type-safe wrappers for method arguments
- **Build Integration**: 
  - ℹ️ **DFX Integration**: Motoko canisters do not support dfx.json prebuild hooks; manual codegen workflow
  - ❌ **Mops Limitation**: mops.toml doesn't support build hooks - manual workflow required
- **Auto-Discovery**: Intelligent .did file discovery with `src/declarations` prioritization
- **Delegated Accessors**: User-controlled field extraction pattern for type safety
- **CLI Tool**: Complete command-line interface with project analysis and integration setup

### Strategy 2: Macro System (Future)
- **Motoko Macros**: Use when available for compile-time code generation
- **Annotation-based**: Use comments or attributes to mark inspectable methods

### Strategy 3: Manual Type Registration ✅ IMPLEMENTED  
- **Developer-provided Types**: Explicit type registration for complex validation
- **Accessor Functions**: Use developer-written functions for field extraction
- **ErasedValidator Pattern**: Type-safe validation with function generators

## Code Generation Architecture

### Auto-Discovery System

The code generation tool implements intelligent project analysis:

```typescript
// Auto-discovery logic prioritizes canonical sources
if (fs.existsSync(path.join(projectRoot, 'src/declarations'))) {
  // Use dfx generate output as primary source
  patterns = ['src/declarations/**/*.did', 'did/**/*.did'];
} else {
  // Fallback to project-wide search with smart filtering
  patterns = ['**/*.did'];
}

// Smart filtering excludes build artifacts
const filtered = didFiles.filter(file => {
  const relativePath = path.relative(projectRoot, file);
  return !relativePath.includes('.dfx/local/lsp/') &&  // LSP temp files
         !relativePath.includes('constructor.did') &&  // Constructor files
         !relativePath.includes('.mops/') &&           // Package managers
         !relativePath.includes('node_modules/');
});
```

### Simple Args Union Pattern (✅ Actual Implementation)

Generated code uses simple Args union types with direct accessor functions:

```motoko
// ✅ What we actually generate - simple and practical
module TestCanisterInspect {
  /// Type aliases for convenience (only types that actually exist)
  public type Result = Types.Result;

  /// Args union type for ErasedValidator pattern  
  public type Args = {
    #send_message: Text;
    #guarded_method: Text;
    #get_info: ();
    #None: ();
  };

  /// Simple accessor functions
  public func getSendMessageMessage(args: Args): Text {
    switch (args) {
      case (#send_message(value)) value;
      case (_) "";
    };
  };

  public func getGuardedMethodData(args: Args): Text {
    switch (args) {
      case (#guarded_method(value)) value;
      case (_) "";
    };
  };
}
```

**Key Benefits of This Approach:**
- ✅ **Simple**: No complex generic functions or type parameters
- ✅ **Type-safe**: Direct pattern matching with compile-time checks
- ✅ **Dynamic**: Only imports types that actually exist in the Candid interface
- ✅ **Practical**: Easy to understand and modify
- ✅ **Performant**: No runtime type resolution overhead

### Discovery Workflow

```mermaid
graph TD
    A[Developer runs dfx generate] --> B[Creates src/declarations/ with .did files]
    B --> C[Run: cd tools/codegen && npx ts-node src/cli.ts discover ../../]
    C --> D[Auto-detect src/declarations as primary source]
    D --> E[Filter out build artifacts and temp files]
    E --> F[Parse Candid interfaces with didc tool]
    F --> G[Generate simple Args union types]
    G --> H[Generate type aliases for existing types only]
    H --> I[Create accessor functions with clean camelCase naming]
```

## Code Generation Workflow

```mermaid
graph TD
    A[Parse .did file with didc tool] --> B[Extract service methods and types]
    B --> C[Generate separate _types.mo file with didc]
    C --> D[Create Args union type for all methods]
    D --> E[Generate simple accessor functions]
    E --> F[Create dynamic type aliases for existing types only]
    F --> G[Output ready-to-use Motoko module]
    G --> H[Developer imports and uses generated code]
```
