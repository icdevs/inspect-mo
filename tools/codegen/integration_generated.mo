/// Auto-generated InspectMo integration module using ErasedValidator pattern
/// Generated from Candid interface
/// 
/// This module contains:
/// - Args union type for ErasedValidator pattern
/// - Type-safe accessor functions for method parameters  
/// - ErasedValidator initialization template
/// - System inspect function template
///
/// Usage:
/// 1. Import this module in your canister
/// 2. Copy the Args union type to your canister
/// 3. Use the ErasedValidator initialization code
/// 4. Customize validation rules as needed

import InspectMo "mo:inspect-mo/lib";
import Principal "mo:core/Principal";
import Result "mo:core/Result";
import Debug "mo:core/Debug";

module {

  /// Args union type for ErasedValidator pattern
  public type Args = {
    #Clear_data: ();
    #Get_inspect_logs: ();
    #Get_message: ();
    #Store_message: Text;
    #None: ();
  };

  /// Accessor functions for ErasedValidator pattern
  public func getStore_messageMsg(args: Args): Text {
    switch (args) {
      case (#Store_message(value)) value;
      case (_) "";
    };
  };


  /// ErasedValidator initialization template
  public func createValidatorInspector() : InspectMo.InspectMo {
    let inspector = InspectMo.InspectMo(
      {
        supportAudit = false;
        supportTimer = false;
        supportAdvanced = false;
      },
      func(state: InspectMo.State) {}
    );

    // Setup validation rules using ErasedValidator pattern
    // clear_data validation
    inspector.inspect(inspector.createMethodGuardInfo<()>(
      "clear_data",
      false, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): () {
        switch (args) {
          case (#Clear_data(params)) {
            // No parameters to process
            ()
          };
          case (_) {
            // Default fallback
            ()
          };
        };
      }
    ));

    // get_inspect_logs validation
    inspector.inspect(inspector.createMethodGuardInfo<[Text]>(
      "get_inspect_logs",
      true, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): [Text] {
        switch (args) {
          case (#Get_inspect_logs(params)) {
            // No parameters - add your return logic here
            Debug.trap("Implement return logic for get_inspect_logs")
          };
          case (_) {
            // Default fallback - provide appropriate default
            Debug.trap("Invalid args type for get_inspect_logs")
          };
        };
      }
    ));

    // get_message validation
    inspector.inspect(inspector.createMethodGuardInfo<Text>(
      "get_message",
      true, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): Text {
        switch (args) {
          case (#Get_message(params)) {
            // No parameters - add your return logic here
            Debug.trap("Implement return logic for get_message")
          };
          case (_) {
            // Default fallback - provide appropriate default
            Debug.trap("Invalid args type for get_message")
          };
        };
      }
    ));

    // store_message validation
    inspector.inspect(inspector.createMethodGuardInfo<Text>(
      "store_message",
      false, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): Text {
        switch (args) {
          case (#Store_message(params)) {
            // Extract single parameter: msg
            let param = params;
            // Add your processing logic here
            Debug.trap("Implement processing logic for store_message")
          };
          case (_) {
            // Default fallback - provide appropriate default
            Debug.trap("Invalid args type for store_message")
          };
        };
      }
    ));

    inspector
  };

  /// System inspect function template for ErasedValidator pattern
  public func generateSystemInspect() : Text {
    let template = ```
  system func inspect({
    arg : Blob;
    caller : Principal;
    msg : {
      #clear_data : ();
      #get_inspect_logs : ();
      #get_message : ();
      #store_message : (Text);
    }
  }) : Bool {
    let (methodName, isQuery, msgArgs) = switch (msg) {
      case (#clear_data _) ("clear_data", false, #Clear_data(()));
      case (#get_inspect_logs _) ("get_inspect_logs", true, #Get_inspect_logs(()));
      case (#get_message _) ("get_message", true, #Get_message(()));
      case (#store_message params) ("store_message", false, #Store_message(params));
      case (_) ("unknown_method", false, #None(()));
    };
    
    let inspectArgs : InspectMo.InspectArgs<Args> = {
      methodName = methodName;
      caller = caller;
      arg = arg;
      msg = msgArgs;
      isQuery = isQuery;
      isInspect = true;
      cycles = ?0;
      deadline = null;
    };
    
    let result = validatorInspector.inspectCheck(inspectArgs);
    switch (result) {
      case (#ok) { true };
      case (#err(_)) { false };
    }
  };
    ```;
    template
  };

}