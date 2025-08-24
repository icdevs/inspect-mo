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
    #Get_data: ();
    #Set_data: Text;
    #Update_counter: Nat;
    #None: ();
  };

  /// Accessor functions for ErasedValidator pattern
  public func getSet_dataParam0(args: Args): Text {
    switch (args) {
      case (#Set_data(value)) value;
      case (_) { /* default value for Text */ };
    };
  };

  public func getUpdate_counterParam0(args: Args): Nat {
    switch (args) {
      case (#Update_counter(value)) value;
      case (_) { /* default value for Nat */ };
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
    // get_data validation
    inspector.inspect(inspector.createMethodGuardInfo<Text>(
      "get_data",
      true, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): Text {
        switch (args) {
          case (#Get_data(params)) {
            // Extract and return typed parameters
            // Add your parameter processing here
          };
          case (_) {
            // Default fallback
          };
        };
      }
    ));

    // set_data validation
    inspector.inspect(inspector.createMethodGuardInfo<Text>(
      "set_data",
      false, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): Text {
        switch (args) {
          case (#Set_data(params)) {
            // Extract and return typed parameters
            // Add your parameter processing here
          };
          case (_) {
            // Default fallback
          };
        };
      }
    ));

    // update_counter validation
    inspector.inspect(inspector.createMethodGuardInfo<Nat>(
      "update_counter",
      false, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): Nat {
        switch (args) {
          case (#Update_counter(params)) {
            // Extract and return typed parameters
            // Add your parameter processing here
          };
          case (_) {
            // Default fallback
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
      #get_data : ();
      #set_data : (Text);
      #update_counter : (Nat);
    }
  }) : Bool {
    let (methodName, isQuery) = switch (msg) {
      case (#get_data _) ("get_data", true);
      case (#set_data _) ("set_data", false);
      case (#update_counter _) ("update_counter", false);
      case (_) ("unknown_method", false);
    };
    
    let inspectArgs : InspectMo.InspectArgs<Args> = {
      methodName = methodName;
      caller = caller;
      arg = arg;
      msg = #None(()); // Basic implementation
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