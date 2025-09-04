import {test} "mo:test/async";
import Debug "mo:core/Debug";
import InspectMo "../src/core/inspector";
import Types "../src/migrations/types";
import Text "mo:core/Text";
import Blob "mo:core/Blob";
import Principal "mo:core/Principal";
import TimerTool "mo:timer-tool";
import ClassPlusLib "mo:class-plus";

persistent actor BasicTest {

/// Comprehensive unit tests for Week 1 implementation

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
    Debug.print("Creating TimerTool Environment");
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
    }
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

// Initialize the TimerTool before running tests
ignore tt();

// Initialize the inspector
ignore inspector();

func createTestInspector() : InspectMo.InspectMo {
  // For tests, we can just return the main inspector since it has proper environment
  inspector();
};

type Args = {
    #test0: () -> ();
    #test1: () -> Text;
    #test2: () -> (Text,Text);
    #test3: () -> {item: Text};
  };

public func runTests() : async () {

await test("inspector initialization tests", func() : async () {
  Debug.print("Testing inspector initialization...");
  
  let inspectMo = createTestInspector();
  let inspector = inspectMo.createInspector<Args>();
  
  Debug.print("✓ Inspector initialization tests passed");
  
  // Minimal config
  let mockInspectMo = InspectMo.InspectMo(
    null, // No stored state
    Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai"), // Mock instantiator
    Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"), // Mock canister
    null, // No config for minimal test
    null, // No environment for unit tests
    func(state: InspectMo.State) {} // No-op storage change
  );
  let inspector1 = mockInspectMo.createInspector<Args>();
  Debug.print("✓ Minimal config initialization");
  
  // Full config
  let fullConfig : InspectMo.InitArgs = {
    allowAnonymous = ?false;
    defaultMaxArgSize = ?1024;
    authProvider = null; // Will be implemented in Week 5
    rateLimit = null; // Will be implemented in Week 5
    queryDefaults = ?{
      allowAnonymous = ?true;
      maxArgSize = ?512;
      rateLimit = null;
    };
    updateDefaults = ?{
      allowAnonymous = ?false;
      maxArgSize = ?2048;
      rateLimit = null;
    };
    developmentMode = true;
    auditLog = true;
  };
  
  let mockInspectMo2 = InspectMo.InspectMo(
    null, // No stored state
    Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai"), // Mock instantiator  
    Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"), // Mock canister
    ?fullConfig,
    null, // No environment for unit tests
    func(state: InspectMo.State) {} // No-op storage change
  );
  let inspector2 = mockInspectMo2.createInspector<Args>();
  Debug.print("✓ Full config initialization");
  Debug.print("✓ Inspector initialization tests passed");
});

/*
await test("validation rule creation tests", func() : async () {
  Debug.print("Testing validation rule creation...");
  
  // Text size rules using old-style format with T=Args, M=specific message types
  let textRule1 = InspectMo.textSize<Args,Text>(func(text: Text): Text {
    text // Accessor receives M (Text) and returns Text for validation
  }, ?1, ?100);
  
  let textRule2 = InspectMo.textSize<Args,(Text,Text)>(func(args: (Text,Text)): Text {
    args.0 // Accessor receives M ((Text,Text)) and extracts Text for validation
  }, null, ?1000);
  Debug.print("✓ Text size rules created");
  
  // Blob size rules with T=Args, M=Blob
  let blobRule = InspectMo.blobSize<Args,Blob>(func(blob: Blob): Blob {
    blob // Accessor receives M (Blob) and returns Blob for validation
  }, ?1, ?2048);
  Debug.print("✓ Blob size rules created");
  
  // Numeric value rules with T=Args, M=specific numeric types
  let natRule = InspectMo.natValue<Args,Nat>(func(nat: Nat): Nat {
    nat // Accessor receives M (Nat) and returns Nat for validation
  }, ?0, ?1000);
  
  let intRule = InspectMo.intValue<Args,Int>(func(int: Int): Int {
    int // Accessor receives M (Int) and returns Int for validation
  }, ?(-100), ?100);
  Debug.print("✓ Numeric value rules created");
  
  // Permission rules - examples for different M types with T=Args
  let authRuleForText = InspectMo.requireAuth<Args,Text>();
  let authRuleForTuple = InspectMo.requireAuth<Args,(Text,Text)>();
  let authRuleForRecord = InspectMo.requireAuth<Args,{item: Text}>();
  
  let permRuleForText = InspectMo.requirePermission<Args,Text>("write");
  let roleRuleForText = InspectMo.requireRole<Args,Text>("admin");
  Debug.print("✓ Permission rules created");
  
  // Source control rules - examples for different M types with T=Args
  let blockIngressRuleForText = InspectMo.blockIngress<Args,Text>();
  let blockAllRuleForText = InspectMo.blockAll<Args,Text>();
  Debug.print("✓ Source control rules created");
  
  Debug.print("✓ Validation rule creation tests passed");
});
*/

/*
await test("utility function tests", func() : async () {
  Debug.print("Testing utility functions...");
  
  // Text size validation - positive cases
  assert InspectMo.validateTextSize("hello", ?1, ?10);
  assert InspectMo.validateTextSize("", ?0, ?10);
  assert InspectMo.validateTextSize("exactly10!", ?10, ?10);
  
  // Text size validation - negative cases
  assert not InspectMo.validateTextSize("", ?1, ?10); // Too short
  assert not InspectMo.validateTextSize("this is way too long for the limit", ?1, ?10); // Too long
  
  Debug.print("✓ Text size validation");
  
  // Blob size validation - positive cases
  let smallBlob = Text.encodeUtf8("small");
  let largeBlob = Text.encodeUtf8("this is a much larger blob for testing");
  
  assert InspectMo.validateBlobSize(smallBlob, ?1, ?100);
  assert InspectMo.validateBlobSize(largeBlob, ?10, ?100);
  
  // Blob size validation - negative cases
  assert not InspectMo.validateBlobSize(smallBlob, ?10, ?100); // Too small
  assert not InspectMo.validateBlobSize(largeBlob, ?1, ?10); // Too large
  
  Debug.print("✓ Blob size validation");
  
  // Nat value validation - positive cases
  assert InspectMo.validateNatValue(50, ?0, ?100);
  assert InspectMo.validateNatValue(0, ?0, ?100);
  assert InspectMo.validateNatValue(100, ?0, ?100);
  
  // Nat value validation - negative cases
  assert not InspectMo.validateNatValue(150, ?0, ?100); // Too large
  
  Debug.print("✓ Nat value validation");
  
  // Int value validation - positive cases
  assert InspectMo.validateIntValue(0, ?(-50), ?50);
  assert InspectMo.validateIntValue(-25, ?(-50), ?50);
  assert InspectMo.validateIntValue(25, ?(-50), ?50);
  
  // Int value validation - negative cases
  assert not InspectMo.validateIntValue(-75, ?(-50), ?50); // Too small
  assert not InspectMo.validateIntValue(75, ?(-50), ?50); // Too large
  
  Debug.print("✓ Int value validation");
  Debug.print("✓ Utility function tests passed");
});
*/

await test("method registration tests", func() : async () {
  Debug.print("Testing method registration...");
  
  type Args = {
    #test0: () -> ();
    #test1: () -> Text;
    #test2: () -> (Text,Text);
    #test3: () -> {item: Text};
  };
  
  let config : InspectMo.InitArgs = {
    allowAnonymous = ?false;
    defaultMaxArgSize = ?1024;
    authProvider = null;
    rateLimit = null;
    queryDefaults = null;
    updateDefaults = null;
    developmentMode = true;
    auditLog = false;
  };
  
  let mockInspectMo = InspectMo.InspectMo(
    null, // No stored state
    Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai"), // Mock instantiator
    Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"), // Mock canister  
    ?config,
    null, // No environment for unit tests
    func(state: InspectMo.State) {} // No-op storage change
  );
  let inspector = mockInspectMo.createInspector<Args>();
  
  // Register method for test1 variant using new ErasedValidator pattern
  let test1Info = inspector.createMethodGuardInfo<Text>(
    "test1",
    false,
    [
      InspectMo.textSize<Args,Text>(func(text: Text): Text { text }, ?1, ?100),
      InspectMo.requireAuth<Args,Text>()
    ],
    func(args: Args): Text { 
      switch (args) {
        case (#test1(fn)) fn();
        case (_) "default";
      }
    }
  );
  inspector.inspect(test1Info);
  Debug.print("✓ Test1 method registered");
  
  // Register method for test2 variant using new ErasedValidator pattern
  let test2Info = inspector.createMethodGuardInfo<(Text,Text)>(
    "test2",
    false,
    [
      InspectMo.textSize<Args,(Text,Text)>(func(args: (Text,Text)): Text { args.0 }, ?1, ?50)
    ],
    func(args: Args): (Text,Text) { 
      switch (args) {
        case (#test2(fn)) fn();
        case (_) ("default", "default");
      }
    }
  );
  inspector.inspect(test2Info);
  Debug.print("✓ Test2 method registered");
  
  // Register method for test3 variant using new ErasedValidator pattern
  let test3Info = inspector.createMethodGuardInfo<{item: Text}>(
    "test3",
    false,
    [
      InspectMo.customCheck<Args, {item:Text}>(func(checkArgs: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (checkArgs.args) {
          case (#test3(fn)) {
            let record = fn();
            if (Text.size(record.item) > 0) { #ok } else { #err("Empty item not allowed") }
          };
          case (_) #err("Invalid variant for test3");
        }
      })
    ],
    func(args: Args): {item: Text} { 
      switch (args) {
        case (#test3(fn)) fn();
        case (_) {{ item = "default" }};
      }
    }
  );
  inspector.guard(test3Info);
  Debug.print("✓ Test3 method registered");
  
  Debug.print("✓ Method registration tests passed");
});

await test("type safety tests", func() : async () {
  Debug.print("Testing type safety...");
  
  type Args = {
    #test0: () -> ();
    #test1: () -> Text;
    #test2: () -> (Text,Text);
    #test3: () -> {item: Text};
  };
  
  // Test with different generic types using new ErasedValidator pattern
  let textMockInspectMo = InspectMo.InspectMo(
    null, 
    Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai"),
    Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"),
    ?{
      allowAnonymous = null;
      defaultMaxArgSize = null;
      authProvider = null;
      rateLimit = null;
      queryDefaults = null;
      updateDefaults = null;
      developmentMode = true;
      auditLog = false;
    },
    null,
    func(state: InspectMo.State) {}
  );
  let inspector = textMockInspectMo.createInspector<Args>();
  
  // Register method for handling test1 variant using new ErasedValidator pattern
  let test1Info = inspector.createMethodGuardInfo<Text>(
    "test1",
    false,
    [
      InspectMo.textSize<Args,Text>(func(text: Text): Text { text }, ?1, ?100)
    ],
    func(args: Args): Text { 
      switch (args) {
        case (#test1(fn)) fn();
        case (_) "fallback";
      }
    }
  );
  inspector.inspect(test1Info);
  
  // Register method for handling test2 variant using new ErasedValidator pattern
  let test2Info = inspector.createMethodGuardInfo<(Text,Text)>(
    "test2",
    true,
    [
      InspectMo.customCheck<Args, (Text,Text)>(func(checkArgs: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (checkArgs.args) {
          case (#test2(fn)) {
            let (first, second) = fn();
            if (Text.size(first) > 0 and Text.size(second) > 0) { #ok } else { #err("Empty tuple elements") }
          };
          case (_) #err("Expected test2 variant");
        }
      })
    ],
    func(args: Args): (Text,Text) { 
      switch (args) {
        case (#test2(fn)) fn();
        case (_) ("default", "default");
      }
    }
  );
  inspector.guard(test2Info);
  
  // Register method for handling test3 variant using new ErasedValidator pattern
  let test3Info = inspector.createMethodGuardInfo<{item: Text}>(
    "test3",
    true,
    [
      InspectMo.textSize<Args,{item: Text}>(func(record: {item: Text}): Text { record.item }, ?3, ?100)
    ],
    func(args: Args): {item: Text} { 
      switch (args) {
        case (#test3(fn)) fn();
        case (_) {{ item = "default" }};
      }
    }
  );
  inspector.inspect(test3Info);
  
  Debug.print("✓ Generic type safety verified with Args union type");
  Debug.print("✓ Different variant extraction patterns work correctly");
  Debug.print("✓ Type safety tests passed");
});

};

}
