import Debug "mo:core/Debug";
import Principal "mo:core/Principal";
import TT "mo:timer-tool";
import ClassPlusLib "mo:class-plus";
import InspectMo "../src/core/inspector";
import ICRC16Validator "../src/utils/icrc16_validator";
import CandyTypes "mo:candy/types";

persistent actor ICRC16MapTest {

/// Test ICRC16 Map validation functionality with full TimerTool setup

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

type CandyShared = CandyTypes.CandyShared;
  
  public func runTests() : async () {
    
    Debug.print("🚀 Starting ICRC16 Map validation functionality tests...");
    
    // Test validateMapRequiredKeys
    testValidateMapRequiredKeys();
    
    // Test validateMapAllowedKeys
    testValidateMapAllowedKeys();
    
    // Test validateMapEntryCount
    testValidateMapEntryCount();
    
    // Test getMapValue
    testGetMapValue();
    
    // Test inner accessor functions
    testMapInnerAccessors();
    
    Debug.print("✅ All ICRC16 Map validation tests passed!");
  };

  private func testValidateMapRequiredKeys() {
    Debug.print("Testing validateMapRequiredKeys...");
    
    // Test valid Map with all required keys
    let mapCandy : CandyShared = #Map([
      ("name", #Text("test")),
      ("version", #Nat(1)),
      ("active", #Bool(true))
    ]);
    
    let requiredKeys = ["name", "version"];
    let result1 = ICRC16Validator.validateMapRequiredKeys(mapCandy, requiredKeys);
    assert(result1 == true);
    
    // Test Map missing required key
    let mapCandy2 : CandyShared = #Map([
      ("name", #Text("test")),
      ("active", #Bool(true))
    ]);
    
    let result2 = ICRC16Validator.validateMapRequiredKeys(mapCandy2, requiredKeys);
    assert(result2 == false);
    
    // Test non-Map candy
    let textCandy : CandyShared = #Text("not a map");
    let result3 = ICRC16Validator.validateMapRequiredKeys(textCandy, requiredKeys);
    assert(result3 == false);
    
    Debug.print("  ✓ validateMapRequiredKeys tests passed");
  };

  private func testValidateMapAllowedKeys() {
    Debug.print("Testing validateMapAllowedKeys...");
    
    // Test Map with only allowed keys
    let mapCandy : CandyShared = #Map([
      ("name", #Text("test")),
      ("version", #Nat(1))
    ]);
    
    let allowedKeys = ["name", "version", "active"];
    let result1 = ICRC16Validator.validateMapAllowedKeys(mapCandy, allowedKeys);
    assert(result1 == true);
    
    // Test Map with forbidden key
    let mapCandy2 : CandyShared = #Map([
      ("name", #Text("test")),
      ("forbidden", #Text("not allowed"))
    ]);
    
    let allowedKeys2 = ["name", "version"];
    let result2 = ICRC16Validator.validateMapAllowedKeys(mapCandy2, allowedKeys2);
    assert(result2 == false);
    
    Debug.print("  ✓ validateMapAllowedKeys tests passed");
  };

  private func testValidateMapEntryCount() {
    Debug.print("Testing validateMapEntryCount...");
    
    // Test valid count range
    let mapCandy : CandyShared = #Map([
      ("key1", #Text("value1")),
      ("key2", #Text("value2")),
      ("key3", #Text("value3"))
    ]);
    
    let result1 = ICRC16Validator.validateMapEntryCount(mapCandy, ?2, ?5);
    assert(result1 == true);
    
    // Test count too low
    let mapCandy2 : CandyShared = #Map([
      ("key1", #Text("value1"))
    ]);
    
    let result2 = ICRC16Validator.validateMapEntryCount(mapCandy2, ?2, ?5);
    assert(result2 == false);
    
    // Test count too high
    let mapCandy3 : CandyShared = #Map([
      ("key1", #Text("value1")),
      ("key2", #Text("value2")),
      ("key3", #Text("value3")),
      ("key4", #Text("value4")),
      ("key5", #Text("value5")),
      ("key6", #Text("value6"))
    ]);
    
    let result3 = ICRC16Validator.validateMapEntryCount(mapCandy3, ?2, ?5);
    assert(result3 == false);
    
    Debug.print("  ✓ validateMapEntryCount tests passed");
  };

  private func testGetMapValue() {
    Debug.print("Testing getMapValue...");
    
    let mapCandy : CandyShared = #Map([
      ("name", #Text("test")),
      ("version", #Nat(1))
    ]);
    
    // Test existing key
    switch (ICRC16Validator.getMapValue(mapCandy, "name")) {
      case (?#Text(value)) assert(value == "test");
      case (_) assert(false);
    };
    
    // Test non-existing key
    let result = ICRC16Validator.getMapValue(mapCandy, "missing");
    assert(result == null);
    
    Debug.print("  ✓ getMapValue tests passed");
  };

  private func testMapInnerAccessors() {
    Debug.print("Testing Map inner accessors...");
    
    let mapEntries : [(Text, CandyShared)] = [
      ("name", #Text("test")),
      ("version", #Nat(1)),
      ("active", #Bool(true))
    ];
    
    // Test inner required keys
    let requiredKeys = ["name", "version"];
    let result1 = ICRC16Validator.validateMapInnerRequiredKeys(mapEntries, requiredKeys);
    assert(result1 == true);
    
    // Test inner allowed keys
    let allowedKeys = ["name", "version", "active"];
    let result2 = ICRC16Validator.validateMapInnerAllowedKeys(mapEntries, allowedKeys);
    assert(result2 == true);
    
    // Test inner entry count
    let result3 = ICRC16Validator.validateMapInnerEntryCount(mapEntries, ?2, ?5);
    assert(result3 == true);
    
    // Test inner get value
    switch (ICRC16Validator.getMapInnerValue(mapEntries, "name")) {
      case (?#Text(value)) assert(value == "test");
      case (_) assert(false);
    };
    
    Debug.print("  ✓ Map inner accessors tests passed");
  };

  // Standard test method for DFX deployment pattern
  public func test() : async () {
    await runTests();
  };
};
