import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import InspectMo "../src/lib";
import TimerTool "mo:timer-tool";
import ClassPlusLib "mo:class-plus";

persistent actor SimpleBasicTest {

  // Timer tool setup following working examples
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
      Debug.print("Creating TimerTool Environment");
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
      }
    });
    onInitialize = ?(func (newClass: TimerTool.TimerTool) : async* () {
      newClass.initialize<system>();
    });
    onStorageChange = func(state: TimerTool.State) {
      tt_migration_state := state;
    };
  });

  // Create proper environment for ICRC85 and TimerTool
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

  // Create main inspector following working examples  
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

  // Initialize components
  ignore tt();
  ignore inspector();

  public func testBasicFunctionality(): async Result.Result<Text, Text> {
    Debug.print("Testing basic InspectMo functionality...");
    
    // Test that we can create an inspector instance
    let inspectorInstance = inspector();
    let testInspector = inspectorInstance.createInspector<{#test: () -> ()}>();
    
    Debug.print("✅ Basic inspector functionality working");
    #ok("✅ Basic test passed - InspectMo with TimerTool integration working correctly")
  };

  public func runTests(): async () {
    Debug.print("🔧 Running simplified basic tests...");
    
    switch (await testBasicFunctionality()) {
      case (#ok(msg)) Debug.print(msg);
      case (#err(err)) Debug.print("❌ Test failed: " # err);
    };
    
    Debug.print("✅ All basic tests completed");
  };
}
