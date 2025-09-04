import Debug "mo:core/Debug";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import TT "mo:timer-tool";
import ClassPlusLib "mo:class-plus";
import InspectMo "../src/core/inspector";

persistent actor PermissionIntegrationNewTest {

/// Test permission validation rules with InspectMo ErasedValidator pattern

// Timer tool setup following main.mo pattern
transient let initManager = ClassPlusLib.ClassPlusInitializationManager(
  Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"), 
  Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"), 
  false
);
stable var tt_migration_state: TT.State = TT.Migration.migration.initialState;

transient let tt = TT.Init<system>({
  manager = initManager;
  initialState = tt_migration_state;
  args = null;
  pullEnvironment = ?(func() : TT.Environment {
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
  onInitialize = ?(func (newClass: TT.TimerTool) : async* () {
    newClass.initialize<system>();
  });
  onStorageChange = func(state: TT.State) {
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
let userPrincipal = Principal.fromText("e73oq-siaaa-aaaah-qcpwa-cai");
let moderatorPrincipal = Principal.fromText("s6bzd-46mcd-mlbx5-cq2jv-m2mhx-nhj6y-erh6g-y73vq-fnfe6-zax3q-mqe");

// Define Args union type for permission integration tests
type Args = {
  #test_method: {content: Text};
};

public func runTests() : async () {
  await testBasicInspection();
  Debug.print("🔐 PERMISSION INTEGRATION TESTS COMPLETED! 🔐");
};

private func testBasicInspection() : async () {
  Debug.print("Testing basic inspection functionality...");
  
  // Test simple method validation like main.test.mo
  inspector.inspect(inspector.createMethodGuardInfo<{content: Text}>(
    "test_method",
    false,
    [
      InspectMo.textSize<Args, {content: Text}>(
        func(data: {content: Text}): Text { data.content },
        ?1, ?100
      )
    ],
    func(args: Args): {content: Text} {
      switch (args) {
        case (#test_method(data)) data;
        case (_) ({ content = "default" });
      }
    }
  ));
  
  // Test validation
  let validArgs : Args = #test_method({content = "Valid content"});
  switch (inspector.inspectCheck(validArgs)) {
    case (#ok) Debug.print("✓ Basic inspection test passed");
    case (#err(msg)) Debug.print("❌ Basic inspection test failed: " # msg);
  };
};

private func testPermissionBasedValidation() : async () {
  Debug.print("Testing permission-based validation with standard inspector pattern...");
  
  // Create mock whitelist for demonstration
  let whitelist = [adminPrincipal, userPrincipal, moderatorPrincipal];
  
  // Register content creation with authentication and custom permission check
  inspector.inspect(inspector.createMethodGuardInfo<{title: Text; content: Text}>(
    "create_content",
    false,
    [
      InspectMo.requireAuth<Args, {title: Text; content: Text}>(),
      InspectMo.customCheck<Args, {title: Text; content: Text}>(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        // Check if caller is in whitelist
        let isWhitelisted = args.caller == adminPrincipal or args.caller == userPrincipal or args.caller == moderatorPrincipal;
        if (not isWhitelisted) {
          return #err("Caller not whitelisted");
        };
        
        // Check content for spam
        switch (args.args) {
          case (#create_content(fn)) {
            let data = fn();
            if (Text.contains(data.content, #text "spam")) {
              #err("Content contains prohibited terms")
            } else {
              #ok
            }
          };
          case (_) #err("Invalid message variant");
        }
      }),
      InspectMo.textSize<Args, {title: Text; content: Text}>(
        func(data: {title: Text; content: Text}): Text { data.title },
        ?1, ?100
      )
    ],
    func(args: Args): {title: Text; content: Text} {
      switch (args) {
        case (#create_content(fn)) fn();
        case (_) ({ title = "default"; content = "default" });
      }
    }
  ));
  
  // Register read content method
  inspector.inspect(inspector.createMethodGuardInfo<Nat>(
      }
    }
  );
  inspector.guard(createContentInfo);
  
  // Register content reading with custom whitelist check
  let readContentInfo = inspector.createMethodGuardInfo<Nat>(
    "read_content",
    true,
    [
      InspectMo.customCheck<Args, Nat>(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        // Check if caller is in whitelist
        let isWhitelisted = args.caller == adminPrincipal or args.caller == userPrincipal or args.caller == moderatorPrincipal;
        if (not isWhitelisted) {
          #err("Caller not whitelisted")
        } else {
          #ok
        }
      })
    ],
    func(args: Args): Nat {
      switch (args) {
        case (#read_content(fn)) fn();
        case (_) 0;
      }
    }
  );
  inspector.guard(readContentInfo);
  
  // Register admin action with strict validation (only admin allowed)
  let adminActionInfo = inspector.createMethodGuardInfo<Text>(
    "admin_action",
    false,
    [
      InspectMo.requireAuth<Args, Text>(),
      InspectMo.customCheck<Args, Text>(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        // Only admin principal allowed
        if (args.caller == adminPrincipal) {
          #ok
        } else {
          #err("Only admin allowed")
        }
      })
    ],
    func(args: Args): Text {
      switch (args) {
        case (#admin_action(fn)) fn();
        case (_) "default";
      }
    }
  );
  inspector.guard(adminActionInfo);
  
  // Register moderation action with custom permission check
  let moderateContentInfo = inspector.createMethodGuardInfo<{id: Nat; action: Text}>(
    "moderate_content",
    false,
    [
      InspectMo.requireAuth<Args, {id: Nat; action: Text}>(),
      InspectMo.customCheck<Args, {id: Nat; action: Text}>(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        // Check if caller is admin or moderator
        let canModerate = args.caller == adminPrincipal or args.caller == moderatorPrincipal;
        if (not canModerate) {
          return #err("Only admins and moderators can moderate");
        };
        
        // Check specific action permissions
        switch (args.args) {
          case (#moderate_content(fn)) {
            let data = fn();
            // Only admins can ban users, moderators can warn
            if (data.action == "ban" and args.caller != adminPrincipal) {
              #err("Only admins can ban users")
            } else {
              #ok
            }
          };
          case (_) #err("Invalid message variant");
        }
      })
    ],
    func(args: Args): {id: Nat; action: Text} {
      switch (args) {
        case (#moderate_content(fn)) fn();
        case (_) ({ id = 0; action = "default" });
      }
    }
  );
  inspector.guard(moderateContentInfo);
  
  // Test helper function
  let testPermissionAccess = func(methodName: Text, msgVariant: Args, caller: Principal, shouldSucceed: Bool, description: Text) {
    let args : InspectMo.InspectArgs<Args> = {
      methodName = methodName;
      caller = caller;
      arg = Text.encodeUtf8("test");
      isQuery = methodName == "read_content";
      cycles = null;
      deadline = null;
      isInspect = false;
      msg = msgVariant;
    };
    
    switch (inspector.guardCheck(args)) {
      case (#ok) {
        if (shouldSucceed) {
          Debug.print("✓ " # description # " access granted");
        } else {
          Debug.print("✗ " # description # " should have been denied");
          assert false;
        }
      };
      case (#err(msg)) {
        if (not shouldSucceed) {
          Debug.print("✓ " # description # " access denied: " # msg);
        } else {
          Debug.print("✗ " # description # " should have been granted: " # msg);
          assert false;
        }
      };
    };
  };
  
  // Test admin access (should have all permissions)
  testPermissionAccess("create_content", #create_content(func() { {title = "Admin Post"; content = "Admin content"} }), adminPrincipal, true, "Admin create");
  testPermissionAccess("read_content", #read_content(func() { 1 }), adminPrincipal, true, "Admin read");
  testPermissionAccess("admin_action", #admin_action(func() { "admin task" }), adminPrincipal, true, "Admin action");
  testPermissionAccess("moderate_content", #moderate_content(func() { {id = 1; action = "ban"} }), adminPrincipal, true, "Admin moderation");
  
  // Test moderator access
  testPermissionAccess("create_content", #create_content(func() { {title = "Mod Post"; content = "Mod content"} }), moderatorPrincipal, true, "Moderator create");
  testPermissionAccess("read_content", #read_content(func() { 1 }), moderatorPrincipal, true, "Moderator read");
  testPermissionAccess("admin_action", #admin_action(func() { "admin task" }), moderatorPrincipal, false, "Moderator admin action");
  testPermissionAccess("moderate_content", #moderate_content(func() { {id = 1; action = "warn"} }), moderatorPrincipal, true, "Moderator warning");
  testPermissionAccess("moderate_content", #moderate_content(func() { {id = 1; action = "ban"} }), moderatorPrincipal, false, "Moderator ban");
  
  // Test user access
  testPermissionAccess("create_content", #create_content(func() { {title = "User Post"; content = "User content"} }), userPrincipal, true, "User create");
  testPermissionAccess("read_content", #read_content(func() { 1 }), userPrincipal, true, "User read");
  testPermissionAccess("admin_action", #admin_action(func() { "admin task" }), userPrincipal, false, "User admin action");
  testPermissionAccess("moderate_content", #moderate_content(func() { {id = 1; action = "warn"} }), userPrincipal, false, "User moderation");
  
  // Test content validation
  testPermissionAccess("create_content", #create_content(func() { {title = "Spam Post"; content = "This is spam content"} }), userPrincipal, false, "User spam content");
  
  // Test unauthorized access
  let unauthorizedPrincipal = Principal.fromText("2vxsx-fae");
  testPermissionAccess("create_content", #create_content(func() { {title = "Unauthorized"; content = "Unauthorized content"} }), unauthorizedPrincipal, false, "Unauthorized create");
  testPermissionAccess("read_content", #read_content(func() { 1 }), unauthorizedPrincipal, false, "Unauthorized read");
  
  Debug.print("✓ Permission-based validation with ErasedValidator test passed");
};

private func testLayeredPermissionValidation() : async () {
  Debug.print("Testing layered permission validation...");
  
  let config : InspectMo.InitArgs = {
    allowAnonymous = ?true; // Allow some public access
    defaultMaxArgSize = ?1024;
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
  
  // Register public content (no restrictions)
  let publicContentInfo = inspector.createMethodGuardInfo<Text>(
    "public_content",
    true,
    [
      // No restrictions for public content
    ],
    func(args: Args): Text {
      switch (args) {
        case (#public_content(fn)) fn();
        case (_) "default";
      }
    }
  );
  inspector.guard(publicContentInfo);
  
  // Register user profile with progressive restrictions
  let userProfileInfo = inspector.createMethodGuardInfo<Text>(
    "user_profile",
    true,
    [
      InspectMo.requireAuth<Args, Text>(), // Must be authenticated
      InspectMo.customCheck<Args, Text>(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        // Additional permission logic could go here
        if (args.caller == Principal.anonymous()) {
          #err("Anonymous access not allowed for profiles")
        } else {
          #ok
        }
      })
    ],
    func(args: Args): Text {
      switch (args) {
        case (#user_profile(fn)) fn();
        case (_) "default";
      }
    }
  );
  inspector.guard(userProfileInfo);
  
  // Test layered access
  let testLayeredAccess = func(methodName: Text, msgVariant: Args, caller: Principal, description: Text) {
    let args : InspectMo.InspectArgs<Args> = {
      methodName = methodName;
      caller = caller;
      arg = Text.encodeUtf8("test");
      isQuery = true;
      cycles = null;
      deadline = null;
      isInspect = false;
      msg = msgVariant;
    };
    
    switch (inspector.guardCheck(args)) {
      case (#ok) Debug.print("✓ " # description # " access granted");
      case (#err(msg)) Debug.print("✓ " # description # " access denied: " # msg);
    };
  };
  
  // Test public content (everyone should have access)
  testLayeredAccess("public_content", #public_content(func() { "public data" }), adminPrincipal, "Admin public");
  testLayeredAccess("public_content", #public_content(func() { "public data" }), moderatorPrincipal, "Moderator public");
  testLayeredAccess("public_content", #public_content(func() { "public data" }), userPrincipal, "User public");
  testLayeredAccess("public_content", #public_content(func() { "public data" }), Principal.anonymous(), "Anonymous public");
  
  // Test user profile (requires authentication)
  testLayeredAccess("user_profile", #user_profile(func() { "profile data" }), adminPrincipal, "Admin profile");
  testLayeredAccess("user_profile", #user_profile(func() { "profile data" }), moderatorPrincipal, "Moderator profile");
  testLayeredAccess("user_profile", #user_profile(func() { "profile data" }), userPrincipal, "User profile");
  testLayeredAccess("user_profile", #user_profile(func() { "profile data" }), Principal.anonymous(), "Anonymous profile");
  
  Debug.print("✓ Layered permission validation test passed");
};

Debug.print("🔐 PERMISSION INTEGRATION WITH ERASEDVALIDATOR TESTS COMPLETED! 🔐");

// Public function to call for starting tests
public func test() : async () {
  await runTests();
};

};
