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
    #Completely_blocked: ();
    #Get_call_counts: ();
    #Get_info: ();
    #Guarded_method: Text;
    #Health_check: ();
    #Internal_only: ();
    #Reset_call_counts: ();
    #Send_message: Text;
    #Unrestricted: ();
    #None: ();
  };

  /// Accessor functions for ErasedValidator pattern
  public func getGuarded_methodData(args: Args): Text {
    switch (args) {
      case (#Guarded_method(value)) value;
      case (_) "";
    };
  };

  public func getSend_messageMessage(args: Args): Text {
    switch (args) {
      case (#Send_message(value)) value;
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
    // completely_blocked validation
    inspector.inspect(inspector.createMethodGuardInfo<Text>(
      "completely_blocked",
      false, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): Text {
        switch (args) {
          case (#Completely_blocked(params)) {
            // No parameters - add your return logic here
            Debug.trap("Implement return logic for completely_blocked")
          };
          case (_) {
            // Default fallback - provide appropriate default
            Debug.trap("Invalid args type for completely_blocked")
          };
        };
      }
    ));

    // get_call_counts validation
    inspector.inspect(inspector.createMethodGuardInfo<Text>(
      "get_call_counts",
      false, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): Text {
        switch (args) {
          case (#Get_call_counts(params)) {
            // No parameters - add your return logic here
            Debug.trap("Implement return logic for get_call_counts")
          };
          case (_) {
            // Default fallback - provide appropriate default
            Debug.trap("Invalid args type for get_call_counts")
          };
        };
      }
    ));

    // get_info validation
    inspector.inspect(inspector.createMethodGuardInfo<Text>(
      "get_info",
      true, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): Text {
        switch (args) {
          case (#Get_info(params)) {
            // No parameters - add your return logic here
            Debug.trap("Implement return logic for get_info")
          };
          case (_) {
            // Default fallback - provide appropriate default
            Debug.trap("Invalid args type for get_info")
          };
        };
      }
    ));

    // guarded_method validation
    inspector.inspect(inspector.createMethodGuardInfo<Result>(
      "guarded_method",
      false, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): Result {
        switch (args) {
          case (#Guarded_method(params)) {
            // Extract single parameter: data
            let param = params;
            // Add your processing logic here
            Debug.trap("Implement processing logic for guarded_method")
          };
          case (_) {
            // Default fallback - provide appropriate default
            Debug.trap("Invalid args type for guarded_method")
          };
        };
      }
    ));

    // health_check validation
    inspector.inspect(inspector.createMethodGuardInfo<Text>(
      "health_check",
      true, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): Text {
        switch (args) {
          case (#Health_check(params)) {
            // No parameters - add your return logic here
            Debug.trap("Implement return logic for health_check")
          };
          case (_) {
            // Default fallback - provide appropriate default
            Debug.trap("Invalid args type for health_check")
          };
        };
      }
    ));

    // internal_only validation
    inspector.inspect(inspector.createMethodGuardInfo<Text>(
      "internal_only",
      false, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): Text {
        switch (args) {
          case (#Internal_only(params)) {
            // No parameters - add your return logic here
            Debug.trap("Implement return logic for internal_only")
          };
          case (_) {
            // Default fallback - provide appropriate default
            Debug.trap("Invalid args type for internal_only")
          };
        };
      }
    ));

    // reset_call_counts validation
    inspector.inspect(inspector.createMethodGuardInfo<()>(
      "reset_call_counts",
      false, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): () {
        switch (args) {
          case (#Reset_call_counts(params)) {
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

    // send_message validation
    inspector.inspect(inspector.createMethodGuardInfo<Text>(
      "send_message",
      false, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): Text {
        switch (args) {
          case (#Send_message(params)) {
            // Extract single parameter: message
            let param = params;
            // Add your processing logic here
            Debug.trap("Implement processing logic for send_message")
          };
          case (_) {
            // Default fallback - provide appropriate default
            Debug.trap("Invalid args type for send_message")
          };
        };
      }
    ));

    // unrestricted validation
    inspector.inspect(inspector.createMethodGuardInfo<Text>(
      "unrestricted",
      false, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): Text {
        switch (args) {
          case (#Unrestricted(params)) {
            // No parameters - add your return logic here
            Debug.trap("Implement return logic for unrestricted")
          };
          case (_) {
            // Default fallback - provide appropriate default
            Debug.trap("Invalid args type for unrestricted")
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
      #completely_blocked : ();
      #get_call_counts : ();
      #get_info : ();
      #guarded_method : (Text);
      #health_check : ();
      #internal_only : ();
      #reset_call_counts : ();
      #send_message : (Text);
      #unrestricted : ();
    }
  }) : Bool {
    let (methodName, isQuery, msgArgs) = switch (msg) {
      case (#completely_blocked _) ("completely_blocked", false, #Completely_blocked(()));
      case (#get_call_counts _) ("get_call_counts", false, #Get_call_counts(()));
      case (#get_info _) ("get_info", true, #Get_info(()));
      case (#guarded_method params) ("guarded_method", false, #Guarded_method(params));
      case (#health_check _) ("health_check", true, #Health_check(()));
      case (#internal_only _) ("internal_only", false, #Internal_only(()));
      case (#reset_call_counts _) ("reset_call_counts", false, #Reset_call_counts(()));
      case (#send_message params) ("send_message", false, #Send_message(params));
      case (#unrestricted _) ("unrestricted", false, #Unrestricted(()));
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