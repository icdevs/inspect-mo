/// Simple test canister for PIC.js integration testing
/// This canister demonstrates InspectMo functionality with real ingress calls
import InspectMo "../src/core/inspector";
import Principal "mo:core/Principal";
import Debug "mo:core/Debug";
import Result "mo:core/Result";
import Array "mo:core/Array";
import Text "mo:core/Text";

persistent actor TestCanisterSimple {
  
  // Args union for ErasedValidator pattern
  type Args = {
    #SimpleMessage: Text;
    #None: ();
  };
  
  // Counter to track how many times each method is called
  private stable var callCounts : [(Text, Nat)] = [];
  
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

  // Initialize Inspector with ErasedValidator pattern
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

  transient func createTestInspector() : InspectMo.InspectMo {
    InspectMo.InspectMo(
      null, 
      Principal.fromText("s6bzd-46mcd-mlbx5-cq2jv-m2mhx-nhj6y-erh6g-y73vq-fnfe6-zax3q-mqe"), 
      Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai"),
      ?defaultConfig, 
      null,
      func(state: InspectMo.State) {}
    )
  };

  transient let inspector = createTestInspector();
  transient let validatorInspector = inspector.createInspector<Args>();

  // Accessor functions (kept for potential future use)
  transient func _getMessageText(args: Args): Text { 
    switch (args) {
      case (#SimpleMessage(text)) { text };
      case (_) { "" };
    }
  };

  // ===== QUERY METHODS =====
  
  // Test 1: Query method with no restrictions (should NOT go through inspect)
  public query func health_check() : async Text {
    "Canister is healthy"
  };

  // Test 2: Query with inspect rules (should NOT go through inspect anyway)
  transient let _ = validatorInspector.inspect(validatorInspector.createMethodGuardInfo<()>(
    "get_info",
    true,
    [
      InspectMo.requireAuth() // This won't actually be enforced for queries
    ],
    func(args: Args) : () {
      switch (args) {
        case (#None(unit)) unit;
        case (_) ();
      };
    }
  ));
  public query func get_info() : async Text {
    "This is basic info - query method"
  };

  // ===== UPDATE METHODS WITH INSPECT RULES =====
  
  // Test 3: Update method with text size validation + auth
  transient let _ = validatorInspector.inspect(validatorInspector.createMethodGuardInfo<Text>(
    "send_message",
    false,
    [
      #textSize(func(msg: Text) : Text { msg }, ?1, ?100),
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

  // Test 4: Method that blocks ingress (should fail when called via ingress)
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

  // Test 5: Method that blocks all calls (should always fail)
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

  // Test 6: Method with no inspect rules (should always work)
  public func unrestricted() : async Text {
    incrementCallCount("unrestricted");
    "This method has no restrictions"
  };

  // ===== GUARD TESTING METHODS =====
  
  // Test 7: Method with guard rules for runtime validation
  transient let _ = validatorInspector.guard(validatorInspector.createMethodGuardInfo<Text>(
    "guarded_method",
    false,
    [
      #customCheck(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        // Custom business logic check
        switch (args.args) {
          case (#SimpleMessage(text)) {
            if (text.size() < 5) {
              #err("Message too short for business rules")
            } else {
              #ok
            }
          };
          case (_) { #err("Invalid message format") };
        }
      })
    ],
    func(args: Args) : Text {
      switch (args) {
        case (#SimpleMessage(text)) text;
        case (_) "";
      };
    }
  ));
  public func guarded_method(data: Text) : async Result.Result<Text, Text> {
    // Check guard at runtime - using ErasedValidator pattern
    let inspectArgs : InspectMo.InspectArgs<Args> = {
      methodName = "guarded_method";
      caller = Principal.fromText("s6bzd-46mcd-mlbx5-cq2jv-m2mhx-nhj6y-erh6g-y73vq-fnfe6-zax3q-mqe");
      arg = Text.encodeUtf8(data);
      msg = #SimpleMessage(data);
      isQuery = false;
      isInspect = false;
      cycles = ?0;
      deadline = null;
    };
    
    let guardResult = validatorInspector.guardCheck(inspectArgs);
    
    switch (guardResult) {
      case (#ok) {
        incrementCallCount("guarded_method");
        #ok("Guard passed: " # data)
      };
      case (#err(msg)) {
        #err("Guard failed: " # msg)
      };
    }
  };

  // ===== UTILITY METHODS FOR TESTING =====
  
  // Get call counts for verification
  public query func get_call_counts() : async [(Text, Nat)] {
    callCounts
  };
  
  // Reset call counts
  public func reset_call_counts() : async () {
    callCounts := [];
  };

  // ===== SYSTEM FUNCTION =====
  
  // System function - this is where the actual ingress validation happens
  system func inspect({
    caller : Principal;
    arg : Blob;
    msg : {
      #health_check : () -> ();
      #get_info : () -> ();
      #send_message : () -> (message : Text);
      #internal_only : () -> ();
      #completely_blocked : () -> ();
      #unrestricted : () -> ();
      #guarded_method : () -> (data : Text);
      #get_call_counts : () -> ();
      #reset_call_counts : () -> ();
    }
  }) : Bool {
    
    // Extract method name and determine if it's a query
    let (methodName, isQuery) = switch (msg) {
      case (#health_check _) { ("health_check", true) };
      case (#get_info _) { ("get_info", true) };
      case (#send_message _) { ("send_message", false) };
      case (#internal_only _) { ("internal_only", false) };
      case (#completely_blocked _) { ("completely_blocked", false) };
      case (#unrestricted _) { ("unrestricted", false) };
      case (#guarded_method _) { ("guarded_method", false) };
      case (#get_call_counts _) { ("get_call_counts", true) };
      case (#reset_call_counts _) { ("reset_call_counts", false) };
    };
    
    // Create inspect arguments for ErasedValidator pattern
    let inspectArgs : InspectMo.InspectArgs<Args> = {
      methodName = methodName;
      caller = caller;
      arg = arg;
      msg = #None(());
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
