
import {test} "mo:test/async";
import InspectMo "../src/core/inspector";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import Debug "mo:core/Debug";
import Array "mo:core/Array";
import Nat "mo:core/Nat";

/// Error handling and edge cases test suite with ErasedValidator pattern
/// Tests error propagation, edge cases, and system robustness

// Global Args union type for all test scenarios
type ValidationArgs = {
  content: Text;
};

type BoundaryArgs = {
  text: Text;
};

type RecoveryArgs = {
  content: Text;
};

type Args = {
  #validation: ValidationArgs;
  #boundary: BoundaryArgs;
  #recovery: RecoveryArgs;
};

let testPrincipal = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
let adminPrincipal = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");

let defaultConfig : InspectMo.InitArgs = {
  allowAnonymous = ?true;
  defaultMaxArgSize = ?1024;
  authProvider = null;
  rateLimit = null;
  queryDefaults = null;
  updateDefaults = null;
  developmentMode = false;
  auditLog = true;
};

func createTestInspector() : InspectMo.InspectMo {
  InspectMo.InspectMo(
    null, adminPrincipal, testPrincipal, ?defaultConfig, null,
    func(state: InspectMo.State) {}
  )
};

// Helper functions to create default args
let defaultValidationArgs : ValidationArgs = { content = "default" };
let defaultBoundaryArgs : BoundaryArgs = { text = "default" };
let defaultRecoveryArgs : RecoveryArgs = { content = "default" };

/// ========================================
/// ERROR PROPAGATION TESTS  
/// ========================================

await test("error message propagation and formatting", func() : async () {
  Debug.print("Testing error message propagation...");
  
  let inspector = createTestInspector();
  let errorInspector = inspector.createInspector<Args>();
  
  // Test detailed error messages with custom validation
  errorInspector.inspect(errorInspector.createMethodGuardInfo<ValidationArgs>(
    "detailedError",
    false,
    [
      #customCheck(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (args.args) {
          case (#validation(validationArgs)) {
            let content = validationArgs.content;
            if (Text.size(content) == 0) {
              #err("VALIDATION_ERROR: Content cannot be empty")
            } else if (Text.size(content) > 100) {
              #err("SIZE_ERROR: Content exceeds maximum length")
            } else if (Text.contains(content, #text "<script")) {
              #err("SECURITY_ERROR: Script tags not allowed")
            } else {
              #ok
            }
          };
          case (_) #err("Invalid argument type");
        };
      })
    ],
    func(args: Args) : ValidationArgs {
      switch (args) {
        case (#validation(validationArgs)) validationArgs;
        case (_) defaultValidationArgs;
      };
    }
  ));
  
  // Test empty content error
  let emptyArgs : InspectMo.InspectArgs<Args> = {
    methodName = "detailedError";
    caller = testPrincipal;
    arg = Text.encodeUtf8("empty test");
    msg = #validation({ content = "" });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (errorInspector.inspectCheck(emptyArgs)) {
    case (#err(msg)) {
      assert(Text.contains(msg, #text "VALIDATION_ERROR"));
      Debug.print("✓ Empty content error: " # msg);
    };
    case (#ok) { assert false; };
  };
  
  // Test security error
  let scriptArgs : InspectMo.InspectArgs<Args> = {
    methodName = "detailedError";
    caller = testPrincipal;
    arg = Text.encodeUtf8("script test");
    msg = #validation({ content = "Hello <script>alert('xss')</script>" });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (errorInspector.inspectCheck(scriptArgs)) {
    case (#err(msg)) {
      assert(Text.contains(msg, #text "SECURITY_ERROR"));
      Debug.print("✓ Security error: " # msg);
    };
    case (#ok) { assert false; };
  };
  
  // Test valid content passes
  let validArgs : InspectMo.InspectArgs<Args> = {
    methodName = "detailedError";
    caller = testPrincipal;
    arg = Text.encodeUtf8("valid test");
    msg = #validation({ content = "This is valid content" });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (errorInspector.inspectCheck(validArgs)) {
    case (#ok) Debug.print("✓ Valid content passed");
    case (#err(msg)) {
      Debug.print("❌ Valid content should have passed: " # msg);
      assert false;
    };
  };
  
  Debug.print("✓ Error message propagation tests passed");
});

await test("boundary value edge cases", func() : async () {
  Debug.print("Testing boundary value edge cases...");
  
  let inspector = createTestInspector();
  let boundaryInspector = inspector.createInspector<Args>();
  
  // Test exact boundary conditions (5-10 characters)
  boundaryInspector.inspect(boundaryInspector.createMethodGuardInfo<BoundaryArgs>(
    "boundaryTest",
    false,
    [
      #textSize(func(args: BoundaryArgs) : Text { args.text }, ?5, ?10)
    ],
    func(args: Args) : BoundaryArgs {
      switch (args) {
        case (#boundary(boundaryArgs)) boundaryArgs;
        case (_) defaultBoundaryArgs;
      };
    }
  ));
  
  // Test minimum boundary (exactly 5 characters) - should pass
  let minArgs : InspectMo.InspectArgs<Args> = {
    methodName = "boundaryTest";
    caller = testPrincipal;
    arg = Text.encodeUtf8("min test");
    msg = #boundary({ text = "12345" });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (boundaryInspector.inspectCheck(minArgs)) {
    case (#ok) Debug.print("✓ Minimum boundary (5 chars) passed");
    case (#err(msg)) {
      Debug.print("❌ Minimum boundary should have passed: " # msg);
      assert false;
    };
  };
  
  // Test below minimum (4 characters) - should fail
  let belowArgs : InspectMo.InspectArgs<Args> = {
    methodName = "boundaryTest";
    caller = testPrincipal;
    arg = Text.encodeUtf8("below test");
    msg = #boundary({ text = "1234" });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (boundaryInspector.inspectCheck(belowArgs)) {
    case (#err(_)) Debug.print("✓ Below minimum rejected");
    case (#ok) {
      Debug.print("❌ Below minimum should have been rejected");
      assert false;
    };
  };
  
  // Test maximum boundary (exactly 10 characters) - should pass
  let maxArgs : InspectMo.InspectArgs<Args> = {
    methodName = "boundaryTest";
    caller = testPrincipal;
    arg = Text.encodeUtf8("max test");
    msg = #boundary({ text = "1234567890" });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (boundaryInspector.inspectCheck(maxArgs)) {
    case (#ok) Debug.print("✓ Maximum boundary (10 chars) passed");
    case (#err(msg)) {
      Debug.print("❌ Maximum boundary should have passed: " # msg);
      assert false;
    };
  };
  
  // Test above maximum (11 characters) - should fail
  let aboveArgs : InspectMo.InspectArgs<Args> = {
    methodName = "boundaryTest";
    caller = testPrincipal;
    arg = Text.encodeUtf8("above test");
    msg = #boundary({ text = "12345678901" });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (boundaryInspector.inspectCheck(aboveArgs)) {
    case (#err(_)) Debug.print("✓ Above maximum rejected");
    case (#ok) {
      Debug.print("❌ Above maximum should have been rejected");
      assert false;
    };
  };
  
  Debug.print("✓ Boundary value edge cases tests passed");
});

await test("error recovery and fallback mechanisms", func() : async () {
  Debug.print("Testing error recovery and fallback...");
  
  let inspector = createTestInspector();
  let recoveryInspector = inspector.createInspector<Args>();
  
  // Create validation with fallback logic
  recoveryInspector.inspect(recoveryInspector.createMethodGuardInfo<RecoveryArgs>(
    "recoveryTest",
    false,
    [
      #customCheck(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (args.args) {
          case (#recovery(recoveryArgs)) {
            let content = recoveryArgs.content;
            
            // Primary validation
            if (Text.contains(content, #text "primary")) {
              #ok
            } else if (Text.contains(content, #text "fallback") and Text.size(content) <= 50) {
              // Fallback validation with different criteria
              #ok  
            } else if (Text.contains(content, #text "emergency") and args.caller == adminPrincipal) {
              // Emergency access for admin
              #ok
            } else {
              #err("VALIDATION_FAILED: Content must contain 'primary', 'fallback' (≤50 chars), or 'emergency' (admin only)")
            }
          };
          case (_) #err("Invalid argument type");
        };
      })
    ],
    func(args: Args) : RecoveryArgs {
      switch (args) {
        case (#recovery(recoveryArgs)) recoveryArgs;
        case (_) defaultRecoveryArgs;
      };
    }
  ));
  
  // Test primary validation
  let primaryArgs : InspectMo.InspectArgs<Args> = {
    methodName = "recoveryTest";
    caller = testPrincipal;
    arg = Text.encodeUtf8("primary test");
    msg = #recovery({ content = "primary content" });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (recoveryInspector.inspectCheck(primaryArgs)) {
    case (#ok) Debug.print("✓ Primary validation passed");
    case (#err(msg)) {
      Debug.print("❌ Primary validation should have passed: " # msg);
      assert false;
    };
  };
  
  // Test fallback validation
  let fallbackArgs : InspectMo.InspectArgs<Args> = {
    methodName = "recoveryTest";
    caller = testPrincipal;
    arg = Text.encodeUtf8("fallback test");
    msg = #recovery({ content = "fallback content" });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (recoveryInspector.inspectCheck(fallbackArgs)) {
    case (#ok) Debug.print("✓ Fallback validation passed");
    case (#err(msg)) {
      Debug.print("❌ Fallback validation should have passed: " # msg);
      assert false;
    };
  };
  
  // Test emergency access for admin
  let emergencyArgs : InspectMo.InspectArgs<Args> = {
    methodName = "recoveryTest";
    caller = adminPrincipal;
    arg = Text.encodeUtf8("emergency test");
    msg = #recovery({ content = "emergency access" });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (recoveryInspector.inspectCheck(emergencyArgs)) {
    case (#ok) Debug.print("✓ Emergency access granted for admin");
    case (#err(msg)) {
      Debug.print("❌ Emergency access should have been granted: " # msg);
      assert false;
    };
  };
  
  // Test emergency access denied for non-admin
  let emergencyDeniedArgs : InspectMo.InspectArgs<Args> = {
    methodName = "recoveryTest";
    caller = testPrincipal;
    arg = Text.encodeUtf8("emergency denied test");
    msg = #recovery({ content = "emergency access" });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (recoveryInspector.inspectCheck(emergencyDeniedArgs)) {
    case (#err(_)) Debug.print("✓ Emergency access denied for non-admin");
    case (#ok) {
      Debug.print("❌ Emergency access should have been denied for non-admin");
      assert false;
    };
  };
  
  Debug.print("✓ Error recovery and fallback tests passed");
});

Debug.print("🛡️ ERROR HANDLING AND EDGE CASES TESTS COMPLETED! 🛡️");
