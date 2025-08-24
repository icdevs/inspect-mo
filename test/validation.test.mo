import {test} "mo:test/async";
import Debug "mo:core/Debug";
import InspectMo "../src/core/inspector";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import Blob "mo:core/Blob";
import Runtime "mo:core/Runtime";

/// Comprehensive validation test suite using ErasedValidator pattern
/// Tests boundary and runtime validation with various rule types

// Global Args union type for validation testing
type ProtectedArgs = {
  action: Text;
};

type GuardedArgs = {
  content: Text;
  value: Nat;
};

type CustomArgs = {
  data: Text;
  isValid: Bool;
};

type Args = {
  #protected: ProtectedArgs;
  #guarded: GuardedArgs;
  #custom: CustomArgs;
};

let testPrincipal = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
let adminPrincipal = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");

let defaultConfig : InspectMo.InitArgs = {
  allowAnonymous = ?false;
  defaultMaxArgSize = ?1024;
  authProvider = null;
  rateLimit = null;
  queryDefaults = null;
  updateDefaults = null;
  developmentMode = true;
  auditLog = false;
};

func createTestInspector() : InspectMo.InspectMo {
  InspectMo.InspectMo(
    null, adminPrincipal, testPrincipal, ?defaultConfig, null,
    func(state: InspectMo.State) {}
  )
};

// Helper functions for default args
let defaultProtectedArgs : ProtectedArgs = { action = "default" };
let defaultGuardedArgs : GuardedArgs = { content = "default"; value = 0 };
let defaultCustomArgs : CustomArgs = { data = "default"; isValid = false };

await test("boundary validation tests", func() : async () {
  Debug.print("Testing boundary validation...");
  
  let inspector = createTestInspector();
  let boundaryInspector = inspector.createInspector<Args>();
  
  // Register a method with auth requirement using ErasedValidator pattern
  boundaryInspector.inspect(boundaryInspector.createMethodGuardInfo<ProtectedArgs>(
    "protected_method",
    false,
    [
      #requireAuth
    ],
    func(args: Args): ProtectedArgs {
      switch (args) {
        case (#protected(protectedArgs)) protectedArgs;
        case (_) defaultProtectedArgs;
      }
    }
  ));
  
  // Test with anonymous caller (should fail)
  let anonArgs : InspectMo.InspectArgs<Args> = {
    methodName = "protected_method";
    caller = Principal.fromText("2vxsx-fae"); // Anonymous principal
    arg = Text.encodeUtf8("test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = true;
    msg = #protected({ action = "sensitive_operation" });
  };
  
  switch (boundaryInspector.inspectCheck(anonArgs)) {
    case (#ok) {
      Debug.print("❌ Expected anonymous rejection but got success");
      assert false;
    };
    case (#err(msg)) Debug.print("✓ Anonymous caller correctly rejected: " # msg);
  };
  
  // Test with authenticated caller (should pass)
  let authArgs : InspectMo.InspectArgs<Args> = {
    methodName = "protected_method";
    caller = testPrincipal;
    arg = Text.encodeUtf8("test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = true;
    msg = #protected({ action = "allowed_operation" });
  };
  
  switch (boundaryInspector.inspectCheck(authArgs)) {
    case (#ok) Debug.print("✓ Authenticated caller correctly accepted");
    case (#err(msg)) {
      Debug.print("❌ Expected success but got: " # msg);
      assert false;
    };
  };
  
  Debug.print("✓ Boundary validation tests passed");
});

await test("runtime validation tests", func() : async () {
  Debug.print("Testing runtime validation...");
  
  let allowAllConfig : InspectMo.InitArgs = {
    allowAnonymous = ?true; // Allow for runtime testing
    defaultMaxArgSize = ?1024;
    authProvider = null;
    rateLimit = null;
    queryDefaults = null;
    updateDefaults = null;
    developmentMode = true;
    auditLog = false;
  };
  
  let runtimeInspector = InspectMo.InspectMo(
    null, adminPrincipal, testPrincipal, ?allowAllConfig, null,
    func(state: InspectMo.State) {}
  );
  let guardInspector = runtimeInspector.createInspector<Args>();
  
  // Register a method with size validation using ErasedValidator pattern
  guardInspector.guard(guardInspector.createMethodGuardInfo<GuardedArgs>(
    "guarded_method",
    false,
    [
      #textSize(
        func(args: GuardedArgs): Text { args.content }, // Accessor that gets Text from GuardedArgs
        ?1, ?10 // Min 1, max 10 characters
      )
    ],
    func(args: Args): GuardedArgs {
      switch (args) {
        case (#guarded(guardedArgs)) guardedArgs;
        case (_) defaultGuardedArgs;
      }
    }
  ));
  
  let caller = testPrincipal;
  
  // Test with valid text (should pass)
  let validArgs : InspectMo.InspectArgs<Args> = {
    methodName = "guarded_method";
    caller = caller;
    arg = Text.encodeUtf8("hello");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #guarded({ content = "hello"; value = 42 });
  };
  
  switch (guardInspector.guardCheck(validArgs)) {
    case (#ok) Debug.print("✓ Valid text correctly accepted");
    case (#err(msg)) {
      Debug.print("❌ Expected success but got: " # msg);
      assert false;
    };
  };
  
  // Test with text too long (should fail)
  let invalidArgs : InspectMo.InspectArgs<Args> = {
    methodName = "guarded_method";
    caller = caller;
    arg = Text.encodeUtf8("this text is way too long");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #guarded({ content = "this text is way too long"; value = 42 });
  };
  
  switch (guardInspector.guardCheck(invalidArgs)) {
    case (#ok) {
      Debug.print("❌ Expected failure but got success");
      assert false;
    };
    case (#err(msg)) Debug.print("✓ Invalid text correctly rejected: " # msg);
  };
  
  Debug.print("✓ Runtime validation tests passed");
});

await test("complex validation tests", func() : async () {
  Debug.print("Testing complex validation scenarios...");
  
  let inspector = createTestInspector();
  let complexInspector = inspector.createInspector<Args>();
  
  // Register method with multiple validation rules
  complexInspector.guard(complexInspector.createMethodGuardInfo<GuardedArgs>(
    "complex_method",
    false,
    [
      #requireAuth,
      #textSize(func(args: GuardedArgs): Text { args.content }, ?5, ?50),
      #natValue(func(args: GuardedArgs): Nat { args.value }, ?1, ?1000)
    ],
    func(args: Args): GuardedArgs {
      switch (args) {
        case (#guarded(guardedArgs)) guardedArgs;
        case (_) defaultGuardedArgs;
      }
    }
  ));
  
  // Test all validations pass
  let allValidArgs : InspectMo.InspectArgs<Args> = {
    methodName = "complex_method";
    caller = testPrincipal; // Authenticated
    arg = Text.encodeUtf8("complex test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #guarded({ content = "valid content"; value = 100 }); // Valid size and value
  };
  
  switch (complexInspector.guardCheck(allValidArgs)) {
    case (#ok) Debug.print("✓ Complex validation with all rules passed");
    case (#err(msg)) {
      Debug.print("❌ Expected success but got: " # msg);
      assert false;
    };
  };
  
  // Test auth failure
  let authFailArgs : InspectMo.InspectArgs<Args> = {
    methodName = "complex_method";
    caller = Principal.fromText("2vxsx-fae"); // Anonymous
    arg = Text.encodeUtf8("auth fail test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #guarded({ content = "valid content"; value = 100 });
  };
  
  switch (complexInspector.guardCheck(authFailArgs)) {
    case (#ok) {
      Debug.print("❌ Expected auth failure but got success");
      assert false;
    };
    case (#err(msg)) {
      assert(Text.contains(msg, #text "requireAuth"));
      Debug.print("✓ Auth validation failed as expected: " # msg);
    };
  };
  
  // Test size failure
  let sizeFailArgs : InspectMo.InspectArgs<Args> = {
    methodName = "complex_method";
    caller = testPrincipal; // Authenticated
    arg = Text.encodeUtf8("size fail test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #guarded({ content = "tiny"; value = 100 }); // Too short (< 5 chars)
  };
  
  switch (complexInspector.guardCheck(sizeFailArgs)) {
    case (#ok) {
      Debug.print("❌ Expected size failure but got success");
      assert false;
    };
    case (#err(msg)) {
      assert(Text.contains(msg, #text "textSize"));
      Debug.print("✓ Size validation failed as expected: " # msg);
    };
  };
  
  // Test value failure
  let valueFailArgs : InspectMo.InspectArgs<Args> = {
    methodName = "complex_method";
    caller = testPrincipal; // Authenticated
    arg = Text.encodeUtf8("value fail test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #guarded({ content = "valid content"; value = 2000 }); // Too high (> 1000)
  };
  
  switch (complexInspector.guardCheck(valueFailArgs)) {
    case (#ok) {
      Debug.print("❌ Expected value failure but got success");
      assert false;
    };
    case (#err(msg)) {
      assert(Text.contains(msg, #text "nat value"));
      Debug.print("✓ Value validation failed as expected: " # msg);
    };
  };
  
  Debug.print("✓ Complex validation tests passed");
});

await test("custom validation tests", func() : async () {
  Debug.print("Testing custom validation logic...");
  
  let inspector = createTestInspector();
  let customInspector = inspector.createInspector<Args>();
  
  // Register method with custom validation logic
  customInspector.guard(customInspector.createMethodGuardInfo<CustomArgs>(
    "custom_method",
    false,
    [
      #customCheck(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (args.args) {
          case (#custom(customArgs)) {
            if (not customArgs.isValid) {
              #err("CUSTOM_ERROR: isValid flag is false")
            } else if (Text.contains(customArgs.data, #text "forbidden")) {
              #err("CUSTOM_ERROR: Forbidden keyword detected")
            } else if (Text.size(customArgs.data) == 0) {
              #err("CUSTOM_ERROR: Data cannot be empty")
            } else {
              #ok
            }
          };
          case (_) #err("Invalid message variant");
        }
      })
    ],
    func(args: Args): CustomArgs {
      switch (args) {
        case (#custom(customArgs)) customArgs;
        case (_) defaultCustomArgs;
      }
    }
  ));
  
  let caller = testPrincipal;
  
  // Test custom check with valid input
  let customValidArgs : InspectMo.InspectArgs<Args> = {
    methodName = "custom_method";
    caller = caller;
    arg = Text.encodeUtf8("valid");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #custom({ data = "valid data"; isValid = true });
  };
  
  switch (customInspector.guardCheck(customValidArgs)) {
    case (#ok) Debug.print("✓ Custom check with valid input passed");
    case (#err(msg)) {
      Debug.print("❌ Expected success but got: " # msg);
      assert false;
    };
  };
  
  // Test custom check with invalid flag
  let invalidFlagArgs : InspectMo.InspectArgs<Args> = {
    methodName = "custom_method";
    caller = caller;
    arg = Text.encodeUtf8("invalid flag");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #custom({ data = "some data"; isValid = false });
  };
  
  switch (customInspector.guardCheck(invalidFlagArgs)) {
    case (#ok) {
      Debug.print("❌ Expected failure but got success");
      assert false;
    };
    case (#err(msg)) {
      assert(Text.contains(msg, #text "isValid flag is false"));
      Debug.print("✓ Custom check with invalid flag failed: " # msg);
    };
  };
  
  // Test custom check with forbidden content
  let forbiddenArgs : InspectMo.InspectArgs<Args> = {
    methodName = "custom_method";
    caller = caller;
    arg = Text.encodeUtf8("forbidden test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #custom({ data = "this contains forbidden content"; isValid = true });
  };
  
  switch (customInspector.guardCheck(forbiddenArgs)) {
    case (#ok) {
      Debug.print("❌ Expected failure but got success");
      assert false;
    };
    case (#err(msg)) {
      assert(Text.contains(msg, #text "Forbidden keyword"));
      Debug.print("✓ Custom check with forbidden content failed: " # msg);
    };
  };
  
  // Test custom check with empty data
  let emptyDataArgs : InspectMo.InspectArgs<Args> = {
    methodName = "custom_method";
    caller = caller;
    arg = Text.encodeUtf8("empty test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #custom({ data = ""; isValid = true });
  };
  
  switch (customInspector.guardCheck(emptyDataArgs)) {
    case (#ok) {
      Debug.print("❌ Expected failure but got success");
      assert false;
    };
    case (#err(msg)) {
      assert(Text.contains(msg, #text "Data cannot be empty"));
      Debug.print("✓ Custom check with empty data failed: " # msg);
    };
  };
  
  Debug.print("✓ Custom validation tests passed");
});

Debug.print("🧪 VALIDATION TESTS COMPLETED! 🧪");
