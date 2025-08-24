# Inspect-Mo: API Reference & Examples

**📝 Current API Status**: This documentation reflects the **current ErasedValidator API** implemented in the library. Some example files in the `examples/` directory may show older API patterns and are being updated.

## Core API Overview

The Inspect-Mo library provides validation at two different execution points using an **ErasedValidator** pattern for type-safe, efficient validation:

1. **Inspect Pattern**: Validation during system `inspect_message` calls
2. **Guard Pattern**: Validation within method implementations with full context

### ErasedValidator Architecture

The library uses a sophisticated **function generator** approach to solve type erasure challenges:

- **Registration Time**: Full type information available, validation logic "baked" into type-erased functions
- **Execution Time**: Simple function calls with no type complexity
- **Storage**: All methods stored in same BTree regardless of their individual type parameters

## Basic Usage

```motoko
import InspectMo "mo:inspect-mo";
import Debug "mo:core/Debug";
import Error "mo:core/Error";

actor MyCanister {

  type MessageAccessor = {
    #update_profile : (Text, Text); // (bio, displayName)
    #get_profile : (Principal);
  };

  // Initialize inspector with global configuration
  private let config: InspectMo.InitArgs = {
    allowAnonymous = ?false;
    defaultMaxArgSize = ?1024 * 1024; // 1MB default
    authProvider = null; // Your auth provider
    rateLimit = null;
    queryDefaults = ?{
      allowAnonymous = true;
      maxArgSize = 10_000;
      rateLimit = null;
    };
    updateDefaults = ?{
      allowAnonymous = false;
      maxArgSize = 1024 * 1024;
      rateLimit = null;
    };
    developmentMode = false;
    auditLog = true;
  };

  private let inspectMo = InspectMo.InspectMo(
    null, // migration state
    Principal.fromActor(MyCanister), // instantiator
    Principal.fromActor(MyCanister), // canister principal
    ?config,
    null, // environment
    func(state) {} // state update callback
  );
  
  private let inspector = inspectMo.createInspector<MessageAccessor>();

  // Register inspect validation using ErasedValidator pattern
  let updateProfileInspectInfo = inspector.createMethodGuardInfo<(Text, Text)>(
    "update_profile",
    false, // isQuery
    [
      InspectMo.textSize<MessageAccessor, (Text, Text)>(func(args: (Text, Text)): Text { args.0 }, null, ?5000), // bio max 5KB
      InspectMo.textSize<MessageAccessor, (Text, Text)>(func(args: (Text, Text)): Text { args.1 }, ?1, ?100),   // displayName 1-100 chars
      InspectMo.requireAuth<MessageAccessor, (Text, Text)>()
    ],
    func(msg: MessageAccessor) : (Text, Text) = switch(msg) {
      case (#update_profile(bio, displayName)) (bio, displayName);
      case (_) Debug.trap("Wrong message type");
    }
  );
  inspector.inspect(updateProfileInspectInfo);

  // Register guard validation with business logic
  let updateProfileGuardInfo = inspector.createMethodGuardInfo<(Text, Text)>(
    "update_profile", 
    false,
    [
      InspectMo.customCheck<MessageAccessor, (Text, Text)>(func(args: InspectMo.CustomCheckArgs<MessageAccessor>): InspectMo.GuardResult {
        // Example: Check if user owns the profile based on args (MessageAccessor)
        switch (args.args) {
          case (#update_profile(bio, displayName)) {
            if (args.caller == Principal.fromText("user-principal")) { #ok }
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
  inspector.guard(updateProfileGuardInfo);

  public shared(msg) func update_profile(bio: Text, displayName: Text): async () { 
    // Guard validation check
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
      case (#ok) { /* proceed with implementation */ };
      case (#err(errMsg)) { throw Error.reject(errMsg) };
    };
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
      isQuery = false; // determine based on method_name if needed
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
```

  public shared(msg) func update_profile(bio: Text, displayName: Text): async () { 
    // Runtime validation check
    switch (inspector.guard("update_profile", msg.caller)) {
      case (#ok) { /* continue */ };
      case (#err(msg)) { throw Error.reject(msg) };
    };
    
    // Implementation
  };
}
```

## Accessor Functions

Accessor functions extract specific fields from method arguments for validation. These are typically **auto-generated** by the `inspect-mo-generate` tool from your Candid interface:

```bash
# Generate accessor functions and types from your canister
npx inspect-mo-generate path/to/your/canister.did -o generated-types.mo
```

**Generated accessor functions:**
```motoko
## ErasedValidator Pattern

The library solves the type erasure challenge using a **function generator** approach:

### Key Concepts

1. **Registration Time**: Full type information available
   ```motoko
   inspector.createMethodGuardInfo<M>(
     methodName: Text,
     isQuery: Bool, 
     rules: [ValidationRule<T,M>],
     msgAccessor: (T) -> M
   ) : MethodGuardInfo<T>
   ```

2. **Type Erasure**: Validation logic "baked" into type-erased functions
   ```motoko
   public type ErasedValidator<T> = (InspectArgs<T>) -> Result<(), Text>
   ```

3. **Execution Time**: Simple function calls regardless of method-specific types
   ```motoko
   switch (guardInfo.validator(args)) {
     case (#ok) { /* proceed */ };
     case (#err(msg)) { /* handle error */ };
   }
   ```

### Benefits

- **Type Safety**: Full compile-time type checking during registration
- **Performance**: No runtime type resolution or casting
- **Simplicity**: Same BTree stores all methods regardless of their types
- **Flexibility**: Each method can have completely different parameter types
```

## Validation Rules

All validation rules now follow the pattern `ValidationRule<T,M>` where:
- `T`: Message variant type (e.g., `MessageAccessor`)  
- `M`: Method parameter type (e.g., `(Text, Text)`)

### Text Size Validation
```motoko
// Validate bio field (first parameter) max 5KB
InspectMo.textSize<MessageAccessor, (Text, Text)>(
  func(args: (Text, Text)): Text { args.0 }, // accessor for bio receives M type
  null,                                       // no minimum
  ?5000                                      // max 5KB
)

// Validate displayName field (second parameter) 1-100 chars  
InspectMo.textSize<MessageAccessor, (Text, Text)>(
  func(args: (Text, Text)): Text { args.1 }, // accessor for displayName receives M type
  ?1,                                         // min 1 char
  ?100                                       // max 100 chars
)
```

### Blob Size Validation
```motoko
// Validate file upload max 2MB
InspectMo.blobSize<MessageAccessor, Blob>(
  func(blob: Blob): Blob { blob },    // accessor for single blob parameter receives M type
  ?100,                               // min 100 bytes
  ?2_000_000                         // max 2MB
)
```

### Permission-Based Rules
```motoko
// Require authenticated caller (non-anonymous)
InspectMo.requireAuth<MessageAccessor, (Text, Text)>()

// Require specific permission
InspectMo.requirePermission<MessageAccessor, (Text, Text)>("write")

// Require specific role  
InspectMo.requireRole<MessageAccessor, (Text, Text)>("admin")
```

### Access Control Rules
```motoko
// Block all ingress calls (allow only canister-to-canister)
InspectMo.blockIngress<MessageAccessor, (Text, Text)>()

// Block all calls (maintenance mode)
InspectMo.blockAll<MessageAccessor, (Text, Text)>()

// Allow only specific principals
InspectMo.allowedCallers<MessageAccessor, (Text, Text)>(
  Map.fromArray([
    (Principal.fromText("allowed-user"), ()),
    (Principal.fromText("another-user"), ())
  ], Principal.compare)
)
```

## Guard Validation

### Custom Business Logic
```motoko
InspectMo.customCheck<MessageAccessor, (Text, Text)>(
  func(args: InspectMo.CustomCheckArgs<MessageAccessor>): InspectMo.GuardResult { 
    // Access MessageAccessor variant and perform business logic
    switch (args.args) {
      case (#update_profile(bio, displayName)) {
        if (Text.size(bio) > 0 and Text.size(displayName) > 0) { #ok }
        else { #err("Bio and display name are required") }
      };
      case (_) #err("Invalid message variant");
    }
  }
)
```

### Dynamic Authorization
```motoko
InspectMo.dynamicAuth<MessageAccessor, (Text, Text)>(
  func(args: InspectMo.DynamicAuthArgs<MessageAccessor>): InspectMo.GuardResult { 
    // Access auth provider and check permissions based on MessageAccessor
    switch (args.args) {
      case (#update_profile(bio, displayName)) {
        // Check if caller owns this profile
        if (args.caller == Principal.fromText("expected-owner")) { #ok }
        else { #err("You can only update your own profile") }
      };
      case (_) #err("Invalid message variant");
    }
  }
)
```

## Complete Examples

### File Upload Canister
```motoko
import InspectMo "mo:inspect-mo";



actor FileUploader {

  type InspectMessage = {
    #upload_metadata : Text -> ();
    #upload_file : (Blob, Text) -> FileId;
  };

  private let inspector = InspectMo.init<InspectMessage({
    allowAnonymous = ?false;
    updateDefaults = ?{
      maxArgSize = ?1_000_000; // 1MB default
    };
  });

  // Small metadata uploads
  inspector.inspect("upload_metadata", [
    InspectMo.textSize<Text>(Types.getMetadata, max = ?5_000),
    InspectMo.requireAuth()
  ]);
  public func upload_metadata(metadata: Text): async () {
    // Implementation
  };

  // Large file uploads with comprehensive validation
  inspector.inspect( "upload_file", [
    InspectMo.blobSize<Blob, Text>(Types.getFileData, min = ?1, max = ?1_000_000),
    InspectMo.textSize<Blob, Text>(Types.getFileType, min = ?1, max = ?50),
    InspectMo.requireRole("uploader")
  ]);
  inspector.guard("upload_file",[
    InspectMo.customCheck<(Blob, Text)>(func(args: CustomCheckArgs<(Blob, Text)>): GuardResult { 
      let (_, fileType) = args.args;
      if (isValidFileType(fileType)) { #ok }
      else { #err("Invalid file type: " # fileType) }
    })
  ]);
  public func upload_file(fileData: Blob, fileType: Text): async FileId {
    switch (inspector.guardCheck("upload_file", msg.caller)) {
      case (#ok) { /* continue */ };
      case (#err(msg)) { throw Error.reject(msg) };
    };
    // Implementation
  };

  system func inspect({
    caller : Principal;
    arg : Blob;
    msg : InspectMessage
  }) : Bool {
    let (methodName, isQuery) = switch (msg) {
      case (#upload_metadata _) { ("upload_metadata", false) };
      case (#upload_file _) { ("upload_file", false) };
    };
    
    let inspectArgs : InspectMo.InspectArgs = {
      caller = caller;
      arg = arg;
      methodName = methodName;
      isQuery = isQuery;
      isIngress = Principal.isAnonymous(caller);
      msg = msg;
      argTypes = [];
    };
    
    inspector.inspectCheck(inspectArgs)
  };
}
```

### DeFi Canister with Role-Based Access
```motoko
import InspectMo "mo:inspect-mo";
import Permissions "mo:rbac";

actor DeFiCanister {
  private var permissions = Permissions.init();
  
  type InspectMessage = {
    #get_balance: () -> Nat;
    #transfer: () -> (Principal, Nat);
    #admin_set_fee :  Nat -> ();
  }
  
  private let inspector = InspectMo.init<InspectMessage>({
    allowAnonymous = ?false;
    authProvider = ?permissions;
    
    queryDefaults = ?{
      allowAnonymous = ?true;
      maxArgSize = ?1_000;
    };
    updateDefaults = ?{
      allowAnonymous = ?false;
      maxArgSize = ?10_000;
    };
  });

  // Public queries ....but only inspects for converted to update calls
  inspector.inspect(inspector, "get_balance", []);
  public query func get_balance(account: Principal): async Nat {
    // Implementation
  };

  // User operations
  inspector.inspect("transfer", [
    InspectMo.requirePermission("transfer"),
    InspectMo.natValue<Principal, Nat>(Types.getTransferAmount, max = ?1_000_000)
  ]);
  inspector.guard([
    InspectMo.dynamicAuth<(Principal, Nat)>(func(args: DynamicAuthArgs<(Principal, Nat)>): GuardResult { 
      let (to, amount) = args.args;
      if (hasTransferPermission(args.caller, to, amount)) { #ok }
      else { #err("Transfer not authorized") }
    })
  ]);
  public func transfer(to: Principal, amount: Nat): async Result<(), Text> {
    switch (inspector.guardCheck("transfer", msg.caller)) {
      case (#ok) { /* continue */ };
      case (#err(msg)) { throw Error.reject(msg) };
    };
    // Implementation
  };

  // Admin operations
  inspector.inspect("admin_set_fee", [
    InspectMo.requireRole("admin"),
    InspectMo.natValue<Nat>(Types.getFeeAmount, max = ?10_000)
  ]);
  //must still do guard because updates via Other canisters don't go through inspect
  inspector.guard("admin_set_fee", [
    InspectMo.requireRole("admin"),
    InspectMo.natValue<Nat>(Types.getFeeAmount, max = ?10_000)
  ]);
  public func admin_set_fee(newFee: Nat): async () {
    //must still do guard because updates via Other canisters don't go through inspect
    switch (inspector.guardCheck("transfer", msg.caller)) {
      case (#ok) { /* continue */ };
      case (#err(msg)) { throw Error.reject(msg) };
    };
    // Implementation
  };

  system func inspect({
    caller : Principal;
    arg : Blob;
    msg : InspectMessage
  }) : Bool {
    let (methodName, isQuery) = switch (msg) {
      case (#get_balance _) { ("get_balance", true) };
      case (#transfer _) { ("transfer", false) };
      case (#admin_set_fee _) { ("admin_set_fee", false) };
    };
    
    let inspectArgs : InspectMo.InspectArgs = {
      caller = caller;
      arg = arg;
      methodName = methodName;
      isQuery = isQuery;
      isIngress = Principal.isAnonymous(caller);
      msg = msg;
      argTypes = [];
    };
    
    inspector.inspectCheck(inspectArgs)
  };
}
```

## Configuration Options

### Inspector Initialization
```motoko
// Configuration type
private let config: InspectMo.InitArgs = {
  allowAnonymous: ?Bool;         // Global default for anonymous access
  defaultMaxArgSize: ?Nat;       // Global default argument size limit
  authProvider: ?AuthProvider;   // Permission system integration
  rateLimit: ?RateLimitConfig;   // Global rate limiting
  
  queryDefaults: ?{              // Defaults for query methods
    allowAnonymous: ?Bool;
    maxArgSize: ?Nat;
    rateLimit: ?RateLimitConfig;
  };
  updateDefaults: ?{             // Defaults for update methods
    allowAnonymous: ?Bool;
    maxArgSize: ?Nat;
    rateLimit: ?RateLimitConfig;
  };
  
  developmentMode: Bool;         // Enable relaxed rules for testing
  auditLog: Bool;               // Enable audit logging
};

// Initialize with Class Plus integration
private let inspectMo = InspectMo.InspectMo(
  null, // migration state
  Principal.fromActor(MyCanister), // self principal
  Principal.fromActor(MyCanister), // canister principal
  ?config,
  null, // environment
  func(state) {} // state update callback
);

// Create typed inspector
private let inspector = inspectMo.createInspector<MessageAccessor>();
```

### Rate Limiting Configuration
```motoko
let rateLimitConfig: InspectMo.RateLimitConfig = {
  maxPerMinute: ?Nat;
  maxPerHour: ?Nat;
  maxPerDay: ?Nat;
  maxPerHour: ?Nat;
  maxPerDay: ?Nat;
  exemptRoles: ?[Text];
})
```

## Error Handling

### GuardResult Type
```motoko
public type GuardResult = {
  #ok;
  #err: Text;
};
```

### Runtime Validation
```motoko
public func my_method(arg: T): async () {
  switch (inspector.guard("my_method", msg.caller)) {
    case (#ok) { /* continue with implementation */ };
    case (#err(message)) { 
      // Log error, perform cleanup, etc.
      throw Error.reject(message) 
    };
  };
  
  // Method implementation
};
```

## Best Practices

### 1. Layered Security
- Use **inspect** for validation in system inspect_message (size limits, basic auth)
- Use **guard** for complex business logic and dynamic state checks

### 2. Performance Optimization
- Keep accessor functions simple and fast
- Use inspect validation to reject obviously invalid requests early
- Cache permission checks when possible

### 3. Error Messages
- Provide clear, actionable error messages in guard functions
- Avoid exposing sensitive system information in error messages

### 4. Testing
- Test both inspect and guard validation paths
- Test with various argument sizes and types
- Test permission edge cases and role changes

## Migration Guide

### From Manual inspect_message
```motoko
// Old approach
system func inspect({ caller; arg; msg }) : Bool {
  switch (msg) {
    case (#upload(data)) {
      data.size() <= 1_000_000 and not Principal.isAnonymous(caller)
    };
    case (_) { true };
  }
};

// New approach with Inspect-Mo
InspectMo.inspect(inspector, "upload", [
  InspectMo.blobSize<Blob>(Types.getUploadData, max = ?1_000_000),
  InspectMo.requireAuth()
]);
```

This provides better type safety, composability, and maintainability while achieving the same security goals.
