import {test; expect} "mo:test/async";
import InspectMo "../src/core/inspector";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import Blob "mo:core/Blob";
import Array "mo:core/Array";
import Debug "mo:core/Debug";

/// Comprehensive validation rules test suite using ErasedValidator pattern
/// This file tests ALL validation rule types systematically with proper Args union types

// Test data setup
let testPrincipal = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
let anonymousPrincipal = Principal.fromText("2vxsx-fae");
let adminPrincipal = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");

// Simplified test argument types for comprehensive validation
type TextArgs = { content: Text };
type BlobArgs = { data: Blob };
type NumberArgs = { value: Nat };
type IntArgs = { intValue: Int };
type ComplexArgs = { title: Text; content: Text; priority: Nat };
type CustomArgs = { name: Text; value: Nat };

// Comprehensive Args union type covering all test methods
type Args = {
  #text_validation: TextArgs;
  #blob_validation: BlobArgs;
  #number_validation: NumberArgs;
  #int_validation: IntArgs;
  #auth_validation: TextArgs;
  #caller_validation: TextArgs;
  #block_validation: TextArgs;
  #complex_validation: ComplexArgs;
  #custom_validation: CustomArgs;
};

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

// Create test inspector
func createTestInspector() : InspectMo.InspectMo {
  InspectMo.InspectMo(
    null, adminPrincipal, testPrincipal, ?defaultConfig, null,
    func(state: InspectMo.State) {}
  )
};

// Helper functions for default args
let defaultTextArgs : TextArgs = { content = "default" };
let defaultBlobArgs : BlobArgs = { data = Text.encodeUtf8("default") };
let defaultNumberArgs : NumberArgs = { value = 0 };
let defaultIntArgs : IntArgs = { intValue = 0 };
let defaultComplexArgs : ComplexArgs = { title = "default"; content = "default"; priority = 1 };
let defaultCustomArgs : CustomArgs = { name = "default"; value = 0 };

/// ========================================
/// TEXT SIZE VALIDATION TESTS
/// ========================================

await test("textSize validation - basic functionality", func() : async () {
  Debug.print("Testing textSize validation rules with ErasedValidator...");
  
  let inspector = createTestInspector();
  let textInspector = inspector.createInspector<Args>();
  
  // Register different text size validation methods
  textInspector.inspect(textInspector.createMethodGuardInfo<TextArgs>(
    "short_text",
    false,
    [
      #textSize(func(args: TextArgs): Text { args.content }, ?1, ?5)
    ],
    func(args: Args): TextArgs {
      switch (args) {
        case (#text_validation(textArgs)) textArgs;
        case (_) defaultTextArgs;
      }
    }
  ));
  
  textInspector.inspect(textInspector.createMethodGuardInfo<TextArgs>(
    "medium_text",
    false,
    [
      #textSize(func(args: TextArgs): Text { args.content }, ?5, ?20)
    ],
    func(args: Args): TextArgs {
      switch (args) {
        case (#text_validation(textArgs)) textArgs;
        case (_) defaultTextArgs;
      }
    }
  ));
  
  // Test valid cases
  let shortValid : InspectMo.InspectArgs<Args> = {
    methodName = "short_text";
    caller = testPrincipal;
    arg = Text.encodeUtf8("hi");
    msg = #text_validation({ content = "hi" });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (textInspector.inspectCheck(shortValid)) {
    case (#ok) Debug.print("✓ Short text validation passed");
    case (#err(msg)) {
      Debug.print("❌ Short text should have passed: " # msg);
      assert false;
    };
  };
  
  let mediumValid : InspectMo.InspectArgs<Args> = {
    methodName = "medium_text";
    caller = testPrincipal;
    arg = Text.encodeUtf8("hello world");
    msg = #text_validation({ content = "hello world" });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (textInspector.inspectCheck(mediumValid)) {
    case (#ok) Debug.print("✓ Medium text validation passed");
    case (#err(msg)) {
      Debug.print("❌ Medium text should have passed: " # msg);
      assert false;
    };
  };
  
  // Test invalid cases
  let shortInvalid : InspectMo.InspectArgs<Args> = {
    methodName = "short_text";
    caller = testPrincipal;
    arg = Text.encodeUtf8("too long text");
    msg = #text_validation({ content = "too long text" });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (textInspector.inspectCheck(shortInvalid)) {
    case (#err(msg)) Debug.print("✓ Too long text rejected: " # msg);
    case (#ok) {
      Debug.print("❌ Too long text should have been rejected");
      assert false;
    };
  };
  
  Debug.print("✓ Text size validation tests passed");
});

/// ========================================
/// BLOB SIZE VALIDATION TESTS
/// ========================================

await test("blobSize validation - comprehensive", func() : async () {
  Debug.print("Testing blobSize validation rules...");
  
  let inspector = createTestInspector();
  let blobInspector = inspector.createInspector<Args>();
  
  // Register blob size validation method
  blobInspector.inspect(blobInspector.createMethodGuardInfo<BlobArgs>(
    "blob_test",
    false,
    [
      #blobSize(func(args: BlobArgs): Blob { args.data }, ?1, ?20)
    ],
    func(args: Args): BlobArgs {
      switch (args) {
        case (#blob_validation(blobArgs)) blobArgs;
        case (_) defaultBlobArgs;
      }
    }
  ));
  
  // Create test blobs
  let smallBlob = Text.encodeUtf8("small");  // 5 bytes
  let largeBlob = Text.encodeUtf8("this is a very large blob that exceeds size limit"); // >20 bytes
  
  // Test valid case
  let validBlobArgs : InspectMo.InspectArgs<Args> = {
    methodName = "blob_test";
    caller = testPrincipal;
    arg = Text.encodeUtf8("blob test");
    msg = #blob_validation({ data = smallBlob });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (blobInspector.inspectCheck(validBlobArgs)) {
    case (#ok) Debug.print("✓ Valid blob size passed");
    case (#err(msg)) {
      Debug.print("❌ Valid blob should have passed: " # msg);
      assert false;
    };
  };
  
  // Test invalid case
  let invalidBlobArgs : InspectMo.InspectArgs<Args> = {
    methodName = "blob_test";
    caller = testPrincipal;
    arg = Text.encodeUtf8("blob test");
    msg = #blob_validation({ data = largeBlob });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (blobInspector.inspectCheck(invalidBlobArgs)) {
    case (#err(msg)) Debug.print("✓ Too large blob rejected: " # msg);
    case (#ok) {
      Debug.print("❌ Too large blob should have been rejected");
      assert false;
    };
  };
  
  Debug.print("✓ Blob size validation tests passed");
});

/// ========================================
/// NUMERIC VALIDATION TESTS
/// ========================================

await test("natValue validation - ranges and boundaries", func() : async () {
  Debug.print("Testing natValue validation rules...");
  
  let inspector = createTestInspector();
  let numberInspector = inspector.createInspector<Args>();
  
  // Register numeric validation method  
  numberInspector.inspect(numberInspector.createMethodGuardInfo<NumberArgs>(
    "number_test",
    false,
    [
      #natValue(func(args: NumberArgs): Nat { args.value }, ?1, ?10)
    ],
    func(args: Args): NumberArgs {
      switch (args) {
        case (#number_validation(numberArgs)) numberArgs;
        case (_) defaultNumberArgs;
      }
    }
  ));
  
  // Test valid values
  let validNumberArgs : InspectMo.InspectArgs<Args> = {
    methodName = "number_test";
    caller = testPrincipal;
    arg = Text.encodeUtf8("number test");
    msg = #number_validation({ value = 5 });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (numberInspector.inspectCheck(validNumberArgs)) {
    case (#ok) Debug.print("✓ Valid number passed");
    case (#err(msg)) {
      Debug.print("❌ Valid number should have passed: " # msg);
      assert false;
    };
  };
  
  // Test invalid value (too high)
  let invalidNumberArgs : InspectMo.InspectArgs<Args> = {
    methodName = "number_test";
    caller = testPrincipal;
    arg = Text.encodeUtf8("number test");
    msg = #number_validation({ value = 15 });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (numberInspector.inspectCheck(invalidNumberArgs)) {
    case (#err(msg)) Debug.print("✓ Invalid number rejected: " # msg);
    case (#ok) {
      Debug.print("❌ Invalid number should have been rejected");
      assert false;
    };
  };
  
  Debug.print("✓ Nat value validation tests passed");
});

/// ========================================
/// AUTHENTICATION VALIDATION TESTS
/// ========================================

await test("requireAuth validation - anonymous vs authenticated", func() : async () {
  Debug.print("Testing requireAuth validation rules...");
  
  let inspector = createTestInspector();
  let authInspector = inspector.createInspector<Args>();
  
  // Register method requiring authentication
  authInspector.inspect(authInspector.createMethodGuardInfo<TextArgs>(
    "protected_method",
    false,
    [
      #requireAuth
    ],
    func(args: Args): TextArgs {
      switch (args) {
        case (#auth_validation(textArgs)) textArgs;
        case (_) defaultTextArgs;
      }
    }
  ));
  
  // Test with authenticated principal
  let authArgs : InspectMo.InspectArgs<Args> = {
    methodName = "protected_method";
    caller = testPrincipal;
    arg = Text.encodeUtf8("auth test");
    msg = #auth_validation({ content = "test" });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (authInspector.inspectCheck(authArgs)) {
    case (#ok) Debug.print("✓ Authenticated user passed");
    case (#err(msg)) {
      Debug.print("❌ Authenticated user should have passed: " # msg);
      assert false;
    };
  };
  
  // Test with anonymous principal
  let anonArgs : InspectMo.InspectArgs<Args> = {
    methodName = "protected_method";
    caller = anonymousPrincipal;
    arg = Text.encodeUtf8("anon test");
    msg = #auth_validation({ content = "test" });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (authInspector.inspectCheck(anonArgs)) {
    case (#err(msg)) Debug.print("✓ Anonymous user rejected: " # msg);
    case (#ok) {
      Debug.print("❌ Anonymous user should have been rejected");
      assert false;
    };
  };
  
  Debug.print("✓ RequireAuth validation tests passed");
});

/// ========================================
/// CUSTOM CHECK TESTS
/// ========================================

await test("customCheck validation - business logic", func() : async () {
  Debug.print("Testing customCheck validation rules...");
  
  let inspector = createTestInspector();
  let customInspector = inspector.createInspector<Args>();
  
  // Register method with custom validation logic
  customInspector.inspect(customInspector.createMethodGuardInfo<CustomArgs>(
    "custom_method",
    false,
    [
      #customCheck(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (args.args) {
          case (#custom_validation(customArgs)) {
            if (customArgs.value > 100) {
              #err("CUSTOM_ERROR: Value cannot exceed 100")
            } else if (Text.contains(customArgs.name, #text "forbidden")) {
              #err("CUSTOM_ERROR: Forbidden content detected")
            } else {
              #ok
            }
          };
          case (_) #err("Invalid argument type");
        };
      })
    ],
    func(args: Args): CustomArgs {
      switch (args) {
        case (#custom_validation(customArgs)) customArgs;
        case (_) defaultCustomArgs;
      }
    }
  ));
  
  // Test valid case
  let validCustomArgs : InspectMo.InspectArgs<Args> = {
    methodName = "custom_method";
    caller = testPrincipal;
    arg = Text.encodeUtf8("custom test");
    msg = #custom_validation({ name = "allowed"; value = 50 });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (customInspector.inspectCheck(validCustomArgs)) {
    case (#ok) Debug.print("✓ Valid custom check passed");
    case (#err(msg)) {
      Debug.print("❌ Valid custom check should have passed: " # msg);
      assert false;
    };
  };
  
  // Test invalid case (value too high)
  let invalidCustomArgs : InspectMo.InspectArgs<Args> = {
    methodName = "custom_method";
    caller = testPrincipal;
    arg = Text.encodeUtf8("custom test");
    msg = #custom_validation({ name = "normal"; value = 150 });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (customInspector.inspectCheck(invalidCustomArgs)) {
    case (#err(msg)) {
      assert(Text.contains(msg, #text "CUSTOM_ERROR"));
      Debug.print("✓ Invalid custom check rejected: " # msg);
    };
    case (#ok) {
      Debug.print("❌ Invalid custom check should have been rejected");
      assert false;
    };
  };
  
  Debug.print("✓ Custom check validation tests passed");
});

/// ========================================
/// COMBINED RULES TESTS
/// ========================================

await test("multiple validation rules - complex scenarios", func() : async () {
  Debug.print("Testing multiple validation rules combined...");
  
  let inspector = createTestInspector();
  let multiInspector = inspector.createInspector<Args>();
  
  // Combine multiple rules
  multiInspector.inspect(multiInspector.createMethodGuardInfo<ComplexArgs>(
    "complex_method",
    false,
    [
      #requireAuth,
      #textSize(func(args: ComplexArgs): Text { args.content }, ?5, ?50),
      #natValue(func(args: ComplexArgs): Nat { args.priority }, ?1, ?10)
    ],
    func(args: Args): ComplexArgs {
      switch (args) {
        case (#complex_validation(complexArgs)) complexArgs;
        case (_) defaultComplexArgs;
      }
    }
  ));
  
  // Test valid case (all rules pass)
  let validComplexArgs : InspectMo.InspectArgs<Args> = {
    methodName = "complex_method";
    caller = testPrincipal;
    arg = Text.encodeUtf8("complex test");
    msg = #complex_validation({ title = "title"; content = "valid text content"; priority = 5 });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (multiInspector.inspectCheck(validComplexArgs)) {
    case (#ok) Debug.print("✓ Complex validation passed");
    case (#err(msg)) {
      Debug.print("❌ Complex validation should have passed: " # msg);
      assert false;
    };
  };
  
  // Test invalid case (anonymous + correct size + valid priority)
  let anonComplexArgs : InspectMo.InspectArgs<Args> = {
    methodName = "complex_method";
    caller = anonymousPrincipal;
    arg = Text.encodeUtf8("complex test");
    msg = #complex_validation({ title = "title"; content = "valid text content"; priority = 5 });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (multiInspector.inspectCheck(anonComplexArgs)) {
    case (#err(msg)) Debug.print("✓ Anonymous complex call rejected: " # msg);
    case (#ok) {
      Debug.print("❌ Anonymous complex call should have been rejected");
      assert false;
    };
  };
  
  // Test invalid case (authenticated + wrong size)
  let badSizeComplexArgs : InspectMo.InspectArgs<Args> = {
    methodName = "complex_method";
    caller = testPrincipal;
    arg = Text.encodeUtf8("complex test");
    msg = #complex_validation({ title = "title"; content = "hi"; priority = 5 });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (multiInspector.inspectCheck(badSizeComplexArgs)) {
    case (#err(msg)) Debug.print("✓ Bad size complex call rejected: " # msg);
    case (#ok) {
      Debug.print("❌ Bad size complex call should have been rejected");
      assert false;
    };
  };
  
  Debug.print("✓ Multiple validation rules tests passed");
});

/// ========================================
/// UTILITY FUNCTION TESTS
/// ========================================

await test("utility functions - comprehensive coverage", func() : async () {
  Debug.print("Testing utility functions...");
  
  // Test validateTextSize
  assert(InspectMo.validateTextSize("hello", ?1, ?10));
  assert(InspectMo.validateTextSize("12345", ?5, ?5)); // Exactly 5 characters
  assert(not InspectMo.validateTextSize("hi", ?5, ?10)); // Too short
  assert(not InspectMo.validateTextSize("this is too long", ?1, ?5)); // Too long
  
  Debug.print("✓ Utility functions tests passed");
});

Debug.print("🎉 ALL COMPREHENSIVE VALIDATION RULES TESTS COMPLETED! 🎉");
