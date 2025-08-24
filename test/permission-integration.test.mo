import {test} "mo:test/async";
import Debug "mo:core/Debug";
import Principal "mo:core/Principal";
import Time "mo:core/Time";

import Auth "../src/security/auth";
import RBACAdapter "../src/integrations/permission_systems/rbac_adapter";
import IIIntegration "../src/integrations/permission_systems/ii_integration";
import CustomAuth "../src/integrations/permission_systems/custom_auth";

/// Test permission system integrations

await test("RBAC adapter basic functionality", func() : async () {
  Debug.print("Testing RBAC adapter...");
  
  // Create permission system and RBAC adapter
  let permConfig = {
    cacheTTL = 3600;
    maxCacheSize = 100;
    allowAnonymousRead = false;
    defaultDenyMode = true;
    sessionTimeout = ?(8 * 60 * 60);
  };
  let permissionSystem = Auth.PermissionSystem(permConfig);
  
  let rbacConfig = RBACAdapter.createStandardConfig("testapp");
  let permissionMapping = RBACAdapter.createCRUDMapping();
  let rbacAdapter = RBACAdapter.RBACAdapter(permissionSystem, rbacConfig, permissionMapping);
  
  // Define roles
  RBACAdapter.defineStandardRoles(permissionSystem);
  
  let testPrincipal = Principal.fromText("s6bzd-46mcd-mlbx5-cq2jv-m2mhx-nhj6y-erh6g-y73vq-fnfe6-zax3q-mqe"); // Use real self-authenticating user principal
  
  // Test session creation
  let session = rbacAdapter.ensureSession(testPrincipal, func(_p) { ["user"] });
  Debug.print("✓ Session created with roles: " # debug_show(session.roles));
  
  // Test permission checking
  let hasRead = rbacAdapter.hasPermission(testPrincipal, "read");
  switch (hasRead) {
    case (#granted) Debug.print("✓ Read permission granted");
    case (_) Debug.print("✗ Read permission denied");
  };
  
  // Test role checking
  let isUser = rbacAdapter.hasRole(testPrincipal, "user");
  assert isUser;
  Debug.print("✓ User role confirmed");
  
  // Test admin checking
  let isAdmin = rbacAdapter.isAdmin(testPrincipal);
  assert not isAdmin;
  Debug.print("✓ Admin check correctly returned false");
  
  // Test validation rules
  let readRule = rbacAdapter.createReadRule();
  let writeRule = rbacAdapter.createWriteRule();
  Debug.print("✓ Validation rules created successfully");
  
  Debug.print("✓ RBAC adapter test passed");
});

await test("Internet Identity integration", func() : async () {
  Debug.print("Testing simplified Internet Identity integration...");
  
  // Create simplified auth setup
  let setup = IIIntegration.createAuthSetup("myapp");
  
  let testUserPrincipal = Principal.fromText("s6bzd-46mcd-mlbx5-cq2jv-m2mhx-nhj6y-erh6g-y73vq-fnfe6-zax3q-mqe"); // Real self-authenticating user principal
  let testCanisterPrincipal = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai"); // Canister principal
  
  // Test principal type detection
  let isUser = setup.iiIntegration.isSelfAuthenticating(testUserPrincipal);
  Debug.print("✓ Principal type detection: " # debug_show(isUser));
  
  // Test authentication with user principal
  let authResult1 = setup.iiIntegration.authenticate(testUserPrincipal);
  switch (authResult1) {
    case (#authenticated(profile)) {
      Debug.print("✓ User authentication successful");
      Debug.print("✓ First seen: " # debug_show(profile.firstSeen));
      Debug.print("✓ Login count: " # debug_show(profile.loginCount));
    };
    case (_) {
      Debug.print("✗ Expected user authentication to succeed");
      assert false;
    };
  };
  
  // Test authentication with canister principal
  let authResult2 = setup.iiIntegration.authenticate(testCanisterPrincipal);
  switch (authResult2) {
    case (#canister(principal)) {
      Debug.print("✓ Canister principal correctly identified");
    };
    case (_) {
      Debug.print("✗ Expected canister identification");
      assert false;
    };
  };
  
  // Test anonymous principal
  let authResult3 = setup.iiIntegration.authenticate(Principal.anonymous());
  switch (authResult3) {
    case (#anonymous) {
      Debug.print("✓ Anonymous principal correctly identified");
    };
    case (_) {
      Debug.print("✗ Expected anonymous identification");
      assert false;
    };
  };
  
  // Test authentication status
  let isAuth = setup.iiIntegration.isAuthenticated(testUserPrincipal);
  assert isAuth;
  Debug.print("✓ Authentication status confirmed");
  
  // Test user stats (NOTE: Time-based stats like newUsersToday need PIC.js tests for realistic time simulation)
  let stats = setup.iiIntegration.getUserStats();
  Debug.print("✓ User stats - Total: " # debug_show(stats.totalUsers) # 
             ", Active: " # debug_show(stats.activeUsers) # 
             " (newUsersToday: " # debug_show(stats.newUsersToday) # " - time-based, may be inaccurate in mops test)");
  
  // Test utility function
  let isPrincipalUser = IIIntegration.isUserPrincipal(testUserPrincipal);
  assert isPrincipalUser;
  Debug.print("✓ Utility function confirmed user principal");
  
  Debug.print("✓ Simplified Internet Identity integration test passed");
});

await test("custom auth provider", func() : async () {
  Debug.print("Testing custom auth provider...");
  
  // Create a simple token validator
  let validateToken = func(token: Text) : async* ?{
    principal: Principal;
    roles: [Text];
    permissions: [Text];
  } {
    if (token == "valid-token-123") {
      ?{
        principal = Principal.fromText("s6bzd-46mcd-mlbx5-cq2jv-m2mhx-nhj6y-erh6g-y73vq-fnfe6-zax3q-mqe");
        roles = ["user", "verified"];
        permissions = ["read", "write"];
      }
    } else {
      null
    }
  };
  
  // Create token auth provider
  let provider = CustomAuth.createTokenAuthProvider(validateToken, "TestTokenAuth");
  
  // Create permission system
  let permConfig = {
    cacheTTL = 3600;
    maxCacheSize = 100;
    allowAnonymousRead = false;
    defaultDenyMode = true;
    sessionTimeout = ?(4 * 60 * 60);
  };
  let permissionSystem = Auth.PermissionSystem(permConfig);
  
  // Create custom auth adapter
  let customAdapter = CustomAuth.CustomAuthAdapter(provider, permissionSystem, null);
  
  // Test provider info
  let providerInfo = customAdapter.getProviderInfo();
  Debug.print("✓ Provider: " # providerInfo.name # " v" # providerInfo.version);
  
  // Test authentication with missing token (should get challenge)
  let testPrincipal = Principal.fromText("s6bzd-46mcd-mlbx5-cq2jv-m2mhx-nhj6y-erh6g-y73vq-fnfe6-zax3q-mqe");
  let context = {
    caller = testPrincipal;
    origin = ?"https://myapp.com";
    timestamp = Time.now();
    metadata = [];
  };
  
  let authResult1 = await* customAdapter.authenticate(context);
  switch (authResult1) {
    case (#challenge(challenge)) {
      Debug.print("✓ Challenge created: " # challenge.challengeType);
      
      // Test challenge response with valid token
      let response = {
        challengeId = challenge.challengeId;
        response = "valid-token-123";
        metadata = [];
      };
      
      let authResult2 = await* customAdapter.verifyChallenge(response);
      switch (authResult2) {
        case (#success({ principal; roles; permissions })) {
          Debug.print("✓ Challenge verification successful");
          Debug.print("✓ Authenticated principal: " # Principal.toText(principal));
          Debug.print("✓ Roles: " # debug_show(roles));
          Debug.print("✓ Permissions: " # debug_show(permissions));
        };
        case (_) {
          Debug.print("✗ Challenge verification failed");
          assert false;
        };
      };
    };
    case (_) {
      Debug.print("✗ Expected challenge, got: " # debug_show(authResult1));
      assert false;
    };
  };
  
  // Test direct authentication with token in metadata
  let contextWithToken = {
    caller = testPrincipal;
    origin = ?"https://myapp.com";
    timestamp = Time.now();
    metadata = [("token", "valid-token-123")];
  };
  
  let authResult3 = await* customAdapter.authenticate(contextWithToken);
  switch (authResult3) {
    case (#success({ principal; roles })) {
      Debug.print("✓ Direct token authentication successful");
      Debug.print("✓ Roles: " # debug_show(roles));
    };
    case (_) {
      Debug.print("✗ Direct token authentication failed");
      assert false;
    };
  };
  
  Debug.print("✓ Custom auth provider test passed");
});

await test("permission optimization patterns", func() : async () {
  Debug.print("Testing permission optimization patterns...");
  
  // Create systems
  let permConfig = {
    cacheTTL = 1; // Short TTL for testing
    maxCacheSize = 10;
    allowAnonymousRead = true;
    defaultDenyMode = false;
    sessionTimeout = ?(60);
  };
  let permissionSystem = Auth.PermissionSystem(permConfig);
  
  let rbacConfig = RBACAdapter.createStandardConfig("perftest");
  let granularMapping = RBACAdapter.createGranularMapping();
  let rbacAdapter = RBACAdapter.RBACAdapter(permissionSystem, rbacConfig, granularMapping);
  
  // Define roles
  RBACAdapter.defineStandardRoles(permissionSystem);
  
  let testPrincipal = Principal.fromText("s6bzd-46mcd-mlbx5-cq2jv-m2mhx-nhj6y-erh6g-y73vq-fnfe6-zax3q-mqe");
  
  // Test multiple operation permissions
  let operations = ["create", "read", "update", "delete", "export", "import"];
  for (operation in operations.vals()) {
    let perms = rbacAdapter.getOperationPermissions(operation);
    Debug.print("✓ Operation '" # operation # "' requires: " # debug_show(perms));
  };
  
  // Test session with multiple roles
  let session = rbacAdapter.ensureSession(testPrincipal, func(_p) { ["moderator", "user"] });
  Debug.print("✓ Multi-role session created: " # debug_show(session.roles));
  Debug.print("✓ Flattened permissions: " # debug_show(session.permissions));
  
  // Test permission caching
  let access1 = rbacAdapter.hasOperationAccess(testPrincipal, "read");
  let access2 = rbacAdapter.hasOperationAccess(testPrincipal, "read"); // Should use cache
  
  Debug.print("✓ Permission caching test completed");
  
  // Test fallback validation
  let fallbackResult = rbacAdapter.validateWithFallback(
    testPrincipal,
    "nonexistent-permission",
    ["moderator"]
  );
  assert fallbackResult; // Should succeed due to moderator role
  Debug.print("✓ Fallback validation successful");
  
  Debug.print("✓ Permission optimization test passed");
});
