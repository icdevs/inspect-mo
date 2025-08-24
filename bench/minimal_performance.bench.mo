import Bench "mo:bench";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";

module {
  public func init() : Bench.Bench {
    let bench = Bench.Bench();

    bench.name("Minimal Performance Test");
    bench.description("Very basic performance benchmark to test setup");

    bench.rows([
      "simple_loop"
    ]);
    
    bench.cols(["100", "1000"]);

    bench.runner(func(row, col) {
      switch (Nat.fromText(col)) {
        case null { };
        case (?n) {
          if (row == "simple_loop") {
            // Simple arithmetic loop
            var sum = 0;
            for (i in Iter.range(1, n)) {
              sum += i;
            };
            ignore sum;
          };
        };
      };
    });

    bench;
  };
};
