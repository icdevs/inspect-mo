import Debug "mo:core/Debug";
import Principal "mo:core/Principal";
import TT "mo:timer-tool";
import ClassPlusLib "mo:class-plus";
import InspectMo "../src/core/inspector";
import ICRC16Validator "../src/utils/icrc16_validator";
import CandyTypes "mo:candy/types";

persistent actor ICRC16ValidatorValueMapTest {

/// Test ICRC16 ValueMap validation functionality with full TimerTool setup

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
    
    Debug.print("🚀 Starting ICRC16 ValueMap validation functionality tests...");
    
    // Test validateValueMapRequiredKeys
    testValidateValueMapRequiredKeys();
    
    // Test validateValueMapAllowedKeys
    testValidateValueMapAllowedKeys();
    
    // Test validateValueMapEntryCount
    testValidateValueMapEntryCount();
    
    // Test getValueMapValue
    testGetValueMapValue();
    
    // Test inner accessor functions
    testValueMapInnerAccessors();
    
    Debug.print("✅ All ICRC16 ValueMap validation tests passed!");
  };

  private func testValidateValueMapRequiredKeys() {
    Debug.print("Testing validateValueMapRequiredKeys...");
    
    // Test valid ValueMap with all required keys
    let valueMapCandy : CandyShared = #ValueMap([
      (#Text("name"), #Text("test")),
      (#Text("version"), #Nat(1)),
      (#Text("active"), #Bool(true))
    ]);
    
    let requiredKeys = [#Text("name"), #Text("version")];
    let result1 = ICRC16Validator.validateValueMapRequiredKeys(valueMapCandy, requiredKeys);
    assert(result1 == true);
    
    // Test ValueMap missing required key
    let valueMapCandy2 : CandyShared = #ValueMap([
      (#Text("name"), #Text("test")),
      (#Text("active"), #Bool(true))
    ]);
    
    let result2 = ICRC16Validator.validateValueMapRequiredKeys(valueMapCandy2, requiredKeys);
    assert(result2 == false);
    
    // Test non-ValueMap candy
    let textCandy : CandyShared = #Text("not a valuemap");
    let result3 = ICRC16Validator.validateValueMapRequiredKeys(textCandy, requiredKeys);
    assert(result3 == false);
    
    Debug.print("  ✓ validateValueMapRequiredKeys tests passed");
  };

  private func testValidateValueMapAllowedKeys() {
    Debug.print("Testing validateValueMapAllowedKeys...");
    
    // Test ValueMap with only allowed keys
    let valueMapCandy : CandyShared = #ValueMap([
      (#Text("name"), #Text("test")),
      (#Text("version"), #Nat(1))
    ]);
    
    let allowedKeys = [#Text("name"), #Text("version"), #Text("active")];
    let result1 = ICRC16Validator.validateValueMapAllowedKeys(valueMapCandy, allowedKeys);
    assert(result1 == true);
    
    // Test ValueMap with forbidden key
    let valueMapCandy2 : CandyShared = #ValueMap([
      (#Text("name"), #Text("test")),
      (#Text("forbidden"), #Text("not allowed"))
    ]);
    
    let allowedKeys2 = [#Text("name"), #Text("version")];
    let result2 = ICRC16Validator.validateValueMapAllowedKeys(valueMapCandy2, allowedKeys2);
    assert(result2 == false);
    
    Debug.print("  ✓ validateValueMapAllowedKeys tests passed");
  };

  private func testValidateValueMapEntryCount() {
    Debug.print("Testing validateValueMapEntryCount...");
    
    // Test valid count range
    let valueMapCandy : CandyShared = #ValueMap([
      (#Text("key1"), #Text("value1")),
      (#Text("key2"), #Text("value2")),
      (#Text("key3"), #Text("value3"))
    ]);
    
    let result1 = ICRC16Validator.validateValueMapEntryCount(valueMapCandy, ?2, ?5);
    assert(result1 == true);
    
    // Test count too low
    let valueMapCandy2 : CandyShared = #ValueMap([
      (#Text("key1"), #Text("value1"))
    ]);
    
    let result2 = ICRC16Validator.validateValueMapEntryCount(valueMapCandy2, ?2, ?5);
    assert(result2 == false);
    
    // Test count too high
    let valueMapCandy3 : CandyShared = #ValueMap([
      (#Text("key1"), #Text("value1")),
      (#Text("key2"), #Text("value2")),
      (#Text("key3"), #Text("value3")),
      (#Text("key4"), #Text("value4")),
      (#Text("key5"), #Text("value5")),
      (#Text("key6"), #Text("value6"))
    ]);
    
    let result3 = ICRC16Validator.validateValueMapEntryCount(valueMapCandy3, ?2, ?5);
    assert(result3 == false);
    
    Debug.print("  ✓ validateValueMapEntryCount tests passed");
  };

  private func testGetValueMapValue() {
    Debug.print("Testing getValueMapValue...");
    
    let valueMapCandy : CandyShared = #ValueMap([
      (#Text("name"), #Text("test")),
      (#Nat(42), #Text("answer"))
    ]);
    
    // Test existing key
    switch (ICRC16Validator.getValueMapValue(valueMapCandy, #Text("name"))) {
      case (?#Text(value)) assert(value == "test");
      case (_) assert(false);
    };
    
    // Test existing numeric key
    switch (ICRC16Validator.getValueMapValue(valueMapCandy, #Nat(42))) {
      case (?#Text(value)) assert(value == "answer");
      case (_) assert(false);
    };
    
    // Test non-existing key
    let result = ICRC16Validator.getValueMapValue(valueMapCandy, #Text("missing"));
    assert(result == null);
    
    Debug.print("  ✓ getValueMapValue tests passed");
  };

  private func testValueMapInnerAccessors() {
    Debug.print("Testing ValueMap inner accessors...");
    
    let valueMapEntries : [(CandyShared, CandyShared)] = [
      (#Text("name"), #Text("test")),
      (#Text("version"), #Nat(1)),
      (#Text("active"), #Bool(true))
    ];
    
    // Test inner required keys
    let requiredKeys = [#Text("name"), #Text("version")];
    let result1 = ICRC16Validator.validateValueMapInnerRequiredKeys(valueMapEntries, requiredKeys);
    assert(result1 == true);
    
    // Test inner allowed keys
    let allowedKeys = [#Text("name"), #Text("version"), #Text("active")];
    let result2 = ICRC16Validator.validateValueMapInnerAllowedKeys(valueMapEntries, allowedKeys);
    assert(result2 == true);
    
    // Test inner entry count
    let result3 = ICRC16Validator.validateValueMapInnerEntryCount(valueMapEntries, ?2, ?5);
    assert(result3 == true);
    
    // Test inner get value
    switch (ICRC16Validator.getValueMapInnerValue(valueMapEntries, #Text("name"))) {
      case (?#Text(value)) assert(value == "test");
      case (_) assert(false);
    };
    
    Debug.print("  ✓ ValueMap inner accessors tests passed");
  };

  // Standard test method for DFX deployment pattern
  public func test() : async () {
    await runTests();
  };
};
