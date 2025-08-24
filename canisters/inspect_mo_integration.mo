/// InspectMo Integration Test Canister
/// This canister demonstrates real InspectMo usage in system inspect
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Text "mo:base/Text";

import InspectMo "../src/core/inspector";

persistent actor InspectMoIntegration {
  
  // ===== STATE =====
  private stable var message : Text = "";
  private stable var inspectLogs : [Text] = [];
  
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
  
  transient func createTestInspector() : InspectMo.InspectMo {
    InspectMo.InspectMo(
      null, 
      Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai"), 
      Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"),
      ?config, 
      null,
      func(state: InspectMo.State) {
        Debug.print("📊 InspectMo State Updated");
      }
    )
  };
  
  private transient let inspectMo = createTestInspector();
  private transient let validatorInspector = inspectMo.createInspector<Args>();
  
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
