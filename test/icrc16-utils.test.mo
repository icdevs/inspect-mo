import {test} "mo:test/async";
import Debug "mo:base/Debug";
import ICRC16 "../src/utils/icrc16";
import CandyTypes "mo:candy/types";

module {
  type CandyShared = CandyTypes.CandyShared;
  type PropertyShared = CandyTypes.PropertyShared;
  
  public func run() : async () {
    Debug.print("🧪 Testing ICRC16 Utilities Module");

    await test("Type name detection", func() : async () {
      let intVal = #Int(42);
      let textVal = #Text("hello");
      let classVal = #Class([]);
      
      assert(ICRC16.getTypeName(intVal) == "Int");
      assert(ICRC16.getTypeName(textVal) == "Text");
      assert(ICRC16.getTypeName(classVal) == "Class");
      
      Debug.print("✅ Type name detection working");
    });

    await test("Type validation", func() : async () {
      let context = ICRC16.createContext("test", 5);
      let intVal = #Int(42);
      
      // Valid type check
      let result1 = ICRC16.validateType(intVal, ["Int", "Nat"], context);
      switch (result1) {
        case (#ok(())) Debug.print("✅ Valid type accepted");
        case (#err(_)) assert(false);
      };
      
      // Invalid type check
      let result2 = ICRC16.validateType(intVal, ["Text", "Bool"], context);
      switch (result2) {
        case (#ok(())) assert(false);
        case (#err(error)) {
          Debug.print("✅ Invalid type rejected: " # ICRC16.formatError(error));
        };
      };
    });

    await test("Size validation", func() : async () {
      let context = ICRC16.createContext("test", 5);
      let textVal = #Text("hello");
      
      // Valid size
      let result1 = ICRC16.validateSize(textVal, { min = ?3; max = ?10 }, context);
      switch (result1) {
        case (#ok(())) Debug.print("✅ Valid size accepted");
        case (#err(_)) assert(false);
      };
      
      // Invalid size (too short)
      let result2 = ICRC16.validateSize(textVal, { min = ?10; max = ?20 }, context);
      switch (result2) {
        case (#ok(())) assert(false);
        case (#err(error)) {
          Debug.print("✅ Invalid size rejected: " # ICRC16.formatError(error));
        };
      };
    });

    await test("Text pattern validation", func() : async () {
      let context = ICRC16.createContext("test", 5);
      
      // Valid alphanumeric text
      let result1 = ICRC16.validateTextPattern("abc123", {
        minLength = ?3;
        maxLength = ?10;
        pattern = ?"alphanumeric";
        allowedValues = null;
      }, context);
      switch (result1) {
        case (#ok(())) Debug.print("✅ Valid alphanumeric text accepted");
        case (#err(_)) assert(false);
      };
      
      // Valid email
      let result2 = ICRC16.validateTextPattern("test@example.com", {
        minLength = null;
        maxLength = null;
        pattern = ?"email";
        allowedValues = null;
      }, context);
      switch (result2) {
        case (#ok(())) Debug.print("✅ Valid email accepted");
        case (#err(_)) assert(false);
      };
      
      // Test allowed values
      let result3 = ICRC16.validateTextPattern("admin", {
        minLength = null;
        maxLength = null;
        pattern = null;
        allowedValues = ?["admin", "user", "guest"];
      }, context);
      switch (result3) {
        case (#ok(())) Debug.print("✅ Allowed value accepted");
        case (#err(_)) assert(false);
      };
    });

    await test("Range validation", func() : async () {
      let context = ICRC16.createContext("test", 5);
      let natVal = #Nat(50);
      
      // Valid range
      let result1 = ICRC16.validateRange(natVal, {
        min = ?#Nat(1);
        max = ?#Nat(100);
      }, context);
      switch (result1) {
        case (#ok(())) Debug.print("✅ Value in valid range accepted");
        case (#err(_)) assert(false);
      };
      
      // Out of range (too high)
      let result2 = ICRC16.validateRange(natVal, {
        min = ?#Nat(1);
        max = ?#Nat(25);
      }, context);
      switch (result2) {
        case (#ok(())) assert(false);
        case (#err(error)) {
          Debug.print("✅ Out of range value rejected: " # ICRC16.formatError(error));
        };
      };
    });

    await test("Structure validation", func() : async () {
      let context = ICRC16.createContext("test", 5);
      
      // Valid structure
      let properties : [PropertyShared] = [
        { name = "id"; value = #Nat(123); immutable = true },
        { name = "username"; value = #Text("alice"); immutable = false },
        { name = "active"; value = #Bool(true); immutable = false }
      ];
      
      let result1 = ICRC16.validateStructure(properties, {
        requiredProperties = ["id", "username"];
        optionalProperties = ["active", "email"];
        allowAdditionalProperties = false;
        maxDepth = ?3;
      }, context);
      switch (result1) {
        case (#ok(())) Debug.print("✅ Valid structure accepted");
        case (#err(_)) assert(false);
      };
      
      // Missing required property
      let result2 = ICRC16.validateStructure(properties, {
        requiredProperties = ["id", "username", "email"];
        optionalProperties = ["active"];
        allowAdditionalProperties = false;
        maxDepth = ?3;
      }, context);
      switch (result2) {
        case (#ok(())) assert(false);
        case (#err(errors)) {
          Debug.print("✅ Missing property detected: " # debug_show(errors.size()) # " errors");
        };
      };
    });

    await test("Property access", func() : async () {
      let properties : [PropertyShared] = [
        { name = "id"; value = #Nat(123); immutable = true },
        { name = "username"; value = #Text("alice"); immutable = false }
      ];
      
      // Get existing property
      switch (ICRC16.getProperty(properties, "username")) {
        case (?(#Text(value))) {
          assert(value == "alice");
          Debug.print("✅ Property access working: " # value);
        };
        case (_) assert(false);
      };
      
      // Get non-existing property
      switch (ICRC16.getProperty(properties, "email")) {
        case (null) Debug.print("✅ Non-existing property returns null");
        case (?_) assert(false);
      };
    });

    await test("Context management", func() : async () {
      let rootContext = ICRC16.createContext("root", 5);
      let childContext = ICRC16.childContext(rootContext, "user");
      let grandchildContext = ICRC16.childContext(childContext, "profile");
      
      assert(rootContext.path == "root");
      assert(rootContext.depth == 0);
      assert(childContext.path == "root.user");
      assert(childContext.depth == 1);
      assert(grandchildContext.path == "root.user.profile");
      assert(grandchildContext.depth == 2);
      
      Debug.print("✅ Context management working");
      Debug.print("  Root: " # rootContext.path);
      Debug.print("  Child: " # childContext.path);
      Debug.print("  Grandchild: " # grandchildContext.path);
    });

    Debug.print("✅ All ICRC16 utility tests passed!");
  };
};
