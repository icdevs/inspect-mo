/// Test canister for PIC.js integration testing
/// This canister demonstrates InspectMo functionality with real ingress calls
import InspectMo "../src/core/inspector";
import Principal "mo:core/Principal";
import Debug "mo:core/Debug";
import Result "mo:core/Result";
import Array "mo:core/Array";
import Text "mo:core/Text";

persistent actor TestCanister {
  
  // Args union for ErasedValidator pattern with multiple types
  type Args = {
    #SimpleMessage: Text;
    #ProfileUpdate: (Text, Text);
    #None: ();
  };
  
  // Counter to track how many times each method is called
  private stable var callCounts : [(Text, Nat)] = [];
  
  // Helper to increment call count
  private func incrementCallCount(methodName: Text) : () {
    let existing = callCounts;
    var found = false;
    let updated = Array.map<(Text, Nat), (Text, Nat)>(existing, func((name, count)) {
      if (name == methodName) {
        found := true;
        (name, count + 1)
      } else {
        (name, count)
      }
    });
    if (not found) {
      callCounts := Array.concat<(Text, Nat)>(updated, [(methodName, 1)]);
    } else {
      callCounts := updated;
    };
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

  // Accessor functions
  transient func getMessageText(args: Args): Text { 
    switch (args) {
      case (#SimpleMessage(text)) { text };
      case (_) { "" };
    }
  };

  transient func getProfileName(args: Args): Text { 
    switch (args) {
      case (#ProfileUpdate(name, _)) { name };
      case (_) { "" };
    }
  };

  transient func getProfileBio(args: Args): Text { 
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
  transient let _ = validatorInspector.inspect(validatorInspector.createMethodGuardInfo<()>(
    "get_info",
    true,
    [
      #requireAuth // This won't actually be enforced for queries
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

  // Test 4: Update method with multiple parameter validation
  transient let _ = validatorInspector.inspect(validatorInspector.createMethodGuardInfo<(Text, Text)>(
    "update_profile",
    false,
    [
      #textSize(func(profile: (Text, Text)) : Text { profile.0 }, ?1, ?50),   // Name: 1-50 chars
      #textSize(func(profile: (Text, Text)) : Text { profile.1 }, ?0, ?500),  // Bio: 0-500 chars
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

  // Test 7: Method with permission requirement
  transient let _ = validatorInspector.inspect(validatorInspector.createMethodGuardInfo<()>(
    "admin_only",
    false,
    [
      #requirePermission("admin")
    ],
    func(args: Args) : () {
      switch (args) {
        case (#None(unit)) unit;
        case (_) ();
      };
    }
  ));
  public func admin_only() : async Text {
    incrementCallCount("admin_only");
    "Admin operation completed"
  };

  // Test 8: Method with no inspect rules (should always work)
  public func unrestricted() : async Text {
    incrementCallCount("unrestricted");
    "This method has no restrictions"
  };

  // ===== GUARD TESTING METHODS =====
  
  // Test 9: Method with guard rules that complement inspect
  transient let _ = validatorInspector.inspect(validatorInspector.createMethodGuardInfo<()>(
    "guarded_method",
    false,
    [
      #requireAuth
    ],
    func(args: Args) : () {
      switch (args) {
        case (#None(unit)) unit;
        case (_) ();
      };
    }
  ));
  transient let guardMethodInfo = validatorInspector.createMethodGuardInfo<Text>(
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
  );
  transient let _ = validatorInspector.guard(guardMethodInfo);
  public func guarded_method(data: Text) : async Result.Result<Text, Text> {
    // Check guard at runtime
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

  // Test 10: Query method with guard (should hit guard even if no inspect)
  transient let guardQueryInfo = validatorInspector.createMethodGuardInfo<Text>(
    "guarded_query",
    true,
    [
      #customCheck(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (args.args) {
          case (#SimpleMessage(text)) {
            if (text == "forbidden") {
              #err("Forbidden input")
            } else {
              #ok
            }
          };
          case (_) { #err("Invalid input format") };
        }
      })
    ],
    func(args: Args) : Text {
      switch (args) {
        case (#SimpleMessage(text)) text;
        case (_) "";
      };
    }
  );
  transient let _ = validatorInspector.guard(guardQueryInfo);
  public query func guarded_query(input: Text) : async Result.Result<Text, Text> {
    // Check guard at runtime
    let inspectArgs : InspectMo.InspectArgs<Args> = {
      methodName = "guarded_query";
      caller = Principal.fromText("s6bzd-46mcd-mlbx5-cq2jv-m2mhx-nhj6y-erh6g-y73vq-fnfe6-zax3q-mqe");
      arg = Text.encodeUtf8(input);
      msg = #SimpleMessage(input);
      isQuery = true;
      isInspect = false;
      cycles = ?0;
      deadline = null;
    };
    
    let guardResult = validatorInspector.guardCheck(inspectArgs);
    
    switch (guardResult) {
      case (#ok) {
        #ok("Query result: " # input)
      };
      case (#err(msg)) {
        #err("Query guard failed: " # msg)
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
  
  // Get inspector state for debugging
  public query func get_inspector_state() : async Text {
    "Inspector configured with rules"
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
      #update_profile : () -> (name : Text, bio : Text);
      #internal_only : () -> ();
      #completely_blocked : () -> ();
      #admin_only : () -> ();
      #unrestricted : () -> ();
      #guarded_method : () -> (data : Text);
      #guarded_query : () -> (input : Text);
      #get_call_counts : () -> ();
      #reset_call_counts : () -> ();
      #get_inspector_state : () -> ();
    }
  }) : Bool {
    
    // Extract method name and determine if it's a query
    let (methodName, isQuery) = switch (msg) {
      case (#health_check _) { ("health_check", true) };
      case (#get_info _) { ("get_info", true) };
      case (#send_message _) { ("send_message", false) };
      case (#update_profile _) { ("update_profile", false) };
      case (#internal_only _) { ("internal_only", false) };
      case (#completely_blocked _) { ("completely_blocked", false) };
      case (#admin_only _) { ("admin_only", false) };
      case (#unrestricted _) { ("unrestricted", false) };
      case (#guarded_method _) { ("guarded_method", false) };
      case (#guarded_query _) { ("guarded_query", true) };
      case (#get_call_counts _) { ("get_call_counts", true) };
      case (#reset_call_counts _) { ("reset_call_counts", false) };
      case (#get_inspector_state _) { ("get_inspector_state", true) };
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
