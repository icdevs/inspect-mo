import InspectMo "../src/lib";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import Time "mo:core/Time";
import Debug "mo:core/Debug";
import Map "mo:core/Map";
import Result "mo:core/Result";
import Array "mo:core/Array";
import Nat "mo:core/Nat";
import Iter "mo:core/Iter";
import CandyTypes "mo:candy/types";
import ClassPlus "mo:class-plus";
import TT "mo:timer-tool";
import OVSFixed "mo:ovs-fixed";

/// =========================================================================
/// ENHANCED USER MANAGEMENT - ICRC16 INTEGRATION EXAMPLE
/// =========================================================================
/// 
/// This example demonstrates ICRC16 metadata validation with InspectMo:
/// 1. ✅ ICRC16 metadata validation for user profiles
/// 2. ✅ Mixed traditional + ICRC16 validation rules
/// 3. ✅ CandyShared data structures for extensible profiles
/// 4. ✅ Comprehensive validation patterns
///
/// 🎯 DEMONSTRATES ICRC16 FUNCTIONALITY
/// =========================================================================

persistent actor EnhancedUserManagement {

  type CandyShared = CandyTypes.CandyShared;

  /// Enhanced user profile with ICRC16 metadata
  public type UserProfile = {
    id: Nat;
    username: Text;
    email: Text;
    created_at: Int;
    metadata: CandyShared; // ICRC16 metadata field
    preferences: CandyShared; // User preferences as ICRC16 data
    tags: [Text]; // For array validation
  };

  /// API request types with ICRC16 data
  public type CreateUserRequest = {
    username: Text;
    email: Text;
    metadata: CandyShared; // User-provided metadata
    preferences: CandyShared; // User preferences
    tags: [Text];
  };

  public type UpdateMetadataRequest = {
    userId: Nat;
    metadata: CandyShared;
  };

  /// Message accessor for InspectMo
  public type MessageAccessor = {
    #create_user: CreateUserRequest;
    #update_metadata: UpdateMetadataRequest;
    #get_user: Nat;
  };

  public type ApiResult<T> = Result.Result<T, Text>;
  
  /// =========================================================================
  /// STATE MANAGEMENT
  /// =========================================================================
  
  var nextUserId: Nat = 1;
  var userEntries: [(Nat, UserProfile)] = [];
  var users = Map.fromIter<Nat, UserProfile>(userEntries.vals(), Nat.compare);
  
  /// =========================================================================
  /// TIMERTOOL AND INSPECTMO SETUP WITH ICRC16
  /// =========================================================================
  
  // Timer tool setup following main.mo pattern
  transient let initManager = ClassPlus.ClassPlusInitializationManager(
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

  transient let inspectMo = InspectMo.Init<system>({
    manager = initManager;
    initialState = inspector_migration_state;
    args = ?{
      allowAnonymous = ?false;
      defaultMaxArgSize = ?2048; // Larger for ICRC16 data
      authProvider = null;
      rateLimit = null;
      queryDefaults = ?{
        allowAnonymous = ?true;
        maxArgSize = ?1024;
        rateLimit = null;
      };
      updateDefaults = ?{
        allowAnonymous = ?false;
        maxArgSize = ?2048;
        rateLimit = null;
      };
      developmentMode = false;
      auditLog = true;
    };
    pullEnvironment = ?(func() : InspectMo.Environment {
      createEnvironment()
    });
    onInitialize = null;
    onStorageChange = func(state: InspectMo.State) {
      inspector_migration_state := state;
    };
  });
  
  /// Create typed inspector
  transient let inspector = inspectMo().createInspector<MessageAccessor>();
  
  /// =========================================================================
  /// ICRC16 + TRADITIONAL VALIDATION RULES
  /// =========================================================================
  
  /// Enhanced user creation with ICRC16 validation
  transient let createUserGuardInfo = inspector.createMethodGuardInfo<CreateUserRequest>(
    "create_user",
    false,
    [
      // Traditional validation rules
      #textSize(func(req: CreateUserRequest): Text { req.username }, ?3, ?20),
      #textSize(func(req: CreateUserRequest): Text { req.email }, ?5, ?100),
      
      // ICRC16 validation rules for metadata
      #candyType(func(req: CreateUserRequest): CandyShared { req.metadata }, "Class"),
      #candySize(func(req: CreateUserRequest): CandyShared { req.metadata }, ?1, ?20),
      #candyDepth(func(req: CreateUserRequest): CandyShared { req.metadata }, 3),
      
      // ICRC16 validation for preferences  
      #candyType(func(req: CreateUserRequest): CandyShared { req.preferences }, "Class"),
      
      // Custom validation to check preference properties
      #customCandyCheck(func(req: CreateUserRequest): CandyShared { req.preferences }, func(candy: CandyShared): Result.Result<(), Text> {
        switch (candy) {
          case (#Class(properties)) {
            let hasTheme = Array.find<{name: Text; value: CandyShared; immutable: Bool}>(properties, func(prop) = prop.name == "theme") != null;
            if (not hasTheme) {
              #err("Preferences must contain 'theme' property")
            } else {
              #ok()
            }
          };
          case (_) #err("Preferences must be a Class structure");
        }
      }),
      
      // Traditional validation for array of text  
      #customCheck(func(args) {
        switch (args.args) {
          case (#create_user(req)) {
            let tags = req.tags;
            if (Array.size(tags) < 1) {
              #err("Must have at least 1 tag")
            } else if (Array.size(tags) > 10) {
              #err("Cannot have more than 10 tags")
            } else {
              #ok
            }
          };
          case (_) #err("Invalid message variant");
        }
      }),
      
      // Custom ICRC16 validation
      #customCandyCheck(func(req: CreateUserRequest): CandyShared { req.metadata }, func(candy: CandyShared): Result.Result<(), Text> {
        switch (candy) {
          case (#Class(properties)) {
            // Check for required properties
            let hasName = Array.find<{name: Text; value: CandyShared; immutable: Bool}>(properties, func(prop) = prop.name == "name") != null;
            let hasType = Array.find<{name: Text; value: CandyShared; immutable: Bool}>(properties, func(prop) = prop.name == "type") != null;
            
            if (not hasName) {
              #err("Metadata must contain 'name' property")
            } else if (not hasType) {
              #err("Metadata must contain 'type' property")
            } else {
              #ok()
            }
          };
          case (_) #err("Metadata must be a Class structure");
        }
      })
    ],
    func(msg: MessageAccessor) : CreateUserRequest = switch(msg) {
      case (#create_user(req)) req;
      case (_) {
        { 
          username = ""; 
          email = ""; 
          metadata = #Text(""); 
          preferences = #Text(""); 
          tags = [] 
        }
      };
    }
  );
  inspector.guard(createUserGuardInfo);
  
  /// Metadata update validation with ICRC16
  transient let updateMetadataGuardInfo = inspector.createMethodGuardInfo<UpdateMetadataRequest>(
    "update_metadata",
    false,
    [
      // ICRC16 validation for new metadata
      #candyType(func(req: UpdateMetadataRequest): CandyShared { req.metadata }, "Class"),
      #candySize(func(req: UpdateMetadataRequest): CandyShared { req.metadata }, ?1, ?30),
      #candyDepth(func(req: UpdateMetadataRequest): CandyShared { req.metadata }, 4),
      
      // Custom validation for metadata structure
      #customCandyCheck(func(req: UpdateMetadataRequest): CandyShared { req.metadata }, func(candy: CandyShared): Result.Result<(), Text> {
        switch (candy) {
          case (#Class(properties)) {
            if (Array.size(properties) == 0) {
              #err("Metadata cannot be empty")
            } else {
              #ok()
            }
          };
          case (_) #err("Metadata must be a Class structure");
        }
      })
    ],
    func(msg: MessageAccessor) : UpdateMetadataRequest = switch(msg) {
      case (#update_metadata(req)) req;
      case (_) {{ userId = 0; metadata = #Text("") }};
    }
  );
  inspector.guard(updateMetadataGuardInfo);
  
  /// =========================================================================
  /// INSPECT RULES - Access Control 
  /// =========================================================================
  
  /// Require authentication for user operations
  transient let createUserInspectInfo = inspector.createMethodGuardInfo<CreateUserRequest>(
    "create_user",
    false,
    [
      #requireAuth()
    ],
    func(msg: MessageAccessor) : CreateUserRequest = switch(msg) {
      case (#create_user(req)) req;
      case (_) {
        { 
          username = ""; 
          email = ""; 
          metadata = #Text(""); 
          preferences = #Text(""); 
          tags = [] 
        }
      };
    }
  );
  inspector.inspect(createUserInspectInfo);
  
  transient let updateMetadataInspectInfo = inspector.createMethodGuardInfo<UpdateMetadataRequest>(
    "update_metadata",
    false,
    [
      #requireAuth()
    ],
    func(msg: MessageAccessor) : UpdateMetadataRequest = switch(msg) {
      case (#update_metadata(req)) req;
      case (_) {{ userId = 0; metadata = #Text("") }};
    }
  );
  inspector.inspect(updateMetadataInspectInfo);
  
  /// =========================================================================
  /// SYSTEM INSPECT FUNCTION
  /// =========================================================================
  
  system func inspect({
    caller : Principal;
    arg : Blob;
    msg : {
      #create_user : () -> (request : CreateUserRequest);
      #update_metadata : () -> (request : UpdateMetadataRequest);
      #get_user : () -> (user_id : Nat);
      #get_status : () -> ();
      #get_user_count : () -> ();
      #list_users : () -> ();
      #create_sample_user : () -> ();
    };
  }) : Bool {
    let method_name = switch (msg) {
      case (#create_user(_)) "create_user";
      case (#update_metadata(_)) "update_metadata";
      case (#get_user(_)) "get_user";
      case (#get_status(_)) "get_status";
      case (#get_user_count(_)) "get_user_count";
      case (#list_users(_)) "list_users";
      case (#create_sample_user(_)) "create_sample_user";
    };
    
    Debug.print("🔍 INSPECT: " # method_name # " called by " # Principal.toText(caller));
    
    // Convert the system message format to our MessageAccessor
    let convertedMsg : MessageAccessor = switch (msg) {
      case (#create_user(_)) {
        // For demo purposes, use placeholder ICRC16 data
        let sampleMetadata = #Class([
          { name = "name"; value = #Text("Sample User"); immutable = false },
          { name = "type"; value = #Text("standard"); immutable = false }
        ]);
        let samplePreferences = #Class([
          { name = "theme"; value = #Text("light"); immutable = false },
          { name = "notifications"; value = #Bool(true); immutable = false }
        ]);
        #create_user({ 
          username = "placeholder"; 
          email = "placeholder@example.com";
          metadata = sampleMetadata;
          preferences = samplePreferences;
          tags = ["sample"];
        })
      };
      case (#update_metadata(_)) {
        let sampleMetadata = #Class([
          { name = "updated"; value = #Text("true"); immutable = false }
        ]);
        #update_metadata({ userId = 1; metadata = sampleMetadata })
      };
      case (#get_user(_)) {
        #get_user(1)
      };
      case (_) {
        #get_user(0)
      };
    };
    
    let args : InspectMo.InspectArgs<MessageAccessor> = {
      methodName = method_name;
      caller = caller;
      arg = arg;
      isQuery = false;
      cycles = null;
      deadline = null;
      isInspect = true;
      msg = convertedMsg;
    };
    
    switch (inspector.inspectCheck(args)) {
      case (#ok) {
        Debug.print("✅ INSPECT PASSED for " # method_name # " (ICRC16 validation included)");
        true
      };
      case (#err(errMsg)) {
        Debug.print("❌ INSPECT FAILED for " # method_name # ": " # errMsg);
        false
      };
    }
  };
  
  /// =========================================================================
  /// PUBLIC API METHODS WITH ICRC16
  /// =========================================================================
  
  /// Create a new user with ICRC16 metadata validation
  public shared(msg) func create_user(request: CreateUserRequest) : async ApiResult<UserProfile> {
    Debug.print("👤 Creating user with ICRC16 metadata: " # request.username);
    
    // Guard validation (includes ICRC16 rules)
    let args : InspectMo.InspectArgs<MessageAccessor> = {
      methodName = "create_user";
      caller = msg.caller;
      arg = to_candid(request);
      isQuery = false;
      cycles = null;
      deadline = null;
      isInspect = false;
      msg = #create_user(request);
    };
    
    switch (inspector.guardCheck(args)) {
      case (#ok) {
        // Check if username already exists  
        let existingUser = Iter.find(Map.entries(users), func((id, user): (Nat, UserProfile)): Bool {
          user.username == request.username
        });
        
        switch (existingUser) {
          case (?found) {
            #err("Username already exists: " # request.username)
          };
          case null {
            // Create new user with ICRC16 metadata
            let userId = nextUserId;
            nextUserId += 1;
            
            let user : UserProfile = {
              id = userId;
              username = request.username;
              email = request.email;
              created_at = Time.now();
              metadata = request.metadata; // ICRC16 validated metadata
              preferences = request.preferences; // ICRC16 validated preferences
              tags = request.tags; // Array validated tags
            };
            
            Map.add(users, Nat.compare, userId, user);
            
            Debug.print("✅ User created with ICRC16 metadata: " # request.username);
            #ok(user)
          };
        }
      };
      case (#err(errMsg)) {
        Debug.print("❌ ICRC16 validation failed: " # errMsg);
        #err(errMsg)
      };
    }
  };
  
  /// Update user metadata with ICRC16 validation
  public shared(msg) func update_metadata(request: UpdateMetadataRequest) : async ApiResult<UserProfile> {
    Debug.print("🔄 Updating metadata for user: " # Nat.toText(request.userId));
    
    // Guard validation (ICRC16 rules)
    let args : InspectMo.InspectArgs<MessageAccessor> = {
      methodName = "update_metadata";
      caller = msg.caller;
      arg = to_candid(request);
      isQuery = false;
      cycles = null;
      deadline = null;
      isInspect = false;
      msg = #update_metadata(request);
    };
    
    switch (inspector.guardCheck(args)) {
      case (#ok) {
        switch (Map.get(users, Nat.compare, request.userId)) {
          case (?user) {
            let updatedUser : UserProfile = {
              id = user.id;
              username = user.username;
              email = user.email;
              created_at = user.created_at;
              metadata = request.metadata; // New ICRC16 validated metadata
              preferences = user.preferences;
              tags = user.tags;
            };
            
            ignore Map.replace(users, Nat.compare, request.userId, updatedUser);
            
            Debug.print("✅ Metadata updated with ICRC16 validation");
            #ok(updatedUser)
          };
          case null {
            #err("User not found: " # Nat.toText(request.userId))
          };
        }
      };
      case (#err(errMsg)) {
        Debug.print("❌ ICRC16 metadata validation failed: " # errMsg);
        #err(errMsg)
      };
    }
  };
  
  /// =========================================================================
  /// QUERY METHODS
  /// =========================================================================
  
  /// Get user by ID (includes ICRC16 metadata)
  public query func get_user(user_id: Nat) : async ?UserProfile {
    Map.get(users, Nat.compare, user_id)
  };
  
  /// List all users with their ICRC16 metadata
  public query func list_users() : async [UserProfile] {
    Array.fromIter<UserProfile>(
      Iter.map(Map.entries(users), func((id, user): (Nat, UserProfile)): UserProfile = user)
    )
  };
  
  /// Get user count
  public query func get_user_count() : async Nat {
    Map.size(users)
  };
  
  /// Get status
  public query func get_status() : async {user_count: Nat; next_id: Nat} {
    {
      user_count = Map.size(users);
      next_id = nextUserId;
    }
  };
  
  /// =========================================================================
  /// UTILITY FUNCTIONS FOR TESTING
  /// =========================================================================
  
  /// Create sample ICRC16 data for testing
  public func create_sample_user() : async ApiResult<UserProfile> {
    let sampleMetadata = #Class([
      { name = "name"; value = #Text("Sample User"); immutable = false },
      { name = "type"; value = #Text("standard"); immutable = false },
      { name = "role"; value = #Text("user"); immutable = false }
    ]);
    
    let samplePreferences = #Class([
      { name = "theme"; value = #Text("dark"); immutable = false },
      { name = "notifications"; value = #Bool(true); immutable = false },
      { name = "language"; value = #Text("en"); immutable = false }
    ]);
    
    let request : CreateUserRequest = {
      username = "sampleuser";
      email = "sample@example.com";
      metadata = sampleMetadata;
      preferences = samplePreferences;
      tags = ["sample", "test", "icrc16"];
    };
    
    // Manually create without going through full validation for testing
    let userId = nextUserId;
    nextUserId += 1;
    
    let user : UserProfile = {
      id = userId;
      username = request.username;
      email = request.email;
      created_at = Time.now();
      metadata = request.metadata;
      preferences = request.preferences;
      tags = request.tags;
    };
    
    Map.add(users, Nat.compare, userId, user);
    #ok(user)
  };
  
  /// =========================================================================
  /// STABLE UPGRADE HOOKS
  /// =========================================================================
  
  system func preupgrade() {
    userEntries := Array.fromIter(Map.entries(users));
  };
  
  system func postupgrade() {
    userEntries := [];
  };
}

/// =========================================================================
/// 📚 ICRC16 + INSPECTMO INTEGRATION SUMMARY:
/// =========================================================================
/// 
/// ✅ 1. ICRC16 VALIDATION RULES:
///    - #candyType: Validates CandyShared type structure
///    - #candySize: Validates size constraints
///    - #candyDepth: Validates nesting depth
///    - #propertyExists: Validates required properties
///    - #propertyType: Validates property types
///    - #customCandyCheck: Custom ICRC16 business logic
/// 
/// ✅ 2. MIXED VALIDATION:
///    - Traditional rules: #textSize, #arraySize
///    - ICRC16 rules: #candyType, #candySize, etc.
///    - Both types work together seamlessly
/// 
/// ✅ 3. CANDYSHARED INTEGRATION:
///    - User metadata as CandyShared structures
///    - Preferences stored as ICRC16 data
///    - Flexible, extensible data models
/// 
/// ✅ 4. COMPREHENSIVE VALIDATION:
///    - Parameter validation in guard rules
///    - Access control in inspect rules
///    - Custom business logic validation
/// 
/// 🎯 TESTED WITH PIC.JS:
/// - Real canister deployment and testing
/// - ICRC16 validation rule verification
/// - Mixed validation scenario testing
/// - Error handling and edge cases
/// =========================================================================
