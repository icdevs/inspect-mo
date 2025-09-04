import Debug "mo:core/Debug";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import Blob "mo:core/Blob";
import Array "mo:core/Array";
import TT "mo:timer-tool";
import ClassPlusLib "mo:class-plus";
import InspectMo "../src/core/inspector";

persistent actor class AsyncValidationTest() {

/// Comprehensive async InspectMo validation functionality test suite

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

// Define Args union type for all async validation tests
type Args = {
  #protected_method: ();
  #text_guard_method: Text;
  #blob_guard_method: Blob;
  #custom_method: Text;
  #dynamic_auth_method: Text;
  #secure_method: Text;
};

public func runTests() : async () {
  await testAuthentication();
  await testValidationRules();
  Debug.print("🔐 ASYNC VALIDATION TESTS COMPLETED! 🔐");
};

private func testAuthentication() : async () {
  Debug.print("Testing requireAuth validation...");
  
  // Create an inspector instance for auth testing
  let inspectorInstance = inspector().Inspector<Args>({
    allowAnonymous = ?false;
    defaultMaxArgSize = ?1024;
    authProvider = null;
    rateLimit = null;
    queryDefaults = null;
    updateDefaults = null;
    developmentMode = true;
    auditLog = false;
  });
  
  // Test simple method validation with authentication
  inspectorInstance.inspect(inspectorInstance.createMethodGuardInfo<()>(
    "protected_method",
    false,
    [
      InspectMo.requireAuth<Args, ()>()
    ],
    func(args: Args): () {
      switch (args) {
        case (#protected_method(data)) data;
        case (_) ();
      }
    }
  ));
  
  // Test validation with a proper InspectArgs structure
  let validArgs : InspectMo.InspectArgs<Args> = {
    arg = Text.encodeUtf8("test");
    caller = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
    cycles = null;
    deadline = null;
    isInspect = true;
    isQuery = false;
    methodName = "protected_method";
    msg = #protected_method(());
  };
  
  switch (inspectorInstance.inspectCheck(validArgs)) {
    case (#ok) Debug.print("✓ Authentication test passed");
    case (#err(msg)) Debug.print("❌ Authentication test failed: " # msg);
  };
};

private func testValidationRules() : async () {
  Debug.print("Testing validation rules...");
  
  // Create an inspector instance for validation testing
  let inspectorInstance = inspector().Inspector<Args>({
    allowAnonymous = ?true;
    defaultMaxArgSize = ?1024;
    authProvider = null;
    rateLimit = null;
    queryDefaults = null;
    updateDefaults = null;
    developmentMode = true;
    auditLog = false;
  });
  
  // Test text size validation
  inspectorInstance.inspect(inspectorInstance.createMethodGuardInfo<Text>(
    "text_guard_method",
    false,
    [
      InspectMo.textSize<Args, Text>(
        func(data: Text): Text { data },
        ?1, ?100
      )
    ],
    func(args: Args): Text {
      switch (args) {
        case (#text_guard_method(data)) data;
        case (_) "default";
      }
    }
  ));
  
  // Test validation
  let validArgs : InspectMo.InspectArgs<Args> = {
    arg = Text.encodeUtf8("test");
    caller = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
    cycles = null;
    deadline = null;
    isInspect = true;
    isQuery = false;
    methodName = "text_guard_method";
    msg = #text_guard_method("Valid text");
  };
  
  switch (inspectorInstance.inspectCheck(validArgs)) {
    case (#ok) Debug.print("✓ Validation rules test passed");
    case (#err(msg)) Debug.print("❌ Validation rules test failed: " # msg);
  };
};

// Public function to call for starting tests
public func test() : async () {
  await runTests();
};

};
