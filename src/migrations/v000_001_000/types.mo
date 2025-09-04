// do not remove comments from this file
import Time "mo:core/Time";
import Principal "mo:core/Principal";
import OVSFixed "mo:ovs-fixed";
import TimerToolLib "mo:timer-tool";
import LogLib "mo:stable-local-log";
import Result "mo:core/Result";
import Map "mo:core/Map";
import CandyTypes "mo:candy/types";

// please do not import any types from your project outside migrations folder here
// it can lead to bugs when you change those types later, because migration types should not be changed
// you should also avoid importing these types anywhere in your project directly from here
// use MigrationTypes.Current property instead


module {

  // do not remove the timer tool as it is essential for icrc85
  public let TimerTool = TimerToolLib;
  public let Log = LogLib;

  /// Stable configuration that can be passed to actors (no functions)

  /// Full configuration for the InspectMo class (includes functions)
  public type InitArgs = {
    allowAnonymous: ?Bool;         // Global default for anonymous access
    defaultMaxArgSize: ?Nat;       // Global default argument size limit
    authProvider: ?AuthProvider;   // Permission system integration (function - not stable)
    rateLimit: ?RateLimitConfig;   // Global rate limiting
    
    // Query vs Update specific defaults
    queryDefaults: ?QueryConfig;   // Defaults for query calls
    updateDefaults: ?UpdateConfig; // Defaults for update calls
    
    developmentMode: Bool;         // Enable relaxed rules for testing
    auditLog: Bool;               // Enable audit logging

  };

  /// Configuration specific to query methods
  public type QueryConfig = {
    allowAnonymous: ?Bool;
    maxArgSize: ?Nat;
    rateLimit: ?RateLimitConfig;
  };

  /// Configuration specific to update methods
  public type UpdateConfig = {
    allowAnonymous: ?Bool;
    maxArgSize: ?Nat;
    rateLimit: ?RateLimitConfig;
  };

  // ========================================
  // Validation Rule Types
  // ========================================

  /// ICRC16 validation context for complex structure validation
  public type ICRC16ValidationContext = {
    allowedKeys: ?[Text];          // Allowed keys for record/map structures
    requiredKeys: ?[Text];         // Required keys for record/map structures
    maxDepth: ?Nat;               // Maximum nesting depth
    allowedTypes: ?[Text];         // Allowed value types
    customValidator: ?(CandyTypes.CandyShared -> Result.Result<(), Text>); // Custom validation function
  };

  /// Boundary validation rules for inspect_message with typed accessor functions
  // M - Message type
  public type ValidationRule<T,M> = {
    // MVP Core Rules for boundary validation with typed accessor functions
    #textSize: (accessor: M -> Text, min: ?Nat, max: ?Nat);     // Text size validation with typed accessor
    #blobSize: (accessor: M -> Blob, min: ?Nat, max: ?Nat);     // Blob size validation with typed accessor
    #natValue: (accessor: M -> Nat, min: ?Nat, max: ?Nat);      // Nat value range validation with typed accessor
    #intValue: (accessor: M -> Int, min: ?Int, max: ?Int);      // Int value range validation with typed accessor
    #requirePermission: Text;                                   // Require specific permission
    #blockIngress;                                              // Block all ingress calls at boundary
    #blockAll;                                                 // Block all calls at boundary
    
    // Additional rules (post-MVP)
    #allowedCallers: Map.Map<Principal, ()>;                               // Static whitelist of allowed principals
    #blockedCallers: Map.Map<Principal, ()>;                               // Static blacklist of blocked principals
    #requireAuth;                                               // Require authenticated caller
    #requireRole: Text;                                         // Require specific role
    #rateLimit: RateLimitRule;                                 // Method-specific rate limiting
    
    // Runtime validation with typed context
    #customCheck: (CustomCheckArgs<T>) -> GuardResult;          // Custom business logic with typed args
    #dynamicAuth: (DynamicAuthArgs<T>) -> GuardResult;          // Dynamic auth with typed args
    
    // ICRC16 CandyShared validation rules
    #candyType: (accessor: M -> CandyTypes.CandyShared, expectedType: Text); // Validate CandyShared type
    #candySize: (accessor: M -> CandyTypes.CandyShared, min: ?Nat, max: ?Nat); // Validate CandyShared serialized size
    #candyDepth: (accessor: M -> CandyTypes.CandyShared, maxDepth: Nat); // Validate CandyShared nesting depth
    #candyPattern: (accessor: M -> CandyTypes.CandyShared, pattern: Text); // Validate CandyShared against regex pattern
    #candyRange: (accessor: M -> CandyTypes.CandyShared, min: ?Int, max: ?Int); // Validate CandyShared numeric range
    #candyStructure: (accessor: M -> CandyTypes.CandyShared, context: ICRC16ValidationContext); // Validate CandyShared structure
    #propertyExists: (accessor: M -> [CandyTypes.PropertyShared], propertyName: Text); // Check property exists in PropertyShared array
    #propertyType: (accessor: M -> [CandyTypes.PropertyShared], propertyName: Text, expectedType: Text); // Validate property type
    #propertySize: (accessor: M -> [CandyTypes.PropertyShared], propertyName: Text, min: ?Nat, max: ?Nat); // Validate property size
    #arrayLength: (accessor: M -> CandyTypes.CandyShared, min: ?Nat, max: ?Nat); // Validate array length
    #arrayItemType: (accessor: M -> CandyTypes.CandyShared, expectedType: Text); // Validate array item types
    #mapKeyExists: (accessor: M -> CandyTypes.CandyShared, key: Text); // Check map key existence
    #mapSize: (accessor: M -> CandyTypes.CandyShared, min: ?Nat, max: ?Nat); // Validate map size
    #customCandyCheck: (accessor: M -> CandyTypes.CandyShared, validator: CandyTypes.CandyShared -> Result.Result<(), Text>); // Custom CandyShared validation
    #nestedValidation: (accessor: M -> CandyTypes.CandyShared, rules: [ValidationRule<T,M>]); // Nested ICRC16 validation rules
  };



  // ========================================
  // Guard Context Types
  // ========================================

  /// Typed context for custom check functions
  public type CustomCheckArgs<T> = {
    args: T;                    // The typed method arguments
    caller: Principal;          // The caller principal
    cycles: ?Nat;              // Available cycles
    deadline: ?Nat;            // Call deadline
  };

  /// Typed context for dynamic authorization functions
  public type DynamicAuthArgs<T> = {
    args: T;                    // The typed method arguments
    caller: ?Principal;         // The caller principal (optional for flexibility)
    permissions: ?AuthProvider; // Reference to permission system
  };

  /// Source type restriction for calls
  public type SourceType = {
    #ingressOnly;      // Only allow ingress calls (block canister-to-canister)
    #canisterOnly;     // Only allow canister-to-canister calls (block ingress)
    #any;              // Allow both ingress and canister calls
  };

  /// Standard result type for guard operations
  public type GuardResult = Result.Result<(), Text>;

  // ========================================
  // Rate Limiting Types (Enhanced for Week 5)
  // ========================================

  /// Time window for rate limiting
  public type TimeWindow = {
    #Second: Nat;
    #Minute: Nat; 
    #Hour: Nat;
    #Day: Nat;
  };
  
  /// Enhanced rate limit configuration
  public type RateLimitConfig = {
    maxRequests: Nat;
    timeWindow: TimeWindow;
    exemptRoles: [Text];
    exemptPrincipals: [Principal];
  };

  /// Method-specific rate limiting rule (deprecated - use RateLimitConfig)
  public type RateLimitRule = {
    maxPerMinute: ?Nat;
    maxPerHour: ?Nat;
    maxPerDay: ?Nat;
    exemptRoles: ?[Text];
  };

  /// Rate limit check result
  public type RateLimitResult = {
    #allowed;
    #denied: {
      limit: Nat;
      window: TimeWindow;
      retryAfter: Int;
    };
  };

  // ========================================
  // Authentication Types (Enhanced for Week 5)
  // ========================================

  /// Permission representation
  public type Permission = Text;
  
  /// Role representation  
  public type Role = Text;
  
  /// User session information
  public type UserSession = {
    principal: Principal;
    roles: [Role];
    permissions: [Permission];
    expiresAt: ?Int;
    metadata: [(Text, Text)];
  };
  
  /// Authentication result
  public type AuthResult = {
    #authenticated: UserSession;
    #denied: Text;
    #expired: Int;
  };
  
  /// Permission check result
  public type PermissionResult = {
    #granted;
    #denied: Text;
    #unknownPermission: Text;
  };
  
  /// Role definition with permissions
  public type RoleDefinition = {
    name: Role;
    permissions: [Permission];
    inherits: [Role];
    metadata: [(Text, Text)];
  };

  /// Enhanced authentication provider interface
  public type AuthProvider = {
    /// Legacy methods (maintained for compatibility)
    checkRole: (Principal, Text) -> Bool;
    checkPermission: (Principal, Text) -> Bool;
    isAuthenticated: Principal -> Bool;
    
    /// New async methods for Week 5+ features
    authenticate: ?(Principal) -> async* AuthResult;
    hasPermission: ?(Principal, Permission) -> async* PermissionResult;
    getRoles: ?(Principal) -> async* [Role];
    getPermissions: ?(Principal) -> async* [Permission];
    validateSession: ?(Principal) -> async* Bool;
    refreshSession: ?(Principal) -> async* ?UserSession;
  };

  /// Permission system configuration
  public type PermissionConfig = {
    cacheTTL: Int;
    maxCacheSize: Nat;
    allowAnonymousRead: Bool;
    defaultDenyMode: Bool;
    sessionTimeout: ?Int;
  };

  // ========================================
  // Method Registration Types
  // ========================================

  public type ErasedValidator<T> = (InspectArgs<T>) -> Result.Result<(), Text>;

  /// Method registration information for dual guard/inspect pattern
  /// M - Method Accessor Type
  /// V - Parameter Accessor Function
  public type MethodGuardInfo<T> = {
    methodName: Text;
    validator: ErasedValidator<T>;     // Rules for  validation
    isQuery: Bool;
  };

  // ========================================
  // Inspection Context Types
  // ========================================

  /// Enhanced inspect arguments with method context and parsing
  /// T - Raw message variant type
  /// M - Method Accessor Type
  public type InspectArgs<T> = {
    methodName: Text;
    caller: Principal;
    arg: Blob;               //should be empty for guards
    isQuery: Bool;           // Is this a query call?
    cycles: ?Nat;              // Available cycles
    deadline: ?Nat;            // Call timeout
    isInspect: Bool;           // Is this an inspect call?
    msg: T;                       // Raw message variant
  };

  /// Parsed argument values for validation
  public type ArgValue = {
    #nat: Nat;
    #text: Text;
    #blob: Blob;
    #principal: Principal;
    #bool: Bool;
    #array: [ArgValue];
    #record: [(Text, ArgValue)];
    #variant: (Text, ?ArgValue);
    #option: ?ArgValue;
    #unknown: Blob;                 // Fallback for complex types
  };

  /// Type information for size calculation and validation
  public type TypeInfo = {
    #nat: Nat;              // Serialized size for Nat
    #text: Nat;             // Byte length for Text
    #blob: Nat;             // Byte length for Blob
    #compound: [TypeInfo];  // For records, arrays, etc.
    #unknown;               // Fallback for complex types
  };

  // ========================================
  // Generic Accessor Function Types
  // ========================================

  /// Generic accessor function type for extracting values from method arguments
  public type Accessor<T, R> = T -> R;

  /// Text accessor function type
  public type TextAccessor<T> = Accessor<T, Text>;

  /// Blob accessor function type
  public type BlobAccessor<T> = Accessor<T, Blob>;

  /// Nat accessor function type
  public type NatAccessor<T> = Accessor<T, Nat>;

  /// Int accessor function type
  public type IntAccessor<T> = Accessor<T, Int>;

  // ========================================
  // Utility Types
  // ========================================

  /// Timestamp type for audit logging
  public type Timestamp = Int;

  /// Principal validation result
  public type PrincipalValidation = {
    #valid;
    #invalid: Text;        // Reason for invalidity
    #anonymous;            // Special case for anonymous principals
  };

  /// Method call statistics for monitoring
  public type CallStats = {
    methodName: Text;
    totalCalls: Nat;
    rejectedCalls: Nat;
    lastCall: Timestamp;
    averageArgSize: Nat;
  };

  // do not remove ICRC85 as it is essential for funding open source projects
  public type ICRC85Options = OVSFixed.ICRC85Environment;

  // you may add to this environment, but do not remove tt or advanced.icrc85
  public type Environment = {
    tt: TimerToolLib.TimerTool;
    advanced : ?{
      icrc85 : ICRC85Options;
    };
    log: ?Log.Local_log;
  };

  //do not remove the tt or icrc85 from this type
  public type Stats = {
    tt: TimerToolLib.Stats;
    icrc85: {
      nextCycleActionId: ?Nat;
      lastActionReported: ?Nat;
      activeActions: Nat;
    };
    log: [Text];
  };

  ///MARK: State
  // do not remove the tt or icrc85 from this type
  public type State = {
    icrc85: {
      var nextCycleActionId: ?Nat;
      var lastActionReported: ?Nat;
      var activeActions: Nat;
    };
  };
};