import {test} "mo:test/async";
import InspectMo "../src/core/inspector";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import Debug "mo:core/Debug";

/// Basic sample test demonstrating ErasedValidator pattern
/// Simple validation scenarios to establish conversion patterns

// Global Args union type for sample testing
type SampleArgs = {
  content: Text;
  value: Nat;
};

type Args = {
  #sample: SampleArgs;
};

let testPrincipal = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
let adminPrincipal = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");

let defaultConfig : InspectMo.InitArgs = {
  allowAnonymous = ?true;
  defaultMaxArgSize = ?1024;
  authProvider = null;
  rateLimit = null;
  queryDefaults = null;
  updateDefaults = null;
  developmentMode = true;
  auditLog = false;
};

func createTestInspector() : InspectMo.InspectMo {
  InspectMo.InspectMo(
    null, adminPrincipal, testPrincipal, ?defaultConfig, null,
    func(state: InspectMo.State) {}
  )
};

// Helper function for default args
let defaultSampleArgs : SampleArgs = { content = "default"; value = 0 };

await test("basic text size validation", func() : async () {
  Debug.print("Testing basic text size validation...");
  
  let inspector = createTestInspector();
  let sampleInspector = inspector.createInspector<Args>();
  
  // Register method with text size validation (5-20 characters)
  sampleInspector.inspect(sampleInspector.createMethodGuardInfo<SampleArgs>(
    "sampleMethod",
    false,
    [
      #textSize(func(args: SampleArgs) : Text { args.content }, ?5, ?20)
    ],
    func(args: Args) : SampleArgs {
      switch (args) {
        case (#sample(sampleArgs)) sampleArgs;
        case (_) defaultSampleArgs;
      };
    }
  ));
  
  // Test valid content
  let validArgs : InspectMo.InspectArgs<Args> = {
    methodName = "sampleMethod";
    caller = testPrincipal;
    arg = Text.encodeUtf8("valid test");
    msg = #sample({ content = "Hello World"; value = 42 });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (sampleInspector.inspectCheck(validArgs)) {
    case (#ok) Debug.print("✓ Valid content passed");
    case (#err(msg)) {
      Debug.print("❌ Valid content should have passed: " # msg);
      assert false;
    };
  };
  
  // Test content too short
  let shortArgs : InspectMo.InspectArgs<Args> = {
    methodName = "sampleMethod";
    caller = testPrincipal;
    arg = Text.encodeUtf8("short test");
    msg = #sample({ content = "Hi"; value = 42 });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (sampleInspector.inspectCheck(shortArgs)) {
    case (#err(_)) Debug.print("✓ Short content rejected");
    case (#ok) {
      Debug.print("❌ Short content should have been rejected");
      assert false;
    };
  };
  
  Debug.print("✓ Basic text size validation tests passed");
});

await test("require auth validation", func() : async () {
  Debug.print("Testing require auth validation...");
  
  let inspector = createTestInspector();
  let authInspector = inspector.createInspector<Args>();
  
  // Register method requiring authentication
  authInspector.inspect(authInspector.createMethodGuardInfo<SampleArgs>(
    "authMethod",
    false,
    [
      #requireAuth
    ],
    func(args: Args) : SampleArgs {
      switch (args) {
        case (#sample(sampleArgs)) sampleArgs;
        case (_) defaultSampleArgs;
      };
    }
  ));
  
  // Test authenticated caller
  let authArgs : InspectMo.InspectArgs<Args> = {
    methodName = "authMethod";
    caller = testPrincipal;
    arg = Text.encodeUtf8("auth test");
    msg = #sample({ content = "authenticated"; value = 100 });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (authInspector.inspectCheck(authArgs)) {
    case (#ok) Debug.print("✓ Authenticated caller passed");
    case (#err(msg)) {
      Debug.print("❌ Authenticated caller should have passed: " # msg);
      assert false;
    };
  };
  
  // Test anonymous caller
  let anonArgs : InspectMo.InspectArgs<Args> = {
    methodName = "authMethod";
    caller = Principal.fromText("2vxsx-fae"); // anonymous principal
    arg = Text.encodeUtf8("anon test");
    msg = #sample({ content = "anonymous"; value = 100 });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (authInspector.inspectCheck(anonArgs)) {
    case (#err(_)) Debug.print("✓ Anonymous caller rejected");
    case (#ok) {
      Debug.print("❌ Anonymous caller should have been rejected");
      assert false;
    };
  };
  
  Debug.print("✓ Require auth validation tests passed");
});

await test("custom check validation", func() : async () {
  Debug.print("Testing custom check validation...");
  
  let inspector = createTestInspector();
  let customInspector = inspector.createInspector<Args>();
  
  // Register method with custom validation logic
  customInspector.inspect(customInspector.createMethodGuardInfo<SampleArgs>(
    "customMethod",
    false,
    [
      #customCheck(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (args.args) {
          case (#sample(sampleArgs)) {
            if (sampleArgs.value > 100) {
              #err("CUSTOM_ERROR: Value cannot exceed 100")
            } else if (Text.contains(sampleArgs.content, #text "forbidden")) {
              #err("CUSTOM_ERROR: Forbidden content detected")
            } else {
              #ok
            }
          };
          case (_) #err("Invalid argument type");
        };
      })
    ],
    func(args: Args) : SampleArgs {
      switch (args) {
        case (#sample(sampleArgs)) sampleArgs;
        case (_) defaultSampleArgs;
      };
    }
  ));
  
  // Test valid custom check
  let validCustomArgs : InspectMo.InspectArgs<Args> = {
    methodName = "customMethod";
    caller = testPrincipal;
    arg = Text.encodeUtf8("custom test");
    msg = #sample({ content = "allowed content"; value = 50 });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (customInspector.inspectCheck(validCustomArgs)) {
    case (#ok) Debug.print("✓ Valid custom check passed");
    case (#err(msg)) {
      Debug.print("❌ Valid custom check should have passed: " # msg);
      assert false;
    };
  };
  
  // Test value too high
  let highValueArgs : InspectMo.InspectArgs<Args> = {
    methodName = "customMethod";
    caller = testPrincipal;
    arg = Text.encodeUtf8("high value test");
    msg = #sample({ content = "normal content"; value = 150 });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (customInspector.inspectCheck(highValueArgs)) {
    case (#err(msg)) {
      assert(Text.contains(msg, #text "CUSTOM_ERROR"));
      Debug.print("✓ High value rejected: " # msg);
    };
    case (#ok) {
      Debug.print("❌ High value should have been rejected");
      assert false;
    };
  };
  
  // Test forbidden content
  let forbiddenArgs : InspectMo.InspectArgs<Args> = {
    methodName = "customMethod";
    caller = testPrincipal;
    arg = Text.encodeUtf8("forbidden test");
    msg = #sample({ content = "this is forbidden content"; value = 25 });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (customInspector.inspectCheck(forbiddenArgs)) {
    case (#err(msg)) {
      assert(Text.contains(msg, #text "Forbidden content"));
      Debug.print("✓ Forbidden content rejected: " # msg);
    };
    case (#ok) {
      Debug.print("❌ Forbidden content should have been rejected");
      assert false;
    };
  };
  
  Debug.print("✓ Custom check validation tests passed");
});

Debug.print("🔬 SAMPLE TESTS COMPLETED! 🔬");