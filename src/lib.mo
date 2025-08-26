// Main InspectMo library entry point
// Re-exports the core inspector functionality with Class Plus integration
//
// ⚠️  IMPORTANT: RBAC Integration Examples ⚠️
// The RBAC adapters in src/integrations/permission_systems/ are EXAMPLE IMPLEMENTATIONS ONLY
// and are NOT production-ready. They demonstrate integration patterns but have significant
// performance limitations including O(n) lookups, no caching, and missing security features.
// See docs/WORKPLAN.md Phase 2 for production-ready RBAC development plans.

import Inspector "core/inspector";

module {
  // Re-export the main Inspector module and class
  public let InspectMo = Inspector.InspectMo;  // This is the class constructor
  public type InspectMo = Inspector.InspectMo;  // This is the class type
  
  // Re-export core types for convenience
  public type InitArgs = Inspector.InitArgs;
  public type RateLimitConfig = Inspector.RateLimitConfig;
  public type AuthProvider = Inspector.AuthProvider;

  public type ValidationRule<T,M> = Inspector.ValidationRule<T,M>;

  public type GuardResult = Inspector.GuardResult;
  public type InspectArgs<T> = Inspector.InspectArgs<T>;
  public type CustomCheckArgs<T> = Inspector.CustomCheckArgs<T>;
  public type DynamicAuthArgs<T> = Inspector.DynamicAuthArgs<T>;
  public type Environment = Inspector.Environment;
  public type State = Inspector.State;
  
  // Re-export initialization functions
  public let Init = Inspector.Init;
  public let init = Inspector.init; // Simplified init function

  public let initialState = Inspector.initialState;
  
  // Re-export validation rule builders
  public let textSize = Inspector.textSize;
  public let blobSize = Inspector.blobSize;
  public let natValue = Inspector.natValue;
  public let intValue = Inspector.intValue;
  public let requirePermission = Inspector.requirePermission;
  public let requireAuth = Inspector.requireAuth;
  public let requireRole = Inspector.requireRole;
  public let blockIngress = Inspector.blockIngress;
  public let blockAll = Inspector.blockAll;
  
  // Re-export runtime validation rule builders
  public let dynamicAuth = Inspector.dynamicAuth;
  public let customCheck = Inspector.customCheck;
  public let blobSizeCheck = Inspector.blobSizeCheck;
  public let textSizeCheck = Inspector.textSizeCheck;
  
  // Re-export utility functions
  public let validateTextSize = Inspector.validateTextSize;
  public let validateBlobSize = Inspector.validateBlobSize;
  public let validateNatValue = Inspector.validateNatValue;
  public let validateIntValue = Inspector.validateIntValue;


};