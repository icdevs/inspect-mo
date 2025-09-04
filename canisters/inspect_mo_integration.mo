/// InspectMo Integration Test Canister
/// This canister demonstrates real InspectMo usage in system inspect
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Text "mo:base/Text";
import _Int "mo:core/Int";
import _Time "mo:core/Time";
import ClassPlus "mo:class-plus";
import TT "mo:timer-tool";
import Log "mo:stable-local-log";
import OVSFixed "mo:ovs-fixed";

import InspectMo "../src/lib";

persistent actor {
  
  var _owner = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");

  transient let initManager = ClassPlus.ClassPlusInitializationManager(_owner, _owner, true);

  transient let ttInitArgs : ?TT.InitArgList = null;

  // Runtime ICRC85 environment (nullable until enabled by test)
  transient var icrc85_env : OVSFixed.ICRC85Environment = null;

  private func reportTTExecution(execInfo: TT.ExecutionReport): Bool{
    Debug.print("INSPECT_INTEGRATION: TimerTool Execution: " # debug_show(execInfo));
    return false;
  };

  private func reportTTError(errInfo: TT.ErrorReport) : ?Nat{
    Debug.print("INSPECT_INTEGRATION: TimerTool Error: " # debug_show(errInfo));
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
      Debug.print("INSPECT_INTEGRATION: Initializing TimerTool");
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

  // ===== STATE =====
  private var message : Text = "";
  private var inspectLogs : [Text] = [];
  
  // Args union for ErasedValidator pattern
  type Args = {
    #StoreMessage: Text;
    #None: ();
  };
  
  // ===== INSPECTMO SETUP =====
  
  private transient let config = {
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

  transient let inspectMo = InspectMo.Init<system>({
    manager = initManager;
    initialState = inspector_migration_state;
    args = ?config;
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
      Debug.print("INSPECT_INTEGRATION: Initializing InspectMo");
    });

    onStorageChange = func(state: InspectMo.State) {
      inspector_migration_state := state;
    };
  });
  
  private transient let validatorInspector = inspectMo().createInspector<Args>();
  
  // Configure inspection rules
  private transient let _ = do {
    // Rule 1: store_message requires non-empty text + size limits
    validatorInspector.guard(validatorInspector.createMethodGuardInfo<Text>(
      "store_message",
      false,
      [
        #customCheck(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
          switch (args.args) {
            case (#StoreMessage(text)) {
              if (Text.size(text) > 0) { 
                #ok 
              } else { 
                #err("❌ Empty message not allowed") 
              }
            };
            case (_) { #err("Invalid message format") };
          }
        }),
        #textSize(func(msg: Text): Text { msg }, ?1, ?100)
      ],
      func(args: Args): Text {
        switch (args) {
          case (#StoreMessage(text)) text;
          case (_) "";
        };
      }
    ));
    
    // Rule 2: clear_data requires authentication (no anonymous)
    validatorInspector.inspect(validatorInspector.createMethodGuardInfo<()>(
      "clear_data",
      false,
      [
        #requireAuth
      ],
      func(args: Args): () {
        switch (args) {
          case (#None(unit)) unit;
          case (_) ();
        };
      }
    ));
  };
  
  private func addLog(entry: Text) {
    inspectLogs := Array.append<Text>(inspectLogs, [entry]);
  };
  
  // ===== PUBLIC METHODS =====
  
  public func store_message(msg: Text) : async Text {
    message := msg;
    let logEntry = "📝 Message stored: " # msg;
    addLog(logEntry);
    "Message stored: " # msg
  };
  
  public query func get_message() : async Text {
    message
  };
  
  public func clear_data() : async () {
    message := "";
    addLog("🗑️ Data cleared");
  };
  
  public query func get_inspect_logs() : async [Text] {
    inspectLogs
  };
  
  // ===== SYSTEM INSPECT (The Real InspectMo Integration!) =====
  
  system func inspect({
    caller : Principal;
    arg : Blob;
    msg : {
      #store_message : () -> (msg : Text);
      #clear_data : () -> ();
      #get_message : () -> (); // Query methods shouldn't appear here, but just in case
      #get_inspect_logs : () -> (); // Query methods shouldn't appear here
    }
  }) : Bool {
    
    Debug.print("🔍 INSPECT: Method called by " # Principal.toText(caller));
    
    // Extract method name and parameters using InspectMo patterns
    switch (msg) {
      case (#store_message _) {
        Debug.print("🔍 INSPECT: store_message detected");
        
        // Create inspect arguments for guard check
        let inspectArgs : InspectMo.InspectArgs<Args> = {
          methodName = "store_message";
          caller = caller;
          arg = arg;
          msg = #StoreMessage("demo text"); // In reality, this would be parsed from `arg : Blob`
          isQuery = false;
          isInspect = true;
          cycles = ?0;
          deadline = null;
        };
        
        // Use InspectMo to validate the parameters
        let guardResult = validatorInspector.guardCheck(inspectArgs);
        switch (guardResult) {
          case (#ok) {
            Debug.print("✅ INSPECT: store_message guard validation PASSED");
            addLog("✅ Guard validation passed for store_message");
            true // Allow the call
          };
          case (#err(msg)) {
            Debug.print("❌ INSPECT: store_message guard validation FAILED: " # msg);
            addLog("❌ Guard validation failed: " # msg);
            false // Reject the call
          };
        }
      };
      
      case (#clear_data _) {
        Debug.print("🔍 INSPECT: clear_data detected");
        
        // Create InspectArgs for the inspect check
        let inspectArgs : InspectMo.InspectArgs<Args> = {
          methodName = "clear_data";
          caller = caller;
          arg = arg;
          msg = #None(());
          isQuery = false;
          isInspect = true;
          cycles = ?0;
          deadline = null;
        };
        
        // Use InspectMo to validate using inspect rules
        let inspectResult = validatorInspector.inspectCheck(inspectArgs);
        if (inspectResult == #ok) {
          Debug.print("✅ INSPECT: clear_data inspection PASSED");
          addLog("✅ Inspection passed for clear_data");
        } else {
          Debug.print("❌ INSPECT: clear_data inspection FAILED");
          addLog("❌ Inspection failed for clear_data");
        };
        switch (inspectResult) {
          case (#ok) { true };
          case (#err(_)) { false };
        }
      };
      
      case (_) {
        Debug.print("🔍 INSPECT: Unknown method, allowing by default");
        true // Allow unknown methods for now
      };
    }
  };
}
