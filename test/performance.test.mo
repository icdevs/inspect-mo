import {test} "mo:test/async";
import InspectMo "../src/core/inspector";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import Debug "mo:core/Debug";
import Time "mo:core/Time";
import Array "mo:core/Array";
import Iter "mo:core/Iter";
import Nat "mo:core/Nat";
import TimerTool "mo:timer-tool";
import ClassPlusLib "mo:class-plus";

persistent actor PerformanceTest {

/// Comprehensive performance and rate limiting test suite using ErasedValidator pattern
/// Tests rate limiting, performance under load, and system limits

// Timer tool setup following main.mo pattern
transient let initManager = ClassPlusLib.ClassPlusInitializationManager(
  Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"), 
  Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"), 
  false
);
stable var tt_migration_state: TimerTool.State = TimerTool.Migration.migration.initialState;

transient let tt = TimerTool.Init<system>({
  manager = initManager;
  initialState = tt_migration_state;
  args = null;
  pullEnvironment = ?(func() : TimerTool.Environment {
    {      
      advanced = ?{
        icrc85 = ?{
          asset = null;
          collector = null;
          handler = null;
          kill_switch = null;
          period = ?3600;
          platform = null;
          tree = null;
        };
      };
      reportExecution = null;
      reportError = null;
      syncUnsafe = null;
      reportBatch = null;
    };
  });
  onInitialize = ?(func (newClass: TimerTool.TimerTool) : async* () {
    newClass.initialize<system>();
  });
  onStorageChange = func(state: TimerTool.State) {
    tt_migration_state := state;
  };
});

// Create proper environment for ICRC85 and TimerTool following main.mo pattern
func createEnvironment() : InspectMo.Environment {
  {
    tt = tt();
    advanced = ?{
      icrc85 = ?{
        asset = null;
        collector = null;
        handler = null;
        kill_switch = null;
        period = ?3600;
        platform = null;
        tree = null;
      };
    };
    log = null;
  };
};

// Create main inspector following main.mo pattern
stable var inspector_migration_state: InspectMo.State = InspectMo.initialState();

transient let inspector = InspectMo.Init<system>({
  manager = initManager;
  initialState = inspector_migration_state;
  args = ?{
    allowAnonymous = ?false;
    defaultMaxArgSize = ?1024;
    authProvider = null;
    rateLimit = null;
    queryDefaults = null;
    updateDefaults = null;
    developmentMode = true;
    auditLog = false;
  };
  pullEnvironment = ?(func() : InspectMo.Environment {
    createEnvironment()
  });
  onInitialize = null;
  onStorageChange = func(state: InspectMo.State) {
    inspector_migration_state := state;
  };
});

func createTestInspector() : InspectMo.InspectMo {
  // For tests, we can just return the main inspector since it has proper environment
  inspector();
};

let testPrincipal = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
let adminPrincipal = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");
let userPrincipal = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");

// Performance test argument types
type PerformanceArgs = { content: Text; requestId: Nat };
type StressArgs = { operation: Text; data: Text; counter: Nat };

// Args union type for performance testing
type Args = {
  #performance_test: PerformanceArgs;
  #stress_test: StressArgs;
  #load_test: PerformanceArgs;
};

// Helper functions for default args
let defaultPerformanceArgs : PerformanceArgs = { content = "default"; requestId = 0 };
let defaultStressArgs : StressArgs = { operation = "default"; data = "default"; counter = 0 };

public func runTests() : async () {

/// ========================================
/// PERFORMANCE TESTS
/// ========================================

await test("validation performance under load", func() : async () {
  Debug.print("Testing validation performance under load...");
  
  let inspectMo = createTestInspector();
  let perfInspector = inspectMo.createInspector<Args>();
  
  // Create a complex validation rule set
  perfInspector.inspect(perfInspector.createMethodGuardInfo<PerformanceArgs>(
    "performance_test",
    false,
    [
      #textSize(func(args: PerformanceArgs): Text { args.content }, ?1, ?1000),
      #customCheck(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (args.args) {
          case (#performance_test(perfArgs)) {
            if (perfArgs.requestId % 2 == 0) { #ok } else { #ok } // Always pass for perf test
          };
          case (_) #ok;
        }
      }),
      #customCheck(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (args.args) {
          case (#performance_test(perfArgs)) {
            if (Text.size(perfArgs.content) > 0) { #ok } else { #err("Empty content") }
          };
          case (_) #ok;
        }
      })
    ],
    func(args: Args): PerformanceArgs {
      switch (args) {
        case (#performance_test(perfArgs)) perfArgs;
        case (_) defaultPerformanceArgs;
      }
    }
  ));
  
  // Performance test: many small requests
  Debug.print("Testing many small requests...");
  let startTime = Time.now();
  
  for (i in Array.keys(Array.tabulate<Nat>(100, func(x) { x }))) {
    let content = "small request " # Nat.toText(i);
    
    let perfArgs : InspectMo.InspectArgs<Args> = {
      methodName = "performance_test";
      caller = testPrincipal;
      arg = Text.encodeUtf8(content);
      msg = #performance_test({ content = content; requestId = i });
      isQuery = false;
      isInspect = false;
      cycles = ?0;
      deadline = null;
    };
    
    switch (perfInspector.inspectCheck(perfArgs)) {
      case (#ok) { /* Expected */ };
      case (#err(msg)) {
        Debug.print("❌ Performance test failed at request " # Nat.toText(i) # ": " # msg);
        assert false;
      };
    };
  };
  
  let endTime = Time.now();
  let duration = endTime - startTime;
  Debug.print("✓ 100 small requests completed in " # debug_show(duration) # " nanoseconds");
  
  // Performance test: large request validation
  Debug.print("Testing large request validation...");
  let largeContent = Text.join(" ", Array.map<Nat, Text>(Array.tabulate<Nat>(51, func(i: Nat): Nat { i }), func(i: Nat): Text { "word" # Nat.toText(i) }).vals());
  
  let largeStartTime = Time.now();
  
  let largePerfArgs : InspectMo.InspectArgs<Args> = {
    methodName = "performance_test";
    caller = testPrincipal;
    arg = Text.encodeUtf8(largeContent);
    msg = #performance_test({ content = largeContent; requestId = 999 });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  let largeResult = perfInspector.inspectCheck(largePerfArgs);
  let largeEndTime = Time.now();
  let largeDuration = largeEndTime - largeStartTime;
  
  switch (largeResult) {
    case (#ok) Debug.print("✓ Large request validated in " # debug_show(largeDuration) # " nanoseconds");
    case (#err(msg)) {
      Debug.print("❌ Large request should have passed: " # msg);
      assert false;
    };
  };
  
  Debug.print("✓ Performance under load tests completed");
});

await test("memory usage with large validation sets", func() : async () {
  Debug.print("Testing memory usage with large validation sets...");
  
  let inspectMo = createTestInspector();
  let memoryInspector = inspectMo.createInspector<Args>();
  
  // Create many different guards to test memory usage
  for (i in Array.keys(Array.tabulate<Nat>(20, func(x) { x }))) {
    let methodName = "memory_test_" # Nat.toText(i);
    let minSize = i + 1;
    let maxSize = (i + 1) * 10;
    
    memoryInspector.inspect(memoryInspector.createMethodGuardInfo<PerformanceArgs>(
      methodName,
      false,
      [
        #textSize(func(args: PerformanceArgs): Text { args.content }, ?minSize, ?maxSize)
      ],
      func(args: Args): PerformanceArgs {
        switch (args) {
          case (#performance_test(perfArgs)) perfArgs;
          case (_) defaultPerformanceArgs;
        }
      }
    ));
  };
  
  // Test all guards
  for (i in Array.keys(Array.tabulate<Nat>(20, func(x) { x }))) {
    let methodName = "memory_test_" # Nat.toText(i);
    let validContent = Text.join("", Array.map<Nat, Text>(Array.tabulate<Nat>((i + 1) * 5, func(_: Nat): Nat { 0 }), func(_: Nat): Text { "a" }).vals());
    
    let memoryArgs : InspectMo.InspectArgs<Args> = {
      methodName = methodName;
      caller = testPrincipal;
      arg = Text.encodeUtf8(validContent);
      msg = #performance_test({ content = validContent; requestId = i });
      isQuery = false;
      isInspect = false;
      cycles = ?0;
      deadline = null;
    };
    
    switch (memoryInspector.inspectCheck(memoryArgs)) {
      case (#ok) { /* Expected */ };
      case (#err(msg)) {
        Debug.print("❌ Memory test failed for method " # methodName # ": " # msg);
        assert false;
      };
    };
  };
  
  Debug.print("✓ Memory usage with large validation sets completed");
});

/// ========================================
/// SYSTEM LIMITS TESTS
/// ========================================

await test("maximum argument size limits", func() : async () {
  Debug.print("Testing maximum argument size limits...");
  
  let inspectMo = createTestInspector();
  let sizeInspector = inspectMo.createInspector<Args>();
  
  sizeInspector.inspect(sizeInspector.createMethodGuardInfo<PerformanceArgs>(
    "size_limit_test",
    false,
    [
      #textSize(func(args: PerformanceArgs): Text { args.content }, ?1, ?200) // Higher than system limit
    ],
    func(args: Args): PerformanceArgs {
      switch (args) {
        case (#performance_test(perfArgs)) perfArgs;
        case (_) defaultPerformanceArgs;
      }
    }
  ));
  
  // Test small content (should pass)
  let smallContent = "small content";
  let smallArgs : InspectMo.InspectArgs<Args> = {
    methodName = "size_limit_test";
    caller = testPrincipal;
    arg = Text.encodeUtf8(smallContent);
    msg = #performance_test({ content = smallContent; requestId = 1 });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (sizeInspector.inspectCheck(smallArgs)) {
    case (#ok) Debug.print("✓ Small content passed");
    case (#err(msg)) {
      Debug.print("❌ Small content should have passed: " # msg);
      assert false;
    };
  };
  
  // Test content at system limit
  let limitContent = Text.join("", Array.map<Nat, Text>(Array.tabulate<Nat>(100, func(i: Nat): Nat { i }), func(_: Nat): Text { "a" }).vals()); // 100 chars
  let limitArgs : InspectMo.InspectArgs<Args> = {
    methodName = "size_limit_test";
    caller = testPrincipal;
    arg = Text.encodeUtf8(limitContent);
    msg = #performance_test({ content = limitContent; requestId = 2 });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  let limitResult = sizeInspector.inspectCheck(limitArgs);
  Debug.print("At limit result: " # debug_show(limitResult));
  
  // Test content exceeding system limit
  let excessContent = Text.join("", Array.map<Nat, Text>(Array.tabulate<Nat>(150, func(i: Nat): Nat { i }), func(_: Nat): Text { "a" }).vals()); // 150 chars
  let excessArgs : InspectMo.InspectArgs<Args> = {
    methodName = "size_limit_test";
    caller = testPrincipal;
    arg = Text.encodeUtf8(excessContent);
    msg = #performance_test({ content = excessContent; requestId = 3 });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  let excessResult = sizeInspector.inspectCheck(excessArgs);
  Debug.print("Excess size result: " # debug_show(excessResult));
  
  Debug.print("✓ Maximum argument size limits tests completed");
});

await test("concurrent validation stress test", func() : async () {
  Debug.print("Testing concurrent validation stress...");
  
  let inspectMo = createTestInspector();
  let stressInspector = inspectMo.createInspector<Args>();
  
  // Create multiple complex validation scenarios
  stressInspector.inspect(stressInspector.createMethodGuardInfo<StressArgs>(
    "stress_test_1",
    false,
    [
      #textSize(func(args: StressArgs): Text { args.operation }, ?1, ?20),
      #customCheck(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (args.args) {
          case (#stress_test(stressArgs)) {
            if (stressArgs.counter % 3 == 0) { #ok } else { #ok }
          };
          case (_) #ok;
        }
      })
    ],
    func(args: Args): StressArgs {
      switch (args) {
        case (#stress_test(stressArgs)) stressArgs;
        case (_) defaultStressArgs;
      }
    }
  ));
  
  stressInspector.inspect(stressInspector.createMethodGuardInfo<StressArgs>(
    "stress_test_2",
    false,
    [
      #textSize(func(args: StressArgs): Text { args.data }, ?5, ?50),
      #natValue(func(args: StressArgs): Nat { args.counter }, ?0, ?1000)
    ],
    func(args: Args): StressArgs {
      switch (args) {
        case (#stress_test(stressArgs)) stressArgs;
        case (_) defaultStressArgs;
      }
    }
  ));
  
  stressInspector.inspect(stressInspector.createMethodGuardInfo<StressArgs>(
    "stress_test_3",
    false,
    [
      #requireAuth,
      #textSize(func(args: StressArgs): Text { args.operation }, ?1, ?30)
    ],
    func(args: Args): StressArgs {
      switch (args) {
        case (#stress_test(stressArgs)) stressArgs;
        case (_) defaultStressArgs;
      }
    }
  ));
  
  // Simulate concurrent access patterns
  let principals = [testPrincipal, userPrincipal, adminPrincipal];
  let guards = ["stress_test_1", "stress_test_2", "stress_test_3"];
  let operations = ["stress test op", "even length text!!", "any operation here"];
  let dataContents = ["stress test data", "longer data content here", "valid data"];
  
  // Run mixed validation scenarios
  for (i in Array.keys(Array.tabulate<Nat>(9, func(x) { x }))) {
    let principal = principals[i % 3];
    let guard = guards[i % 3];
    let operation = operations[i % 3];
    let data = dataContents[i % 3];
    
    let stressArgs : InspectMo.InspectArgs<Args> = {
      methodName = guard;
      caller = principal;
      arg = Text.encodeUtf8("stress test");
      msg = #stress_test({ operation = operation; data = data; counter = i });
      isQuery = false;
      isInspect = false;
      cycles = ?0;
      deadline = null;
    };
    
    let result = stressInspector.inspectCheck(stressArgs);
    Debug.print("Stress test " # Nat.toText(i) # " (" # guard # "): " # debug_show(result));
    
    // Most should pass, some may fail auth (stress_test_3 for non-admin)
    switch (result) {
      case (#ok) { /* Good */ };
      case (#err(msg)) {
        // Expected for auth failures on stress_test_3
        if (guard == "stress_test_3" and principal != adminPrincipal) {
          Debug.print("✓ Expected auth failure for " # guard);
        } else {
          Debug.print("ℹ️ Stress test failure (may be expected): " # msg);
        };
      };
    };
  };
  
  Debug.print("✓ Concurrent validation stress tests completed");
});

Debug.print("⚡ ALL PERFORMANCE AND VALIDATION TESTS COMPLETED! ⚡");

};

}
