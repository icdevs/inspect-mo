import {test} "mo:test/async";
import Debug "mo:core/Debug";
import InspectMo "../src/core/inspector";
import Principal "mo:core/Principal";
import Text "mo:core/Text";

/// Manual validation test demonstrating ErasedValidator pattern using test framework
/// Shows comprehensive usage with proper Args union types

// Global Args union type for manual validation testing
type MessageArgs = {
  content: Text;
  priority: Nat;
};

type ValidationArgs = {
  text: Text;
};

type Args = {
  #message: MessageArgs;
  #validation: ValidationArgs;
};

let testPrincipal = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
let adminPrincipal = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");

// Helper functions for default args
let defaultMessageArgs : MessageArgs = { content = "default"; priority = 0 };
let defaultValidationArgs : ValidationArgs = { text = "default" };

func createTestInspector() : InspectMo.InspectMo {
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
  
  InspectMo.InspectMo(
    null, adminPrincipal, testPrincipal, ?config, null,
    func(state: InspectMo.State) {}
  )
};

await test("ErasedValidator validation demo", func() : async () {
    Debug.print("=== STARTING ERASEDVALIDATOR VALIDATION DEMO ===");
    
    let mockInspectMo = createTestInspector();
    let inspector = mockInspectMo.createInspector<Args>();
    
    Debug.print("✓ Inspector created successfully");
    
    // Register a protected method using ErasedValidator pattern
    inspector.inspect(inspector.createMethodGuardInfo<MessageArgs>(
      "send_message",
      false,
      [
        #requireAuth
      ],
      func(args: Args): MessageArgs {
        switch (args) {
          case (#message(messageArgs)) messageArgs;
          case (_) defaultMessageArgs;
        }
      }
    ));
    Debug.print("✓ Method 'send_message' registered with auth requirement");
    
    // Test 1: Anonymous caller (should be rejected)
    let anonArgs : InspectMo.InspectArgs<Args> = {
      methodName = "send_message";
      caller = Principal.fromText("2vxsx-fae"); // Anonymous principal
      arg = Text.encodeUtf8("hello");
      isQuery = false;
      cycles = null;
      deadline = null;
      isInspect = true;
      msg = #message({ content = "test message"; priority = 1 });
    };
    
    let anonResult = inspector.inspectCheck(anonArgs);
    Debug.print("Anonymous caller result: " # debug_show(anonResult));
    switch (anonResult) {
      case (#err(_)) Debug.print("✓ Anonymous caller correctly rejected");
      case (#ok) {
        Debug.print("✗ Anonymous caller should have been rejected");
        assert false;
      };
    };
    
    // Test 2: Authenticated caller (should be accepted)
    let authArgs : InspectMo.InspectArgs<Args> = {
      methodName = "send_message";
      caller = testPrincipal;
      arg = Text.encodeUtf8("hello");
      isQuery = false;
      cycles = null;
      deadline = null;
      isInspect = true;
      msg = #message({ content = "authenticated message"; priority = 2 });
    };
    
    let authResult = inspector.inspectCheck(authArgs);
    Debug.print("Authenticated caller result: " # debug_show(authResult));
    switch (authResult) {
      case (#ok) Debug.print("✓ Authenticated caller correctly accepted");
      case (#err(msg)) {
        Debug.print("✗ Unexpected error: " # msg);
        assert false;
      };
    };
    
    // Test 3: Runtime validation with ErasedValidator pattern
    inspector.guard(inspector.createMethodGuardInfo<ValidationArgs>(
      "validate_text",
      false,
      [
        #textSize(
          func(args: ValidationArgs): Text { args.text },
          ?1, ?10 // Min 1, max 10 characters
        )
      ],
      func(args: Args): ValidationArgs {
        switch (args) {
          case (#validation(validationArgs)) validationArgs;
          case (_) defaultValidationArgs;
        }
      }
    ));
    Debug.print("✓ Runtime validation rule registered");
    
    let caller = testPrincipal;
    
    // Test valid text
    let validTextArgs : InspectMo.InspectArgs<Args> = {
      methodName = "validate_text";
      caller = caller;
      arg = Text.encodeUtf8("hello");
      isQuery = false;
      cycles = null;
      deadline = null;
      isInspect = false;
      msg = #validation({ text = "hello" });
    };
    
    let validResult = inspector.guardCheck(validTextArgs);
    Debug.print("Valid text result: " # debug_show(validResult));
    switch (validResult) {
      case (#ok) Debug.print("✓ Valid text accepted");
      case (#err(msg)) {
        Debug.print("✗ Unexpected error: " # msg);
        assert false;
      };
    };
    
    // Test invalid text (too long)
    let invalidTextArgs : InspectMo.InspectArgs<Args> = {
      methodName = "validate_text";
      caller = caller;
      arg = Text.encodeUtf8("this text is way too long for validation");
      isQuery = false;
      cycles = null;
      deadline = null;
      isInspect = false;
      msg = #validation({ text = "this text is way too long for validation" });
    };
    
    let invalidResult = inspector.guardCheck(invalidTextArgs);
    Debug.print("Invalid text result: " # debug_show(invalidResult));
    switch (invalidResult) {
      case (#ok) {
        Debug.print("✗ Should have been rejected");
        assert false;
      };
      case (#err(msg)) Debug.print("✓ Invalid text correctly rejected: " # msg);
    };
    
    // Test 4: Complex validation with multiple rules
    inspector.guard(inspector.createMethodGuardInfo<MessageArgs>(
      "complex_message",
      false,
      [
        #requireAuth,
        #textSize(func(args: MessageArgs): Text { args.content }, ?5, ?50),
        #natValue(func(args: MessageArgs): Nat { args.priority }, ?1, ?10)
      ],
      func(args: Args): MessageArgs {
        switch (args) {
          case (#message(messageArgs)) messageArgs;
          case (_) defaultMessageArgs;
        }
      }
    ));
    Debug.print("✓ Complex validation rule registered");
    
    // Test complex validation - all pass
    let complexValidArgs : InspectMo.InspectArgs<Args> = {
      methodName = "complex_message";
      caller = testPrincipal; // Authenticated
      arg = Text.encodeUtf8("complex");
      isQuery = false;
      cycles = null;
      deadline = null;
      isInspect = false;
      msg = #message({ content = "valid complex message"; priority = 5 }); // Valid size and priority
    };
    
    let complexValidResult = inspector.guardCheck(complexValidArgs);
    switch (complexValidResult) {
      case (#ok) Debug.print("✓ Complex validation passed");
      case (#err(msg)) {
        Debug.print("✗ Complex validation should have passed: " # msg);
        assert false;
      };
    };
    
    // Test complex validation - priority too high
    let complexInvalidArgs : InspectMo.InspectArgs<Args> = {
      methodName = "complex_message";
      caller = testPrincipal; // Authenticated
      arg = Text.encodeUtf8("invalid priority");
      isQuery = false;
      cycles = null;
      deadline = null;
      isInspect = false;
      msg = #message({ content = "valid content"; priority = 15 }); // Invalid priority (> 10)
    };
    
    let complexInvalidResult = inspector.guardCheck(complexInvalidArgs);
    switch (complexInvalidResult) {
      case (#ok) {
        Debug.print("✗ Complex validation should have failed");
        assert false;
      };
      case (#err(msg)) Debug.print("✓ Complex validation correctly failed: " # msg);
    };
    
    Debug.print("=== ERASEDVALIDATOR VALIDATION DEMO COMPLETED ===");
    
    Debug.print("✓ All ErasedValidator validation tests completed successfully");
});

Debug.print("🎯 MANUAL VALIDATION DEMO TEST COMPLETED! 🎯");
