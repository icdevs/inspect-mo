import {test} "mo:test/async";
import CandyTypes "mo:candy/types";
import Debug "mo:core/Debug";

await test("candy library import test", func() : async () {
  Debug.print("Testing candy library import...");
  
  let testCandy : CandyTypes.CandyShared = #Text("test");
  Debug.print("Candy import successful");
  
  // Test basic candy creation and pattern matching
  switch (testCandy) {
    case (#Text(value)) {
      assert value == "test";
      Debug.print("✓ Basic CandyShared creation works");
    };
    case (_) {
      assert false; // Should not reach here
    };
  };
  
  // Test Map variant
  let mapCandy : CandyTypes.CandyShared = #Map([("key1", #Text("value1")), ("key2", #Int(42))]);
  switch (mapCandy) {
    case (#Map(entries)) {
      assert entries.size() == 2;
      Debug.print("✓ Map CandyShared creation works");
    };
    case (_) {
      assert false;
    };
  };
  
  // Test Class variant with PropertyShared
  let propShared : CandyTypes.PropertyShared = {
    name = "test_prop";
    value = #Text("test_value"); 
    immutable = true;
  };
  let classCandy : CandyTypes.CandyShared = #Class([propShared]);
  switch (classCandy) {
    case (#Class(props)) {
      assert props.size() == 1;
      assert props[0].name == "test_prop";
      Debug.print("✓ Class CandyShared creation works");
    };
    case (_) {
      assert false;
    };
  };
  
  // Test ValueMap variant
  let valueMapCandy : CandyTypes.CandyShared = #ValueMap([(#Text("key"), #Int(123))]);
  switch (valueMapCandy) {
    case (#ValueMap(entries)) {
      assert entries.size() == 1;
      Debug.print("✓ ValueMap CandyShared creation works");
    };
    case (_) {
      assert false;
    };
  };
  
  Debug.print("All candy library tests passed!");
});
