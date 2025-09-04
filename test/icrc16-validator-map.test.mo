import ICRC16Validator "../src/utils/icrc16_validator";
import CandyTypes "mo:candy/types";
import Debug "mo:core/Debug";

// Test for ICRC16 Map validation functionality
persistent actor {
  
  type CandyShared = CandyTypes.CandyShared;
  
  public func runTests() : async () {
    
    Debug.print("Testing ICRC16 Map validation functionality...");
    
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
};
