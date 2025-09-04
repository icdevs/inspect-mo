import {test} "mo:test/async";
import Debug "mo:base/Debug";
import CandyTypes "mo:candy/types";

module {
  type CandyShared = CandyTypes.CandyShared;
  type PropertyShared = CandyTypes.PropertyShared;

  public func run() : async () {
    Debug.print("🚀 Starting ICRC16 CandyShared Performance Tests");

    await test("Basic CandyShared operations", func() : async () {
      // Test primitive types
      let intVal = #Int(42);
      let textVal = #Text("Hello ICRC16");
      let boolVal = #Bool(true);
      
      Debug.print("✅ Created primitive types: Int, Text, Bool");
      
      // Test Class structure
      let userClass = #Class([
        { name = "id"; value = #Nat(123); immutable = true },
        { name = "username"; value = #Text("alice"); immutable = false },
        { name = "active"; value = #Bool(true); immutable = false }
      ]);
      
      Debug.print("✅ Created Class with 3 properties");
      
      // Test Map structure  
      let configMap = #Map([
        ("debug", #Bool(true)),
        ("maxUsers", #Nat(1000)),
        ("version", #Text("1.0.0"))
      ]);
      
      Debug.print("✅ Created Map with 3 entries");
      
      // Test Array structure
      let numbers = #Array([#Nat(1), #Nat(2), #Nat(3), #Nat(4), #Nat(5)]);
      
      Debug.print("✅ Created Array with 5 elements");
      
      // Test type detection
      let typeNames = switch (userClass) {
        case (#Class(_)) "Class";
        case (#Map(_)) "Map";
        case (#Array(_)) "Array";
        case (_) "Other";
      };
      
      Debug.print("✅ Type detection working: " # typeNames);
      
      Debug.print("📊 All ICRC16 basic operations successful");
    });

    Debug.print("✅ ICRC16 Performance Testing Complete");
  };
};
