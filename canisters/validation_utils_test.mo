import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import ValidationUtils "../src/utils/validation_utils";
import CoreTypes "../src/migrations/v000_001_000/types";

persistent actor ValidationUtilsTestCanister {

  type ValidationRule<T, M> = CoreTypes.ValidationRule<T, M>;

  // Simple text-only tests
  func createTextAccessor() : { text: Text } -> Text {
    func(item: { text: Text }) : Text = item.text
  };

  // Test result tracking
  private stable var testResults: [Text] = [];

  func recordTest(testName: Text, success: Bool, message: Text) {
    let result = testName # ": " # (if (success) "PASSED" else "FAILED") # " - " # message;
    testResults := Array.append(testResults, [result]);
    Debug.print(result);
  };

  // Test functions
  public func testAppendValidationRules() : async Bool {
    let baseRules: [ValidationRule<{ text: Text }, { text: Text }>] = [
      #textSize(createTextAccessor(), ?1, null)
    ];
    let newRule: ValidationRule<{ text: Text }, { text: Text }> = #textSize(createTextAccessor(), null, ?100);
    
    let combined = ValidationUtils.appendValidationRule(baseRules, newRule);
    
    if (combined.size() != 2) {
      recordTest("appendValidationRules", false, "Expected 2 rules, got " # Nat.toText(combined.size()));
      return false;
    };
    
    // Test with empty base
    let emptyBase: [ValidationRule<{ text: Text }, { text: Text }>] = [];
    let combinedFromEmpty = ValidationUtils.appendValidationRule(emptyBase, newRule);
    if (combinedFromEmpty.size() != 1) {
      recordTest("appendValidationRules", false, "Expected 1 rule when appending to empty, got " # Nat.toText(combinedFromEmpty.size()));
      return false;
    };
    
    recordTest("appendValidationRules", true, "All append tests passed");
    return true;
  };

  public func testCombineValidationRules() : async Bool {
    let rules1: [ValidationRule<{ text: Text }, { text: Text }>] = [
      #textSize(createTextAccessor(), ?1, null)
    ];
    let rules2: [ValidationRule<{ text: Text }, { text: Text }>] = [
      #textSize(createTextAccessor(), null, ?100),
      #textSize(createTextAccessor(), ?5, ?50)
    ];
    let rules3: [ValidationRule<{ text: Text }, { text: Text }>] = [
      #textSize(createTextAccessor(), ?10, null)
    ];
    
    let combined = ValidationUtils.combineValidationRules([rules1, rules2, rules3]);
    if (combined.size() != 4) {
      recordTest("combineValidationRules", false, "Expected 4 rules, got " # Nat.toText(combined.size()));
      return false;
    };
    
    // Test with empty arrays mixed in
    let empty: [ValidationRule<{ text: Text }, { text: Text }>] = [];
    let combinedWithEmpty = ValidationUtils.combineValidationRules([empty, rules1, empty]);
    if (combinedWithEmpty.size() != 1) {
      recordTest("combineValidationRules", false, "Expected 1 rule with empty arrays, got " # Nat.toText(combinedWithEmpty.size()));
      return false;
    };
    
    recordTest("combineValidationRules", true, "All combine tests passed");
    return true;
  };

  public func testValidationRuleBuilder() : async Bool {
    let builder = ValidationUtils.ValidationRuleBuilder<{ text: Text }, { text: Text }>();
    
    // Test adding text size rule
    builder.textSize(createTextAccessor(), ?1, ?100);
    let rules1 = builder.build();
    if (rules1.size() != 1) {
      recordTest("ValidationRuleBuilder", false, "Expected 1 rule after textSize, got " # Nat.toText(rules1.size()));
      return false;
    };
    
    // Test adding more rules
    builder.textSize(createTextAccessor(), ?5, ?50);
    let rules2 = builder.build();
    if (rules2.size() != 2) {
      recordTest("ValidationRuleBuilder", false, "Expected 2 rules after second textSize, got " # Nat.toText(rules2.size()));
      return false;
    };
    
    recordTest("ValidationRuleBuilder", true, "All builder tests passed");
    return true;
  };

  public func testPredefinedRuleSets() : async Bool {
    // Test basic validation
    let basicRules = ValidationUtils.basicValidation(
      createTextAccessor(),
      ?5,    // min length
      ?100   // max length
    );
    if (basicRules.size() < 2) {
      recordTest("PredefinedRuleSets", false, "Basic validation should have at least 2 rules, got " # Nat.toText(basicRules.size()));
      return false;
    };
    
    recordTest("PredefinedRuleSets", true, "Basic rule set tests passed");
    return true;
  };

  // Public function to run all tests
  public func runAllTests() : async [Text] {
    let test1 = await testAppendValidationRules();
    let test2 = await testCombineValidationRules();  
    let test3 = await testValidationRuleBuilder();
    let test4 = await testPredefinedRuleSets();
    
    let summary = "SUMMARY: " # (if (test1 and test2 and test3 and test4) "ALL TESTS PASSED" else "SOME TESTS FAILED");
    recordTest("Overall", test1 and test2 and test3 and test4, summary);
    
    return testResults;
  };

  // Helper to get current test results
  public query func getTestResults() : async [Text] {
    testResults
  };

  // Helper to clear test results
  public func clearTestResults() : async () {
    testResults := [];
  };
}
