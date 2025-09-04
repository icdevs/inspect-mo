import Bench "mo:bench";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Text "mo:base/Text";
import ValidationUtils "../src/utils/validation_utils";
import CoreTypes "../src/migrations/v000_001_000/types";

module {
  public func init() : Bench.Bench {
    let bench = Bench.Bench();

    bench.name("ValidationRule Array Utilities Performance");
    bench.description("Performance benchmarks for ValidationRule Array Utilities - appendValidationRule, combineValidationRules, and ValidationRuleBuilder");

    bench.rows([
      "append_single_rule",
      "append_to_large_array", 
      "combine_small_arrays",
      "combine_large_arrays",
      "builder_pattern_small",
      "builder_pattern_large",
      "predefined_basic_rules",
      "array_size_scaling"
    ]);
    
    bench.cols(["10", "100", "1000"]);

    bench.runner(func(row, col) {
      switch (Nat.fromText(col)) {
        case null { }; 
        case (?n) {
          
          // Test types and accessor function
          type TestData = { text: Text };
          type TestMetadata = { text: Text };
          type TestValidationRule = CoreTypes.ValidationRule<TestData, TestMetadata>;
          
          func createTextAccessor() : TestData -> Text {
            func(item: TestData) : Text = item.text
          };
          
          // Create test rules for benchmarking
          func createTestRule(id: Nat) : TestValidationRule {
            #textSize(createTextAccessor(), ?id, ?(id * 100))
          };
          
          // Create array of test rules
          func createTestRuleArray(size: Nat) : [TestValidationRule] {
            Array.tabulate<TestValidationRule>(size, func(i) = createTestRule(i))
          };
          
          if (row == "append_single_rule") {
            // Benchmark: Append single rule to arrays of different sizes
            let baseRules = createTestRuleArray(n);
            let newRule = createTestRule(9999);
            
            for (i in Iter.range(0, 100)) {
              let _ = ValidationUtils.appendValidationRule(baseRules, newRule);
            };
          }
          else if (row == "append_to_large_array") {
            // Benchmark: Append to progressively larger arrays
            let baseRules = createTestRuleArray(n * 10); // Scale up base array size
            let newRule = createTestRule(9999);
            
            for (i in Iter.range(0, 50)) {
              let _ = ValidationUtils.appendValidationRule(baseRules, newRule);
            };
          }
          else if (row == "combine_small_arrays") {
            // Benchmark: Combine multiple small arrays
            let arrayCount = n / 10; // Number of arrays to combine
            let arraySize = 5; // Small arrays
            let arrays = Array.tabulate<[TestValidationRule]>(
              arrayCount, 
              func(i) = createTestRuleArray(arraySize)
            );
            
            for (i in Iter.range(0, 100)) {
              let _ = ValidationUtils.combineValidationRules(arrays);
            };
          }
          else if (row == "combine_large_arrays") {
            // Benchmark: Combine fewer but larger arrays
            let arrayCount = n / 100; // Fewer arrays
            let arraySize = n; // Larger arrays
            let arrays = Array.tabulate<[TestValidationRule]>(
              arrayCount, 
              func(i) = createTestRuleArray(arraySize)
            );
            
            for (i in Iter.range(0, 20)) {
              let _ = ValidationUtils.combineValidationRules(arrays);
            };
          }
          else if (row == "builder_pattern_small") {
            // Benchmark: Builder pattern with small number of rules
            let iterations = n;
            
            for (i in Iter.range(0, 50)) {
              let builder = ValidationUtils.ValidationRuleBuilder<TestData, TestMetadata>();
              
              for (j in Iter.range(0, iterations / 10)) {
                builder.textSize(createTextAccessor(), ?j, ?(j * 10));
              };
              
              let _ = builder.build();
            };
          }
          else if (row == "builder_pattern_large") {
            // Benchmark: Builder pattern with larger number of rules
            let iterations = n;
            
            for (i in Iter.range(0, 10)) {
              let builder = ValidationUtils.ValidationRuleBuilder<TestData, TestMetadata>();
              
              for (j in Iter.range(0, iterations)) {
                builder.textSize(createTextAccessor(), ?j, ?(j * 10));
              };
              
              let _ = builder.build();
            };
          }
          else if (row == "predefined_basic_rules") {
            // Benchmark: Predefined rule sets creation
            for (i in Iter.range(0, n)) {
              let _ = ValidationUtils.basicValidation(
                createTextAccessor(),
                ?1,
                ?(i * 100)
              );
            };
          }
          else if (row == "array_size_scaling") {
            // Benchmark: How operations scale with array size
            let baseSize = n;
            let rules1 = createTestRuleArray(baseSize);
            let rules2 = createTestRuleArray(baseSize);
            let rules3 = createTestRuleArray(baseSize);
            
            for (i in Iter.range(0, 20)) {
              // Test both append and combine operations
              let combined = ValidationUtils.combineValidationRules([rules1, rules2]);
              let _ = ValidationUtils.appendValidationRule(combined, createTestRule(i));
            };
          };
        };
      };
    });

    bench
  }
}
