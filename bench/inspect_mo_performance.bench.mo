import Bench "mo:bench";
import Nat "mo:base/Nat";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Array "mo:base/Array";
import InspectMo "../src/lib";

module {
  public func init() : Bench.Bench {
    let bench = Bench.Bench();

    bench.name("InspectMo Performance Benchmarks");
    bench.description("Comprehensive performance testing for InspectMo validation rules");

    // Test different scales: small, medium, large data sets
    bench.rows([
      "inspector_creation",
      "text_size_validation_small", 
      "text_size_validation_large",
      "blob_size_validation_small",
      "blob_size_validation_large", 
      "auth_validation",
      "permission_validation",
      "inspect_check_simple",
      "inspect_check_complex",
      "guard_check_simple",
      "guard_check_complex",
      "rule_registration",
      "multiple_rules_chain"
    ]);
    
    // Different iteration counts for performance scaling
    bench.cols(["100", "1000", "10000"]);

    bench.runner(func(row, col) {
      switch (Nat.fromText(col)) {
        case null { return }; // Skip invalid column values
        case (?n) {
          
          // Setup test data
          let testUser = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
          let testCanister = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");
          let smallText = "Hello World";
          let largeText = Text.join("", Iter.fromArray(Array.tabulate<Text>(1000, func(i) = "Large text content for performance testing. ")));
          let smallBlob : Blob = Text.encodeUtf8("Small blob data");
          let largeBlob : Blob = Text.encodeUtf8(largeText);
          
          // Test Args type for ErasedValidator
          type TestArgs = {
            #SimpleText: Text;
            #LargeText: Text;
            #SimpleBlob: Blob;
            #LargeBlob: Blob;
            #None: ();
          };
          
          // Create InspectMo instance for testing
          let defaultConfig = {
            supportAudit = false;
            supportTimer = false;
            supportAdvanced = false;
          };
          
          let inspectMo = InspectMo.InspectMo(
            null,
            testUser,
            testCanister,
            ?defaultConfig,
            null,
            func(state: InspectMo.State) {}
          );
          
          let inspector = inspectMo.createInspector<TestArgs>();
          
          // Test scenarios
          if (row == "inspector_creation") {
            // Benchmark Inspector creation overhead
            for (i in Iter.range(1, n)) {
              let inspector = InspectMo.InspectMo(
                null,
                testUser,
                testCanister,
                ?config,
                null,
                func(state: InspectMo.State) {}
              );
              ignore inspector.createInspector();
            };
            
          } else if (row == "text_size_validation_small") {
            // Benchmark small text size validation
            let inspector = InspectMo.InspectMo(null, testUser, testCanister, ?config, null, func(state: InspectMo.State) {});
            let inst = inspector.createInspector();
            
            for (i in Iter.range(1, n)) {
              ignore InspectMo.validateTextSize(smallText, ?1, ?100);
            };
            
          } else if (row == "text_size_validation_large") {
            // Benchmark large text size validation  
            let inspector = InspectMo.InspectMo(null, testUser, testCanister, ?config, null, func(state: InspectMo.State) {});
            let inst = inspector.createInspector();
            
            for (i in Iter.range(1, n)) {
              ignore InspectMo.validateTextSize(largeText, ?1, ?100000);
            };
            
          } else if (row == "blob_size_validation_small") {
            // Benchmark small blob size validation
            let inspector = InspectMo.InspectMo(null, testUser, testCanister, ?config, null, func(state: InspectMo.State) {});
            let inst = inspector.createInspector();
            
            for (i in Iter.range(1, n)) {
              ignore InspectMo.validateBlobSize(smallBlob, ?1, ?100);
            };
            
          } else if (row == "blob_size_validation_large") {
            // Benchmark large blob size validation
            let inspector = InspectMo.InspectMo(null, testUser, testCanister, ?config, null, func(state: InspectMo.State) {});
            let inst = inspector.createInspector();
            
            for (i in Iter.range(1, n)) {
              ignore InspectMo.validateBlobSize(largeBlob, ?1, ?100000);
            };
            
          } else if (row == "auth_validation") {
            // Benchmark authentication validation
            let inspector = InspectMo.InspectMo(null, testUser, testCanister, ?config, null, func(state: InspectMo.State) {});
            let inst = inspector.createInspector();
            
            let authRule = InspectMo.requireAuth();
            
            for (i in Iter.range(1, n)) {
              let inspectArgs : InspectMo.InspectArgs = {
                caller = testUser;
                arg = Text.encodeUtf8("test");
                methodName = "test_method";
                isQuery = false;
                msg = smallText;
                isIngress = true;
                parsedArgs = ?smallText;
                argSizes = [Text.size(smallText)];
                argTypes = [];
              };
              ignore inst.validateInspectRule(authRule, inspectArgs);
            };
            
          } else if (row == "permission_validation") {
            // Benchmark permission validation
            let inspector = InspectMo.InspectMo(null, testUser, testCanister, ?config, null, func(state: InspectMo.State) {});
            let inst = inspector.createInspector();
            
            let permRule = InspectMo.requirePermission("read");
            
            for (i in Iter.range(1, n)) {
              let inspectArgs : InspectMo.InspectArgs = {
                caller = testUser;
                arg = Text.encodeUtf8("test");
                methodName = "test_method";
                isQuery = false;
                msg = smallText;
                isIngress = true;
                parsedArgs = ?smallText;
                argSizes = [Text.size(smallText)];
                argTypes = [];
              };
              ignore inst.validateInspectRule(permRule, inspectArgs);
            };
            
          } else if (row == "inspect_check_simple") {
            // Benchmark simple inspect check with one rule
            let inspector = InspectMo.InspectMo(null, testUser, testCanister, ?config, null, func(state: InspectMo.State) {});
            let inst = inspector.createInspector();
            
            // Register a simple text size rule
            ignore inst.inspect("test_method", [
              InspectMo.textSize(func(x: Text) : Text { x }, ?1, ?100)
            ]);
            
            for (i in Iter.range(1, n)) {
              let inspectArgs : InspectMo.InspectArgs = {
                caller = testUser;
                arg = Text.encodeUtf8(smallText);
                methodName = "test_method";
                isQuery = false;
                msg = smallText;
                isIngress = true;
                parsedArgs = ?smallText;
                argSizes = [Text.size(smallText)];
                argTypes = [];
              };
              ignore inst.inspectCheck(inspectArgs);
            };
            
          } else if (row == "inspect_check_complex") {
            // Benchmark complex inspect check with multiple rules
            let inspector = InspectMo.InspectMo(null, testUser, testCanister, ?config, null, func(state: InspectMo.State) {});
            let inst = inspector.createInspector();
            
            // Register multiple rules
            ignore inst.inspect("test_method", [
              InspectMo.textSize(func(x: Text) : Text { x }, ?1, ?100),
              InspectMo.requireAuth(),
              InspectMo.requirePermission("read")
            ]);
            
            for (i in Iter.range(1, n)) {
              let inspectArgs : InspectMo.InspectArgs = {
                caller = testUser;
                arg = Text.encodeUtf8(smallText);
                methodName = "test_method";
                isQuery = false;
                msg = smallText;
                isIngress = true;
                parsedArgs = ?smallText;
                argSizes = [Text.size(smallText)];
                argTypes = [];
              };
              ignore inst.inspectCheck(inspectArgs);
            };
            
          } else if (row == "guard_check_simple") {
            // Benchmark simple guard check
            let inspector = InspectMo.InspectMo(null, testUser, testCanister, ?config, null, func(state: InspectMo.State) {});
            let inst = inspector.createInspector();
            
            ignore inst.guard("test_method", [
              InspectMo.textSizeCheck(func(x: Text) : Text { x }, ?1, ?100)
            ]);
            
            for (i in Iter.range(1, n)) {
              ignore inst.guardCheck("test_method", smallText, testUser, null, null);
            };
            
          } else if (row == "guard_check_complex") {
            // Benchmark complex guard check with custom logic
            let inspector = InspectMo.InspectMo(null, testUser, testCanister, ?config, null, func(state: InspectMo.State) {});
            let inst = inspector.createInspector();
            
            ignore inst.guard("test_method", [
              InspectMo.customCheck(func(args: InspectMo.CustomCheckArgs<Text>) : InspectMo.GuardResult {
                if (Text.size(args.args) < 5) {
                  #err("Too short")
                } else {
                  #ok
                }
              })
            ]);
            
            for (i in Iter.range(1, n)) {
              ignore inst.guardCheck("test_method", smallText, testUser, null, null);
            };
            
          } else if (row == "rule_registration") {
            // Benchmark rule registration performance
            let inspector = InspectMo.InspectMo(null, testUser, testCanister, ?config, null, func(state: InspectMo.State) {});
            let inst = inspector.createInspector();
            
            for (i in Iter.range(1, n)) {
              ignore inst.inspect("method_" # Nat.toText(i), [
                InspectMo.textSize(func(x: Text) : Text { x }, ?1, ?100)
              ]);
            };
            
          } else if (row == "multiple_rules_chain") {
            // Benchmark performance with many rules on one method
            let inspector = InspectMo.InspectMo(null, testUser, testCanister, ?config, null, func(state: InspectMo.State) {});
            let inst = inspector.createInspector();
            
            // Create a method with many rules
            let rules = [
              InspectMo.textSize(func(x: Text) : Text { x }, ?1, ?1000),
              InspectMo.requireAuth(),
              InspectMo.requirePermission("read"),
              InspectMo.requirePermission("write"),
              InspectMo.requirePermission("admin")
            ];
            
            ignore inst.inspect("complex_method", rules);
            
            for (i in Iter.range(1, n)) {
              let inspectArgs : InspectMo.InspectArgs = {
                caller = testUser;
                arg = Text.encodeUtf8(smallText);
                methodName = "complex_method";
                isQuery = false;
                msg = smallText;
                isIngress = true;
                parsedArgs = ?smallText;
                argSizes = [Text.size(smallText)];
                argTypes = [];
              };
              ignore inst.inspectCheck(inspectArgs);
            };
          };
        };
      };
    });

    bench;
  };
};
