// Simple validation test for ValidationRule Array Utilities
import Debug "mo:base/Debug";
import Array "mo:base/Array";
import CandyTypes "mo:candy/types";
import ValidationUtils "../src/utils/validation_utils";
import MigrationTypes "../src/migrations/types";

persistent actor ValidationUtilsTest {

  type ValidationRule<T, M> = MigrationTypes.Current.ValidationRule<T, M>;

  // Test utilities and stubs
  func sampleMetadata() : CandyTypes.CandyShared {
    #Class([
      {name = "name"; value = #Text("TestItem"); immutable = false},
      {name = "description"; value = #Text("A test item for validation"); immutable = false},
      {name = "version"; value = #Nat(1); immutable = false}
    ])
  };

  func createTextAccessor() : { text: Text } -> Text {
    func(item: { text: Text }) : Text = item.text
  };

  func createMetadataAccessor() : { metadata: CandyTypes.CandyShared } -> CandyTypes.CandyShared {
    func(item: { metadata: CandyTypes.CandyShared }) : CandyTypes.CandyShared = item.metadata
  };

  // Simple test runner
  func assertTest(condition: Bool, message: Text) {
    if (not condition) {
      Debug.print("FAILED: " # message);
      Debug.trap(message);
    } else {
      Debug.print("PASSED: " # message);
    }
  };

  // Test functions
  func testAppendValidationRules() {
    Debug.print("Testing appendValidationRules...");
    
    let baseRules: [ValidationRule<{ text: Text }, { text: Text }>] = [
      #textSize(createTextAccessor(), ?1, null)
    ];
    let newRule: ValidationRule<{ text: Text }, { text: Text }> = #textSize(createTextAccessor(), null, ?100);
    
    let combined = ValidationUtils.appendValidationRule<{ text: Text }, { text: Text }>(baseRules, newRule);
    
    assertTest(combined.size() == 2, "Should have 2 rules after append");
    
    // Test with empty base
    let emptyBase: [ValidationRule<{ text: Text }, { text: Text }>] = [];
    let combinedFromEmpty = ValidationUtils.appendValidationRule<{ text: Text }, { text: Text }>(emptyBase, newRule);
    assertTest(combinedFromEmpty.size() == 1, "Should have 1 rule when appending to empty array");
    
    Debug.print("appendValidationRules tests completed");
  };

  func testCombineValidationRules() {
    Debug.print("Testing combineValidationRules...");
    
    let rules1: [ValidationRule<{ text: Text }, { text: Text }>] = [
      #textSize(createTextAccessor(), ?1, null)
    ];
    let rules2: [ValidationRule<{ text: Text }, { text: Text }>] = [
      #textSize(createTextAccessor(), null, ?100),
      #requireAuth
    ];
    let rules3: [ValidationRule<{ text: Text }, { text: Text }>] = [
      #textSize(createTextAccessor(), ?5, ?50)
    ];
    
    let combined = ValidationUtils.combineValidationRules([rules1, rules2, rules3]);
    assertTest(combined.size() == 4, "Should combine all rules from arrays");
    
    // Test with empty arrays
    let empty: [ValidationRule<{ text: Text }, { text: Text }>] = [];
    let combinedWithEmpty = ValidationUtils.combineValidationRules([empty, rules1, empty]);
    assertTest(combinedWithEmpty.size() == 1, "Should handle empty arrays correctly");
    
    Debug.print("combineValidationRules tests completed");
  };

  func testValidationRuleBuilder() {
    Debug.print("Testing ValidationRuleBuilder...");
    
    let builder = ValidationUtils.ValidationRuleBuilder<{ text: Text; size: Nat }, { text: Text; size: Nat }>();
    
    builder.textSize(createTextAccessor(), ?1, null);
    builder.textSize(createTextAccessor(), null, ?100);
    let rules = builder.build();
    
    assertTest(rules.size() == 2, "Builder should create correct number of rules");
    
    // Test empty builder
    let emptyBuilder = ValidationUtils.ValidationRuleBuilder<{ text: Text }, { text: Text }>();
    let emptyRules = emptyBuilder.build();
    assertTest(emptyRules.size() == 0, "Empty builder should produce no rules");
    
    Debug.print("ValidationRuleBuilder tests completed");
  };

  func testPredefinedRuleSets() {
    Debug.print("Testing predefined rule sets...");
    
    // Test basic validation
    let basicRules = ValidationUtils.basicValidation(
      createTextAccessor(),
      ?5,    // min length
      ?100   // max length
    );
    assertTest(basicRules.size() >= 2, "Basic validation should have at least 2 rules");
    
    // Test ICRC16 metadata validation
    let icrc16Rules = ValidationUtils.icrc16MetadataValidation(
      createMetadataAccessor(),
      ?1000,  // max size
      5       // max depth
    );
    assertTest(icrc16Rules.size() >= 3, "ICRC16 validation should have at least 3 rules");
    
    // Test comprehensive validation
    let comprehensiveRules = ValidationUtils.comprehensiveValidation(
      createTextAccessor(),
      createMetadataAccessor(),
      ?1,     // min text length
      ?200,   // max text length
      ?2000,  // max metadata size
      10      // max metadata depth
    );
    assertTest(comprehensiveRules.size() >= 5, "Comprehensive validation should have at least 5 rules");
    
    Debug.print("Predefined rule sets tests completed");
  };

  // Main test execution
  public func runTests() : async () {
    Debug.print("Starting ValidationRule Array Utilities tests...");
    
    testAppendValidationRules();
    testCombineValidationRules();
    testValidationRuleBuilder();
    testPredefinedRuleSets();
    
    Debug.print("All ValidationRule Array Utilities tests completed successfully!");
  };
}
