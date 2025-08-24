import {test} "mo:test/async";
import InspectMo "../src/core/inspector";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import Debug "mo:core/Debug";

/// Test main library functionality with ErasedValidator pattern

let testPrincipal = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
let adminPrincipal = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");

// Define Args union type for testing library exports
type TestMethodArgs = {
  content: Text;
};

type ValidationTestArgs = {
  text: Text;
};

type Args = {
  #test_method: TestMethodArgs;
  #validation_test: ValidationTestArgs;
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

func createTestInspector() : InspectMo.InspectMo {
  InspectMo.InspectMo(
    null, adminPrincipal, testPrincipal, ?defaultConfig, null,
    func(state: InspectMo.State) {}
  )
};

// Default record values
let defaultTestMethodArgs : TestMethodArgs = { content = "default" };
let defaultValidationTestArgs : ValidationTestArgs = { text = "default" };

await test("library exports and basic functionality", func() : async () {
  Debug.print("Testing main library exports...");
  
  // Test InspectMo instance creation
  let mockInspectMo = createTestInspector();
  let inspector = mockInspectMo.createInspector<Args>();
  Debug.print("✓ InspectMo instance creation works");
  
  // Test method registration using ErasedValidator pattern
  inspector.inspect(inspector.createMethodGuardInfo<TestMethodArgs>(
    "test_method",
    false,
    [
      #requireAuth,
      #textSize(func(args: TestMethodArgs): Text { args.content }, ?1, ?100),
      #customCheck(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (args.args) {
          case (#test_method(testArgs)) {
            if (Text.size(testArgs.content) > 0) {
              #ok
            } else {
              #err("Content cannot be empty")
            }
          };
          case (_) #err("Invalid message variant");
        }
      })
    ],
    func(args: Args): TestMethodArgs {
      switch (args) {
        case (#test_method(testArgs)) testArgs;
        case (_) defaultTestMethodArgs;
      };
    }
  ));
  Debug.print("✓ Method registration with ErasedValidator pattern works");
  
  // Test validation execution
  let validArgs : InspectMo.InspectArgs<Args> = {
    methodName = "test_method";
    caller = testPrincipal;
    arg = Text.encodeUtf8("hello");
    isQuery = false;
    cycles = ?0;
    deadline = null;
    isInspect = true;
    msg = #test_method({ content = "hello" });
  };
  
  switch (inspector.inspectCheck(validArgs)) {
    case (#ok) Debug.print("✓ Validation execution works");
    case (#err(msg)) {
      Debug.print("❌ Validation should have passed: " # msg);
      assert false;
    };
  };
  
  Debug.print("✓ Main library exports test passed");
});

await test("advanced validation rule combinations", func() : async () {
  Debug.print("Testing advanced validation rule combinations...");
  
  let mockInspectMo = createTestInspector();
  let inspector = mockInspectMo.createInspector<Args>();
  
  // Test complex validation rule combination
  inspector.inspect(inspector.createMethodGuardInfo<ValidationTestArgs>(
    "validation_test",
    false,
    [
      #requireAuth,
      #textSize(func(args: ValidationTestArgs): Text { args.text }, ?1, ?50),
      #customCheck(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (args.args) {
          case (#validation_test(testArgs)) {
            let text = testArgs.text;
            if (Text.contains(text, #text "forbidden")) {
              #err("Forbidden content detected")
            } else {
              #ok
            }
          };
          case (_) #err("Invalid message variant");
        }
      }),
      #customCheck(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        // Dynamic auth check
        if (Principal.isAnonymous(args.caller)) {
          #err("Dynamic auth: Anonymous not allowed")
        } else {
          #ok
        }
      })
    ],
    func(args: Args): ValidationTestArgs {
      switch (args) {
        case (#validation_test(testArgs)) testArgs;
        case (_) defaultValidationTestArgs;
      };
    }
  ));
  
  // Test valid case
  let validArgs : InspectMo.InspectArgs<Args> = {
    methodName = "validation_test";
    caller = testPrincipal;
    arg = Text.encodeUtf8("hello world");
    isQuery = false;
    cycles = ?0;
    deadline = null;
    isInspect = true;
    msg = #validation_test({ text = "hello world" });
  };
  
  switch (inspector.inspectCheck(validArgs)) {
    case (#ok) Debug.print("✓ Complex validation passed");
    case (#err(msg)) {
      Debug.print("❌ Complex validation should have passed: " # msg);
      assert false;
    };
  };
  
  // Test forbidden content
  let forbiddenArgs : InspectMo.InspectArgs<Args> = {
    methodName = "validation_test";
    caller = testPrincipal;
    arg = Text.encodeUtf8("forbidden content");
    isQuery = false;
    cycles = ?0;
    deadline = null;
    isInspect = true;
    msg = #validation_test({ text = "forbidden content" });
  };
  
  switch (inspector.inspectCheck(forbiddenArgs)) {
    case (#err(msg)) {
      Debug.print("✓ Forbidden content correctly rejected: " # msg);
      assert(Text.contains(msg, #text "Forbidden content detected"));
    };
    case (#ok) {
      Debug.print("❌ Forbidden content should have been rejected");
      assert false;
    };
  };
  
  // Test anonymous caller
  let anonymousArgs : InspectMo.InspectArgs<Args> = {
    methodName = "validation_test";
    caller = Principal.anonymous();
    arg = Text.encodeUtf8("hello");
    isQuery = false;
    cycles = ?0;
    deadline = null;
    isInspect = true;
    msg = #validation_test({ text = "hello" });
  };
  
  switch (inspector.inspectCheck(anonymousArgs)) {
    case (#err(msg)) {
      Debug.print("✓ Anonymous caller correctly rejected: " # msg);
    };
    case (#ok) {
      Debug.print("❌ Anonymous caller should have been rejected");
      assert false;
    };
  };
  
  Debug.print("✓ Advanced validation rule combinations test passed");
});

Debug.print("📚 ALL MAIN LIBRARY TESTS COMPLETED! 📚");