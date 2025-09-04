import ICRC16Validator "../src/utils/icrc16_validator";
import CandyTypes "mo:candy/types";
import Debug "mo:core/Debug";

// Test for ICRC16 Class validation functionality
persistent actor {
  
  type CandyShared = CandyTypes.CandyShared;
  type PropertyShared = CandyTypes.PropertyShared;
  
  public func runTests() : async () {
    
    Debug.print("Testing ICRC16 Class validation functionality...");
    
    // Test validateClassRequiredProperties
    testValidateClassRequiredProperties();
    
    // Test validateClassAllowedProperties
    testValidateClassAllowedProperties();
    
    // Test validateClassPropertyCount
    testValidateClassPropertyCount();
    
    // Test getClassProperty
    testGetClassProperty();
    
    // Test inner accessor functions
    testClassInnerAccessors();
    
    Debug.print("✅ All ICRC16 Class validation tests passed!");
  };

  private func testValidateClassRequiredProperties() {
    Debug.print("Testing validateClassRequiredProperties...");
    
    // Test valid Class with all required properties
    let classCandy : CandyShared = #Class([
      { name = "name"; value = #Text("test"); immutable = false },
      { name = "version"; value = #Nat(1); immutable = true },
      { name = "active"; value = #Bool(true); immutable = false }
    ]);
    
    let requiredProperties = ["name", "version"];
    let result1 = ICRC16Validator.validateClassRequiredProperties(classCandy, requiredProperties);
    assert(result1 == true);
    
    // Test Class missing required property
    let classCandy2 : CandyShared = #Class([
      { name = "name"; value = #Text("test"); immutable = false },
      { name = "active"; value = #Bool(true); immutable = false }
    ]);
    
    let result2 = ICRC16Validator.validateClassRequiredProperties(classCandy2, requiredProperties);
    assert(result2 == false);
    
    // Test non-Class candy
    let textCandy : CandyShared = #Text("not a class");
    let result3 = ICRC16Validator.validateClassRequiredProperties(textCandy, requiredProperties);
    assert(result3 == false);
    
    Debug.print("  ✓ validateClassRequiredProperties tests passed");
  };

  private func testValidateClassAllowedProperties() {
    Debug.print("Testing validateClassAllowedProperties...");
    
    // Test Class with only allowed properties
    let classCandy : CandyShared = #Class([
      { name = "name"; value = #Text("test"); immutable = false },
      { name = "version"; value = #Nat(1); immutable = true }
    ]);
    
    let allowedProperties = ["name", "version", "active"];
    let result1 = ICRC16Validator.validateClassAllowedProperties(classCandy, allowedProperties);
    assert(result1 == true);
    
    // Test Class with forbidden property
    let classCandy2 : CandyShared = #Class([
      { name = "name"; value = #Text("test"); immutable = false },
      { name = "forbidden"; value = #Text("not allowed"); immutable = false }
    ]);
    
    let allowedProperties2 = ["name", "version"];
    let result2 = ICRC16Validator.validateClassAllowedProperties(classCandy2, allowedProperties2);
    assert(result2 == false);
    
    Debug.print("  ✓ validateClassAllowedProperties tests passed");
  };

  private func testValidateClassPropertyCount() {
    Debug.print("Testing validateClassPropertyCount...");
    
    // Test valid count range
    let classCandy : CandyShared = #Class([
      { name = "prop1"; value = #Text("value1"); immutable = false },
      { name = "prop2"; value = #Text("value2"); immutable = false },
      { name = "prop3"; value = #Text("value3"); immutable = false }
    ]);
    
    let result1 = ICRC16Validator.validateClassPropertyCount(classCandy, ?2, ?5);
    assert(result1 == true);
    
    // Test count too low
    let classCandy2 : CandyShared = #Class([
      { name = "prop1"; value = #Text("value1"); immutable = false }
    ]);
    
    let result2 = ICRC16Validator.validateClassPropertyCount(classCandy2, ?2, ?5);
    assert(result2 == false);
    
    // Test count too high
    let classCandy3 : CandyShared = #Class([
      { name = "prop1"; value = #Text("value1"); immutable = false },
      { name = "prop2"; value = #Text("value2"); immutable = false },
      { name = "prop3"; value = #Text("value3"); immutable = false },
      { name = "prop4"; value = #Text("value4"); immutable = false },
      { name = "prop5"; value = #Text("value5"); immutable = false },
      { name = "prop6"; value = #Text("value6"); immutable = false }
    ]);
    
    let result3 = ICRC16Validator.validateClassPropertyCount(classCandy3, ?2, ?5);
    assert(result3 == false);
    
    Debug.print("  ✓ validateClassPropertyCount tests passed");
  };

  private func testGetClassProperty() {
    Debug.print("Testing getClassProperty...");
    
    let classCandy : CandyShared = #Class([
      { name = "name"; value = #Text("test"); immutable = false },
      { name = "version"; value = #Nat(1); immutable = true }
    ]);
    
    // Test existing property
    switch (ICRC16Validator.getClassProperty(classCandy, "name")) {
      case (?prop) {
        assert(prop.name == "name");
        switch (prop.value) {
          case (#Text(value)) assert(value == "test");
          case (_) assert(false);
        };
        assert(prop.immutable == false);
      };
      case (_) assert(false);
    };
    
    // Test existing immutable property
    switch (ICRC16Validator.getClassProperty(classCandy, "version")) {
      case (?prop) {
        assert(prop.name == "version");
        switch (prop.value) {
          case (#Nat(value)) assert(value == 1);
          case (_) assert(false);
        };
        assert(prop.immutable == true);
      };
      case (_) assert(false);
    };
    
    // Test non-existing property
    let result = ICRC16Validator.getClassProperty(classCandy, "missing");
    assert(result == null);
    
    Debug.print("  ✓ getClassProperty tests passed");
  };

  private func testClassInnerAccessors() {
    Debug.print("Testing Class inner accessors...");
    
    let classProperties : [PropertyShared] = [
      { name = "name"; value = #Text("test"); immutable = false },
      { name = "version"; value = #Nat(1); immutable = true },
      { name = "active"; value = #Bool(true); immutable = false }
    ];
    
    // Test inner required properties
    let requiredProperties = ["name", "version"];
    let result1 = ICRC16Validator.validateClassInnerRequiredProperties(classProperties, requiredProperties);
    assert(result1 == true);
    
    // Test inner allowed properties
    let allowedProperties = ["name", "version", "active"];
    let result2 = ICRC16Validator.validateClassInnerAllowedProperties(classProperties, allowedProperties);
    assert(result2 == true);
    
    // Test inner property count
    let result3 = ICRC16Validator.validateClassInnerPropertyCount(classProperties, ?2, ?5);
    assert(result3 == true);
    
    // Test inner get property
    switch (ICRC16Validator.getClassInnerProperty(classProperties, "name")) {
      case (?prop) {
        assert(prop.name == "name");
        switch (prop.value) {
          case (#Text(value)) assert(value == "test");
          case (_) assert(false);
        };
      };
      case (_) assert(false);
    };
    
    Debug.print("  ✓ Class inner accessors tests passed");
  };
};
