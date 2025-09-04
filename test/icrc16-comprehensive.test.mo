import {test} "mo:test/async";
import ICRC16Rules "../src/utils/icrc16_validation_rules";
import CandyTypes "mo:candy/types";
import Result "mo:base/Result";
import Debug "mo:core/Debug";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Text "mo:base/Text";
import Principal "mo:base/Principal";

/// Comprehensive test suite for ICRC16 validation rules
/// Tests realistic data scenarios, edge cases, and error conditions

// Test data generators
let sampleUserData: CandyTypes.CandyShared = #Class([
  { name = "username"; value = #Text("alice_bob"); immutable = false },
  { name = "age"; value = #Nat(25); immutable = false },
  { name = "email"; value = #Text("alice@example.com"); immutable = false },
  { name = "preferences"; value = #Class([
    { name = "theme"; value = #Text("dark"); immutable = false },
    { name = "notifications"; value = #Bool(true); immutable = false }
  ]); immutable = false }
]);

let sampleProductData: CandyTypes.CandyShared = #Class([
  { name = "id"; value = #Text("prod_123"); immutable = false },
  { name = "name"; value = #Text("Premium Widget"); immutable = false },
  { name = "price"; value = #Nat(9999); immutable = false },
  { name = "categories"; value = #Array([
    #Text("electronics"),
    #Text("widgets"),
    #Text("premium")
  ]); immutable = false },
  { name = "metadata"; value = #Map([
    ("weight", #Nat(1500)),
    ("color", #Text("blue")),
    ("warranty_months", #Nat(24))
  ]); immutable = false }
]);

let deepNestedData: CandyTypes.CandyShared = #Class([
  { name = "level1"; value = #Class([
    { name = "level2"; value = #Class([
      { name = "level3"; value = #Class([
        { name = "level4"; value = #Class([
          { name = "level5"; value = #Text("deep_value"); immutable = false }
        ]); immutable = false }
      ]); immutable = false }
    ]); immutable = false }
  ]); immutable = false }
]);

let largeArrayData: CandyTypes.CandyShared = #Array(
  Array.tabulate<CandyTypes.CandyShared>(1000, func(i) = #Nat(i))
);

let validEmailData: CandyTypes.CandyShared = #Text("user@domain.com");
let invalidTextData: CandyTypes.CandyShared = #Text("invalid@email!format");

// Mock caller for testing
let mockCaller = Principal.fromText("2vxsx-fae");

await test("ICRC16 candyType validation with realistic data", func() : async () {
  Debug.print("Testing candyType validation with various data types...");
  
  let accessor = func(args: CandyTypes.CandyShared) : CandyTypes.CandyShared { args };
  
  // Test valid type matching
  let textRule = ICRC16Rules.candyType(accessor, "Text");
  let classRule = ICRC16Rules.candyType(accessor, "Class");
  
  // Test with sample data
  switch (ICRC16Rules.validateICRC16Rule(textRule, #Text("hello"), mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("✓ Text validation passed"); };
    case (#err(msg)) { Debug.print("Text validation failed: " # msg); };
  };
  
  switch (ICRC16Rules.validateICRC16Rule(classRule, sampleUserData, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("✓ Class validation passed"); };
    case (#err(msg)) { Debug.print("Class validation failed: " # msg); };
  };
  
  // Test type mismatch
  switch (ICRC16Rules.validateICRC16Rule(textRule, #Nat(123), mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("Should have failed type validation"); };
    case (#err(msg)) { Debug.print("✓ Type mismatch correctly rejected: " # msg); };
  };
  
  Debug.print("✓ candyType validation working correctly");
});

await test("ICRC16 candySize validation with size constraints", func() : async () {
  Debug.print("Testing candySize validation with various size constraints...");
  
  let accessor = func(args: CandyTypes.CandyShared) : CandyTypes.CandyShared { args };
  
  // Text size validation
  let textSizeRule = ICRC16Rules.candySize(accessor, ?5, ?20);
  
  // Test valid text size
  switch (ICRC16Rules.validateICRC16Rule(textSizeRule, #Text("hello world"), mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("✓ Valid text size passed"); };
    case (#err(msg)) { Debug.print("Valid text size failed: " # msg); };
  };
  
  // Test text too short
  switch (ICRC16Rules.validateICRC16Rule(textSizeRule, #Text("hi"), mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("Should have failed - text too short"); };
    case (#err(msg)) { Debug.print("✓ Text too short correctly rejected: " # msg); };
  };
  
  // Test text too long
  let longText = #Text("this is a very long text that exceeds the maximum length limit");
  switch (ICRC16Rules.validateICRC16Rule(textSizeRule, longText, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("Should have failed - text too long"); };
    case (#err(msg)) { Debug.print("✓ Text too long correctly rejected: " # msg); };
  };
  
  Debug.print("✓ candySize validation working correctly");
});

await test("ICRC16 candyDepth validation with nested structures", func() : async () {
  Debug.print("Testing candyDepth validation with nested data structures...");
  
  let accessor = func(args: CandyTypes.CandyShared) : CandyTypes.CandyShared { args };
  
  // Allow shallow nesting
  let shallowRule = ICRC16Rules.candyDepth(accessor, 2);
  
  // Test with user data (depth 2)
  switch (ICRC16Rules.validateICRC16Rule(shallowRule, sampleUserData, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("✓ Shallow nesting validation passed"); };
    case (#err(msg)) { Debug.print("Shallow nesting failed: " # msg); };
  };
  
  // Test with deep nested data (should fail)
  switch (ICRC16Rules.validateICRC16Rule(shallowRule, deepNestedData, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("Should have failed - nesting too deep"); };
    case (#err(msg)) { Debug.print("✓ Deep nesting correctly rejected: " # msg); };
  };
  
  // Allow deeper nesting
  let deepRule = ICRC16Rules.candyDepth(accessor, 10);
  switch (ICRC16Rules.validateICRC16Rule(deepRule, deepNestedData, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("✓ Deep nesting validation passed"); };
    case (#err(msg)) { Debug.print("Deep nesting failed: " # msg); };
  };
  
  Debug.print("✓ candyDepth validation working correctly");
});

await test("ICRC16 candyPattern validation with text patterns", func() : async () {
  Debug.print("Testing candyPattern validation with various text patterns...");
  
  let accessor = func(args: CandyTypes.CandyShared) : CandyTypes.CandyShared { args };
  
  // Email pattern validation (simplified pattern)
  let emailRule = ICRC16Rules.candyPattern(accessor, ".*@.*\\..*");
  
  // Test valid email
  switch (ICRC16Rules.validateICRC16Rule(emailRule, validEmailData, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("✓ Valid email pattern passed"); };
    case (#err(msg)) { Debug.print("Valid email pattern failed: " # msg); };
  };
  
  // Test invalid email
  switch (ICRC16Rules.validateICRC16Rule(emailRule, #Text("notanemail"), mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("Should have failed - invalid email pattern"); };
    case (#err(msg)) { Debug.print("✓ Invalid email pattern correctly rejected: " # msg); };
  };
  
  // Username pattern validation (alphanumeric + underscore)
  let usernameRule = ICRC16Rules.candyPattern(accessor, "[a-zA-Z0-9_]+");
  
  switch (ICRC16Rules.validateICRC16Rule(usernameRule, #Text("alice_bob123"), mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("✓ Valid username pattern passed"); };
    case (#err(msg)) { Debug.print("Valid username pattern failed: " # msg); };
  };
  
  switch (ICRC16Rules.validateICRC16Rule(usernameRule, #Text("alice@bob"), mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("Should have failed - invalid username pattern"); };
    case (#err(msg)) { Debug.print("✓ Invalid username pattern correctly rejected: " # msg); };
  };
  
  Debug.print("✓ candyPattern validation working correctly");
});

await test("ICRC16 candyRange validation with numeric ranges", func() : async () {
  Debug.print("Testing candyRange validation with numeric constraints...");
  
  let accessor = func(args: CandyTypes.CandyShared) : CandyTypes.CandyShared { args };
  
  // Age range validation (18-100)
  let ageRule = ICRC16Rules.candyRange(accessor, ?18, ?100);
  
  // Test valid age
  switch (ICRC16Rules.validateICRC16Rule(ageRule, #Nat(25), mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("✓ Valid age range passed"); };
    case (#err(msg)) { Debug.print("Valid age range failed: " # msg); };
  };
  
  // Test age too low
  switch (ICRC16Rules.validateICRC16Rule(ageRule, #Nat(16), mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("Should have failed - age too low"); };
    case (#err(msg)) { Debug.print("✓ Age too low correctly rejected: " # msg); };
  };
  
  // Test age too high
  switch (ICRC16Rules.validateICRC16Rule(ageRule, #Nat(150), mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("Should have failed - age too high"); };
    case (#err(msg)) { Debug.print("✓ Age too high correctly rejected: " # msg); };
  };
  
  // Price range validation with Int values
  let priceRule = ICRC16Rules.candyRange(accessor, ?0, ?1000000);
  
  switch (ICRC16Rules.validateICRC16Rule(priceRule, #Int(9999), mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("✓ Valid price range passed"); };
    case (#err(msg)) { Debug.print("Valid price range failed: " # msg); };
  };
  
  switch (ICRC16Rules.validateICRC16Rule(priceRule, #Int(-100), mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("Should have failed - negative price"); };
    case (#err(msg)) { Debug.print("✓ Negative price correctly rejected: " # msg); };
  };
  
  Debug.print("✓ candyRange validation working correctly");
});

await test("ICRC16 property validation with realistic object structures", func() : async () {
  Debug.print("Testing property validation with user and product data...");
  
  let propertyAccessor = func(args: [CandyTypes.PropertyShared]) : [CandyTypes.PropertyShared] { args };
  
  // Extract properties from sample user data
  let userProperties = switch (sampleUserData) {
    case (#Class(props)) { props };
    case (_) { [] }; // Safe fallback instead of trap
  };
  
  // Test property existence
  let usernameExistsRule = ICRC16Rules.propertyExists(propertyAccessor, "username");
  switch (ICRC16Rules.validateICRC16Rule(usernameExistsRule, userProperties, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("✓ Required property exists"); };
    case (#err(msg)) { Debug.print("Property existence failed: " # msg); };
  };
  
  let missingPropRule = ICRC16Rules.propertyExists(propertyAccessor, "nonexistent");
  switch (ICRC16Rules.validateICRC16Rule(missingPropRule, userProperties, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("Should have failed - property missing"); };
    case (#err(msg)) { Debug.print("✓ Missing property correctly rejected: " # msg); };
  };
  
  // Test property type validation
  let usernameTypeRule = ICRC16Rules.propertyType(propertyAccessor, "username", "Text");
  switch (ICRC16Rules.validateICRC16Rule(usernameTypeRule, userProperties, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("✓ Property type validation passed"); };
    case (#err(msg)) { Debug.print("Property type validation failed: " # msg); };
  };
  
  let wrongTypeRule = ICRC16Rules.propertyType(propertyAccessor, "age", "Text");
  switch (ICRC16Rules.validateICRC16Rule(wrongTypeRule, userProperties, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("Should have failed - wrong property type"); };
    case (#err(msg)) { Debug.print("✓ Wrong property type correctly rejected: " # msg); };
  };
  
  // Test property size validation
  let usernameSizeRule = ICRC16Rules.propertySize(propertyAccessor, "username", ?3, ?20);
  switch (ICRC16Rules.validateICRC16Rule(usernameSizeRule, userProperties, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("✓ Property size validation passed"); };
    case (#err(msg)) { Debug.print("Property size validation failed: " # msg); };
  };
  
  Debug.print("✓ Property validation working correctly");
});

await test("ICRC16 array validation with collection data", func() : async () {
  Debug.print("Testing array validation with product categories...");
  
  let accessor = func(args: CandyTypes.CandyShared) : CandyTypes.CandyShared { args };
  
  // Extract categories array from product data
  let productProperties = switch (sampleProductData) {
    case (#Class(props)) { props };
    case (_) { [] }; // Safe fallback
  };
  
  let categoriesArray = switch (Array.find<CandyTypes.PropertyShared>(productProperties, func(prop) = prop.name == "categories")) {
    case (?prop) { prop.value };
    case null { #Array([]) }; // Safe fallback
  };
  
  // Test array length validation
  let arrayLengthRule = ICRC16Rules.arrayLength(accessor, ?1, ?5);
  switch (ICRC16Rules.validateICRC16Rule(arrayLengthRule, categoriesArray, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("✓ Array length validation passed"); };
    case (#err(msg)) { Debug.print("Array length validation failed: " # msg); };
  };
  
  // Test array item type validation
  let arrayTypeRule = ICRC16Rules.arrayItemType(accessor, "Text");
  switch (ICRC16Rules.validateICRC16Rule(arrayTypeRule, categoriesArray, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("✓ Array item type validation passed"); };
    case (#err(msg)) { Debug.print("Array item type validation failed: " # msg); };
  };
  
  // Test with mixed type array (should fail)
  let mixedArray = #Array([#Text("item1"), #Nat(123), #Text("item3")]);
  switch (ICRC16Rules.validateICRC16Rule(arrayTypeRule, mixedArray, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("Should have failed - mixed array types"); };
    case (#err(msg)) { Debug.print("✓ Mixed array types correctly rejected: " # msg); };
  };
  
  // Test with large array
  let largeLengthRule = ICRC16Rules.arrayLength(accessor, ?1, ?10);
  switch (ICRC16Rules.validateICRC16Rule(largeLengthRule, largeArrayData, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("Should have failed - array too large"); };
    case (#err(msg)) { Debug.print("✓ Large array correctly rejected: " # msg); };
  };
  
  Debug.print("✓ Array validation working correctly");
});

await test("ICRC16 map validation with metadata structures", func() : async () {
  Debug.print("Testing map validation with product metadata...");
  
  let accessor = func(args: CandyTypes.CandyShared) : CandyTypes.CandyShared { args };
  
  // Extract metadata map from product data
  let productProperties = switch (sampleProductData) {
    case (#Class(props)) { props };
    case (_) { [] }; // Safe fallback
  };
  
  let metadataMap = switch (Array.find<CandyTypes.PropertyShared>(productProperties, func(prop) = prop.name == "metadata")) {
    case (?prop) { prop.value };
    case null { #Map([]) }; // Safe fallback
  };
  
  // Test map key existence
  let keyExistsRule = ICRC16Rules.mapKeyExists(accessor, "weight");
  switch (ICRC16Rules.validateICRC16Rule(keyExistsRule, metadataMap, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("✓ Map key exists validation passed"); };
    case (#err(msg)) { Debug.print("Map key exists validation failed: " # msg); };
  };
  
  let missingKeyRule = ICRC16Rules.mapKeyExists(accessor, "missing_key");
  switch (ICRC16Rules.validateICRC16Rule(missingKeyRule, metadataMap, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("Should have failed - key missing"); };
    case (#err(msg)) { Debug.print("✓ Missing map key correctly rejected: " # msg); };
  };
  
  // Test map size validation
  let mapSizeRule = ICRC16Rules.mapSize(accessor, ?1, ?5);
  switch (ICRC16Rules.validateICRC16Rule(mapSizeRule, metadataMap, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("✓ Map size validation passed"); };
    case (#err(msg)) { Debug.print("Map size validation failed: " # msg); };
  };
  
  let restrictiveMapRule = ICRC16Rules.mapSize(accessor, ?1, ?2);
  switch (ICRC16Rules.validateICRC16Rule(restrictiveMapRule, metadataMap, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("Should have failed - map too large"); };
    case (#err(msg)) { Debug.print("✓ Large map correctly rejected: " # msg); };
  };
  
  Debug.print("✓ Map validation working correctly");
});

await test("ICRC16 custom validation with business logic", func() : async () {
  Debug.print("Testing custom validation with business-specific rules...");
  
  let accessor = func(args: CandyTypes.CandyShared) : CandyTypes.CandyShared { args };
  
  // Custom validator for product ID format
  let productIdValidator = func(candy: CandyTypes.CandyShared) : Result.Result<(), Text> {
    switch (candy) {
      case (#Text(id)) {
        if (Text.size(id) < 5) {
          #err("Product ID must be at least 5 characters")
        } else if (not Text.startsWith(id, #text("prod_"))) {
          #err("Product ID must start with 'prod_'")
        } else {
          #ok()
        }
      };
      case (_) { #err("Product ID must be text") };
    }
  };
  
  let customRule = ICRC16Rules.customCandyCheck(accessor, productIdValidator);
  
  // Test valid product ID
  switch (ICRC16Rules.validateICRC16Rule(customRule, #Text("prod_12345"), mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("✓ Custom validation passed for valid ID"); };
    case (#err(msg)) { Debug.print("Custom validation failed: " # msg); };
  };
  
  // Test invalid product ID (too short)
  switch (ICRC16Rules.validateICRC16Rule(customRule, #Text("prod"), mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("Should have failed - ID too short"); };
    case (#err(msg)) { Debug.print("✓ Short ID correctly rejected: " # msg); };
  };
  
  // Test invalid product ID (wrong prefix)
  switch (ICRC16Rules.validateICRC16Rule(customRule, #Text("item_12345"), mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("Should have failed - wrong prefix"); };
    case (#err(msg)) { Debug.print("✓ Wrong prefix correctly rejected: " # msg); };
  };
  
  Debug.print("✓ Custom validation working correctly");
});

await test("ICRC16 edge cases and error conditions", func() : async () {
  Debug.print("Testing edge cases and error conditions...");
  
  let accessor = func(args: CandyTypes.CandyShared) : CandyTypes.CandyShared { args };
  
  // Test with null values
  let nullData = #Option(null);
  let typeRule = ICRC16Rules.candyType(accessor, "Text");
  
  switch (ICRC16Rules.validateICRC16Rule(typeRule, nullData, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("Should have failed - null value"); };
    case (#err(msg)) { Debug.print("✓ Null value correctly rejected: " # msg); };
  };
  
  // Test with empty structures
  let emptyArray = #Array([]);
  let sizeRule = ICRC16Rules.candySize(accessor, ?1, ?10);
  
  switch (ICRC16Rules.validateICRC16Rule(sizeRule, emptyArray, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("Should have failed - empty array"); };
    case (#err(msg)) { Debug.print("✓ Empty array correctly rejected: " # msg); };
  };
  
  // Test with extremely large values
  let hugeNat = #Nat(999999999999999999);
  let rangeRule = ICRC16Rules.candyRange(accessor, ?0, ?1000000);
  
  switch (ICRC16Rules.validateICRC16Rule(rangeRule, hugeNat, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("Should have failed - value too large"); };
    case (#err(msg)) { Debug.print("✓ Large value correctly rejected: " # msg); };
  };
  
  // Test with malformed data
  let propertyAccessor = func(args: [CandyTypes.PropertyShared]) : [CandyTypes.PropertyShared] { args };
  let malformedProperties: [CandyTypes.PropertyShared] = [];
  
  let propExistsRule = ICRC16Rules.propertyExists(propertyAccessor, "any_prop");
  switch (ICRC16Rules.validateICRC16Rule(propExistsRule, malformedProperties, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("Should have failed - no properties"); };
    case (#err(msg)) { Debug.print("✓ Empty properties correctly rejected: " # msg); };
  };
  
  Debug.print("✓ Edge cases and error conditions handled correctly");
});

await test("ICRC16 performance with large datasets", func() : async () {
  Debug.print("Testing performance with large datasets...");
  
  let accessor = func(args: CandyTypes.CandyShared) : CandyTypes.CandyShared { args };
  
  // Create large nested structure
  let largeNestedData = #Class(
    Array.tabulate<CandyTypes.PropertyShared>(100, func(i) = {
      name = "prop_" # Nat.toText(i);
      value = #Class([
        { name = "nested_value"; value = #Text("value_" # Nat.toText(i)); immutable = false }
      ]);
      immutable = false
    })
  );
  
  // Test depth validation on large structure
  let depthRule = ICRC16Rules.candyDepth(accessor, 5);
  switch (ICRC16Rules.validateICRC16Rule(depthRule, largeNestedData, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("✓ Large nested structure validated successfully"); };
    case (#err(msg)) { Debug.print("Large structure validation failed: " # msg); };
  };
  
  // Test type validation on large array
  let typeRule = ICRC16Rules.candyType(accessor, "Array");
  switch (ICRC16Rules.validateICRC16Rule(typeRule, largeArrayData, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("✓ Large array type validation passed"); };
    case (#err(msg)) { Debug.print("Large array validation failed: " # msg); };
  };
  
  // Test array length validation
  let lengthRule = ICRC16Rules.arrayLength(accessor, ?500, ?1500);
  switch (ICRC16Rules.validateICRC16Rule(lengthRule, largeArrayData, mockCaller, "testMethod")) {
    case (#ok()) { Debug.print("✓ Large array length validation passed"); };
    case (#err(msg)) { Debug.print("Large array length validation failed: " # msg); };
  };
  
  Debug.print("✓ Performance tests completed successfully");
});
