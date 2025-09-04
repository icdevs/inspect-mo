// Security DoS Testing for ICRC16 validation
// Tests potential denial-of-service attack vectors

import {test} "mo:test/async";
import InspectMo "../src/core/inspector";
import CandyTypes "mo:candy/types";
import Debug "mo:core/Debug";
import Array "mo:core/Array";
import Text "mo:core/Text";
import Nat "mo:core/Nat";
import Principal "mo:core/Principal";
import TimerTool "mo:timer-tool";
import ClassPlusLib "mo:class-plus";

// Import test suite functions directly
let { it; suite; expect; run } = test;

// Test type for malicious inputs
type MaliciousArgs = {
  deepNested: CandyTypes.CandyShared;
  largeArray: [CandyTypes.CandyShared];
  malformedData: CandyTypes.CandyShared;
};

let inspector = InspectMo.InspectMo<MaliciousArgs>({
  initArgs = {
    authProvider = null;
    timeTool = TimerTool.TimerTool();
    state = null;
    classPlus = ClassPlus.ClassPlus();
  };
  validations = [];
  authorizations = [];
});

// Create deeply nested structure - potential DoS vector
func createDeeplyNested(depth: Nat) : CandyTypes.CandyShared {
  if (depth == 0) {
    #Text("base")
  } else {
    #Class([{
      name = "nested";
      value = createDeeplyNested(depth - 1);
      immutable = false;
    }])
  }
};

// Create extremely large array - potential memory DoS
func createLargeArray(size: Nat) : [CandyTypes.CandyShared] {
  Array.tabulate<CandyTypes.CandyShared>(size, func(i) {
    #Text("item_" # Nat.toText(i))
  })
};

// SECURITY TEST SUITE
suite("ICRC16 DoS Security Tests", func() {

  // Test 1: Depth Bomb Protection
  test("Should reject deeply nested structures beyond maxDepth limit", func() {
    let deepData = createDeeplyNested(20); // Way beyond maxDepth=10
    
    let maliciousArgs: MaliciousArgs = {
      deepNested = deepData;
      largeArray = [];
      malformedData = #Text("normal");
    };
    
    let rule = InspectMo.candyDepth(
      func(args: MaliciousArgs): CandyTypes.CandyShared { args.deepNested },
      10 // maxDepth limit
    );
    
    // This should be rejected due to depth limits
    let result = inspector.inspect({
      caller = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
      arg = to_candid(maliciousArgs);
      method_name = "malicious_deep_test";
    }, [rule]);
    
    expect(result).toEqual(#rejected("candyDepth: Maximum depth exceeded"));
  });

  // Test 2: Memory Bomb Protection
  test("Should handle large arrays without memory exhaustion", func() {
    let largeData = createLargeArray(1000); // Large but reasonable
    
    let maliciousArgs: MaliciousArgs = {
      deepNested = #Text("normal");
      largeArray = largeData;
      malformedData = #Text("normal");
    };
    
    let rule = InspectMo.arrayLength(
      func(args: MaliciousArgs): CandyTypes.CandyShared { 
        #Array(#thawed(Array.map(args.largeArray, func(x) { x })))
      },
      null, // min
      ?500   // max - should reject this
    );
    
    let result = inspector.inspect({
      caller = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
      arg = to_candid(maliciousArgs);
      method_name = "malicious_array_test";
    }, [rule]);
    
    expect(result).toEqual(#rejected("arrayLength: Array length exceeds maximum"));
  });

  // Test 3: Size Limit Protection  
  test("Should enforce size limits on CandyShared structures", func() {
    // Create a structure that's too large
    let largeText = Text.repeat("x", 10000); // 10KB text
    
    let maliciousArgs: MaliciousArgs = {
      deepNested = #Text("normal");
      largeArray = [];
      malformedData = #Text(largeText);
    };
    
    let rule = InspectMo.candySize(
      func(args: MaliciousArgs): CandyTypes.CandyShared { args.malformedData },
      null, // min
      ?1000 // max 1KB - should reject 10KB
    );
    
    let result = inspector.inspect({
      caller = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
      arg = to_candid(maliciousArgs);
      method_name = "malicious_size_test";
    }, [rule]);
    
    expect(result).toEqual(#rejected("candySize: Size limit exceeded"));
  });

  // Test 4: Malformed Variant Protection
  test("Should handle malformed CandyShared gracefully", func() {
    // Test with unexpected variant combinations
    let malformedClass = #Class([
      { name = ""; value = #Nat(0); immutable = false }, // Empty name
      { name = "valid"; value = #Text("ok"); immutable = false }
    ]);
    
    let maliciousArgs: MaliciousArgs = {
      deepNested = #Text("normal");
      largeArray = [];
      malformedData = malformedClass;
    };
    
    let rule = InspectMo.propertyExists(
      func(args: MaliciousArgs): [CandyTypes.PropertyShared] {
        switch (args.malformedData) {
          case (#Class(props)) props;
          case (_) [];
        }
      },
      "nonexistent_property"
    );
    
    let result = inspector.inspect({
      caller = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
      arg = to_candid(maliciousArgs);
      method_name = "malformed_test";
    }, [rule]);
    
    // Should handle gracefully, not crash
    expect(result).toEqual(#rejected("propertyExists: Missing property nonexistent_property"));
  });

  // Test 5: Information Leakage Protection
  test("Should not leak sensitive information in error messages", func() {
    let sensitiveData = #Text("SECRET_API_KEY_12345");
    
    let maliciousArgs: MaliciousArgs = {
      deepNested = sensitiveData;
      largeArray = [];
      malformedData = #Text("normal");
    };
    
    let rule = InspectMo.candyType(
      func(args: MaliciousArgs): CandyTypes.CandyShared { args.deepNested },
      "Nat" // Wrong type, should get error
    );
    
    let result = inspector.inspect({
      caller = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
      arg = to_candid(maliciousArgs);
      method_name = "info_leak_test";
    }, [rule]);
    
    // Check that error message doesn't contain sensitive data
    switch (result) {
      case (#rejected(message)) {
        expect(Text.contains(message, #text("SECRET"))).toEqual(false);
        expect(Text.contains(message, #text("API_KEY"))).toEqual(false);
      };
      case (_) expect(false).toEqual(true); // Should have been rejected
    };
  });
});

run();
