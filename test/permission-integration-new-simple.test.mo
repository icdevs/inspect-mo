import Debug "mo:core/Debug";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import TT "mo:timer-tool";
import ClassPlusLib "mo:class-plus";
import InspectMo "../src/core/inspector";

persistent actor PermissionIntegrationNewTest {

/// Test permission validation rules with standard inspector pattern

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

// Define Args union type for testing
type TestMethodArgs = {
  content: Text;
};

type Args = {
  #test_method: TestMethodArgs;
};

public func runTests() : async () {
  await testBasicInspection();
  Debug.print("🔐 PERMISSION INTEGRATION TESTS COMPLETED! 🔐");
};

private func testBasicInspection() : async () {
  Debug.print("Testing basic inspection functionality...");
  
  // Create an inspector instance
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
  
  // Test simple method validation like main.test.mo
  inspectorInstance.inspect(inspectorInstance.createMethodGuardInfo<TestMethodArgs>(
    "test_method",
    false,
    [
      InspectMo.textSize<Args, TestMethodArgs>(
        func(data: TestMethodArgs): Text { data.content },
        ?1, ?100
      )
    ],
    func(args: Args): TestMethodArgs {
      switch (args) {
        case (#test_method(data)) data;
      }
    }
  ));
  
  // Test validation
  let validArgs : InspectMo.InspectArgs<Args> = {
    arg = Principal.toBlob(Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"));
    caller = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
    cycles = ?0;
    deadline = null;
    isInspect = true;
    isQuery = false;
    methodName = "test_method";
    msg = #test_method({content = "Valid content"});
  };
  switch (inspectorInstance.inspectCheck(validArgs)) {
    case (#ok) Debug.print("✓ Basic inspection test passed");
    case (#err(msg)) Debug.print("❌ Basic inspection test failed: " # msg);
  };
};

// Public function to call for starting tests
public func test() : async () {
  await runTests();
};

};
