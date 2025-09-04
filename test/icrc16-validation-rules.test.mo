import {test} "mo:test/async";
import ICRC16Rules "../src/utils/icrc16_validation_rules";
import CandyTypes "mo:candy/types";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import TimerTool "mo:timer-tool";
import ClassPlusLib "mo:class-plus";
import Principal "mo:base/Principal";

persistent actor ICRC16ValidationRulesTest {

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

  public func runTests() : async () {

await test("ICRC16 Module compiles and types are accessible", func() : async () {
  Debug.print("Testing ICRC16 validation rules module compilation...");
  
  // Test that we can reference the types
  let _: ICRC16Rules.ICRC16ValidationContext = {
    maxDepth = 5;
    maxSize = 1000;
    allowedTypes = ["Text", "Nat"];
    strictMode = true;
  };
  
  // Test that we can create a simple validation rule
  let textAccessor = func(args: CandyTypes.CandyShared) : CandyTypes.CandyShared { args };
  let _rule = ICRC16Rules.candyType<Any, CandyTypes.CandyShared>(textAccessor, "Text");
  
  Debug.print("✓ ICRC16 types and basic validation rules accessible");
});

await test("ICRC16 Validation rule creation works", func() : async () {
  Debug.print("Testing ICRC16 validation rule creation...");
  
  // Test creating different types of validation rules
  let accessor = func(args: CandyTypes.CandyShared) : CandyTypes.CandyShared { args };
  
  let typeRule = ICRC16Rules.candyType(accessor, "Text");
  let sizeRule = ICRC16Rules.candySize(accessor, ?1, ?100);
  let depthRule = ICRC16Rules.candyDepth(accessor, 5);
  let patternRule = ICRC16Rules.candyPattern(accessor, "^[a-zA-Z]+$");
  let rangeRule = ICRC16Rules.candyRange(accessor, ?0, ?1000);
  
  Debug.print("✓ Basic ICRC16 validation rules created successfully");
});

await test("ICRC16 Property validation rules work", func() : async () {
  Debug.print("Testing ICRC16 property validation rules...");
  
  let propertyAccessor = func(args: [CandyTypes.PropertyShared]) : [CandyTypes.PropertyShared] { args };
  
  let existsRule = ICRC16Rules.propertyExists(propertyAccessor, "username");
  let typeRule = ICRC16Rules.propertyType(propertyAccessor, "username", "Text");
  let sizeRule = ICRC16Rules.propertySize(propertyAccessor, "username", ?3, ?20);
  
  Debug.print("✓ Property validation rules created successfully");
});

await test("ICRC16 Array and map validation rules work", func() : async () {
  Debug.print("Testing ICRC16 array and map validation rules...");
  
  let candyAccessor = func(args: CandyTypes.CandyShared) : CandyTypes.CandyShared { args };
  
  let arrayLengthRule = ICRC16Rules.arrayLength(candyAccessor, ?1, ?10);
  let arrayTypeRule = ICRC16Rules.arrayItemType(candyAccessor, "Text");
  let mapKeyRule = ICRC16Rules.mapKeyExists(candyAccessor, "key1");
  let mapSizeRule = ICRC16Rules.mapSize(candyAccessor, ?1, ?20);
  
  Debug.print("✓ Array and map validation rules created successfully");
});

await test("ICRC16 Custom validation rules work", func() : async () {
  Debug.print("Testing ICRC16 custom validation rules...");
  
  let candyAccessor = func(args: CandyTypes.CandyShared) : CandyTypes.CandyShared { args };
  let validator = func(candy: CandyTypes.CandyShared) : Result.Result<(), Text> { #ok() };
  
  let customRule = ICRC16Rules.customCandyCheck(candyAccessor, validator);
  let nestedRule = ICRC16Rules.nestedValidation(candyAccessor, []);
  
  Debug.print("✓ Custom validation rules created successfully");
});

  }; // End runTests function

}; // End actor
