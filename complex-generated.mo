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

import InspectMo "./src/lib";
import Principal "mo:core/Principal";
import Result "mo:core/Result";
import Debug "mo:core/Debug";

module {

  /// Type-safe accessor functions
  // TODO: Implement accessor for vec type
  // TODO: Implement accessor for opt type
  public func getIdNat(args: (Nat)) : Nat { args.0 };
  public func getCountNat(args: (Nat)) : Nat { args.0 };
  public func getBalanceInt(args: (Int)) : Int { args.0 };
  public func getMessageText(args: (Text)) : Text { args.0 };

  /// MessageAccessor type for method discrimination
  public type MessageAccessor = {
    #batch_create_users : ([UserProfile]);
    #clear_all_data : ();
    #create_profile : (UserProfile);
    #create_transaction : (TransactionRequest, ?Text);
    #execute_bulk_operation : (BulkOperation);
    #get_call_logs : ();
    #get_profile : (Nat);
    #get_stats : ();
    #health_check : ();
    #search_users : (SearchFilter, [Nat]);
    #simple_numbers : (Nat, Int);
    #simple_text : (Text);
    #update_profile : (Nat, UserProfile);
    #upload_document : (DocumentUpload);
  };

  public func extractMethodName(call: MessageAccessor) : Text {
    switch (call) {
      case (#batch_create_users _) { "batch_create_users" };
      case (#clear_all_data _) { "clear_all_data" };
      case (#create_profile _) { "create_profile" };
      case (#create_transaction _) { "create_transaction" };
      case (#execute_bulk_operation _) { "execute_bulk_operation" };
      case (#get_call_logs _) { "get_call_logs" };
      case (#get_profile _) { "get_profile" };
      case (#get_stats _) { "get_stats" };
      case (#health_check _) { "health_check" };
      case (#search_users _) { "search_users" };
      case (#simple_numbers _) { "simple_numbers" };
      case (#simple_text _) { "simple_text" };
      case (#update_profile _) { "update_profile" };
      case (#upload_document _) { "upload_document" };
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
      case ("get_profile") { true };
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

  // Guard helper for batch_create_users
  public func guardBatch_create_users(args: [UserProfile], caller: Principal) : Result.Result<(), Text> {
    // TODO: Implement runtime business logic validation
    // Security considerations:
    //   - Consider requiring authentication
    //   - Validate all input parameters
    #ok(())
  };

  // Guard helper for clear_all_data
  public func guardClear_all_data(args: (), caller: Principal) : Result.Result<(), Text> {
    // TODO: Implement runtime business logic validation
    // Security considerations:
    //   - Consider requiring authentication
    #ok(())
  };

  // Guard helper for create_profile
  public func guardCreate_profile(args: UserProfile, caller: Principal) : Result.Result<(), Text> {
    // TODO: Implement runtime business logic validation
    // Security considerations:
    //   - Consider requiring authentication
    //   - Validate all input parameters
    #ok(())
  };

  // Guard helper for create_transaction
  public func guardCreate_transaction(args: (TransactionRequest, ?Text), caller: Principal) : Result.Result<(), Text> {
    // TODO: Implement runtime business logic validation
    // Security considerations:
    //   - Consider requiring authentication
    //   - Validate all input parameters
    #ok(())
  };

  // Guard helper for execute_bulk_operation
  public func guardExecute_bulk_operation(args: BulkOperation, caller: Principal) : Result.Result<(), Text> {
    // TODO: Implement runtime business logic validation
    // Security considerations:
    //   - Consider requiring authentication
    //   - Validate all input parameters
    #ok(())
  };

  // Guard helper for get_call_logs
  public func guardGet_call_logs(args: (), caller: Principal) : Result.Result<(), Text> {
    // TODO: Implement runtime business logic validation
    // Security considerations:
    //   - Consider requiring authentication
    #ok(())
  };

  // Guard helper for get_stats
  public func guardGet_stats(args: (), caller: Principal) : Result.Result<(), Text> {
    // TODO: Implement runtime business logic validation
    // Security considerations:
    //   - Consider requiring authentication
    #ok(())
  };

  // Guard helper for search_users
  public func guardSearch_users(args: (SearchFilter, [Nat]), caller: Principal) : Result.Result<(), Text> {
    // TODO: Implement runtime business logic validation
    // Security considerations:
    //   - Consider requiring authentication
    //   - Validate all input parameters
    #ok(())
  };

  // Guard helper for simple_numbers
  public func guardSimple_numbers(args: (Nat, Int), caller: Principal) : Result.Result<(), Text> {
    // TODO: Implement runtime business logic validation
    // Security considerations:
    //   - Consider requiring authentication
    //   - Validate all input parameters
    #ok(())
  };

  // Guard helper for simple_text
  public func guardSimple_text(args: Text, caller: Principal) : Result.Result<(), Text> {
    // TODO: Implement runtime business logic validation
    // Security considerations:
    //   - Consider requiring authentication
    //   - Validate all input parameters
    #ok(())
  };

  // Guard helper for update_profile
  public func guardUpdate_profile(args: (Nat, UserProfile), caller: Principal) : Result.Result<(), Text> {
    // TODO: Implement runtime business logic validation
    // Security considerations:
    //   - Consider requiring authentication
    //   - Validate all input parameters
    #ok(())
  };

  // Guard helper for upload_document
  public func guardUpload_document(args: DocumentUpload, caller: Principal) : Result.Result<(), Text> {
    // TODO: Implement runtime business logic validation
    // Security considerations:
    //   - Consider requiring authentication
    //   - Validate all input parameters
    #ok(())
  };


}