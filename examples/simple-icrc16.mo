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

/// Simple ICRC16 Example for PIC.js Testing
persistent actor SimpleICRC16Example {

  type CandyShared = CandyTypes.CandyShared;

  /// Simple user with ICRC16 metadata
  public type User = {
    id: Nat;
    name: Text;
    metadata: CandyShared;
  };

  /// Request type
  public type CreateUserRequest = {
    name: Text;
    metadata: CandyShared;
  };

  /// Message accessor
  public type MessageAccessor = {
    #create_user: CreateUserRequest;
    #get_user: Nat;
  };

  public type ApiResult<T> = Result.Result<T, Text>;
  
  /// State
  private stable var nextId: Nat = 1;
  var userEntries: [(Nat, User)] = [];
  var users = Map.fromIter<Nat, User>(userEntries.vals(), Nat.compare);
  
  /// TimerTool and InspectMo setup with proper environment
  
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
      defaultMaxArgSize = ?2048;
      authProvider = null;
      rateLimit = null;
      queryDefaults = null;
      updateDefaults = null;
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
  
  transient let inspector = inspectMo().createInspector<MessageAccessor>();
  
  /// Simple ICRC16 validation
  transient let createUserGuardInfo = inspector.createMethodGuardInfo<CreateUserRequest>(
    "create_user",
    false,
    [
      // Traditional validation
      #textSize(func(req: CreateUserRequest): Text { req.name }, ?3, ?50),
      
      // ICRC16 validation - needs to match CandyShared -> CandyValueStable
      #candyType(func(req: CreateUserRequest): CandyShared { req.metadata }, "Class"),
      #candySize(func(req: CreateUserRequest): CandyShared { req.metadata }, ?1, ?10)
    ],
    func(msg: MessageAccessor) : CreateUserRequest = switch(msg) {
      case (#create_user(req)) req;
      case (_) {{
        name = "default";
        metadata = #Text("default");
      }};
    }
  );
  inspector.guard(createUserGuardInfo);
  
  /// Simple inspect rule
  transient let createUserInspectInfo = inspector.createMethodGuardInfo<CreateUserRequest>(
    "create_user",
    false,
    [
      #requireAuth()
    ],
    func(msg: MessageAccessor) : CreateUserRequest = switch(msg) {
      case (#create_user(req)) req;
      case (_) {{
        name = "default";
        metadata = #Text("default");
      }};
    }
  );
  inspector.inspect(createUserInspectInfo);
  
  /// System inspect
  system func inspect({
    caller : Principal;
    arg : Blob;
    msg : {
      #create_user : () -> (request : CreateUserRequest);
      #create_sample_user : () -> ();
      #get_user : () -> (user_id : Nat);
      #get_status : () -> ();
    };
  }) : Bool {
    let method_name = switch (msg) {
      case (#create_user(_)) "create_user";
      case (#create_sample_user(_)) "create_sample_user";
      case (#get_user(_)) "get_user";
      case (#get_status(_)) "get_status";
    };
    
    Debug.print("🔍 INSPECT ICRC16: " # method_name # " by " # Principal.toText(caller));
    
    let convertedMsg : MessageAccessor = switch (msg) {
      case (#create_user(_)) {
        let sampleMetadata = #Class([
          { name = "type"; value = #Text("user"); immutable = false },
          { name = "version"; value = #Nat(1); immutable = false }
        ]);
        #create_user({ name = "placeholder"; metadata = sampleMetadata })
      };
      case (#get_user(_)) #get_user(1);
      case (_) #get_user(0);
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
        Debug.print("✅ ICRC16 INSPECT PASSED: " # method_name);
        true
      };
      case (#err(errMsg)) {
        Debug.print("❌ ICRC16 INSPECT FAILED: " # method_name # ": " # errMsg);
        false
      };
    }
  };
  
  /// Create user with ICRC16 validation
  public shared(msg) func create_user(request: CreateUserRequest) : async ApiResult<User> {
    Debug.print("👤 Creating user with ICRC16: " # request.name);
    
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
        let userId = nextId;
        nextId += 1;
        
        let user : User = {
          id = userId;
          name = request.name;
          metadata = request.metadata; // ICRC16 validated
        };
        
        Map.add(users, Nat.compare, userId, user);
        
        Debug.print("✅ ICRC16 user created: " # request.name);
        #ok(user)
      };
      case (#err(errMsg)) {
        Debug.print("❌ ICRC16 validation failed: " # errMsg);
        #err(errMsg)
      };
    }
  };
  
  /// Query methods
  public query func get_user(user_id: Nat) : async ?User {
    Map.get(users, Nat.compare, user_id)
  };
  
  public query func get_status() : async {user_count: Nat; next_id: Nat} {
    {
      user_count = Map.size(users);
      next_id = nextId;
    }
  };
  
  /// Test utility
  public func create_sample_user() : async ApiResult<User> {
    let sampleMetadata = #Class([
      { name = "type"; value = #Text("sample"); immutable = false },
      { name = "created"; value = #Text("test"); immutable = false }
    ]);
    
    await create_user({
      name = "sample_user";
      metadata = sampleMetadata;
    })
  };
  
  /// Upgrade hooks
  system func preupgrade() {
    userEntries := Array.fromIter(Map.entries(users));
  };
  
  system func postupgrade() {
    userEntries := [];
  };
}
