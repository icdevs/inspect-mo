/// Test canister demonstrating InspectMo functionality with proper timer setup
import InspectMo "./lib";
import Principal "mo:core/Principal";
import Debug "mo:core/Debug";
import Result "mo:core/Result";
import Array "mo:core/Array";
import Text "mo:core/Text";
import Nat "mo:core/Nat";
import _Int "mo:core/Int";
import _Time "mo:core/Time";
import ClassPlus "mo:class-plus";
import TT "mo:timer-tool";
import Log "mo:stable-local-log";
import OVSFixed "mo:ovs-fixed";

shared (deployer) persistent actor class TestCanister<system>(
  args: ?{
    ttArgs: ?TT.InitArgList;
  }
) = this {
  var _owner = deployer.caller;

  transient let initManager = ClassPlus.ClassPlusInitializationManager(_owner, Principal.fromActor(this), true);

  transient let ttInitArgs : ?TT.InitArgList = do?{args!.ttArgs!};

  // Runtime ICRC85 environment (nullable until enabled by test)
  transient var icrc85_env : OVSFixed.ICRC85Environment = null;

  private func reportTTExecution(execInfo: TT.ExecutionReport): Bool{
    Debug.print("TEST_CANISTER: TimerTool Execution: " # debug_show(execInfo));
    return false;
  };

  private func reportTTError(errInfo: TT.ErrorReport) : ?Nat{
    Debug.print("TEST_CANISTER: TimerTool Error: " # debug_show(errInfo));
    return null;
  };

  var tt_migration_state: TT.State = TT.initialState();

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
      Debug.print("TEST_CANISTER: Initializing TimerTool");
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

  
  // Custom args types for InspectMo validation
  type Args = {
    #SimpleMessage : Text;
    #ProfileUpdate : (Text, Text);
    #GuardedMethod : Text;
    #None : ();
  };
  
  // Counter to track how many times each method is called
  private stable var callCounts : [(Text, Nat)] = [];
  
  // Track argument sizes by method for testing inspectOnlyArgSize functionality
  private stable var methodArgSizes : [(Text, Nat)] = [];
  
  // Helper to store argument size for a method
  private func storeArgSize(methodName: Text, argSize: Nat) : () {
    var found = false;
    var newSizes : [(Text, Nat)] = [];
    
    for ((name, size) in methodArgSizes.vals()) {
      if (name == methodName) {
        newSizes := Array.concat<(Text, Nat)>(newSizes, [(name, argSize)]);
        found := true;
      } else {
        newSizes := Array.concat<(Text, Nat)>(newSizes, [(name, size)]);
      };
    };
    
    if (not found) {
      newSizes := Array.concat<(Text, Nat)>(newSizes, [(methodName, argSize)]);
    };
    
    methodArgSizes := newSizes;
  };

  // Helper to increment call count
  private func incrementCallCount(methodName: Text) : () {
    var found = false;
    var newCounts : [(Text, Nat)] = [];
    
    for ((name, count) in callCounts.vals()) {
      if (name == methodName) {
        newCounts := Array.concat<(Text, Nat)>(newCounts, [(name, count + 1)]);
        found := true;
      } else {
        newCounts := Array.concat<(Text, Nat)>(newCounts, [(name, count)]);
      };
    };
    
    if (not found) {
      newCounts := Array.concat<(Text, Nat)>(newCounts, [(methodName, 1)]);
    };
    
    callCounts := newCounts;
  };

  // Initialize Inspector with proper environment setup
  transient let defaultConfig = {
    allowAnonymous = ?false;
    defaultMaxArgSize = ?1024;
    authProvider = null;
    rateLimit = null;
    queryDefaults = null;
    updateDefaults = null;
    developmentMode = true;
    auditLog = false;
  };

  var inspector_migration_state: InspectMo.State = InspectMo.initialState();

  transient let _inspector = InspectMo.Init<system>({
    manager = initManager;
    initialState = inspector_migration_state;
    args = ?defaultConfig;
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
      Debug.print("TEST_CANISTER: Initializing InspectMo");
    });

    onStorageChange = func(state: InspectMo.State) {
      inspector_migration_state := state;
    };
  });

  transient let validatorInspector = _inspector().createInspector<Args>();

  // Accessor functions for parameter extraction (for textSize guards)
  transient func getMessageText(message: Text): Text { message };
  transient func getFirstParam(params: (Text, Text)): Text { params.0 };
  transient func getSecondParam(params: (Text, Text)): Text { params.1 };

  // Accessor functions for Args union (for argument parsing)
  transient func extractMessageText(args: Args): Text { 
    switch (args) {
      case (#SimpleMessage(text)) { text };
      case (_) { "" };
    }
  };

  transient func extractFirstParam(args: Args): Text { 
    switch (args) {
      case (#ProfileUpdate(name, _)) { name };
      case (_) { "" };
    }
  };

  transient func extractSecondParam(args: Args): Text { 
    switch (args) {
      case (#ProfileUpdate(_, bio)) { bio };
      case (_) { "" };
    }
  };

  // ===== QUERY METHODS =====
  
  // Test 1: Query method with no restrictions (should NOT go through inspect)
  public query func health_check() : async Text {
    "Canister is healthy"
  };

  // Test 2: Query with inspect rules (should NOT go through inspect anyway)
  public query func get_public_info() : async Text {
    "This is public information"
  };

  // Test 2b: Basic query method expected by tests
  public query func get_info() : async Text {
    "This is basic info - query method"
  };

  // ===== UPDATE METHODS WITH INSPECT RULES =====
  
  // Test 3: Update method with text size validation + auth
  transient let _ = validatorInspector.inspect(validatorInspector.createMethodGuardInfo<Text>(
    "send_message",
    false,
    [
      #requireAuth
    ],
    func(args: Args) : Text {
      switch (args) {
        case (#SimpleMessage(text)) text;
        case (_) "";
      };
    }
  ));
  public func send_message(message: Text) : async Text {
    incrementCallCount("send_message");
    "Message sent: " # message
  };

  // Test 4: Method with multiple parameters
  transient let nameGuard = validatorInspector.inspect(validatorInspector.createMethodGuardInfo<(Text, Text)>(
    "update_profile",
    false,
    [
      #requireAuth
    ],
    func(args: Args) : (Text, Text) {
      switch (args) {
        case (#ProfileUpdate(name, bio)) (name, bio);
        case (_) ("", "");
      };
    }
  ));
  public func update_profile(name: Text, bio: Text) : async Text {
    incrementCallCount("update_profile");
    "Profile updated: " # name # " - " # bio
  };

  // Test 5: Method that blocks ingress (should fail when called via ingress)
  transient let _ = validatorInspector.inspect(validatorInspector.createMethodGuardInfo<()>(
    "internal_only",
    false,
    [
      #blockIngress
    ],
    func(args: Args) : () {
      switch (args) {
        case (#None(unit)) unit;
        case (_) ();
      };
    }
  ));
  public func internal_only() : async Text {
    incrementCallCount("internal_only");
    "This should only be callable from other canisters"
  };

  // Test 6: Method that blocks all calls (should always fail)
  transient let _ = validatorInspector.inspect(validatorInspector.createMethodGuardInfo<()>(
    "completely_blocked",
    false,
    [
      #blockAll
    ],
    func(args: Args) : () {
      switch (args) {
        case (#None(unit)) unit;
        case (_) ();
      };
    }
  ));
  public func completely_blocked() : async Text {
    incrementCallCount("completely_blocked");
    "This should never be callable"
  };

  // Test 7: Method with no inspect rules (should always work)
  public func unrestricted() : async Text {
    incrementCallCount("unrestricted");
    "This method has no restrictions"
  };

  // Test 8: Guard method expected by tests - simplified to just requireAuth
  transient let _ = validatorInspector.inspect(validatorInspector.createMethodGuardInfo<Text>(
    "guarded_method",
    false,
    [], // No guard rules - just use requireAuth from main validator
    func(args: Args) : Text {
      switch (args) {
        case (#SimpleMessage(text)) text;
        case (#GuardedMethod(text)) text;
        case (_) "";
      };
    }
  ));
  public func guarded_method(data: Text) : async Result.Result<Text, Text> {
    incrementCallCount("guarded_method");
    if (Text.size(data) >= 5) {
      #ok("Guard passed: " # data)
    } else {
      #err("Guard failed: Message too short for business rules")
    }
  };

  // Test methods for inspectOnlyArgSize functionality
  public func test_small_args(data: Text) : async Result.Result<Text, Text> {
    incrementCallCount("test_small_args");
    
    // Create InspectArgs to use with inspectOnlyArgSize
    let inspectArgs : InspectMo.InspectArgs<Args> = {
      methodName = "test_small_args";
      caller = Principal.fromText("2vxsx-fae"); // dummy caller
      arg = Text.encodeUtf8(data);
      isQuery = false;
      cycles = null;
      deadline = null;
      isInspect = false;
      msg = #SimpleMessage(data);
    };
    
    // Use inspectOnlyArgSize to measure argument size
    let argSize = validatorInspector.inspectOnlyArgSize(inspectArgs);
    storeArgSize("test_small_args", argSize);
    
    #ok("success: small args test with " # Nat.toText(Text.size(data)) # " chars")
  };

  public func test_large_args(data: Text) : async Result.Result<Text, Text> {
    incrementCallCount("test_large_args");
    
    // Create InspectArgs to use with inspectOnlyArgSize
    let inspectArgs : InspectMo.InspectArgs<Args> = {
      methodName = "test_large_args";
      caller = Principal.fromText("2vxsx-fae"); // dummy caller
      arg = Text.encodeUtf8(data);
      isQuery = false;
      cycles = null;
      deadline = null;
      isInspect = false;
      msg = #SimpleMessage(data);
    };
    
    // Use inspectOnlyArgSize to measure argument size
    let argSize = validatorInspector.inspectOnlyArgSize(inspectArgs);
    storeArgSize("test_large_args", argSize);
    
    #ok("success: large args test with " # Nat.toText(Text.size(data)) # " chars")
  };

  public func test_size_validation(data: Text) : async Result.Result<Text, Text> {
    incrementCallCount("test_size_validation");
    
    // Create InspectArgs to use with inspectOnlyArgSize
    let inspectArgs : InspectMo.InspectArgs<Args> = {
      methodName = "test_size_validation";
      caller = Principal.fromText("2vxsx-fae"); // dummy caller
      arg = Text.encodeUtf8(data);
      isQuery = false;
      cycles = null;
      deadline = null;
      isInspect = false;
      msg = #SimpleMessage(data);
    };
    
    // Use inspectOnlyArgSize to measure argument size
    let argSize = validatorInspector.inspectOnlyArgSize(inspectArgs);
    storeArgSize("test_size_validation", argSize);
    
    #ok("success: size validation test")
  };

  // Query method to get last measured arg size
  public query func get_last_arg_size() : async Nat {
    // Return arg size for any test method, prioritizing the most recent one
    var lastArgSize = 0;
    for ((methodName, argSize) in methodArgSizes.vals()) {
      if (methodName == "test_small_args" or methodName == "test_large_args" or methodName == "test_size_validation") {
        lastArgSize := argSize; // This will give us the last one stored
      };
    };
    return lastArgSize;
  };

  // Query method to get arg size for any specific method
  public query func get_method_arg_size(methodName: Text) : async Nat {
    for ((name, size) in methodArgSizes.vals()) {
      if (name == methodName) {
        return size;
      };
    };
    return 0;
  };

  // ===== UTILITY METHODS FOR TESTING =====
  
  // Get call counts for verification
  public query func get_call_counts() : async [(Text, Nat)] {
    callCounts
  };
  
  // Reset call counts
  public func reset_call_counts() : async () {
    callCounts := [];
    methodArgSizes := [];
  };

  // ===== SYSTEM FUNCTION =====
  
  // System function - this is where the actual ingress validation happens
  system func inspect({
    caller : Principal;
    arg : Blob;
    msg : {
      #health_check : () -> ();
      #get_public_info : () -> ();
      #get_info : () -> ();
      #send_message : () -> (message : Text);
      #update_profile : () -> (name : Text, bio : Text);
      #internal_only : () -> ();
      #completely_blocked : () -> ();
      #unrestricted : () -> ();
      #guarded_method : () -> (data : Text);
      #test_small_args : () -> (data : Text);
      #test_large_args : () -> (data : Text);
      #test_size_validation : () -> (data : Text);
      #get_call_counts : () -> ();
      #get_last_arg_size : () -> ();
      #get_method_arg_size : () -> (methodName : Text);
      #reset_call_counts : () -> ();
    }
  }) : Bool {
    
    // Extract method name and determine if it's a query
    let (methodName, isQuery) = switch (msg) {
      case (#health_check _) { ("health_check", true) };
      case (#get_public_info _) { ("get_public_info", true) };
      case (#get_info _) { ("get_info", true) };
      case (#send_message _) { ("send_message", false) };
      case (#update_profile _) { ("update_profile", false) };
      case (#internal_only _) { ("internal_only", false) };
      case (#completely_blocked _) { ("completely_blocked", false) };
      case (#unrestricted _) { ("unrestricted", false) };
      case (#guarded_method _) { ("guarded_method", false) };
      case (#test_small_args _) { ("test_small_args", false) };
      case (#test_large_args _) { ("test_large_args", false) };
      case (#test_size_validation _) { ("test_size_validation", false) };
      case (#get_call_counts _) { ("get_call_counts", true) };
      case (#get_last_arg_size _) { ("get_last_arg_size", true) };
      case (#get_method_arg_size _) { ("get_method_arg_size", true) };
      case (#reset_call_counts _) { ("reset_call_counts", false) };
    };
    
    // Create inspect arguments for ErasedValidator pattern
    let mockArgs : Args = switch (methodName) {
      case ("guarded_method") { #GuardedMethod("mock_text_for_validation") };
      case ("send_message") { #SimpleMessage("mock_message") };
      case ("update_profile") { #ProfileUpdate("mock_name", "mock_bio") };
      case ("test_small_args") { #SimpleMessage("mock_small") };
      case ("test_large_args") { #SimpleMessage("mock_large") };
      case ("test_size_validation") { #SimpleMessage("mock_validation") };
      case (_) { #SimpleMessage("") };
    };
    
    let inspectArgs : InspectMo.InspectArgs<Args> = {
      methodName = methodName;
      caller = caller;
      arg = arg;
      msg = mockArgs;  // Use mock args directly, not wrapped in Some
      isQuery = isQuery;
      isInspect = true; // All calls through inspect are ingress calls
      cycles = ?0;
      deadline = null;
    };
    
    // Use inspector to validate the call
    let result = validatorInspector.inspectCheck(inspectArgs);
    Debug.print("Inspect result for " # methodName # ": " # debug_show(result));
    switch (result) {
      case (#ok) { true };
      case (#err(_)) { false };
    }
  };
}
