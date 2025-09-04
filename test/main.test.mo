import {test} "mo:test/async";
import InspectMo "../src/core/inspector";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import Debug "mo:core/Debug";
import TimerTool "mo:timer-tool";
import ClassPlusLib "mo:class-plus";

persistent actor MainTest {

/// Test main library functionality with ErasedValidator pattern

transient let testPrincipal = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
transient let adminPrincipal = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");

// Timer tool setup following main.mo pattern
transient let initManager = ClassPlusLib.ClassPlusInitializationManager(
  Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"), 
  Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"), 
  false
);
stable var tt_migration_state: TimerTool.State = TimerTool.Migration.migration.initialState;

transient let tt = TimerTool.Init<system>({
  manager = initManager;
  initialState = tt_migration_state;
  args = null;
  pullEnvironment = ?(func() : TimerTool.Environment {
    {      
      advanced = ?{
        icrc85 = ?{
          asset = null;
          collector = null;
          handler = null;
          kill_switch = null;
          period = ?3600;
          platform = null;
          tree = null;
        };
      };
      reportExecution = null;
      reportError = null;
      syncUnsafe = null;
      reportBatch = null;
    };
  });
  onInitialize = ?(func (newClass: TimerTool.TimerTool) : async* () {
    newClass.initialize<system>();
  });
  onStorageChange = func(state: TimerTool.State) {
    tt_migration_state := state;
  };
});

// Create proper environment for ICRC85 and TimerTool following main.mo pattern
func createEnvironment() : InspectMo.Environment {
  {
    tt = tt();
    advanced = ?{
      icrc85 = ?{
        asset = null;
        collector = null;
        handler = null;
        kill_switch = null;
        period = ?3600;
        platform = null;
        tree = null;
      };
    };
    log = null;
  };
};

// Create main inspector following main.mo pattern
stable var inspector_migration_state: InspectMo.State = InspectMo.initialState();

transient let inspector = InspectMo.Init<system>({
  manager = initManager;
  initialState = inspector_migration_state;
  args = ?{
    allowAnonymous = ?false;
    defaultMaxArgSize = ?1024;
    authProvider = null;
    rateLimit = null;
    queryDefaults = null;
    updateDefaults = null;
    developmentMode = true;
    auditLog = false;
  };
  pullEnvironment = ?(func() : InspectMo.Environment {
    createEnvironment()
  });
  onInitialize = null;
  onStorageChange = func(state: InspectMo.State) {
    inspector_migration_state := state;
  };
});

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

transient let defaultConfig : InspectMo.InitArgs = {
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
  // For tests, we can just return the main inspector since it has proper environment
  inspector();
};

// Default record values
transient let defaultTestMethodArgs : TestMethodArgs = { content = "default" };
transient let defaultValidationTestArgs : ValidationTestArgs = { text = "default" };

public func runTests() : async () {
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
      InspectMo.requireAuth<Args, TestMethodArgs>(),
      InspectMo.textSize<Args, TestMethodArgs>(func(args: TestMethodArgs): Text { args.content }, ?1, ?100),
      InspectMo.customCheck<Args, TestMethodArgs>(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
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
      InspectMo.requireAuth<Args, ValidationTestArgs>(),
      InspectMo.textSize<Args, ValidationTestArgs>(func(args: ValidationTestArgs): Text { args.text }, ?1, ?50),
      InspectMo.customCheck<Args, ValidationTestArgs>(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
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
      InspectMo.customCheck<Args, ValidationTestArgs>(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
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
};

}