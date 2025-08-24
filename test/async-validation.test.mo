import {test; expect} "mo:test/async";
import InspectMo "../src/lib";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import Blob "mo:core/Blob";
import Array "mo:core/Array";
import Debug "mo:core/Debug";

/// Comprehensive async InspectMo validation functionality test suite with ErasedValidator

// Define Args union type for all async validation tests
type Args = {
  #protected_method: () -> ();
  #text_guard_method: () -> Text;
  #blob_guard_method: () -> Blob;
  #custom_method: () -> Text;
  #dynamic_auth_method: () -> Text;
  #secure_method: () -> Text;
};

/// Test 1: Authentication and Authorization Rules
await test("authentication - requireAuth rule", func() : async () {
  Debug.print("Testing requireAuth validation with ErasedValidator...");
  
  let config : InspectMo.InitArgs = {
    allowAnonymous = ?false;
    defaultMaxArgSize = ?1024;
    authProvider = null;
    rateLimit = null;
    queryDefaults = null;
    updateDefaults = null;
    developmentMode = true;
    auditLog = false;
  };
  
  let mockInspectMo = InspectMo.InspectMo(
    null,
    Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai"),
    Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"), 
    ?config,
    null,
    func(state: InspectMo.State) {}
  );
  let inspector = mockInspectMo.createInspector<Args>();
  
  // Register a method with auth requirement using ErasedValidator pattern
  let protectedInfo = inspector.createMethodGuardInfo<()>(
    "protected_method",
    false,
    [
      InspectMo.requireAuth<Args, ()>()
    ],
    func(args: Args): () {
      switch (args) {
        case (#protected_method(fn)) fn();
        case (_) ();
      }
    }
  );
  inspector.guard(protectedInfo);
  
  // Test with anonymous caller (should fail)
  let anonArgs : InspectMo.InspectArgs<Args> = {
    caller = Principal.fromText("2vxsx-fae"); // Anonymous principal
    arg = Text.encodeUtf8("test");
    methodName = "protected_method";
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #protected_method(func() { () });
  };
  
  let anonResult = inspector.guardCheck(anonArgs);
  switch (anonResult) {
    case (#ok) { assert false }; // Should reject anonymous caller
    case (#err(msg)) { Debug.print("✓ Anonymous caller rejected: " # msg) };
  };
  
  // Test with authenticated caller (should pass)
  let authArgs : InspectMo.InspectArgs<Args> = {
    caller = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
    arg = Text.encodeUtf8("test");
    methodName = "protected_method";
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #protected_method(func() { () });
  };
  
  let authResult = inspector.guardCheck(authArgs);
  switch (authResult) {
    case (#ok) { Debug.print("✓ Authenticated caller accepted") };
    case (#err(msg)) { assert false };
  };
});

/// Test 2: Runtime Text Size Validation
await test("runtime validation - textSize", func() : async () {
  Debug.print("Testing textSize validation with ErasedValidator...");
  
  let config : InspectMo.InitArgs = {
    allowAnonymous = ?true;
    defaultMaxArgSize = ?1024;
    authProvider = null;
    rateLimit = null;
    queryDefaults = null;
    updateDefaults = null;
    developmentMode = true;
    auditLog = false;
  };
  
  let mockInspectMo = InspectMo.InspectMo(
    null,
    Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai"),
    Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"),
    ?config,
    null,
    func(state: InspectMo.State) {}
  );
  let inspector = mockInspectMo.createInspector<Args>();
  
  // Register method with runtime text validation
  let textGuardInfo = inspector.createMethodGuardInfo<Text>(
    "text_guard_method",
    false,
    [
      InspectMo.textSize<Args, Text>(
        func(text: Text): Text { text },
        ?1, ?10 // Min 1, max 10 characters
      )
    ],
    func(args: Args): Text {
      switch (args) {
        case (#text_guard_method(fn)) fn();
        case (_) "default";
      }
    }
  );
  inspector.guard(textGuardInfo);
  
  let caller = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
  
  // Test with valid text
  let validArgs : InspectMo.InspectArgs<Args> = {
    caller = caller;
    arg = Text.encodeUtf8("test");
    methodName = "text_guard_method";
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #text_guard_method(func() { "hello" });
  };
  let validResult = inspector.guardCheck(validArgs);
  switch (validResult) {
    case (#ok) { Debug.print("✓ Valid text accepted") };
    case (#err(msg)) { assert false };
  };
  
  // Test with text too long
  let invalidArgs : InspectMo.InspectArgs<Args> = {
    caller = caller;
    arg = Text.encodeUtf8("test");
    methodName = "text_guard_method";
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #text_guard_method(func() { "this text is way too long" });
  };
  let invalidResult = inspector.guardCheck(invalidArgs);
  switch (invalidResult) {
    case (#ok) { assert false };
    case (#err(msg)) { Debug.print("✓ Oversized text rejected: " # msg) };
  };
  
  // Test with empty text
  let emptyArgs : InspectMo.InspectArgs<Args> = {
    caller = caller;
    arg = Text.encodeUtf8("test");
    methodName = "text_guard_method";
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #text_guard_method(func() { "" });
  };
  let emptyResult = inspector.guardCheck(emptyArgs);
  switch (emptyResult) {
    case (#ok) { assert false };
    case (#err(msg)) { Debug.print("✓ Empty text rejected: " # msg) };
  };
});

/// Test 3: Runtime Blob Size Validation
await test("runtime validation - blobSize", func() : async () {
  Debug.print("Testing blobSize validation with ErasedValidator...");
  
  let config : InspectMo.InitArgs = {
    allowAnonymous = ?true;
    defaultMaxArgSize = ?1024;
    authProvider = null;
    rateLimit = null;
    queryDefaults = null;
    updateDefaults = null;
    developmentMode = true;
    auditLog = false;
  };
  
  let mockInspectMo = InspectMo.InspectMo(
    null,
    Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai"),
    Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"),
    ?config,
    null,
    func(state: InspectMo.State) {}
  );
  let inspector = mockInspectMo.createInspector<Args>();
  
  // Register method with runtime blob validation
  let blobGuardInfo = inspector.createMethodGuardInfo<Blob>(
    "blob_guard_method",
    false,
    [
      InspectMo.blobSize<Args, Blob>(
        func(blob: Blob): Blob { blob },
        ?1, ?20 // Min 1, max 20 bytes
      )
    ],
    func(args: Args): Blob {
      switch (args) {
        case (#blob_guard_method(fn)) fn();
        case (_) Text.encodeUtf8("default");
      }
    }
  );
  inspector.guard(blobGuardInfo);
  
  let caller = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
  let validBlob = Text.encodeUtf8("small");
  let largeBlob = Text.encodeUtf8("this blob is too large for the limit");
  
  // Test with valid blob
  let validArgs : InspectMo.InspectArgs<Args> = {
    caller = caller;
    arg = Text.encodeUtf8("test");
    methodName = "blob_guard_method";
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #blob_guard_method(func() { validBlob });
  };
  let validResult = inspector.guardCheck(validArgs);
  switch (validResult) {
    case (#ok) { Debug.print("✓ Valid blob accepted") };
    case (#err(msg)) { assert false };
  };
  
  // Test with oversized blob
  let invalidArgs : InspectMo.InspectArgs<Args> = {
    caller = caller;
    arg = Text.encodeUtf8("test");
    methodName = "blob_guard_method";
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #blob_guard_method(func() { largeBlob });
  };
  let invalidResult = inspector.guardCheck(invalidArgs);
  switch (invalidResult) {
    case (#ok) { assert false };
    case (#err(msg)) { Debug.print("✓ Oversized blob rejected: " # msg) };
  };
});

/// Test 4: Custom Validation Logic
await test("runtime validation - customCheck", func() : async () {
  Debug.print("Testing customCheck validation with ErasedValidator...");
  
  let config : InspectMo.InitArgs = {
    allowAnonymous = ?true;
    defaultMaxArgSize = ?1024;
    authProvider = null;
    rateLimit = null;
    queryDefaults = null;
    updateDefaults = null;
    developmentMode = true;
    auditLog = false;
  };
  
  let mockInspectMo = InspectMo.InspectMo(
    null,
    Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai"),
    Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"),
    ?config,
    null,
    func(state: InspectMo.State) {}
  );
  let inspector = mockInspectMo.createInspector<Args>();
  
  // Register method with custom validation
  let customInfo = inspector.createMethodGuardInfo<Text>(
    "custom_method",
    false,
    [
      InspectMo.customCheck<Args, Text>(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (args.args) {
          case (#custom_method(fn)) {
            let text = fn();
            // Custom rule: must start with "valid_" and be at least 7 characters
            if (Text.size(text) >= 7 and Text.startsWith(text, #text("valid_"))) {
              #ok
            } else {
              #err("Text must start with 'valid_' and be at least 7 characters")
            }
          };
          case (_) #err("Invalid message variant");
        }
      })
    ],
    func(args: Args): Text {
      switch (args) {
        case (#custom_method(fn)) fn();
        case (_) "default";
      }
    }
  );
  inspector.guard(customInfo);
  
  let caller = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
  
  // Test with valid input
  let validArgs : InspectMo.InspectArgs<Args> = {
    caller = caller;
    arg = Text.encodeUtf8("test");
    methodName = "custom_method";
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #custom_method(func() { "valid_input" });
  };
  let validResult = inspector.guardCheck(validArgs);
  switch (validResult) {
    case (#ok) { Debug.print("✓ Valid custom input accepted") };
    case (#err(msg)) { assert false };
  };
  
  // Test with invalid prefix
  let invalidPrefixArgs : InspectMo.InspectArgs<Args> = {
    caller = caller;
    arg = Text.encodeUtf8("test");
    methodName = "custom_method";
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #custom_method(func() { "invalid_input" });
  };
  let invalidPrefixResult = inspector.guardCheck(invalidPrefixArgs);
  switch (invalidPrefixResult) {
    case (#ok) { assert false };
    case (#err(msg)) { Debug.print("✓ Invalid prefix rejected: " # msg) };
  };
  
  // Test with too short text
  let shortArgs : InspectMo.InspectArgs<Args> = {
    caller = caller;
    arg = Text.encodeUtf8("test");
    methodName = "custom_method";
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #custom_method(func() { "valid" });
  };
  let shortResult = inspector.guardCheck(shortArgs);
  switch (shortResult) {
    case (#ok) { assert false };
    case (#err(msg)) { Debug.print("✓ Short text rejected: " # msg) };
  };
});

/// Test 5: Dynamic Authentication
await test("runtime validation - dynamicAuth", func() : async () {
  Debug.print("Testing dynamicAuth validation with ErasedValidator...");
  
  let config : InspectMo.InitArgs = {
    allowAnonymous = ?true;
    defaultMaxArgSize = ?1024;
    authProvider = null;
    rateLimit = null;
    queryDefaults = null;
    updateDefaults = null;
    developmentMode = true;
    auditLog = false;
  };
  
  let mockInspectMo = InspectMo.InspectMo(
    null,
    Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai"),
    Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"),
    ?config,
    null,
    func(state: InspectMo.State) {}
  );
  let inspector = mockInspectMo.createInspector<Args>();
  
  // Register method with dynamic auth
  let dynamicAuthInfo = inspector.createMethodGuardInfo<Text>(
    "dynamic_auth_method",
    false,
    [
      InspectMo.dynamicAuth<Args, Text>(func(args: InspectMo.DynamicAuthArgs<Args>): InspectMo.GuardResult {
        switch (args.args) {
          case (#dynamic_auth_method(fn)) {
            let text = fn();
            
            // Custom auth rule: only specific principals can access certain operations
            switch (args.caller) {
              case (?caller) {
                if (Text.startsWith(text, #text("admin_")) and 
                    Principal.toText(caller) != "rdmx6-jaaaa-aaaaa-aaadq-cai") {
                  #err("Admin operations require admin principal")
                } else {
                  #ok
                }
              };
              case null {
                #err("No caller provided")
              };
            }
          };
          case (_) #err("Invalid message variant");
        }
      })
    ],
    func(args: Args): Text {
      switch (args) {
        case (#dynamic_auth_method(fn)) fn();
        case (_) "default";
      }
    }
  );
  inspector.guard(dynamicAuthInfo);
  
  let adminCaller = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
  let userCaller = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");
  
  // Test admin operation with admin caller
  let adminValidArgs : InspectMo.InspectArgs<Args> = {
    caller = adminCaller;
    arg = Text.encodeUtf8("test");
    methodName = "dynamic_auth_method";
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #dynamic_auth_method(func() { "admin_operation" });
  };
  let adminValidResult = inspector.guardCheck(adminValidArgs);
  switch (adminValidResult) {
    case (#ok) { Debug.print("✓ Admin operation by admin caller accepted") };
    case (#err(msg)) { assert false };
  };
  
  // Test admin operation with non-admin caller
  let adminInvalidArgs : InspectMo.InspectArgs<Args> = {
    caller = userCaller;
    arg = Text.encodeUtf8("test");
    methodName = "dynamic_auth_method";
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #dynamic_auth_method(func() { "admin_operation" });
  };
  let adminInvalidResult = inspector.guardCheck(adminInvalidArgs);
  switch (adminInvalidResult) {
    case (#ok) { assert false };
    case (#err(msg)) { Debug.print("✓ Admin operation by non-admin rejected: " # msg) };
  };
  
  // Test regular operation with any caller
  let userValidArgs : InspectMo.InspectArgs<Args> = {
    caller = userCaller;
    arg = Text.encodeUtf8("test");
    methodName = "dynamic_auth_method";
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #dynamic_auth_method(func() { "user_operation" });
  };
  let userValidResult = inspector.guardCheck(userValidArgs);
  switch (userValidResult) {
    case (#ok) { Debug.print("✓ User operation accepted") };
    case (#err(msg)) { assert false };
  };
});

/// Test 6: Multiple Validation Rules
await test("combined validation - multiple rules", func() : async () {
  Debug.print("Testing combined validation rules with ErasedValidator...");
  
  let config : InspectMo.InitArgs = {
    allowAnonymous = ?false; // Require auth
    defaultMaxArgSize = ?1024;
    authProvider = null;
    rateLimit = null;
    queryDefaults = null;
    updateDefaults = null;
    developmentMode = true;
    auditLog = false;
  };
  
  let mockInspectMo = InspectMo.InspectMo(
    null,
    Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai"),
    Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"),
    ?config,
    null,
    func(state: InspectMo.State) {}
  );
  let inspector = mockInspectMo.createInspector<Args>();
  
  // Register method with multiple validation layers
  let secureInfo = inspector.createMethodGuardInfo<Text>(
    "secure_method",
    false,
    [
      InspectMo.requireAuth<Args, Text>(),
      InspectMo.textSize<Args, Text>(
        func(text: Text): Text { text },
        ?5, ?20 // 5-20 chars
      ),
      InspectMo.customCheck<Args, Text>(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (args.args) {
          case (#secure_method(fn)) {
            let text = fn();
            // Must not contain profanity
            if (Text.contains(text, #text("badword"))) {
              #err("Inappropriate content detected")
            } else {
              #ok
            }
          };
          case (_) #err("Invalid message variant");
        }
      })
    ],
    func(args: Args): Text {
      switch (args) {
        case (#secure_method(fn)) fn();
        case (_) "default";
      }
    }
  );
  inspector.guard(secureInfo);
  
  let caller = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
  
  // Test with valid input passing all checks
  let validArgs : InspectMo.InspectArgs<Args> = {
    caller = caller;
    arg = Text.encodeUtf8("test");
    methodName = "secure_method";
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #secure_method(func() { "good_content" });
  };
  let validResult = inspector.guardCheck(validArgs);
  switch (validResult) {
    case (#ok) { Debug.print("✓ Valid content passed all checks") };
    case (#err(msg)) { assert false };
  };
  
  // Test with inappropriate content
  let profanityArgs : InspectMo.InspectArgs<Args> = {
    caller = caller;
    arg = Text.encodeUtf8("test");
    methodName = "secure_method";
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #secure_method(func() { "has_badword" });
  };
  let profanityResult = inspector.guardCheck(profanityArgs);
  switch (profanityResult) {
    case (#ok) { assert false };
    case (#err(msg)) { Debug.print("✓ Inappropriate content rejected: " # msg) };
  };
  
  // Test with text too short
  let shortArgs : InspectMo.InspectArgs<Args> = {
    caller = caller;
    arg = Text.encodeUtf8("test");
    methodName = "secure_method";
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #secure_method(func() { "hi" });
  };
  let shortResult = inspector.guardCheck(shortArgs);
  switch (shortResult) {
    case (#ok) { assert false };
    case (#err(msg)) { Debug.print("✓ Short text rejected: " # msg) };
  };
});

Debug.print("🚀 ALL ASYNC VALIDATION TESTS WITH ERASEDVALIDATOR COMPLETED! 🚀");