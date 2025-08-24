import {test} "mo:test/async";
import Debug "mo:core/Debug";
import InspectMo "../src/lib";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import Blob "mo:core/Blob";
import Runtime "mo:core/Runtime";

/// Test actual validation functionality using ErasedValidator pattern

type Args = {
  #protected_method: () -> Text;
  #guarded_method: () -> Text; 
  #custom_method: () -> Text;
};

await test("boundary validation tests", func() : async () {
  Debug.print("Testing boundary validation...");
  
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
  let protectedMethodInfo = inspector.createMethodGuardInfo<Text>(
    "protected_method",
    false,
    [
      InspectMo.requireAuth<Args, Text>()
    ],
    func(args: Args): Text {
      switch (args) {
        case (#protected_method(fn)) fn();
        case (_) "default";
      }
    }
  );
  inspector.inspect(protectedMethodInfo);
  
  // Test with anonymous caller (should fail)
  let anonArgs : InspectMo.InspectArgs<Args> = {
    methodName = "protected_method";
    caller = Principal.anonymous(); // Anonymous principal
    arg = Text.encodeUtf8("test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = true;
    msg = #protected_method(func() { "test" });
  };
  
  let anonResult = inspector.inspectCheck(anonArgs);
  switch (anonResult) {
    case (#ok) Runtime.trap("Expected anonymous rejection but got success");
    case (#err(msg)) Debug.print("✓ Anonymous caller correctly rejected: " # msg);
  };
  
  // Test with authenticated caller (should pass)
  let authArgs : InspectMo.InspectArgs<Args> = {
    methodName = "protected_method";
    caller = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
    arg = Text.encodeUtf8("test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = true;
    msg = #protected_method(func() { "test" });
  };
  
  let authResult = inspector.inspectCheck(authArgs);
  switch (authResult) {
    case (#ok) Debug.print("✓ Authenticated caller correctly accepted");
    case (#err(msg)) Runtime.trap("Expected success but got: " # msg);
  };
  
  Debug.print("✓ Boundary validation tests passed");
});

await test("runtime validation tests", func() : async () {
  Debug.print("Testing runtime validation...");
  
  let config : InspectMo.InitArgs = {
    allowAnonymous = ?true; // Allow for runtime testing
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
  
  // Register a method with runtime validation using ErasedValidator pattern
  let guardedMethodInfo = inspector.createMethodGuardInfo<Text>(
    "guarded_method",
    false,
    [
      InspectMo.textSize<Args, Text>(
        func(text: Text): Text { text }, // Accessor receives M (Text) and returns Text for validation
        ?1, ?10 // Min 1, max 10 characters
      )
    ],
    func(args: Args): Text {
      switch (args) {
        case (#guarded_method(fn)) fn();
        case (_) "default";
      }
    }
  );
  inspector.guard(guardedMethodInfo);
  
  let caller = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
  
  // Test with valid text (should pass)
  let validArgs : InspectMo.InspectArgs<Args> = {
    methodName = "guarded_method";
    caller = caller;
    arg = Text.encodeUtf8("hello");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #guarded_method(func() { "hello" });
  };
  
  let validResult = inspector.guardCheck(validArgs);
  switch (validResult) {
    case (#ok) Debug.print("✓ Valid text correctly accepted");
    case (#err(msg)) Runtime.trap("Expected success but got: " # msg);
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
    msg = #guarded_method(func() { "this text is way too long" });
  };
  
  let invalidResult = inspector.guardCheck(invalidArgs);
  switch (invalidResult) {
    case (#ok) Runtime.trap("Expected failure but got success");
    case (#err(msg)) Debug.print("✓ Invalid text correctly rejected: " # msg);
  };
  
  // Test custom check using ErasedValidator pattern
  let customMethodInfo = inspector.createMethodGuardInfo<Text>(
    "custom_method",
    false,
    [
      InspectMo.customCheck<Args, Text>(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (args.args) {
          case (#custom_method(fn)) {
            let text = fn();
            if (Text.size(text) > 0) { #ok } else { #err("Empty text not allowed") }
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
  inspector.guard(customMethodInfo);
  
  // Test custom check with valid input
  let customValidArgs : InspectMo.InspectArgs<Args> = {
    methodName = "custom_method";
    caller = caller;
    arg = Text.encodeUtf8("valid");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #custom_method(func() { "valid" });
  };
  
  let customValidResult = inspector.guardCheck(customValidArgs);
  switch (customValidResult) {
    case (#ok) Debug.print("✓ Custom check with valid input passed");
    case (#err(msg)) Runtime.trap("Expected success but got: " # msg);
  };
  
  // Test custom check with invalid input  
  let customInvalidArgs : InspectMo.InspectArgs<Args> = {
    methodName = "custom_method";
    caller = caller;
    arg = Text.encodeUtf8("");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #custom_method(func() { "" });
  };
  
  let customInvalidResult = inspector.guardCheck(customInvalidArgs);
  switch (customInvalidResult) {
    case (#ok) Runtime.trap("Expected failure but got success");
    case (#err(msg)) Debug.print("✓ Custom check with invalid input failed: " # msg);
  };
  
  Debug.print("✓ Runtime validation tests passed");
});
