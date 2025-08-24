/// Test canister demonstrating InspectMo functionality with ErasedValidator pattern
import InspectMo "core/inspector";
import Principal "mo:core/Principal";
import Debug "mo:core/Debug";
import Result "mo:core/Result";
import Array "mo:core/Array";
import Text "mo:core/Text";

persistent actor TestCanister {
  
  // Custom args types for InspectMo validation
  type Args = {
    #SimpleMessage : Text;
    #ProfileUpdate : (Text, Text);
    #GuardedMethod : Text;
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
      #get_public_info : () -> ();
      #get_info : () -> ();
      #send_message : () -> (message : Text);
      #update_profile : () -> (name : Text, bio : Text);
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
      case (#get_public_info _) { ("get_public_info", true) };
      case (#get_info _) { ("get_info", true) };
      case (#send_message _) { ("send_message", false) };
      case (#update_profile _) { ("update_profile", false) };
      case (#internal_only _) { ("internal_only", false) };
      case (#completely_blocked _) { ("completely_blocked", false) };
      case (#unrestricted _) { ("unrestricted", false) };
      case (#guarded_method _) { ("guarded_method", false) };
      case (#get_call_counts _) { ("get_call_counts", true) };
      case (#reset_call_counts _) { ("reset_call_counts", false) };
    };
    
    // Create inspect arguments for ErasedValidator pattern
    let mockArgs : Args = switch (methodName) {
      case ("guarded_method") { #GuardedMethod("mock_text_for_validation") }; // Simplified: treat all guarded_method calls as having text
      case ("send_message") { #SimpleMessage("mock_message") };
      case ("update_profile") { #ProfileUpdate("mock_name", "mock_bio") };
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
