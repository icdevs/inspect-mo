import Bench "mo:bench";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import InspectMo "../src/lib";

module {
  public func init() : Bench.Bench {
    let bench = Bench.Bench();

    bench.name("InspectMo Simple Performance");
    bench.description("Basic performance benchmarks for InspectMo validation functions");

    bench.rows([
      "text_validation_small", 
      "text_validation_large",
      "simple_rule_creation"
    ]);
    
    bench.cols(["100", "1000", "5000"]);

    bench.runner(func(row, col) {
      switch (Nat.fromText(col)) {
        case null { }; 
        case (?n) {
          
          // Test data
          let smallText = "Hello World Test";
          let largeText = "This is a much longer text string that we'll use for testing larger text validation performance. It contains multiple sentences and should give us a good sense of how the validation performs with more substantial content that might be typical in real-world applications.";
          
          if (row == "text_validation_small") {
            // Benchmark small text validation
            for (i in Iter.range(1, n)) {
              ignore InspectMo.validateTextSize(smallText, ?1, ?100);
            };
            
          } else if (row == "text_validation_large") {
            // Benchmark large text validation  
            for (i in Iter.range(1, n)) {
              ignore InspectMo.validateTextSize(largeText, ?1, ?1000);
            };
            
          } else if (row == "simple_rule_creation") {
            // Benchmark simple rule creation and usage
            for (i in Iter.range(1, n)) {
              let rule = InspectMo.textSize(func(x: Text) : Text { x }, ?1, ?100);
              ignore rule;
            };
          };
        };
      };
    });

    bench;
  };
};
