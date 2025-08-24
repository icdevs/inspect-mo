import {test; expect} "mo:test/async";
import InspectMo "../src/lib";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import Debug "mo:core/Debug";
import Array "mo:core/Array";

/// Comprehensive authentication systems test suite
/// Tests all authentication providers and security features

let testPrincipal = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
let adminPrincipal = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");
let userPrincipal = Principal.fromText("e73oq-siaaa-aaaah-qcpwa-cai");
let anonymousPrincipal = Principal.anonymous();

// Define Args union type for all authentication tests
type Args = {
  #auth_required: () -> Text;
  #test_guard: () -> Text;
  #whitelist_auth: () -> Text;
  #admin_action: () -> Text;
  #privileged_action: () -> Text;
  #user_action: () -> Text;
  #provider_auth: () -> Text;
  #timing_resistant: () -> Text;
  #escalation_prevention: () -> Text;
  #session_security: () -> Text;
  #context_auth: () -> Text;
};

/// ========================================
/// CALLER-BASED AUTHENTICATION
/// ========================================

await test("requireAuth caller validation", func() : async () {
  Debug.print("Testing requireAuth caller validation...");
  
  let config : InspectMo.InitArgs = {
    allowAnonymous = ?false; // Strict auth mode
    defaultMaxArgSize = ?1024;
    authProvider = null;
    rateLimit = null;
    queryDefaults = null;
    updateDefaults = null;
    developmentMode = false;
    auditLog = false;
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
  
  // Test basic auth requirement using ErasedValidator pattern
  let authRequiredInfo = inspector.createMethodGuardInfo<Text>(
    "auth_required",
    false,
    [
      InspectMo.dynamicAuth<Args, Text>(func(args: InspectMo.DynamicAuthArgs<Args>): InspectMo.GuardResult {
        switch (args.caller) {
          case (null) { #err("Authentication required") };
          case (?caller) {
            if (Principal.isAnonymous(caller)) {
              #err("Authentication required")
            } else {
              #ok
            }
          };
        }
      })
    ],
    func(args: Args): Text {
      switch (args) {
        case (#auth_required(fn)) fn();
        case (_) "default";
      }
    }
  );
  inspector.guard(authRequiredInfo);
  
  // Test with valid caller
  let validArgs : InspectMo.InspectArgs<Args> = {
    methodName = "auth_required";
    caller = testPrincipal;
    arg = Text.encodeUtf8("test data");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #auth_required(func() { "test data" });
  };
  
  let validResult = inspector.guardCheck(validArgs);
  switch (validResult) {
    case (#ok) Debug.print("✓ Valid caller accepted");
    case (#err(msg)) assert false;
  };
  
  // Test with anonymous caller (should fail)
  let invalidArgs : InspectMo.InspectArgs<Args> = {
    methodName = "auth_required";
    caller = anonymousPrincipal;
    arg = Text.encodeUtf8("test data");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #auth_required(func() { "test data" });
  };
  
  switch (inspector.guardCheck(invalidArgs)) {
    case (#err(msg)) { 
      Debug.print("✓ Anonymous auth error: " # msg);
      assert(Text.contains(msg, #text "Authentication required"));
    };
    case (#ok) { assert false; };
  };
  
  Debug.print("✓ RequireAuth caller validation tests passed");
});

/// ========================================
/// PRINCIPAL-BASED AUTHORIZATION
/// ========================================

await test("principal whitelist authorization", func() : async () {
  Debug.print("Testing principal whitelist authorization...");
  
  let config : InspectMo.InitArgs = {
    allowAnonymous = ?false;
    defaultMaxArgSize = ?1024;
    authProvider = null;
    rateLimit = null;
    queryDefaults = null;
    updateDefaults = null;
    developmentMode = false;
    auditLog = false;
  };
  
  let mockInspectMo = InspectMo.InspectMo(
    null, adminPrincipal, testPrincipal, ?config, null,
    func(state: InspectMo.State) {}
  );
  
  let inspector = mockInspectMo.createInspector<Args>();
  
  // Create whitelist-based authorization using ErasedValidator pattern
  let whitelistInfo = inspector.createMethodGuardInfo<Text>(
    "whitelist_auth",
    false,
    [
      InspectMo.customCheck<Args, Text>(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        let allowedPrincipals = [
          testPrincipal,
          adminPrincipal,
          userPrincipal
        ];
        
        switch (Array.find<Principal>(allowedPrincipals, func(p: Principal): Bool { p == args.caller })) {
          case (?_) { #ok };
          case null { #err("Principal not in whitelist") };
        }
      })
    ],
    func(args: Args): Text {
      switch (args) {
        case (#whitelist_auth(fn)) fn();
        case (_) "default";
      }
    }
  );
  inspector.guard(whitelistInfo);
  
  // Test whitelisted principals
  let testWhitelisted = func(principal: Principal, name: Text) {
    let args : InspectMo.InspectArgs<Args> = {
      methodName = "whitelist_auth";
      caller = principal;
      arg = Text.encodeUtf8("test");
      isQuery = false;
      cycles = null;
      deadline = null;
      isInspect = false;
      msg = #whitelist_auth(func() { "test" });
    };
    
    switch (inspector.guardCheck(args)) {
      case (#ok) Debug.print("✓ " # name # " access granted");
      case (#err(msg)) assert false;
    };
  };
  
  testWhitelisted(testPrincipal, "Test principal");
  testWhitelisted(adminPrincipal, "Admin principal");
  testWhitelisted(userPrincipal, "User principal");
  
  // Test non-whitelisted principal
  let unknownPrincipal = Principal.fromText("ey2ie-7qaaa-aaaah-qcpwq-cai");
  let unknownArgs : InspectMo.InspectArgs<Args> = {
    methodName = "whitelist_auth";
    caller = unknownPrincipal;
    arg = Text.encodeUtf8("test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #whitelist_auth(func() { "test" });
  };
  
  switch (inspector.guardCheck(unknownArgs)) {
    case (#err(msg)) { 
      Debug.print("✓ Whitelist rejection: " # msg);
      assert(Text.contains(msg, #text "Principal not in whitelist"));
    };
    case (#ok) { assert false; };
  };
  
  Debug.print("✓ Principal whitelist authorization tests passed");
});

await test("role-based authorization", func() : async () {
  Debug.print("Testing role-based authorization...");
  
  let config : InspectMo.InitArgs = {
    allowAnonymous = ?false;
    defaultMaxArgSize = ?1024;
    authProvider = null;
    rateLimit = null;
    queryDefaults = null;
    updateDefaults = null;
    developmentMode = false;
    auditLog = false;
  };
  
  let mockInspectMo = InspectMo.InspectMo(
    null, adminPrincipal, testPrincipal, ?config, null,
    func(state: InspectMo.State) {}
  );
  
  let inspector = mockInspectMo.createInspector<Args>();
  
  // Define roles
  func getUserRole(principal: Principal): Text {
    if (principal == adminPrincipal) "admin"
    else if (principal == testPrincipal) "owner" 
    else if (principal == userPrincipal) "user"
    else "guest"
  };
  
  // Admin-only action using ErasedValidator pattern
  let adminInfo = inspector.createMethodGuardInfo<Text>(
    "admin_action",
    false,
    [
      InspectMo.customCheck<Args, Text>(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        let role = getUserRole(args.caller);
        if (role == "admin") {
          #ok
        } else {
          #err("Admin role required, found: " # role)
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
  inspector.guard(adminInfo);
  
  // Owner or admin action
  let privilegedInfo = inspector.createMethodGuardInfo<Text>(
    "privileged_action",
    false,
    [
      InspectMo.customCheck<Args, Text>(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        let role = getUserRole(args.caller);
        if (role == "admin" or role == "owner") {
          #ok
        } else {
          #err("Privileged role required, found: " # role)
        }
      })
    ],
    func(args: Args): Text {
      switch (args) {
        case (#privileged_action(fn)) fn();
        case (_) "default";
      }
    }
  );
  inspector.guard(privilegedInfo);
  
  // Any authenticated user action
  let userInfo = inspector.createMethodGuardInfo<Text>(
    "user_action",
    false,
    [
      InspectMo.customCheck<Args, Text>(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        let role = getUserRole(args.caller);
        if (role != "guest") {
          #ok
        } else {
          #err("Authentication required")
        }
      })
    ],
    func(args: Args): Text {
      switch (args) {
        case (#user_action(fn)) fn();
        case (_) "default";
      }
    }
  );
  inspector.guard(userInfo);
  
  // Helper to test role access
  let testRoleAccess = func(methodName: Text, msgVariant: Args, caller: Principal, shouldSucceed: Bool, description: Text) {
    let args : InspectMo.InspectArgs<Args> = {
      methodName = methodName;
      caller = caller;
      arg = Text.encodeUtf8("test");
      isQuery = false;
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
          assert false;
        }
      };
      case (#err(msg)) {
        if (not shouldSucceed) {
          Debug.print("✓ " # description # " access denied: " # msg);
        } else {
          assert false;
        }
      };
    };
  };
  
  // Test admin access
  testRoleAccess("admin_action", #admin_action(func() { "admin task" }), adminPrincipal, true, "Admin admin_action");
  testRoleAccess("privileged_action", #privileged_action(func() { "admin task" }), adminPrincipal, true, "Admin privileged_action");
  testRoleAccess("user_action", #user_action(func() { "admin task" }), adminPrincipal, true, "Admin user_action");
  
  // Test owner access
  testRoleAccess("admin_action", #admin_action(func() { "owner task" }), testPrincipal, false, "Owner admin_action");
  testRoleAccess("privileged_action", #privileged_action(func() { "owner task" }), testPrincipal, true, "Owner privileged_action");
  testRoleAccess("user_action", #user_action(func() { "owner task" }), testPrincipal, true, "Owner user_action");
  
  // Test regular user access
  testRoleAccess("admin_action", #admin_action(func() { "user task" }), userPrincipal, false, "User admin_action");
  testRoleAccess("privileged_action", #privileged_action(func() { "user task" }), userPrincipal, false, "User privileged_action");
  testRoleAccess("user_action", #user_action(func() { "user task" }), userPrincipal, true, "User user_action");
  
  Debug.print("✓ Role-based authorization tests passed");
});

await test("authentication security edge cases", func() : async () {
  Debug.print("Testing authentication security edge cases...");
  
  let config : InspectMo.InitArgs = {
    allowAnonymous = ?false;
    defaultMaxArgSize = ?1024;
    authProvider = null;
    rateLimit = null;
    queryDefaults = null;
    updateDefaults = null;
    developmentMode = false;
    auditLog = false;
  };
  
  let mockInspectMo = InspectMo.InspectMo(
    null, adminPrincipal, testPrincipal, ?config, null,
    func(state: InspectMo.State) {}
  );
  
  let inspector = mockInspectMo.createInspector<Args>();
  
  // Test privilege escalation prevention
  let escalationInfo = inspector.createMethodGuardInfo<Text>(
    "escalation_prevention",
    false,
    [
      InspectMo.customCheck<Args, Text>(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (args.args) {
          case (#escalation_prevention(fn)) {
            let content = fn();
            
            // Prevent admin impersonation
            if (Text.contains(content, #text "admin_override") and args.caller != adminPrincipal) {
              #err("Admin override attempt detected")
            } else if (Text.contains(content, #text "sudo") and args.caller != adminPrincipal) {
              #err("Privilege escalation attempt detected")
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
        case (#escalation_prevention(fn)) fn();
        case (_) "default";
      }
    }
  );
  inspector.guard(escalationInfo);
  
  // Test session hijacking prevention (stateless validation)
  let sessionInfo = inspector.createMethodGuardInfo<Text>(
    "session_security",
    false,
    [
      InspectMo.customCheck<Args, Text>(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        // Validate caller consistency
        if (Principal.isAnonymous(args.caller)) {
          #err("Anonymous session not allowed")
        } else {
          #ok
        }
      })
    ],
    func(args: Args): Text {
      switch (args) {
        case (#session_security(fn)) fn();
        case (_) "default";
      }
    }
  );
  inspector.guard(sessionInfo);
  
  // Test valid cases
  let validEscalationArgs : InspectMo.InspectArgs<Args> = {
    methodName = "escalation_prevention";
    caller = testPrincipal;
    arg = Text.encodeUtf8("normal content");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #escalation_prevention(func() { "normal content" });
  };
  
  switch (inspector.guardCheck(validEscalationArgs)) {
    case (#ok) Debug.print("✓ Normal content accepted");
    case (#err(msg)) assert false;
  };
  
  let validSessionArgs : InspectMo.InspectArgs<Args> = {
    methodName = "session_security";
    caller = testPrincipal;
    arg = Text.encodeUtf8("test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #session_security(func() { "test" });
  };
  
  switch (inspector.guardCheck(validSessionArgs)) {
    case (#ok) Debug.print("✓ Valid session accepted");
    case (#err(msg)) assert false;
  };
  
  // Test security violations
  let adminOverrideArgs : InspectMo.InspectArgs<Args> = {
    methodName = "escalation_prevention";
    caller = testPrincipal;
    arg = Text.encodeUtf8("admin_override attempt");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #escalation_prevention(func() { "admin_override attempt" });
  };
  
  switch (inspector.guardCheck(adminOverrideArgs)) {
    case (#err(msg)) { 
      Debug.print("✓ Admin override blocked: " # msg);
      assert(Text.contains(msg, #text "Admin override attempt"));
    };
    case (#ok) { assert false; };
  };
  
  let sudoArgs : InspectMo.InspectArgs<Args> = {
    methodName = "escalation_prevention";
    caller = userPrincipal;
    arg = Text.encodeUtf8("sudo rm -rf /");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #escalation_prevention(func() { "sudo rm -rf /" });
  };
  
  switch (inspector.guardCheck(sudoArgs)) {
    case (#err(msg)) { 
      Debug.print("✓ Privilege escalation blocked: " # msg);
      assert(Text.contains(msg, #text "Privilege escalation"));
    };
    case (#ok) { assert false; };
  };
  
  let anonymousSessionArgs : InspectMo.InspectArgs<Args> = {
    methodName = "session_security";
    caller = anonymousPrincipal;
    arg = Text.encodeUtf8("test");
    isQuery = false;
    cycles = null;
    deadline = null;
    isInspect = false;
    msg = #session_security(func() { "test" });
  };
  
  switch (inspector.guardCheck(anonymousSessionArgs)) {
    case (#err(msg)) { 
      Debug.print("✓ Anonymous session blocked: " # msg);
    };
    case (#ok) { assert false; };
  };
  
  Debug.print("✓ Authentication security edge cases tests passed");
});

Debug.print("🔐 ALL AUTHENTICATION TESTS COMPLETED! 🔐");
