/// Internet Identity Integration for InspectMo
/// Simplified integration focusing on self-authenticating principals

import Principal "mo:core/Principal";
import Array "mo:core/Array";
import Text "mo:core/Text";
import Time "mo:core/Time";
import Map "mo:core/Map";

import Types "../../migrations/v000_001_000/types";
import Auth "../../security/auth";
import RBACAdapter "./rbac_adapter";

module {
  
  /// Simple II configuration focused on user management
  public type IIConfig = {
    sessionTimeout: Int; // Session timeout in seconds
    autoCreateUser: Bool; // Automatically create user sessions
    defaultUserRole: Text; // Default role for authenticated users
  };
  
  /// Basic user profile for authenticated users
  public type UserProfile = {
    principal: Principal;
    firstSeen: Int; // When we first saw this user
    lastSeen: Int; // Last activity timestamp
    loginCount: Nat; // Number of times they've authenticated
  };
  
  /// Simple authentication result
  public type AuthResult = {
    #authenticated: UserProfile;
    #anonymous; // Anonymous caller
    #canister: Principal; // Canister caller (might be allowed in some contexts)
  };
  
  /// Simplified Internet Identity integration
  public class IIIntegration(
    config: IIConfig,
    permissionSystem: Auth.PermissionSystem,
    rbacAdapter: RBACAdapter.RBACAdapter
  ) {
    
    // Track user activity
    private var userProfiles = Map.empty<Principal, UserProfile>();
    
    /// Check if a principal is self-authenticating (user, not canister)
    public func isSelfAuthenticating(principal: Principal) : Bool {
      let principalText = Principal.toText(principal);
      let bytes = Principal.toBlob(principal);
      
      // Self-authenticating principals are longer than canister principals
      // and don't end with canister-specific suffixes
      bytes.size() > 10 and not Text.endsWith(principalText, #text "-cai")
    };
    
    /// Simple authentication check based on principal type
    public func authenticate(principal: Principal) : AuthResult {
      if (Principal.isAnonymous(principal)) {
        return #anonymous;
      };
      
      if (not isSelfAuthenticating(principal)) {
        return #canister(principal);
      };
      
      // This is a self-authenticating principal (user)
      let now = Time.now();
      let profile = switch (Map.get(userProfiles, Principal.compare, principal)) {
        case (?existing) {
          // Update existing user
          let updated = {
            principal = existing.principal;
            firstSeen = existing.firstSeen;
            lastSeen = now;
            loginCount = existing.loginCount + 1;
          };
          ignore Map.insert(userProfiles, Principal.compare, principal, updated);
          updated
        };
        case null {
          // New user
          let newProfile = {
            principal;
            firstSeen = now;
            lastSeen = now;
            loginCount = 1;
          };
          ignore Map.insert(userProfiles, Principal.compare, principal, newProfile);
          newProfile
        };
      };
      
      // Ensure session exists for authenticated user
      if (config.autoCreateUser) {
        ignore rbacAdapter.ensureSession(principal, func(_p) { [config.defaultUserRole] });
      };
      
      #authenticated(profile)
    };
    
    /// Create a simple authentication validation rule
    public func createAuthRule() : Types.ValidationRule<Any, Any> {
      #requireAuth
    };
    
    /// Create a validation rule that requires self-authenticating principals
    public func createUserOnlyRule() : Types.ValidationRule<Any, Any> {
      // We can extend the type system later to support this check
      // For now, just require auth
      #requireAuth
    };
    
    /// Get user profile if it exists
    public func getUserProfile(principal: Principal) : ?UserProfile {
      Map.get(userProfiles, Principal.compare, principal)
    };
    
    /// Check if user is authenticated and has a session
    public func isAuthenticated(principal: Principal) : Bool {
      isSelfAuthenticating(principal) and 
      permissionSystem.getSession(principal) != null
    };
    
    /// Get simple user statistics
    public func getUserStats() : {
      totalUsers: Nat;
      activeUsers: Nat;
      newUsersToday: Nat;
    } {
      let now = Time.now();
      let dayAgo = now - 24 * 60 * 60 * 1_000_000_000;
      var totalUsers = 0;
      var activeUsers = 0;
      var newUsersToday = 0;
      
      for ((principal, profile) in Map.entries(userProfiles)) {
        totalUsers += 1;
        
        // Check if user has an active session
        if (isAuthenticated(principal)) {
          activeUsers += 1;
        };
        
        // Check if user was first seen today
        if (profile.firstSeen >= dayAgo) {
          newUsersToday += 1;
        };
      };
      
      { totalUsers; activeUsers; newUsersToday }
    };
    
    /// Logout user (revoke session)
    public func logout(principal: Principal) : Bool {
      permissionSystem.revokeSession(principal)
    };
    
    /// Clean up old data
    public func cleanup() : () {
      permissionSystem.cleanup();
    };
  };
  
  /// Helper functions for Internet Identity integration
  
  /// Create simple II configuration
  public func createSimpleConfig() : IIConfig {
    {
      sessionTimeout = 8 * 60 * 60; // 8 hours
      autoCreateUser = true;
      defaultUserRole = "user";
    }
  };
  
  /// Create a complete authentication setup focused on self-authenticating principals
  public func createAuthSetup(appPrefix: Text) : {
    config: IIConfig;
    permissionSystem: Auth.PermissionSystem;
    rbacAdapter: RBACAdapter.RBACAdapter;
    iiIntegration: IIIntegration;
  } {
    let config = createSimpleConfig();
    
    let permConfig = {
      cacheTTL = 3600; // 1 hour
      maxCacheSize = 1000;
      allowAnonymousRead = false;
      defaultDenyMode = true;
      sessionTimeout = ?config.sessionTimeout;
    };
    
    let permissionSystem = Auth.PermissionSystem(permConfig);
    
    let rbacConfig = RBACAdapter.createStandardConfig(appPrefix);
    let permissionMapping = RBACAdapter.createCRUDMapping();
    let rbacAdapter = RBACAdapter.RBACAdapter(permissionSystem, rbacConfig, permissionMapping);
    
    // Define standard roles
    RBACAdapter.defineStandardRoles(permissionSystem);
    
    let iiIntegration = IIIntegration(config, permissionSystem, rbacAdapter);
    
    { config; permissionSystem; rbacAdapter; iiIntegration }
  };
  
  /// Utility function to check if a principal looks like a user (self-authenticating)
  public func isUserPrincipal(principal: Principal) : Bool {
    if (Principal.isAnonymous(principal)) {
      return false;
    };
    
    let principalText = Principal.toText(principal);
    let bytes = Principal.toBlob(principal);
    
    // Self-authenticating principals are longer and don't end with canister suffixes
    bytes.size() > 10 and not Text.endsWith(principalText, #text "-cai")
  };
}
