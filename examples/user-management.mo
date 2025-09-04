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
import _Int "mo:core/Int";
import _Time "mo:core/Time";
import ClassPlus "mo:class-plus";
import TT "mo:timer-tool";
import Log "mo:stable-local-log";
import OVSFixed "mo:ovs-fixed";

/// =========================================================================
/// SIMPLE USER MANAGEMENT - INSPECTMO INTEGRATION EXAMPLE
/// =========================================================================
/// 
/// This is a simplified example showing the basic InspectMo patterns:
/// 1. ✅ Basic guard rules for parameter validation
/// 2. ✅ Basic inspect rules for access control 
/// 3. ✅ System inspect function
/// 4. ✅ Working with mo:core libraries
///
/// 🎯 USE THIS AS A STARTING TEMPLATE
/// =========================================================================

persistent actor {

  var _owner = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");

  transient let initManager = ClassPlus.ClassPlusInitializationManager(_owner, _owner, true);

  transient let ttInitArgs : ?TT.InitArgList = null;

  // Runtime ICRC85 environment (nullable until enabled by test)
  transient var icrc85_env : OVSFixed.ICRC85Environment = null;

  private func reportTTExecution(execInfo: TT.ExecutionReport): Bool{
    Debug.print("USER_MANAGEMENT: TimerTool Execution: " # debug_show(execInfo));
    return false;
  };

  private func reportTTError(errInfo: TT.ErrorReport) : ?Nat{
    Debug.print("USER_MANAGEMENT: TimerTool Error: " # debug_show(errInfo));
    return null;
  };

  var tt_migration_state: TT.State = TT.Migration.migration.initialState;

  transient let tt  = TT.Init<system>({
    manager = initManager;
    initialState = tt_migration_state;
    args = ttInitArgs;
    pullEnvironment = ?(func() : TT.Environment {
      {      
        advanced = ?{
          icrc85 = icrc85_env;
        };
        reportExecution = ?reportTTExecution;
        reportError = ?reportTTError;
        syncUnsafe = null;
        reportBatch = null;
      };
    });

    onInitialize = ?(func (newClass: TT.TimerTool) : async* () {
      Debug.print("USER_MANAGEMENT: Initializing TimerTool");
      newClass.initialize<system>();
    });
    onStorageChange = func(state: TT.State) {
      tt_migration_state := state;
    }
  });

  var localLog_migration_state: Log.State = Log.initialState();
  transient let localLog = Log.Init<system>({
    args = ?{
      min_level = ?#Debug;
      bufferSize = ?5000;
    };
    manager = initManager;
    initialState = Log.initialState();
    pullEnvironment = ?(func() : Log.Environment {
      {
        tt = tt();
        advanced = null;
        onEvict = null;
      };
    });
    onInitialize = null;
    onStorageChange = func(state: Log.State) {
      localLog_migration_state := state;
    };
  });

  /// Simple user profile
  public type UserProfile = {
    id: Nat;
    username: Text;
    email: Text;
    created_at: Int;
  };

  /// API request types
  public type CreateUserRequest = {
    username: Text;
    email: Text;
  };

  /// Message accessor for InspectMo
  public type MessageAccessor = {
    #create_user: CreateUserRequest;
    #get_user: Nat;
  };

  public type ApiResult<T> = Result.Result<T, Text>;
  
  /// =========================================================================
  /// STATE MANAGEMENT
  /// =========================================================================
  
  private var nextUserId: Nat = 1;
  var userEntries: [(Nat, UserProfile)] = [];
  var users = Map.fromIter<Nat, UserProfile>(userEntries.vals(), Nat.compare);
  
  /// =========================================================================
  /// INSPECTMO SETUP
  /// =========================================================================
  
  /// Basic InspectMo configuration
  transient let inspectMoConfig : InspectMo.InitArgs = {
    allowAnonymous = ?false;
    defaultMaxArgSize = ?1000;
    authProvider = null;
    rateLimit = null;
    queryDefaults = ?{
      allowAnonymous = ?true;
      maxArgSize = ?500;
      rateLimit = null;
    };
    updateDefaults = ?{
      allowAnonymous = ?false;
      maxArgSize = ?1000;
      rateLimit = null;
    };
    developmentMode = false;
    auditLog = true;
  };
  
  var inspector_migration_state: InspectMo.State = InspectMo.initialState();

  /// Initialize InspectMo with proper environment
  transient let inspectMo = InspectMo.Init<system>({
    manager = initManager;
    initialState = inspector_migration_state;
    args = ?inspectMoConfig;
    pullEnvironment = ?(func() : InspectMo.Environment {
      {
        tt = tt();
        advanced = ?{
          icrc85 = icrc85_env;
        };
        log = ?localLog();
      };
    });

    onInitialize = ?(func (_newClass: InspectMo.InspectMo) : async* () {
      Debug.print("USER_MANAGEMENT: Initializing InspectMo");
    });

    onStorageChange = func(state: InspectMo.State) {
      inspector_migration_state := state;
    };
  });
  
  /// Create typed inspector
  transient let inspector = inspectMo().createInspector<MessageAccessor>();
  
  /// =========================================================================
  /// GUARD RULES - Parameter Validation
  /// =========================================================================
  
  /// Username validation guard
  transient let createUserGuardInfo = inspector.createMethodGuardInfo<CreateUserRequest>(
    "create_user",
    false,
    [
      InspectMo.customCheck<MessageAccessor, CreateUserRequest>(func(args) {
        switch (args.args) {
          case (#create_user(req)) {
            let username = req.username;
            if (Text.size(username) < 3) {
              #err("Username must be at least 3 characters")
            } else if (Text.size(username) > 20) {
              #err("Username must be no more than 20 characters")
            } else {
              #ok
            }
          };
          case (_) #err("Invalid message variant");
        }
      })
    ],
    func(msg: MessageAccessor) : CreateUserRequest = switch(msg) {
      case (#create_user(req)) req;
      case (_) {{ username = ""; email = "" }}; // fallback
    }
  );
  inspector.guard(createUserGuardInfo);
  
  /// =========================================================================
  /// INSPECT RULES - Access Control 
  /// =========================================================================
  
  /// Require authentication for user creation
  transient let createUserInspectInfo = inspector.createMethodGuardInfo<CreateUserRequest>(
    "create_user",
    false,
    [
      InspectMo.requireAuth<MessageAccessor, CreateUserRequest>()
    ],
    func(msg: MessageAccessor) : CreateUserRequest = switch(msg) {
      case (#create_user(req)) req;
      case (_) {{ username = ""; email = "" }}; // fallback
    }
  );
  inspector.inspect(createUserInspectInfo);
  
  /// =========================================================================
  /// SYSTEM INSPECT FUNCTION - REQUIRED!
  /// =========================================================================
  
  system func inspect({
    caller : Principal;
    arg : Blob;
    msg : {
      #create_user : () -> (request : CreateUserRequest);
      #get_user : () -> (user_id : Nat);
      #get_status : () -> ();
      #get_user_count : () -> ();
      #init_default_user : () -> ();
      #list_users : () -> ();
    };
  }) : Bool {
    let method_name = switch (msg) {
      case (#create_user(_)) "create_user";
      case (#get_user(_)) "get_user";
      case (#get_status(_)) "get_status";
      case (#get_user_count(_)) "get_user_count";
      case (#init_default_user(_)) "init_default_user";
      case (#list_users(_)) "list_users";
    };
    
    Debug.print("🔍 INSPECT: " # method_name # " called by " # Principal.toText(caller));
    
    // Convert the system message format to our MessageAccessor
    // Note: This is a simplified example - in practice you'd decode parameters from the blob
    let convertedMsg : MessageAccessor = switch (msg) {
      case (#create_user(_)) {
        // For demo purposes, use placeholder data
        #create_user({ username = "placeholder"; email = "placeholder@example.com" })
      };
      case (#get_user(_)) {
        // For demo purposes, use placeholder ID
        #get_user(1)
      };
      case (_) {
        // For other methods, use a default
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
        Debug.print("✅ INSPECT PASSED for " # method_name);
        true
      };
      case (#err(errMsg)) {
        Debug.print("❌ INSPECT FAILED for " # method_name # ": " # errMsg);
        false
      };
    }
  };
  
  /// =========================================================================
  /// PUBLIC API METHODS
  /// =========================================================================
  
  /// Create a new user
  public shared(msg) func create_user(request: CreateUserRequest) : async ApiResult<UserProfile> {
    Debug.print("👤 Creating user: " # request.username);
    
    // Guard validation
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
            // Create new user
            let userId = nextUserId;
            nextUserId += 1;
            
            let user : UserProfile = {
              id = userId;
              username = request.username;
              email = request.email;
              created_at = Time.now();
            };
            
            Map.add(users, Nat.compare, userId, user);
            
            Debug.print("✅ User created successfully: " # request.username);
            #ok(user)
          };
        }
      };
      case (#err(errMsg)) {
        Debug.print("❌ User creation failed: " # errMsg);
        #err(errMsg)
      };
    }
  };
  
  /// =========================================================================
  /// QUERY METHODS
  /// =========================================================================
  
  /// Get user by ID
  public query func get_user(user_id: Nat) : async ?UserProfile {
    Map.get(users, Nat.compare, user_id)
  };
  
  /// List all users
  public query func list_users() : async [UserProfile] {
    Array.fromIter<UserProfile>(
      Iter.map(Map.entries(users), func((id, user): (Nat, UserProfile)): UserProfile = user)
    )
  };
  
  /// Get user count
  public query func get_user_count() : async Nat {
    Map.size(users)
  };
  
  /// =========================================================================
  /// UTILITY FUNCTIONS
  /// =========================================================================
  
  /// Initialize with a default user for testing
  public func init_default_user() : async ApiResult<UserProfile> {
    let defaultUser : UserProfile = {
      id = 1;
      username = "testuser";
      email = "test@example.com";
      created_at = Time.now();
    };
    
    Map.add(users, Nat.compare, 1, defaultUser);
    nextUserId := 2;
    
    #ok(defaultUser)
  };
  
  /// Get status
  public query func get_status() : async {user_count: Nat; next_id: Nat} {
    {
      user_count = Map.size(users);
      next_id = nextUserId;
    }
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
/// 📚 LEARNING SUMMARY - Basic InspectMo Patterns:
/// =========================================================================
/// 
/// ✅ 1. INITIALIZATION:
///    - Configure InspectMo with basic settings
///    - Create typed inspector for your MessageAccessor type
/// 
/// ✅ 2. GUARD RULES:
///    - Use for parameter validation
///    - Chain multiple validations as needed
/// 
/// ✅ 3. INSPECT RULES:
///    - Use for authentication and authorization
///    - Control who can call which methods
/// 
/// ✅ 4. SYSTEM INSPECT FUNCTION:
///    - REQUIRED for InspectMo to work
///    - Converts system message format to your MessageAccessor
///    - Calls inspector.inspectCheck()
/// 
/// ✅ 5. CORE LIBRARIES:
///    - Use mo:core imports for modern Motoko
///    - Map.empty(), Map.add(), Map.get(), etc.
///    - Array.fromIter() for converting iterators
/// 
/// 🎯 NEXT STEPS:
/// - Customize validation rules for your use case
/// - Add more sophisticated authentication
/// - Implement role-based access control
/// - Add rate limiting and audit logging
/// =========================================================================
