/// Auto-generated InspectMo integration module
/// Generated from Candid interface
/// 
/// This module contains:
/// - Type-safe accessor functions for method parameters
/// - MessageAccessor type for method discrimination
/// - Helper functions for integration with your system inspect
///
/// Usage:
/// 1. Import this module in your canister
/// 2. Use the inspect helper in your system func inspect
/// 3. Customize validation rules as needed

import InspectMo "mo:inspect-mo/src/lib";
import Principal "mo:core/Principal";
import Result "mo:core/Result";
import Debug "mo:core/Debug";

module {

  /// Type-safe accessor functions
  public func getDataText(args: (Text)) : Text { args.0 };
  public func getMessageText(args: (Text)) : Text { args.0 };

  /// MessageAccessor type for method discrimination
  public type MessageAccessor = {
    #completely_blocked : ();
    #get_call_counts : ();
    #get_info : ();
    #guarded_method : (Text);
    #health_check : ();
    #internal_only : ();
    #reset_call_counts : ();
    #send_message : (Text);
    #unrestricted : ();
  };

  public func extractMethodName(call: MessageAccessor) : Text {
    switch (call) {
      case (#completely_blocked _) { "completely_blocked" };
      case (#get_call_counts _) { "get_call_counts" };
      case (#get_info _) { "get_info" };
      case (#guarded_method _) { "guarded_method" };
      case (#health_check _) { "health_check" };
      case (#internal_only _) { "internal_only" };
      case (#reset_call_counts _) { "reset_call_counts" };
      case (#send_message _) { "send_message" };
      case (#unrestricted _) { "unrestricted" };
    }
  };

  /// Helper function for integration with your system inspect
  /// Call this from your system func inspect with the inspector object
  public func inspectHelper(
    msg: MessageAccessor,
    inspector: InspectMo.Inspector<MessageAccessor>
  ) : Bool {
    let methodName = extractMethodName(msg);
    
    // Use InspectMo to check the method
    switch (inspector.inspectCheck({
      caller = ?inspector.getCaller(); // Get from context
      arg = ?inspector.getArgBlob(); // Get from context
      methodName = methodName;
      isQuery = ?isQueryMethod(methodName);
      msg = msg;
      isIngress = true;
      parsedArgs = null;
      argSizes = [];
      argTypes = [];
    })) {
      case (true) { true };
      case (false) { false };
    }
  };

  /// Helper to determine if a method is a query
  public func isQueryMethod(methodName: Text) : Bool {
    switch (methodName) {
      case ("get_info") { true };
      case ("health_check") { true };
      case (_) { false };
    }
  };

  /// Usage example:
  /// In your actor:
  /// system func inspect({
  ///   caller : Principal;
  ///   arg : Blob;
  ///   msg : MessageAccessor
  /// }) : Bool {
  ///   // Your custom pre-validation here
  ///   
  ///   // Use the helper
  ///   MyInspectModule.inspectHelper(msg, myInspector)
  /// };

  /// Guard function helpers for runtime validation
  /// Use these in your method implementations for business logic validation

  // Guard helper for completely_blocked
  public func guardCompletely_blocked(args: (), caller: Principal) : Result.Result<(), Text> {
    // TODO: Implement runtime business logic validation
    // Security considerations:
    //   - Consider requiring authentication
    #ok(())
  };

  // Guard helper for get_call_counts
  public func guardGet_call_counts(args: (), caller: Principal) : Result.Result<(), Text> {
    // TODO: Implement runtime business logic validation
    // Security considerations:
    //   - Consider requiring authentication
    #ok(())
  };

  // Guard helper for guarded_method
  public func guardGuarded_method(args: Text, caller: Principal) : Result.Result<(), Text> {
    // TODO: Implement runtime business logic validation
    // Security considerations:
    //   - Consider requiring authentication
    //   - Validate all input parameters
    #ok(())
  };

  // Guard helper for internal_only
  public func guardInternal_only(args: (), caller: Principal) : Result.Result<(), Text> {
    // TODO: Implement runtime business logic validation
    // Security considerations:
    //   - Consider requiring authentication
    #ok(())
  };

  // Guard helper for reset_call_counts
  public func guardReset_call_counts(args: (), caller: Principal) : Result.Result<(), Text> {
    // TODO: Implement runtime business logic validation
    // Security considerations:
    //   - Consider requiring authentication
    #ok(())
  };

  // Guard helper for send_message
  public func guardSend_message(args: Text, caller: Principal) : Result.Result<(), Text> {
    // TODO: Implement runtime business logic validation
    // Security considerations:
    //   - Consider requiring authentication
    //   - Validate all input parameters
    #ok(())
  };

  // Guard helper for unrestricted
  public func guardUnrestricted(args: (), caller: Principal) : Result.Result<(), Text> {
    // TODO: Implement runtime business logic validation
    // Security considerations:
    //   - Consider requiring authentication
    #ok(())
  };


}