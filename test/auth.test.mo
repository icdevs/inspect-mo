import {test} "mo:test/async";
import Debug "mo:core/Debug";
import Principal "mo:core/Principal";
import Array "mo:core/Array";
import Text "mo:core/Text";
import Auth "../src/security/auth";
import InspectMo "../src/core/inspector";
import Map "mo:core/Map";

/// Test authentication and permission system with ErasedValidator integration

await test("ErasedValidator auth integration", func() : async () {
  Debug.print("Testing ErasedValidator with authentication...");
  
  // ErasedValidator setup with Args union pattern
  type UserProfileArgs = {
    name: Text;
    email: Text;
    age: Nat;
  };
  
  type AdminActionArgs = {
    action: Text;
    target: Principal;
  };
  
  type Args = {
    #updateProfile: UserProfileArgs;
    #adminAction: AdminActionArgs;
  };
  
  // Create inspector config without complex auth provider for now
  let inspectConfig : InspectMo.InitArgs = {
    allowAnonymous = ?false;
    defaultMaxArgSize = ?1024;
    authProvider = null; // Simplified for testing
    rateLimit = null;
    queryDefaults = null;
    updateDefaults = null;
    developmentMode = true;
    auditLog = false;
  };
  
  // Create mock InspectMo instance for testing
  let mockInspectMo = InspectMo.InspectMo(
    null, // stored state
    Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"), // instantiator
    Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"), // canister
    ?inspectConfig, // args
    null, // environment
    func(state: InspectMo.State) {} // storageChanged callback
  );
  
  let inspector = mockInspectMo.createInspector<Args>();
  
  // Register methods with authentication rules
  inspector.inspect(inspector.createMethodGuardInfo<UserProfileArgs>(
    "updateProfile",
    false,
    [
      #requireAuth,
      #textSize(func(args: UserProfileArgs) : Text { args.name }, ?1, ?50),
      #textSize(func(args: UserProfileArgs) : Text { args.email }, ?5, ?100),
      #natValue(func(args: UserProfileArgs) : Nat { args.age }, ?0, ?150)
    ],
    func(args: Args) : UserProfileArgs {
      switch (args) {
        case (#updateProfile(profile)) profile;
        case (_) {
          // This should never happen in practice
          { name = "default"; email = "default@example.com"; age = 0 }
        };
      };
    }
  ));
  
  inspector.inspect(inspector.createMethodGuardInfo<AdminActionArgs>(
    "adminAction", 
    false,
    [
      #requireAuth,
      #textSize(func(args: AdminActionArgs) : Text { args.action }, ?1, ?20)
    ],
    func(args: Args) : AdminActionArgs {
      switch (args) {
        case (#adminAction(action)) action;
        case (_) {
          // This should never happen in practice
          { action = "default"; target = Principal.fromText("aaaaa-aa") }
        };
      };
    }
  ));
  
  let testPrincipal = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
  let anonPrincipal = Principal.fromText("2vxsx-fae");
  
  // Test authenticated user updating profile
  let userProfileArgs : InspectMo.InspectArgs<Args> = {
    methodName = "updateProfile";
    caller = testPrincipal;
    arg = Text.encodeUtf8("user profile data");
    msg = #updateProfile({
      name = "John Doe";
      email = "john@example.com";
      age = 30;
    });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (inspector.inspectCheck(userProfileArgs)) {
    case (#ok) Debug.print("✓ Authenticated user can update profile");
    case (#err(msg)) {
      Debug.print("✗ User profile update failed: " # msg);
      assert false;
    };
  };
  
  // Test anonymous user trying to update profile
  let anonProfileArgs : InspectMo.InspectArgs<Args> = {
    methodName = "updateProfile";
    caller = anonPrincipal;
    arg = Text.encodeUtf8("anon profile data");
    msg = #updateProfile({
      name = "Anonymous";
      email = "anon@example.com";
      age = 25;
    });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (inspector.inspectCheck(anonProfileArgs)) {
    case (#ok) {
      Debug.print("✗ Anonymous user should not be able to update profile");
      assert false;
    };
    case (#err(msg)) Debug.print("✓ Anonymous user blocked from profile update: " # msg);
  };
  
  // Test user trying admin action (should pass with basic auth, no role checking)
  let userAdminArgs : InspectMo.InspectArgs<Args> = {
    methodName = "adminAction";
    caller = testPrincipal;
    arg = Text.encodeUtf8("admin action data");
    msg = #adminAction({
      action = "deleteUser";
      target = anonPrincipal;
    });
    isQuery = false;
    isInspect = true;
    cycles = ?0;
    deadline = null;
  };
  
  switch (inspector.inspectCheck(userAdminArgs)) {
    case (#ok) Debug.print("✓ Authenticated user can perform admin action (basic auth only)");
    case (#err(msg)) {
      Debug.print("✗ User admin action failed: " # msg);
      assert false;
    };
  };
  
  Debug.print("✓ ErasedValidator auth integration test passed");
});

await test("permission system basic functionality", func() : async () {
  Debug.print("Testing permission system basic functionality...");
  
  let config : Auth.PermissionConfig = {
    cacheTTL = 300; // 5 minutes
    maxCacheSize = 1000;
    allowAnonymousRead = false;
    defaultDenyMode = true;
    sessionTimeout = ?3600; // 1 hour
  };
  
  let permissionSystem = Auth.PermissionSystem(config);
  let testPrincipal = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
  
  // Define some roles
  let adminRole : Auth.RoleDefinition = {
    name = "admin";
    permissions = ["read", "write", "delete", "admin"];
    inherits = [];
    metadata = [];
  };
  
  let userRole : Auth.RoleDefinition = {
    name = "user";
    permissions = ["read", "write"];
    inherits = [];
    metadata = [];
  };
  
  permissionSystem.defineRoles([adminRole, userRole]);
  
  // Create session for user
  let session = permissionSystem.createSession(testPrincipal, ["user"], [], null);
  Debug.print("✓ User session created with roles: " # debug_show(session.roles));
  Debug.print("✓ User permissions: " # debug_show(session.permissions));
  
  // Test permission checking
  switch (permissionSystem.hasPermission(testPrincipal, "read")) {
    case (#granted) Debug.print("✓ Read permission granted");
    case (#denied(msg)) assert false;
    case (#unknownPermission(_)) assert false;
  };
  
  switch (permissionSystem.hasPermission(testPrincipal, "admin")) {
    case (#granted) assert false; // User shouldn't have admin permission
    case (#denied(msg)) Debug.print("✓ Admin permission correctly denied: " # msg);
    case (#unknownPermission(_)) assert false;
  };
  
  Debug.print("✓ Permission system basic functionality test passed");
});

await test("role inheritance", func() : async () {
  Debug.print("Testing role inheritance...");
  
  let config : Auth.PermissionConfig = {
    cacheTTL = 300;
    maxCacheSize = 1000;
    allowAnonymousRead = false;
    defaultDenyMode = true;
    sessionTimeout = ?3600;
  };
  
  let permissionSystem = Auth.PermissionSystem(config);
  let testPrincipal = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
  
  // Define role hierarchy
  let baseRole : Auth.RoleDefinition = {
    name = "base";
    permissions = ["read"];
    inherits = [];
    metadata = [];
  };
  
  let editorRole : Auth.RoleDefinition = {
    name = "editor";
    permissions = ["write"];
    inherits = ["base"]; // Inherits read permission
    metadata = [];
  };
  
  let adminRole : Auth.RoleDefinition = {
    name = "admin";
    permissions = ["admin"];
    inherits = ["editor"]; // Inherits write and read permissions
    metadata = [];
  };
  
  permissionSystem.defineRoles([baseRole, editorRole, adminRole]);
  
  // Create admin session
  let session = permissionSystem.createSession(testPrincipal, ["admin"], [], null);
  Debug.print("✓ Admin session created");
  Debug.print("✓ Admin permissions: " # debug_show(session.permissions));
  
  // Admin should have all permissions through inheritance
  switch (permissionSystem.hasPermission(testPrincipal, "read")) {
    case (#granted) Debug.print("✓ Admin has read permission (inherited)");
    case (_) assert false;
  };
  
  switch (permissionSystem.hasPermission(testPrincipal, "write")) {
    case (#granted) Debug.print("✓ Admin has write permission (inherited)");
    case (_) assert false;
  };
  
  switch (permissionSystem.hasPermission(testPrincipal, "admin")) {
    case (#granted) Debug.print("✓ Admin has admin permission (direct)");
    case (_) assert false;
  };
  
  Debug.print("✓ Role inheritance test passed");
});

await test("session management", func() : async () {
  Debug.print("Testing session management...");
  
  let config : Auth.PermissionConfig = {
    cacheTTL = 300;
    maxCacheSize = 1000;
    allowAnonymousRead = false;
    defaultDenyMode = true;
    sessionTimeout = ?1; // 1 second for testing
  };
  
  let permissionSystem = Auth.PermissionSystem(config);
  let testPrincipal = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
  
  // Define a basic role
  let userRole : Auth.RoleDefinition = {
    name = "user";
    permissions = ["read"];
    inherits = [];
    metadata = [];
  };
  
  permissionSystem.defineRole(userRole);
  
  // Create session
  let session = permissionSystem.createSession(testPrincipal, ["user"], [], null);
  Debug.print("✓ Session created with expiration");
  
  // Session should be active initially
  switch (permissionSystem.getSession(testPrincipal)) {
    case (?activeSession) Debug.print("✓ Session is active");
    case null assert false;
  };
  
  // Test session revocation
  let revoked = permissionSystem.revokeSession(testPrincipal);
  assert revoked;
  Debug.print("✓ Session revoked successfully");
  
  // Session should be gone
  switch (permissionSystem.getSession(testPrincipal)) {
    case (?_) assert false;
    case null Debug.print("✓ Session properly removed");
  };
  
  Debug.print("✓ Session management test passed");
});

await test("simple auth provider", func() : async () {
  Debug.print("Testing simple auth provider...");
  
  let config : Auth.PermissionConfig = {
    cacheTTL = 300;
    maxCacheSize = 1000;
    allowAnonymousRead = false;
    defaultDenyMode = true;
    sessionTimeout = ?3600;
  };
  
  let permissionSystem = Auth.PermissionSystem(config);
  let testPrincipal = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
  
  // Define roles
  let userRole : Auth.RoleDefinition = {
    name = "user";
    permissions = ["read", "write"];
    inherits = [];
    metadata = [];
  };
  
  permissionSystem.defineRole(userRole);
  
  // Create auth provider
  let getUserRoles = func(principal: Principal) : [Auth.Role] {
    if (Principal.equal(principal, testPrincipal)) {
      ["user"]
    } else {
      []
    }
  };
  
  let authProvider = Auth.createSimpleAuthProvider(permissionSystem, getUserRoles);
  
  // Test authentication
  let authResult = await* authProvider.authenticate(testPrincipal);
  switch (authResult) {
    case (#authenticated(session)) {
      Debug.print("✓ Authentication successful");
      Debug.print("✓ Session roles: " # debug_show(session.roles));
    };
    case (#denied(reason)) assert false;
    case (#expired(_)) assert false;
  };
  
  // Test permission checking through provider
  let permResult = await* authProvider.hasPermission(testPrincipal, "read");
  switch (permResult) {
    case (#granted) Debug.print("✓ Permission check through provider successful");
    case (_) assert false;
  };
  
  Debug.print("✓ Simple auth provider test passed");
});
