import ICRC16Validator "../src/utils/icrc16_validator";
import CandyTypes "mo:candy/types";
import Debug "mo:core/Debug";

// Test for ICRC16 utility and nested validation functionality
persistent actor {
  
  type CandyShared = CandyTypes.CandyShared;
  
  public func runTests() : async () {
    
    Debug.print("Testing ICRC16 utility and nested validation functionality...");
    
    // Test getCandyType
    testGetCandyType();
    
    // Test estimateCandySize
    testEstimateCandySize();
    
    // Test nested validation functions
    testNestedValidation();
    
    Debug.print("✅ All ICRC16 utility and nested validation tests passed!");
  };

  private func testGetCandyType() {
    Debug.print("Testing getCandyType...");
    
    assert(ICRC16Validator.getCandyType(#Text("hello")) == "Text");
    assert(ICRC16Validator.getCandyType(#Nat(42)) == "Nat");
    assert(ICRC16Validator.getCandyType(#Int(-42)) == "Int");
    assert(ICRC16Validator.getCandyType(#Bool(true)) == "Bool");
    assert(ICRC16Validator.getCandyType(#Float(3.14)) == "Float");
    assert(ICRC16Validator.getCandyType(#Array([#Text("item")])) == "Array");
    assert(ICRC16Validator.getCandyType(#Map([("key", #Text("value"))])) == "Map");
    assert(ICRC16Validator.getCandyType(#ValueMap([(#Text("key"), #Text("value"))])) == "ValueMap");
    assert(ICRC16Validator.getCandyType(#Class([{ name = "prop"; value = #Text("value"); immutable = false }])) == "Class");
    
    Debug.print("  ✓ getCandyType tests passed");
  };

  private func testEstimateCandySize() {
    Debug.print("Testing estimateCandySize...");
    
    // Test basic types
    assert(ICRC16Validator.estimateCandySize(#Nat(42)) == 8);
    assert(ICRC16Validator.estimateCandySize(#Bool(true)) == 1);
    assert(ICRC16Validator.estimateCandySize(#Float(3.14)) == 8);
    
    // Test text (4 bytes per character estimate)
    let textSize = ICRC16Validator.estimateCandySize(#Text("hello"));
    assert(textSize == 20); // 5 chars * 4 bytes
    
    // Test array
    let arrayCandy = #Array([#Nat(1), #Nat(2), #Nat(3)]);
    let arraySize = ICRC16Validator.estimateCandySize(arrayCandy);
    assert(arraySize == 24); // 3 * 8 bytes
    
    // Test Map
    let mapCandy = #Map([("key", #Nat(42))]);
    let mapSize = ICRC16Validator.estimateCandySize(mapCandy);
    assert(mapSize == 20); // "key" (3*4) + Nat(8) = 20
    
    // Test ValueMap
    let valueMapCandy = #ValueMap([(#Text("key"), #Nat(42))]);
    let valueMapSize = ICRC16Validator.estimateCandySize(valueMapCandy);
    assert(valueMapSize == 20); // Text(12) + Nat(8) = 20
    
    Debug.print("  ✓ estimateCandySize tests passed");
  };

  private func testNestedValidation() {
    Debug.print("Testing nested validation...");
    
    // Test nested Map validation
    let nestedMapCandy : CandyShared = #Map([
      ("config", #Map([
        ("version", #Nat(1)),
        ("debug", #Bool(true))
      ])),
      ("data", #Text("test"))
    ]);
    
    // Validate that config.version exists and is a Nat
    let result1 = ICRC16Validator.validateNestedMap(
      nestedMapCandy,
      ["config", "version"],
      func(candy: CandyShared) : Bool {
        switch (candy) {
          case (#Nat(_)) true;
          case (_) false;
        }
      }
    );
    assert(result1 == true);
    
    // Test path that doesn't exist
    let result2 = ICRC16Validator.validateNestedMap(
      nestedMapCandy,
      ["config", "missing"],
      func(candy: CandyShared) : Bool { true }
    );
    assert(result2 == false);
    
    // Test nested ValueMap validation
    let nestedValueMapCandy : CandyShared = #ValueMap([
      (#Text("config"), #ValueMap([
        (#Text("version"), #Nat(1)),
        (#Text("debug"), #Bool(true))
      ])),
      (#Text("data"), #Text("test"))
    ]);
    
    let result3 = ICRC16Validator.validateNestedValueMap(
      nestedValueMapCandy,
      [#Text("config"), #Text("version")],
      func(candy: CandyShared) : Bool {
        switch (candy) {
          case (#Nat(_)) true;
          case (_) false;
        }
      }
    );
    assert(result3 == true);
    
    // Test nested Class validation
    let nestedClassCandy : CandyShared = #Class([
      { name = "config"; value = #Class([
        { name = "version"; value = #Nat(1); immutable = true },
        { name = "debug"; value = #Bool(true); immutable = false }
      ]); immutable = false },
      { name = "data"; value = #Text("test"); immutable = false }
    ]);
    
    let result4 = ICRC16Validator.validateNestedClass(
      nestedClassCandy,
      ["config", "version"],
      func(candy: CandyShared) : Bool {
        switch (candy) {
          case (#Nat(_)) true;
          case (_) false;
        }
      }
    );
    assert(result4 == true);
    
    Debug.print("  ✓ nested validation tests passed");
  };
};
