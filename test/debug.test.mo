import {test} "mo:test/async";
import Debug "mo:core/Debug";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import InspectMo "../src/core/inspector";

/// Debug testing with ErasedValidator pattern - demonstrates debug output and error reporting

await test("debug test", func() : async () {
  Debug.print("=== DEBUG TEST START ===");
  Debug.print("This is a debug message");
  Debug.print("Testing 1, 2, 3...");
  Debug.print("=== DEBUG TEST END ===");
});

await test("ErasedValidator debug validation", func() : async () {
  Debug.print("=== ErasedValidator Debug Validation ===");
  
  // ErasedValidator setup with Args union pattern for debugging
  type DebugMessageArgs = {
    message: Text;
    level: Nat; // 0=info, 1=warn, 2=error
    timestamp: ?Nat;
  };
  
  type Args = {
    #debugMessage: DebugMessageArgs;
  };
  
  // Create inspector with debug mode enabled
  let inspectConfig : InspectMo.InitArgs = {
    allowAnonymous = ?true; // Allow anonymous for debug testing
    defaultMaxArgSize = ?2048;
    authProvider = null;
    rateLimit = null;
    queryDefaults = null;
    updateDefaults = null;
    developmentMode = true; // Enable debug mode
    auditLog = true; // Enable audit logging
  };
  
  // Create mock InspectMo instance for testing
  let mockInspectMo = InspectMo.InspectMo(
    null, // stored state
    Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"), // instantiator
    Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"), // canister
    ?inspectConfig, // args
    null, // environment
    func(state: InspectMo.State) {} // storageChanged callback
  );
  
  let inspector = mockInspectMo.createInspector<Args>();
  
  // Register debug method with validation rules
  inspector.inspect(inspector.createMethodGuardInfo<DebugMessageArgs>(
    "debugMessage",
    false,
    [
      #textSize(func(args: DebugMessageArgs) : Text { args.message }, ?1, ?200), // Message size validation
      #natValue(func(args: DebugMessageArgs) : Nat { args.level }, ?0, ?2) // Level validation (0-2)
    ],
    func(args: Args) : DebugMessageArgs {
      switch (args) {
        case (#debugMessage(debugArgs)) debugArgs;
        case (_) {
          Debug.print("❌ Wrong args type for debug method");
          { message = "default"; level = 0; timestamp = null }
        };
      };
    }
  ));
  
  let testPrincipal = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
  
  // Test 1: Valid info message
  Debug.print("📝 Test 1: Valid info message");
  let infoArgs : InspectMo.InspectArgs<Args> = {
    methodName = "debugMessage";
    caller = testPrincipal;
    arg = Text.encodeUtf8("info debug data");
    msg = #debugMessage({
      message = "System startup complete";
      level = 0; // info
      timestamp = ?1234567890;
    });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (inspector.inspectCheck(infoArgs)) {
    case (#ok) Debug.print("✓ Info message validation passed");
    case (#err(msg)) {
      Debug.print("❌ Info message validation failed: " # msg);
      assert false;
    };
  };
  
  // Test 2: Message too long (should fail size check)
  Debug.print("📝 Test 2: Message too long (should fail size validation)");
  let longMessage = "This message is over 200 characters long and should be rejected by size validation. " # 
                   "We need to make sure this string exceeds the 200 character limit that we have set for debug messages. " #
                   "Adding more text to ensure we exceed the limit and trigger the validation error as expected.";
  
  let longArgs : InspectMo.InspectArgs<Args> = {
    methodName = "debugMessage";
    caller = testPrincipal;
    arg = Text.encodeUtf8("long debug data");
    msg = #debugMessage({
      message = longMessage;
      level = 1; // warn
      timestamp = ?1234567890;
    });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (inspector.inspectCheck(longArgs)) {
    case (#ok) {
      Debug.print("❌ Long message should have failed validation");
      assert false;
    };
    case (#err(msg)) Debug.print("✓ Long message correctly rejected: " # msg);
  };
  
  // Test 3: Invalid level (should fail level validation)
  Debug.print("📝 Test 3: Invalid level (should fail level validation)");
  let invalidLevelArgs : InspectMo.InspectArgs<Args> = {
    methodName = "debugMessage";
    caller = testPrincipal;
    arg = Text.encodeUtf8("invalid level data");
    msg = #debugMessage({
      message = "Invalid level test";
      level = 5; // invalid level (should be 0-2)
      timestamp = ?1234567890;
    });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (inspector.inspectCheck(invalidLevelArgs)) {
    case (#ok) {
      Debug.print("❌ Invalid level should have failed validation");
      assert false;
    };
    case (#err(msg)) Debug.print("✓ Invalid level correctly rejected: " # msg);
  };
  
  Debug.print("✓ ErasedValidator debug validation completed successfully");
  Debug.print("=== ErasedValidator Debug Test End ===");
});
