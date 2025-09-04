import {test} "mo:test/async";
import Debug "mo:core/Debug";
import InspectMo "../src/lib";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import Blob "mo:core/Blob";
import Runtime "mo:core/Runtime";
import ClassPlusLib "mo:class-plus";
import TT "mo:timer-tool";

/// Test actual validation functionality using ErasedValidator pattern

persistent actor {

type Args = {
  #protected_method: () -> Text;
  #guarded_method: () -> Text; 
  #custom_method: () -> Text;
};

  // Timer tool setup following main.mo pattern
  transient let initManager = ClassPlusLib.ClassPlusInitializationManager(
    Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"), 
    Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"), 
    false
  );
  stable var tt_migration_state: TT.State = TT.Migration.migration.initialState;

  transient let tt = TT.Init<system>({
    manager = initManager;
    initialState = tt_migration_state;
    args = null;
    pullEnvironment = ?(func() : TT.Environment {
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
    onInitialize = ?(func (newClass: TT.TimerTool) : async* () {
      newClass.initialize<system>();
    });
    onStorageChange = func(state: TT.State) {
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

  // Create test inspector variants for different configs
  private func createTestInspector() : InspectMo.InspectMo {
    // For tests, we can just return the main inspector since it has proper environment
    inspector()
  };

public func runTests() : async () {
await test("boundary validation tests", func() : async () {
  Debug.print("Testing boundary validation...");
  
  let mockInspectMo = createTestInspector();
  let boundaryInspector = mockInspectMo.createInspector<Args>();
  
  // Register a method with auth requirement using ErasedValidator pattern
  let protectedMethodInfo = boundaryInspector.createMethodGuardInfo<Text>(
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
  
  boundaryInspector.inspect(protectedMethodInfo);
  
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
  
  let anonResult = boundaryInspector.inspectCheck(anonArgs);
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
  
  let authResult = boundaryInspector.inspectCheck(authArgs);
  switch (authResult) {
    case (#ok) Debug.print("✓ Authenticated caller correctly accepted");
    case (#err(msg)) Runtime.trap("Expected success but got: " # msg);
  };
  
  Debug.print("✓ Boundary validation tests passed");
});

await test("runtime validation tests", func() : async () {
  Debug.print("Testing runtime validation...");
  
  let mockInspectMo = createTestInspector();
  let runtimeInspector = mockInspectMo.createInspector<Args>();
  
  // Register a method with runtime validation using ErasedValidator pattern
  let guardedMethodInfo = runtimeInspector.createMethodGuardInfo<Text>(
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
  runtimeInspector.guard(guardedMethodInfo);
  
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
  
  let validResult = runtimeInspector.guardCheck(validArgs);
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
  
  let invalidResult = runtimeInspector.guardCheck(invalidArgs);
  switch (invalidResult) {
    case (#ok) Runtime.trap("Expected failure but got success");
    case (#err(msg)) Debug.print("✓ Invalid text correctly rejected: " # msg);
  };
  
  // Test custom check using ErasedValidator pattern
  let customMethodInfo = runtimeInspector.createMethodGuardInfo<Text>(
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
  runtimeInspector.guard(customMethodInfo);
  
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
  
  let customValidResult = runtimeInspector.guardCheck(customValidArgs);
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
  
  let customInvalidResult = runtimeInspector.guardCheck(customInvalidArgs);
  switch (customInvalidResult) {
    case (#ok) Runtime.trap("Expected failure but got success");
    case (#err(msg)) Debug.print("✓ Custom check with invalid input failed: " # msg);
  };
  
  Debug.print("✓ Runtime validation tests passed");
});

  Debug.print("🧪 STANDARD VALIDATION TESTS COMPLETED! 🧪");
};

}