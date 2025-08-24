/// Authentication and Permission System for InspectMo
/// Provides role-based access control, permission caching, and multiple auth provider support

import Map "mo:core/Map";
import Time "mo:core/Time";
import Principal "mo:core/Principal";
import Array "mo:core/Array";
import Result "mo:core/Result";
import Text "mo:core/Text";

module {
  
  /// Permission representation
  public type Permission = Text;
  
  /// Role representation  
  public type Role = Text;
  
  /// User session information
  public type UserSession = {
    principal: Principal;
    roles: [Role];
    permissions: [Permission];
    expiresAt: ?Int; // Optional expiration timestamp
    metadata: [(Text, Text)]; // Additional session data
  };
  
  /// Authentication result
  public type AuthResult = {
    #authenticated: UserSession;
    #denied: Text; // Reason for denial
    #expired: Int; // When the session expired
  };
  
  /// Permission check result
  public type PermissionResult = {
    #granted;
    #denied: Text; // Reason for denial
    #unknownPermission: Text; // Permission not recognized
  };
  
  /// Role definition with permissions
  public type RoleDefinition = {
    name: Role;
    permissions: [Permission];
    inherits: [Role]; // Roles this role inherits from
    metadata: [(Text, Text)];
  };
  
  /// Auth provider interface
  public type AuthProvider = {
    /// Authenticate a principal and return session info
    authenticate: (Principal) -> async* AuthResult;
    
    /// Check if principal has specific permission
    hasPermission: (Principal, Permission) -> async* PermissionResult;
    
    /// Get all roles for a principal
    getRoles: (Principal) -> async* [Role];
    
    /// Get all permissions for a principal (flattened from roles)
    getPermissions: (Principal) -> async* [Permission];
    
    /// Validate session is still active
    validateSession: (Principal) -> async* Bool;
    
    /// Refresh session if supported
    refreshSession: (Principal) -> async* ?UserSession;
  };
  
  /// Permission cache entry
  public type CacheEntry = {
    permissions: [Permission];
    roles: [Role];
    timestamp: Int;
    ttl: Int; // Time to live in seconds
  };
  
  /// Permission system configuration
  public type PermissionConfig = {
    cacheTTL: Int; // Cache time-to-live in seconds
    maxCacheSize: Nat; // Maximum number of cached entries
    allowAnonymousRead: Bool; // Allow anonymous for read operations
    defaultDenyMode: Bool; // Deny by default if permission not found
    sessionTimeout: ?Int; // Default session timeout in seconds
  };
  
  /// Main permission system class
  public class PermissionSystem(config: PermissionConfig) {
    
    // Cache for permission lookups
    private var permissionCache = Map.empty<Principal, CacheEntry>();
    private var roleDefinitions = Map.empty<Role, RoleDefinition>();
    private var activeSessions = Map.empty<Principal, UserSession>();
    
    /// Register a role definition
    public func defineRole(role: RoleDefinition) : () {
      ignore Map.insert(roleDefinitions, Text.compare, role.name, role);
    };
    
    /// Define multiple roles at once
    public func defineRoles(roles: [RoleDefinition]) : () {
      for (role in roles.vals()) {
        defineRole(role);
      };
    };
    
    /// Flatten role permissions including inheritance
    private func flattenRolePermissions(roleName: Role, visited: [Role]) : [Permission] {
      // Prevent infinite recursion
      if (Array.find<Role>(visited, func(r) = r == roleName) != null) {
        return [];
      };
      
      switch (Map.get(roleDefinitions, Text.compare, roleName)) {
        case (?role) {
          let newVisited = Array.concat(visited, [roleName]);
          var allPermissions = role.permissions;
          
          // Add inherited permissions
          for (inheritedRole in role.inherits.vals()) {
            let inheritedPerms = flattenRolePermissions(inheritedRole, newVisited);
            allPermissions := Array.concat(allPermissions, inheritedPerms);
          };
          
          // Remove duplicates
          Array.foldLeft<Permission, [Permission]>(allPermissions, [], func(acc, perm) {
            if (Array.find<Permission>(acc, func(p) = p == perm) == null) {
              Array.concat(acc, [perm])
            } else acc
          })
        };
        case null [];
      }
    };
    
    /// Check if cache entry is still valid
    private func isCacheValid(entry: CacheEntry) : Bool {
      let now = Time.now();
      (now - entry.timestamp) < (entry.ttl * 1_000_000_000)
    };
    
    /// Get permissions from cache or calculate fresh
    private func getPermissionsWithCache(principal: Principal, roles: [Role]) : [Permission] {
      // Check cache first
      switch (Map.get(permissionCache, Principal.compare, principal)) {
        case (?cached) {
          if (isCacheValid(cached)) {
            return cached.permissions;
          };
        };
        case null {};
      };
      
      // Calculate fresh permissions
      var allPermissions : [Permission] = [];
      for (role in roles.vals()) {
        let rolePerms = flattenRolePermissions(role, []);
        allPermissions := Array.concat(allPermissions, rolePerms);
      };
      
      // Remove duplicates
      let uniquePermissions = Array.foldLeft<Permission, [Permission]>(allPermissions, [], func(acc, perm) {
        if (Array.find<Permission>(acc, func(p) = p == perm) == null) {
          Array.concat(acc, [perm])
        } else acc
      });
      
      // Cache the result
      let cacheEntry : CacheEntry = {
        permissions = uniquePermissions;
        roles = roles;
        timestamp = Time.now();
        ttl = config.cacheTTL;
      };
      
      ignore Map.insert(permissionCache, Principal.compare, principal, cacheEntry);
      
      uniquePermissions
    };
    
    /// Create a user session
    public func createSession(
      principal: Principal, 
      roles: [Role],
      metadata: [(Text, Text)],
      customTTL: ?Int
    ) : UserSession {
      let permissions = getPermissionsWithCache(principal, roles);
      let expiresAt = switch (customTTL, config.sessionTimeout) {
        case (?ttl, _) ?(Time.now() + ttl * 1_000_000_000);
        case (null, ?defaultTTL) ?(Time.now() + defaultTTL * 1_000_000_000);
        case (null, null) null;
      };
      
      let session : UserSession = {
        principal;
        roles;
        permissions;
        expiresAt;
        metadata;
      };
      
      ignore Map.insert(activeSessions, Principal.compare, principal, session);
      session
    };
    
    /// Get active session for principal
    public func getSession(principal: Principal) : ?UserSession {
      switch (Map.get(activeSessions, Principal.compare, principal)) {
        case (?session) {
          // Check if session is expired
          switch (session.expiresAt) {
            case (?expiry) {
              if (Time.now() > expiry) {
                ignore Map.delete(activeSessions, Principal.compare, principal);
                null
              } else ?session
            };
            case null ?session;
          }
        };
        case null null;
      }
    };
    
    /// Check if principal has specific permission
    public func hasPermission(principal: Principal, permission: Permission) : PermissionResult {
      // Handle anonymous access
      if (Principal.isAnonymous(principal) and not config.allowAnonymousRead) {
        return #denied("Anonymous access not allowed");
      };
      
      switch (getSession(principal)) {
        case (?session) {
          if (Array.find<Permission>(session.permissions, func(p) = p == permission) != null) {
            #granted
          } else {
            if (config.defaultDenyMode) {
              #denied("Permission '" # permission # "' not granted")
            } else {
              #unknownPermission(permission)
            }
          }
        };
        case null {
          if (config.defaultDenyMode) {
            #denied("No active session")
          } else {
            #unknownPermission(permission)
          }
        };
      }
    };
    
    /// Check if principal has any of the specified permissions
    public func hasAnyPermission(principal: Principal, permissions: [Permission]) : PermissionResult {
      for (permission in permissions.vals()) {
        switch (hasPermission(principal, permission)) {
          case (#granted) return #granted;
          case (_) { /* Continue checking */ };
        };
      };
      #denied("None of the required permissions granted")
    };
    
    /// Check if principal has all specified permissions
    public func hasAllPermissions(principal: Principal, permissions: [Permission]) : PermissionResult {
      for (permission in permissions.vals()) {
        switch (hasPermission(principal, permission)) {
          case (#granted) { /* Continue checking */ };
          case (result) return result;
        };
      };
      #granted
    };
    
    /// Check if principal has specific role
    public func hasRole(principal: Principal, role: Role) : Bool {
      switch (getSession(principal)) {
        case (?session) {
          Array.find<Role>(session.roles, func(r) = r == role) != null
        };
        case null false;
      }
    };
    
    /// Revoke session
    public func revokeSession(principal: Principal) : Bool {
      let deleted = Map.delete(activeSessions, Principal.compare, principal);
      if (deleted) {
        // Also clear permission cache
        ignore Map.delete(permissionCache, Principal.compare, principal);
        true
      } else {
        false
      }
    };
    
    /// Clean up expired sessions and cache entries
    public func cleanup() : () {
      let now = Time.now();
      
      // Clean expired sessions
      let newSessions = Map.empty<Principal, UserSession>();
      for ((principal, session) in Map.entries(activeSessions)) {
        let keepSession = switch (session.expiresAt) {
          case (?expiry) now <= expiry;
          case null true;
        };
        
        if (keepSession) {
          ignore Map.insert(newSessions, Principal.compare, principal, session);
        };
      };
      activeSessions := newSessions;
      
      // Clean expired cache entries
      let newCache = Map.empty<Principal, CacheEntry>();
      for ((principal, entry) in Map.entries(permissionCache)) {
        if (isCacheValid(entry)) {
          ignore Map.insert(newCache, Principal.compare, principal, entry);
        };
      };
      permissionCache := newCache;
    };
    
    /// Get system statistics
    public func getStats() : {
      activeSessions: Nat;
      cachedPermissions: Nat;
      definedRoles: Nat;
    } {
      {
        activeSessions = Map.size(activeSessions);
        cachedPermissions = Map.size(permissionCache);
        definedRoles = Map.size(roleDefinitions);
      }
    };
  };
  
  /// Create a simple RBAC auth provider
  public func createSimpleAuthProvider(
    permissionSystem: PermissionSystem,
    getUserRoles: (Principal) -> [Role]
  ) : AuthProvider {
    {
      authenticate = func(principal: Principal) : async* AuthResult {
        let roles = getUserRoles(principal);
        let session = permissionSystem.createSession(principal, roles, [], null);
        #authenticated(session)
      };
      
      hasPermission = func(principal: Principal, permission: Permission) : async* PermissionResult {
        permissionSystem.hasPermission(principal, permission)
      };
      
      getRoles = func(principal: Principal) : async* [Role] {
        switch (permissionSystem.getSession(principal)) {
          case (?session) session.roles;
          case null [];
        }
      };
      
      getPermissions = func(principal: Principal) : async* [Permission] {
        switch (permissionSystem.getSession(principal)) {
          case (?session) session.permissions;
          case null [];
        }
      };
      
      validateSession = func(principal: Principal) : async* Bool {
        permissionSystem.getSession(principal) != null
      };
      
      refreshSession = func(principal: Principal) : async* ?UserSession {
        switch (permissionSystem.getSession(principal)) {
          case (?session) {
            // Create new session with same roles
            ?permissionSystem.createSession(session.principal, session.roles, session.metadata, null)
          };
          case null null;
        }
      };
    }
  };
  
  /// Common permission constants
  public module Permissions {
    public let READ = "read";
    public let WRITE = "write";
    public let DELETE = "delete";
    public let ADMIN = "admin";
    public let SYSTEM = "system";
    public let EXECUTE = "execute";
    public let CREATE = "create";
    public let UPDATE = "update";
  };
  
  /// Common role constants
  public module Roles {
    public let ADMIN = "admin";
    public let USER = "user";
    public let GUEST = "guest";
    public let SYSTEM = "system";
    public let MODERATOR = "moderator";
  };
}
