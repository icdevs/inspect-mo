/// RBAC (Role-Based Access Control) Adapter for InspectMo
/// Integrates the permission system with InspectMo validation framework

import Map "mo:core/Map";
import Principal "mo:core/Principal";
import Array "mo:core/Array";
import Text "mo:core/Text";
import Result "mo:core/Result";
import Option "mo:core/Option";

import Types "../../migrations/v000_001_000/types";
import Auth "../../security/auth";

module {
  
  /// RBAC configuration for integration with InspectMo
  public type RBACConfig = {
    defaultRole: Text; // Default role for authenticated users
    anonymousRole: ?Text; // Optional role for anonymous users
    adminRoles: [Text]; // Roles that bypass all checks
    permissionPrefix: Text; // Prefix for permission names (e.g., "app:")
  };
  
  /// Permission mapping for different operation types
  public type PermissionMapping = {
    read: [Text]; // Permissions for read operations
    write: [Text]; // Permissions for write operations
    admin: [Text]; // Permissions for admin operations
    custom: [(Text, [Text])]; // Custom operation mappings
  };
  
  /// RBAC adapter class that bridges auth system with InspectMo
  public class RBACAdapter(
    permissionSystem: Auth.PermissionSystem,
    config: RBACConfig,
    permissionMapping: PermissionMapping
  ) {
    
    /// Create a permission-based validation rule
    public func createPermissionRule(permission: Text) : Types.ValidationRule<Any, Any> {
      #requirePermission(config.permissionPrefix # permission)
    };
    
    /// Create a role-based validation rule
    public func createRoleRule(requiredRole: Text) : Types.ValidationRule<Any, Any> {
      #requireRole(requiredRole)
    };
    
    /// Create operation-specific rules based on permission mapping
    public func createReadRule() : Types.ValidationRule<Any, Any> {
      if (permissionMapping.read.size() > 0) {
        createPermissionRule(permissionMapping.read[0])
      } else {
        createPermissionRule("read")
      }
    };
    
    public func createWriteRule() : Types.ValidationRule<Any, Any> {
      if (permissionMapping.write.size() > 0) {
        createPermissionRule(permissionMapping.write[0])
      } else {
        createPermissionRule("write")
      }
    };
    
    public func createAdminRule() : Types.ValidationRule<Any, Any> {
      if (permissionMapping.admin.size() > 0) {
        createPermissionRule(permissionMapping.admin[0])
      } else {
        createPermissionRule("admin")
      }
    };
    
    /// Create a custom operation rule
    public func createCustomOperationRule(operation: Text) : Types.ValidationRule<Any, Any> {
      let permissions = switch (Array.find<(Text, [Text])>(permissionMapping.custom, func((op, _)) { op == operation })) {
        case (?(_, perms)) perms;
        case null [];
      };
      
      if (permissions.size() == 0) {
        // Fallback to operation name as permission
        createPermissionRule(operation)
      } else {
        createPermissionRule(permissions[0])
      }
    };
    
    /// Get a list of all permissions for a given operation
    public func getOperationPermissions(operation: Text) : [Text] {
      switch (operation) {
        case ("read") permissionMapping.read;
        case ("write") permissionMapping.write;
        case ("admin") permissionMapping.admin;
        case (_) {
          switch (Array.find<(Text, [Text])>(permissionMapping.custom, func((op, _)) { op == operation })) {
            case (?(_, perms)) perms;
            case null [operation];
          }
        };
      }
    };
    
    /// Check if principal has specific permission (with prefix)
    public func hasPermission(principal: Principal, permission: Text) : Auth.PermissionResult {
      let fullPermission = config.permissionPrefix # permission;
      permissionSystem.hasPermission(principal, fullPermission)
    };
    
    /// Check if principal has any of the permissions for an operation
    public func hasOperationAccess(principal: Principal, operation: Text) : Auth.PermissionResult {
      let permissions = getOperationPermissions(operation);
      let fullPermissions = Array.map<Text, Text>(permissions, func(p) { config.permissionPrefix # p });
      permissionSystem.hasAnyPermission(principal, fullPermissions)
    };
    
    /// Check if principal has specific role
    public func hasRole(principal: Principal, role: Text) : Bool {
      permissionSystem.hasRole(principal, role)
    };
    
    /// Initialize default session for principal if not exists
    public func ensureSession(principal: Principal, getUserRoles: (Principal) -> [Text]) : Auth.UserSession {
      switch (permissionSystem.getSession(principal)) {
        case (?session) session;
        case null {
          var roles = getUserRoles(principal);
          
          // Add default role for authenticated users
          if (not Principal.isAnonymous(principal)) {
            roles := Array.concat(roles, [config.defaultRole]);
          };
          
          // Add anonymous role if configured
          if (Principal.isAnonymous(principal)) {
            switch (config.anonymousRole) {
              case (?anonRole) roles := Array.concat(roles, [anonRole]);
              case null {};
            };
          };
          
          permissionSystem.createSession(principal, roles, [], null)
        };
      }
    };
    
    /// Check if principal has admin privileges
    public func isAdmin(principal: Principal) : Bool {
      for (adminRole in config.adminRoles.vals()) {
        if (hasRole(principal, adminRole)) {
          return true;
        };
      };
      false
    };
    
    /// Get effective permissions for a principal
    public func getEffectivePermissions(principal: Principal) : [Text] {
      switch (permissionSystem.getSession(principal)) {
        case (?session) session.permissions;
        case null [];
      }
    };
    
    /// Get effective roles for a principal  
    public func getEffectiveRoles(principal: Principal) : [Text] {
      switch (permissionSystem.getSession(principal)) {
        case (?session) session.roles;
        case null [];
      }
    };
    
    /// Validate principal against multiple permission systems
    public func validateWithFallback(
      principal: Principal,
      primaryPermission: Text,
      fallbackRoles: [Text]
    ) : Bool {
      // Try primary permission first
      switch (hasPermission(principal, primaryPermission)) {
        case (#granted) return true;
        case (#denied(_)) {
          // Fall back to role check
          for (role in fallbackRoles.vals()) {
            if (hasRole(principal, role)) {
              return true;
            };
          };
          false
        };
        case (#unknownPermission(_)) {
          // Fall back to role check for unknown permissions
          for (role in fallbackRoles.vals()) {
            if (hasRole(principal, role)) {
              return true;
            };
          };
          false
        };
      }
    };
  };
  
  /// Helper functions for common RBAC patterns
  
  /// Create a standard RBAC configuration
  public func createStandardConfig(appPrefix: Text) : RBACConfig {
    {
      defaultRole = "user";
      anonymousRole = ?"guest";
      adminRoles = ["admin", "system"];
      permissionPrefix = appPrefix # ":";
    }
  };
  
  /// Create a standard permission mapping for CRUD operations
  public func createCRUDMapping() : PermissionMapping {
    {
      read = ["read"];
      write = ["write"];
      admin = ["admin"];
      custom = [
        ("create", ["create", "write"]),
        ("update", ["update", "write"]),
        ("delete", ["delete", "admin"]),
        ("list", ["read"]),
        ("view", ["read"])
      ];
    }
  };
  
  /// Create an enhanced permission mapping with granular controls
  public func createGranularMapping() : PermissionMapping {
    {
      read = ["read"];
      write = ["write"];
      admin = ["admin"];
      custom = [
        ("create", ["create"]),
        ("read", ["read"]),
        ("update", ["update"]),
        ("delete", ["delete"]),
        ("list", ["list"]),
        ("search", ["search", "read"]),
        ("export", ["export", "read"]),
        ("import", ["import", "write"]),
        ("backup", ["backup", "admin"]),
        ("restore", ["restore", "admin"]),
        ("configure", ["configure", "admin"]),
        ("monitor", ["monitor"])
      ];
    }
  };
  
  /// Create a role hierarchy configuration
  public func defineStandardRoles(permissionSystem: Auth.PermissionSystem) : () {
    let roles = [
      {
        name = "guest";
        permissions = ["read"];
        inherits = [];
        metadata = [("description", "Read-only access for anonymous users")];
      },
      {
        name = "user";
        permissions = ["read", "write"];
        inherits = ["guest"];
        metadata = [("description", "Standard user with read/write access")];
      },
      {
        name = "moderator";
        permissions = ["delete", "moderate"];
        inherits = ["user"];
        metadata = [("description", "User with moderation capabilities")];
      },
      {
        name = "admin";
        permissions = ["admin", "configure", "backup", "restore"];
        inherits = ["moderator"];
        metadata = [("description", "Full administrative access")];
      },
      {
        name = "system";
        permissions = ["system", "monitor"];
        inherits = ["admin"];
        metadata = [("description", "System-level access for automation")];
      }
    ];
    
    permissionSystem.defineRoles(roles);
  };
}
