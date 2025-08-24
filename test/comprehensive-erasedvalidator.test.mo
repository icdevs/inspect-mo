import {test; expect} "mo:test/async";
import InspectMo "../src/lib";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import Blob "mo:core/Blob";
import Debug "mo:core/Debug";

/// Comprehensive ErasedValidator pattern demonstration
/// Tests ALL validation rule types in a single cohesive test file

// Test principals
let testPrincipal = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
let adminPrincipal = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");
let userPrincipal = Principal.fromText("e73oq-siaaa-aaaah-qcpwa-cai");

// Comprehensive Args union type covering all validation scenarios
type Args = {
  #text_validation: () -> Text;
  #blob_validation: () -> Blob;
  #nat_validation: () -> Nat;
  #int_validation: () -> Int;
  #auth_required: () -> Text;
  #permission_check: () -> Text;
  #role_check: () -> Text;
  #custom_business: () -> {name: Text; value: Nat};
  #dynamic_auth: () -> {operation: Text; level: Nat};
  #combined_validation: () -> {title: Text; content: Blob; priority: Nat};
  #edge_case_empty: () -> Text;
  #edge_case_unicode: () -> Text;
  #real_world_scenario: () -> {user: Text; action: Text; data: Blob; metadata: {version: Nat; timestamp: Int}};
};

await test("comprehensive text validation with ErasedValidator", func() : async () {
  Debug.print("🔤 Testing comprehensive text validation with ErasedValidator...");
  
  let config : InspectMo.InitArgs = {
    allowAnonymous = ?false;
    defaultMaxArgSize = ?2048;
    authProvider = null;
    rateLimit = null;
    queryDefaults = null;
    updateDefaults = null;
    developmentMode = false;
    auditLog = true;
  };
  
  let mockInspectMo = InspectMo.InspectMo(
    null,
    adminPrincipal,
    testPrincipal,
    ?config,
    null,
    func(state: InspectMo.State) {}
  );
  
  let inspector = mockInspectMo.createInspector<Args>();
  
  // Register text validation with multiple constraints
  let textValidationInfo = inspector.createMethodGuardInfo<Text>(
    "text_validation",
    false,
    [
      InspectMo.requireAuth<Args, Text>(),
      InspectMo.textSize<Args, Text>(func(t: Text): Text { t }, ?3, ?50),
      InspectMo.customCheck<Args, Text>(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (args.args) {
          case (#text_validation(fn)) {
            let text = fn();
            if (Text.contains(text, #text "forbidden")) {
              #err("Text contains forbidden content")
            } else if (Text.startsWith(text, #text "admin_") and args.caller != adminPrincipal) {
              #err("Admin prefix requires admin privileges")
            } else {
              #ok
            }
          };
          case (_) #err("Invalid message variant");
        }
      })
    ],
    func(args: Args): Text {
      switch (args) {
        case (#text_validation(fn)) fn();
        case (_) "default";
      }
    }
  );
  inspector.guard(textValidationInfo);
  
  // Test valid text
  let validResult = inspector.guardCheck({
    methodName = "text_validation";
    caller = userPrincipal;
    arg = Text.encodeUtf8("test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #text_validation(func() { "hello world" });
  });
  assert(validResult == #ok);
  Debug.print("✓ Valid text passed all checks");
  
  // Test forbidden content
  let forbiddenResult = inspector.guardCheck({
    methodName = "text_validation";
    caller = userPrincipal;
    arg = Text.encodeUtf8("test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #text_validation(func() { "this is forbidden content" });
  });
  switch (forbiddenResult) {
    case (#err(msg)) Debug.print("✓ Forbidden content rejected: " # msg);
    case (#ok) assert false;
  };
  
  // Test admin prefix by non-admin
  let adminPrefixResult = inspector.guardCheck({
    methodName = "text_validation";
    caller = userPrincipal;
    arg = Text.encodeUtf8("test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #text_validation(func() { "admin_delete_user" });
  });
  switch (adminPrefixResult) {
    case (#err(msg)) Debug.print("✓ Admin prefix by non-admin rejected: " # msg);
    case (#ok) assert false;
  };
  
  // Test admin prefix by admin
  let adminValidResult = inspector.guardCheck({
    methodName = "text_validation";
    caller = adminPrincipal;
    arg = Text.encodeUtf8("test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #text_validation(func() { "admin_delete_user" });
  });
  assert(adminValidResult == #ok);
  Debug.print("✓ Admin prefix by admin accepted");
  
  Debug.print("🔤 Text validation tests completed!");
});

await test("comprehensive blob and numeric validation", func() : async () {
  Debug.print("🗄️ Testing blob and numeric validation with ErasedValidator...");
  
  let config : InspectMo.InitArgs = {
    allowAnonymous = ?false;
    defaultMaxArgSize = ?2048;
    authProvider = null;
    rateLimit = null;
    queryDefaults = null;
    updateDefaults = null;
    developmentMode = false;
    auditLog = true;
  };
  
  let mockInspectMo = InspectMo.InspectMo(
    null,
    adminPrincipal,
    testPrincipal,
    ?config,
    null,
    func(state: InspectMo.State) {}
  );
  
  let inspector = mockInspectMo.createInspector<Args>();
  
  // Register blob validation
  let blobValidationInfo = inspector.createMethodGuardInfo<Blob>(
    "blob_validation",
    false,
    [
      InspectMo.blobSize<Args, Blob>(func(b: Blob): Blob { b }, ?10, ?1000)
    ],
    func(args: Args): Blob {
      switch (args) {
        case (#blob_validation(fn)) fn();
        case (_) Text.encodeUtf8("default");
      }
    }
  );
  inspector.guard(blobValidationInfo);
  
  // Register nat validation  
  let natValidationInfo = inspector.createMethodGuardInfo<Nat>(
    "nat_validation",
    false,
    [
      InspectMo.natValue<Args, Nat>(func(n: Nat): Nat { n }, ?1, ?100)
    ],
    func(args: Args): Nat {
      switch (args) {
        case (#nat_validation(fn)) fn();
        case (_) 0;
      }
    }
  );
  inspector.guard(natValidationInfo);
  
  // Register int validation
  let intValidationInfo = inspector.createMethodGuardInfo<Int>(
    "int_validation",
    false,
    [
      InspectMo.intValue<Args, Int>(func(i: Int): Int { i }, ?(-50), ?50)
    ],
    func(args: Args): Int {
      switch (args) {
        case (#int_validation(fn)) fn();
        case (_) 0;
      }
    }
  );
  inspector.guard(intValidationInfo);
  
  // Test valid blob
  let validBlobResult = inspector.guardCheck({
    methodName = "blob_validation";
    caller = userPrincipal;
    arg = Text.encodeUtf8("test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #blob_validation(func() { Text.encodeUtf8("this is valid blob content") });
  });
  assert(validBlobResult == #ok);
  Debug.print("✓ Valid blob accepted");
  
  // Test valid nat
  let validNatResult = inspector.guardCheck({
    methodName = "nat_validation";
    caller = userPrincipal;
    arg = Text.encodeUtf8("test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #nat_validation(func() { 42 });
  });
  assert(validNatResult == #ok);
  Debug.print("✓ Valid nat accepted");
  
  // Test valid int
  let validIntResult = inspector.guardCheck({
    methodName = "int_validation";
    caller = userPrincipal;
    arg = Text.encodeUtf8("test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #int_validation(func() { -25 });
  });
  assert(validIntResult == #ok);
  Debug.print("✓ Valid int accepted");
  
  // Test invalid cases
  let invalidBlobResult = inspector.guardCheck({
    methodName = "blob_validation";
    caller = userPrincipal;
    arg = Text.encodeUtf8("test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #blob_validation(func() { Text.encodeUtf8("tiny") });
  });
  switch (invalidBlobResult) {
    case (#err(msg)) Debug.print("✓ Small blob rejected: " # msg);
    case (#ok) assert false;
  };
  
  let invalidNatResult = inspector.guardCheck({
    methodName = "nat_validation";
    caller = userPrincipal;
    arg = Text.encodeUtf8("test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #nat_validation(func() { 500 });
  });
  switch (invalidNatResult) {
    case (#err(msg)) Debug.print("✓ Large nat rejected: " # msg);
    case (#ok) assert false;
  };
  
  let invalidIntResult = inspector.guardCheck({
    methodName = "int_validation";
    caller = userPrincipal;
    arg = Text.encodeUtf8("test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #int_validation(func() { -100 });
  });
  switch (invalidIntResult) {
    case (#err(msg)) Debug.print("✓ Out of range int rejected: " # msg);
    case (#ok) assert false;
  };
  
  Debug.print("🗄️ Blob and numeric validation tests completed!");
});

await test("comprehensive real-world scenario validation", func() : async () {
  Debug.print("🌍 Testing real-world scenario with combined validation...");
  
  let config : InspectMo.InitArgs = {
    allowAnonymous = ?false;
    defaultMaxArgSize = ?4096;
    authProvider = null;
    rateLimit = null;
    queryDefaults = null;
    updateDefaults = null;
    developmentMode = false;
    auditLog = true;
  };
  
  let mockInspectMo = InspectMo.InspectMo(
    null,
    adminPrincipal,
    testPrincipal,
    ?config,
    null,
    func(state: InspectMo.State) {}
  );
  
  let inspector = mockInspectMo.createInspector<Args>();
  
  // Register complex real-world validation
  let realWorldInfo = inspector.createMethodGuardInfo<{user: Text; action: Text; data: Blob; metadata: {version: Nat; timestamp: Int}}>(
    "real_world_scenario",
    false,
    [
      InspectMo.requireAuth<Args, {user: Text; action: Text; data: Blob; metadata: {version: Nat; timestamp: Int}}>(),
      InspectMo.textSize<Args, {user: Text; action: Text; data: Blob; metadata: {version: Nat; timestamp: Int}}>(
        func(input: {user: Text; action: Text; data: Blob; metadata: {version: Nat; timestamp: Int}}): Text { input.user },
        ?3, ?50
      ),
      InspectMo.textSize<Args, {user: Text; action: Text; data: Blob; metadata: {version: Nat; timestamp: Int}}>(
        func(input: {user: Text; action: Text; data: Blob; metadata: {version: Nat; timestamp: Int}}): Text { input.action },
        ?1, ?20
      ),
      InspectMo.blobSize<Args, {user: Text; action: Text; data: Blob; metadata: {version: Nat; timestamp: Int}}>(
        func(input: {user: Text; action: Text; data: Blob; metadata: {version: Nat; timestamp: Int}}): Blob { input.data },
        ?1, ?2048
      ),
      InspectMo.natValue<Args, {user: Text; action: Text; data: Blob; metadata: {version: Nat; timestamp: Int}}>(
        func(input: {user: Text; action: Text; data: Blob; metadata: {version: Nat; timestamp: Int}}): Nat { input.metadata.version },
        ?1, ?10
      ),
      InspectMo.customCheck<Args, {user: Text; action: Text; data: Blob; metadata: {version: Nat; timestamp: Int}}>(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (args.args) {
          case (#real_world_scenario(fn)) {
            let data = fn();
            
            // Business logic: only certain users can perform delete actions
            if (data.action == "delete" and data.user != "admin_user") {
              return #err("Only admin users can perform delete actions");
            };
            
            // Version compatibility check
            if (data.metadata.version < 2) {
              return #err("Minimum API version 2 required");
            };
            
            // Timestamp validation (must be recent)
            if (data.metadata.timestamp < 1000000) {
              return #err("Invalid timestamp - must be recent");
            };
            
            #ok
          };
          case (_) #err("Invalid message variant");
        }
      })
    ],
    func(args: Args): {user: Text; action: Text; data: Blob; metadata: {version: Nat; timestamp: Int}} {
      switch (args) {
        case (#real_world_scenario(fn)) fn();
        case (_) ({ 
          user = "default"; 
          action = "default"; 
          data = Text.encodeUtf8("default"); 
          metadata = { version = 1; timestamp = 0 }
        });
      }
    }
  );
  inspector.guard(realWorldInfo);
  
  // Test valid real-world scenario
  let validScenario = inspector.guardCheck({
    methodName = "real_world_scenario";
    caller = userPrincipal;
    arg = Text.encodeUtf8("test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #real_world_scenario(func() { 
      {
        user = "john_doe";
        action = "update";
        data = Text.encodeUtf8("this is some valid data for the update operation");
        metadata = {
          version = 3;
          timestamp = 1692633600; // Recent timestamp
        };
      }
    });
  });
  assert(validScenario == #ok);
  Debug.print("✓ Valid real-world scenario accepted");
  
  // Test delete action by non-admin
  let deleteScenario = inspector.guardCheck({
    methodName = "real_world_scenario";
    caller = userPrincipal;
    arg = Text.encodeUtf8("test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #real_world_scenario(func() { 
      {
        user = "john_doe";
        action = "delete";
        data = Text.encodeUtf8("data to delete");
        metadata = {
          version = 3;
          timestamp = 1692633600;
        };
      }
    });
  });
  switch (deleteScenario) {
    case (#err(msg)) Debug.print("✓ Delete by non-admin rejected: " # msg);
    case (#ok) assert false;
  };
  
  // Test old API version
  let oldVersionScenario = inspector.guardCheck({
    methodName = "real_world_scenario";
    caller = userPrincipal;
    arg = Text.encodeUtf8("test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #real_world_scenario(func() { 
      {
        user = "john_doe";
        action = "update";
        data = Text.encodeUtf8("some data");
        metadata = {
          version = 1; // Too old
          timestamp = 1692633600;
        };
      }
    });
  });
  switch (oldVersionScenario) {
    case (#err(msg)) Debug.print("✓ Old API version rejected: " # msg);
    case (#ok) assert false;
  };
  
  // Test invalid timestamp
  let badTimestampScenario = inspector.guardCheck({
    methodName = "real_world_scenario";
    caller = userPrincipal;
    arg = Text.encodeUtf8("test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #real_world_scenario(func() { 
      {
        user = "john_doe";
        action = "update";
        data = Text.encodeUtf8("some data");
        metadata = {
          version = 3;
          timestamp = 999; // Too old
        };
      }
    });
  });
  switch (badTimestampScenario) {
    case (#err(msg)) Debug.print("✓ Invalid timestamp rejected: " # msg);
    case (#ok) assert false;
  };
  
  Debug.print("🌍 Real-world scenario validation tests completed!");
});

Debug.print("🎯 ALL COMPREHENSIVE ERASEDVALIDATOR TESTS COMPLETED! 🎯");
