// This file is an example canister that uses the library for this project. It is an example of how to expose the functionality of the class module to the outside world.
// It is not a complete canister and should not be used as such. It is only an example of how to use the library for this project.


import _List "mo:core/List";
import D "mo:core/Debug";
import _Int "mo:core/Int";
import Array "mo:core/Array";
import Nat "mo:core/Nat";
import Principal "mo:core/Principal";
import _Time "mo:core/Time";
import _Error "mo:core/Error";
import ClassPlus "mo:class-plus";
import TT "mo:timer-tool";
import Log "mo:stable-local-log";
import OVSFixed "mo:ovs-fixed";

import InspectMo ".";

shared (deployer) persistent actor class SampleCanister<system>(
  args:?{
   
    ttArgs: ?TT.InitArgList;
  }
) = this {

  

  // transient let thisPrincipal = Principal.fromActor(this);
  var _owner = deployer.caller;

  transient let initManager = ClassPlus.ClassPlusInitializationManager(_owner, Principal.fromActor(this), true);

  transient let ttInitArgs : ?TT.InitArgList = do?{args!.ttArgs!};

  // var icrc10 = ICRC10.initCollection();

  // Test-only: track OVS handler invocations
  var ovs_handler_calls : Nat = 0;
  var ovs_last_units : Nat = 0;
  var ovs_last_namespace : Text = "";
  var ovs_last_platform : Text = "";

  // Track notify-based cycle deposit path
  var notify_calls : Nat = 0;
  var notify_last_namespace : Text = "";
  var notify_last_units : Nat = 0;

  // OVS event history (stable)
  public type OvsEvent = {
    ts : Nat;          // nanoseconds since epoch
    mode : Text;       // "handler" | "notify"
    namespace : Text;  // timer or payment namespace depending on mode
    platform : Text;   // e.g., "icp"
    units : Nat;       // number of actions reported
  };

  var ovs_history : [OvsEvent] = [];

  // Runtime ICRC85 environment (nullable until enabled by test)
  transient var icrc85_env : OVSFixed.ICRC85Environment = null;

  private func reportTTExecution(execInfo: TT.ExecutionReport): Bool{
    D.print("CANISTER: TimerTool Execution: " # debug_show(execInfo));
    return false;
  };

  private func reportTTError(errInfo: TT.ErrorReport) : ?Nat{
    D.print("CANISTER: TimerTool Error: " # debug_show(errInfo));
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
      D.print("Initializing TimerTool");
      newClass.initialize<system>();
      //do any work here necessary for initialization
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
        advanced = null; // Add any advanced options if needed
        onEvict = null;
      };
    });
    onInitialize = null;
    onStorageChange = func(state: Log.State) {
      localLog_migration_state := state;
    };
  });

  // transient let d = localLog().log_debug; // not needed in tests

  var inspector_migration_state: InspectMo.State = InspectMo.initialState();

  transient let _inspector = InspectMo.Init<system>({
    manager = initManager;
    initialState = inspector_migration_state;
    args = ?{
      
      allowAnonymous = ?true ;         // Global default for anonymous access
      defaultMaxArgSize= ?100_000;       // Global default argument size limit
      authProvider= null;   // Permission system integration (function - not stable)
      rateLimit= null;   // Global rate limiting
      
      // Query vs Update specific defaults
      queryDefaults = null;   // Defaults for query calls
      updateDefaults= null; // Defaults for update calls
      
      developmentMode = true;         // Enable relaxed rules for testing
      auditLog = true;
    };
    pullEnvironment = ?(func() : InspectMo.Environment {
      {
        tt = tt();
        advanced = ?{
          icrc85 = icrc85_env;
        }; // Provide dynamic ICRC85 options for tests
        log = localLog();
      };
    });

    onInitialize = ?(func (_newClass: InspectMo.
  InspectMo) : async* () {
      D.print("Initializing Sample Class");
      //do any work here necessary for initialization
    });

    onStorageChange = func(state: InspectMo.State) {
      inspector_migration_state := state;
    };
  });


  public shared func hello(): async Text {
    return "world!";
  };

  // Enable OVS test mode: install a handler so cycles aren't transferred
  public shared func enable_ovs_test(args : ?{
    // Optional: override period in nanoseconds for faster tests
    period_ns : ?Nat;
  }) : async () {
    let periodOpt = do?{ args!.period_ns! };
    icrc85_env := ?{
      kill_switch = ?false;
      handler = ?(func (events: [(Text, OVSFixed.Map)]) : () {
        // Expect a single event with key "icrc85:ovs:shareaction"
        if (events.size() > 0) {
          let (ns, kv) = events[0];
          ovs_last_namespace := ns;
          // Extract some fields for basic verification
          var unitsVal : Nat = 0;
          var platformVal : Text = "";
          label find for ((k, v) in kv.vals()) {
            if (k == "units") {
              switch (v) { case (#Nat(n)) { ovs_last_units := n; unitsVal := n }; case (_) {} };
            } else if (k == "platform") {
              switch (v) { case (#Text(t)) { ovs_last_platform := t; platformVal := t }; case (_) {} };
            };
          };
          // Record history entry for handler mode
          ovs_history := Array.concat<OvsEvent>(ovs_history, [
            {
              ts = _Int.abs(_Time.now());
              mode = "handler";
              namespace = ovs_last_namespace;
              platform = if (platformVal == "") "icp" else platformVal;
              units = unitsVal;
            } : OvsEvent
          ]);
        };
        ovs_handler_calls += 1;
      });
      period = periodOpt; // default of lib is 30 days when null
      asset = ?"cycles";
      platform = ?"icp";
      tree = null;
      collector = null;
    };
    // Refresh environments so downstream libs pick up new settings
    _refresh_envs();
  };

  // Enable OVS send mode: no handler, deposit cycles to a collector (default self)
  public shared func enable_ovs_send_mode(args : ?{
    period_ns : ?Nat;
    collector_self : ?Bool;
  }) : async () {
    let periodOpt = do?{ args!.period_ns! };
    let useSelfCollector : Bool = switch (do?{ args!.collector_self! }) { case (?b) b; case null true };
    let collectorOpt : ?Principal = if (useSelfCollector) ?Principal.fromActor(this) else null;
    icrc85_env := ?{
      kill_switch = ?false;
      handler = null; // allow real send path
      period = periodOpt;
      asset = ?"cycles";
      platform = ?"icp";
      tree = null;
      collector = collectorOpt;
    };
    _refresh_envs();
  };

  // Endpoint expected by OVS cycles-sharing when no handler is provided
  public shared func icrc85_deposit_cycles_notify(pairs: [(Text, Nat)]) : async () {
    notify_calls += 1;
    if (pairs.size() > 0) {
      let (ns, units) = pairs[0];
      notify_last_namespace := ns;
      notify_last_units := units;
      // Record history entry for notify mode
      ovs_history := Array.concat<OvsEvent>(ovs_history, [
        {
          ts = _Int.abs(_Time.now());
          mode = "notify";
          namespace = notify_last_namespace;
          platform = "icp";
          units = notify_last_units;
        } : OvsEvent
      ]);
    };
  };

  // Allow tests to force-refresh the environments of sub-components
  private func _refresh_envs() : () {
    // Push the new environment to InspectMo
    _inspector().setEnvironment(?{
      tt = tt();
      advanced = ?{ icrc85 = icrc85_env };
      log = localLog();
    });
  };

  public shared query func get_ovs_handler_calls() : async Nat { ovs_handler_calls };
  public shared query func get_ovs_last_units() : async Nat { ovs_last_units };
  public shared query func get_ovs_last_namespace() : async Text { ovs_last_namespace };
  public shared query func get_ovs_last_platform() : async Text { ovs_last_platform };

  // Queries for notify path assertions
  public shared query func get_notify_calls() : async Nat { notify_calls };
  public shared query func get_notify_last_namespace() : async Text { notify_last_namespace };
  public shared query func get_notify_last_units() : async Nat { notify_last_units };

  // History APIs
  public shared query func get_ovs_history() : async [OvsEvent] { ovs_history };
  public shared func clear_ovs_history() : async () { ovs_history := [] };


};
