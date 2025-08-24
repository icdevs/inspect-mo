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
    #Batch_create_users: [UserProfile];
    #ClearInspectLogs: ();
    #Clear_all_data: ();
    #Create_profile: UserProfile;
    #Create_transaction: (TransactionRequest, ?Text);
    #Execute_bulk_operation: BulkOperation;
    #GetInspectLogs: ();
    #Get_call_logs: ();
    #Get_profile: Nat;
    #Get_stats: ();
    #Health_check: ();
    #Search_users: (SearchFilter, [Nat]);
    #Simple_numbers: (Nat, Int);
    #Simple_text: Text;
    #Update_profile: (Nat, UserProfile);
    #Upload_document: DocumentUpload;
    #None: ();
  };

  /// Accessor functions for ErasedValidator pattern
  public func getBatch_create_usersUserList(args: Args): [UserProfile] {
    switch (args) {
      case (#Batch_create_users(value)) value;
      case (_) [];
    };
  };

  public func getCreate_profileProfile(args: Args): UserProfile {
    switch (args) {
      case (#Create_profile(value)) value;
      case (_) Debug.trap("No default value for type: UserProfile");
    };
  };

  public func getCreate_transactionReq(args: Args): TransactionRequest {
    switch (args) {
      case (#Create_transaction(params)) params.0;
      case (_) Debug.trap("No default value for type: TransactionRequest");
    };
  };

  public func getCreate_transactionNotes(args: Args): ?Text {
    switch (args) {
      case (#Create_transaction(params)) params.1;
      case (_) null;
    };
  };

  public func getExecute_bulk_operationOp(args: Args): BulkOperation {
    switch (args) {
      case (#Execute_bulk_operation(value)) value;
      case (_) Debug.trap("No default value for type: BulkOperation");
    };
  };

  public func getGet_profileId(args: Args): Nat {
    switch (args) {
      case (#Get_profile(value)) value;
      case (_) 0;
    };
  };

  public func getSearch_usersFilters(args: Args): SearchFilter {
    switch (args) {
      case (#Search_users(params)) params.0;
      case (_) Debug.trap("No default value for type: SearchFilter");
    };
  };

  public func getSearch_usersUserIds(args: Args): [Nat] {
    switch (args) {
      case (#Search_users(params)) params.1;
      case (_) [];
    };
  };

  public func getSimple_numbersCount(args: Args): Nat {
    switch (args) {
      case (#Simple_numbers(params)) params.0;
      case (_) 0;
    };
  };

  public func getSimple_numbersBalance(args: Args): Int {
    switch (args) {
      case (#Simple_numbers(params)) params.1;
      case (_) 0;
    };
  };

  public func getSimple_textMessage(args: Args): Text {
    switch (args) {
      case (#Simple_text(value)) value;
      case (_) "";
    };
  };

  public func getUpdate_profileId(args: Args): Nat {
    switch (args) {
      case (#Update_profile(params)) params.0;
      case (_) 0;
    };
  };

  public func getUpdate_profileUpdates(args: Args): UserProfile {
    switch (args) {
      case (#Update_profile(params)) params.1;
      case (_) Debug.trap("No default value for type: UserProfile");
    };
  };

  public func getUpload_documentDoc(args: Args): DocumentUpload {
    switch (args) {
      case (#Upload_document(value)) value;
      case (_) Debug.trap("No default value for type: DocumentUpload");
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
    // batch_create_users validation
    inspector.inspect(inspector.createMethodGuardInfo<Result_3>(
      "batch_create_users",
      false, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): Result_3 {
        switch (args) {
          case (#Batch_create_users(params)) {
            // Extract single parameter: userList
            let param = params;
            // Add your processing logic here
            Debug.trap("Implement processing logic for batch_create_users")
          };
          case (_) {
            // Default fallback - provide appropriate default
            Debug.trap("Invalid args type for batch_create_users")
          };
        };
      }
    ));

    // clearInspectLogs validation
    inspector.inspect(inspector.createMethodGuardInfo<()>(
      "clearInspectLogs",
      false, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): () {
        switch (args) {
          case (#ClearInspectLogs(params)) {
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

    // clear_all_data validation
    inspector.inspect(inspector.createMethodGuardInfo<()>(
      "clear_all_data",
      false, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): () {
        switch (args) {
          case (#Clear_all_data(params)) {
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

    // create_profile validation
    inspector.inspect(inspector.createMethodGuardInfo<Result_2>(
      "create_profile",
      false, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): Result_2 {
        switch (args) {
          case (#Create_profile(params)) {
            // Extract single parameter: profile
            let param = params;
            // Add your processing logic here
            Debug.trap("Implement processing logic for create_profile")
          };
          case (_) {
            // Default fallback - provide appropriate default
            Debug.trap("Invalid args type for create_profile")
          };
        };
      }
    ));

    // create_transaction validation
    inspector.inspect(inspector.createMethodGuardInfo<Result>(
      "create_transaction",
      false, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): Result {
        switch (args) {
          case (#Create_transaction(params)) {
            // Extract multiple parameters
            let req = params.0;
            let notes = params.1;
            // Add your processing logic here
            Debug.trap("Implement processing logic for create_transaction")
          };
          case (_) {
            // Default fallback - provide appropriate default
            Debug.trap("Invalid args type for create_transaction")
          };
        };
      }
    ));

    // execute_bulk_operation validation
    inspector.inspect(inspector.createMethodGuardInfo<Result>(
      "execute_bulk_operation",
      false, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): Result {
        switch (args) {
          case (#Execute_bulk_operation(params)) {
            // Extract single parameter: op
            let param = params;
            // Add your processing logic here
            Debug.trap("Implement processing logic for execute_bulk_operation")
          };
          case (_) {
            // Default fallback - provide appropriate default
            Debug.trap("Invalid args type for execute_bulk_operation")
          };
        };
      }
    ));

    // getInspectLogs validation
    inspector.inspect(inspector.createMethodGuardInfo<[Text]>(
      "getInspectLogs",
      true, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): [Text] {
        switch (args) {
          case (#GetInspectLogs(params)) {
            // No parameters - add your return logic here
            Debug.trap("Implement return logic for getInspectLogs")
          };
          case (_) {
            // Default fallback - provide appropriate default
            Debug.trap("Invalid args type for getInspectLogs")
          };
        };
      }
    ));

    // get_call_logs validation
    inspector.inspect(inspector.createMethodGuardInfo<Text>(
      "get_call_logs",
      false, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): Text {
        switch (args) {
          case (#Get_call_logs(params)) {
            // No parameters - add your return logic here
            Debug.trap("Implement return logic for get_call_logs")
          };
          case (_) {
            // Default fallback - provide appropriate default
            Debug.trap("Invalid args type for get_call_logs")
          };
        };
      }
    ));

    // get_profile validation
    inspector.inspect(inspector.createMethodGuardInfo<?UserProfile>(
      "get_profile",
      true, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): ?UserProfile {
        switch (args) {
          case (#Get_profile(params)) {
            // Extract single parameter: id
            let param = params;
            // Add your processing logic here
            Debug.trap("Implement processing logic for get_profile")
          };
          case (_) {
            // Default fallback - provide appropriate default
            Debug.trap("Invalid args type for get_profile")
          };
        };
      }
    ));

    // get_stats validation
    inspector.inspect(inspector.createMethodGuardInfo<Text>(
      "get_stats",
      false, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): Text {
        switch (args) {
          case (#Get_stats(params)) {
            // No parameters - add your return logic here
            Debug.trap("Implement return logic for get_stats")
          };
          case (_) {
            // Default fallback - provide appropriate default
            Debug.trap("Invalid args type for get_stats")
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

    // search_users validation
    inspector.inspect(inspector.createMethodGuardInfo<[UserProfile]>(
      "search_users",
      false, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): [UserProfile] {
        switch (args) {
          case (#Search_users(params)) {
            // Extract multiple parameters
            let filters = params.0;
            let userIds = params.1;
            // Add your processing logic here
            Debug.trap("Implement processing logic for search_users")
          };
          case (_) {
            // Default fallback - provide appropriate default
            Debug.trap("Invalid args type for search_users")
          };
        };
      }
    ));

    // simple_numbers validation
    inspector.inspect(inspector.createMethodGuardInfo<Text>(
      "simple_numbers",
      false, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): Text {
        switch (args) {
          case (#Simple_numbers(params)) {
            // Extract multiple parameters
            let count = params.0;
            let balance = params.1;
            // Add your processing logic here
            Debug.trap("Implement processing logic for simple_numbers")
          };
          case (_) {
            // Default fallback - provide appropriate default
            Debug.trap("Invalid args type for simple_numbers")
          };
        };
      }
    ));

    // simple_text validation
    inspector.inspect(inspector.createMethodGuardInfo<Text>(
      "simple_text",
      false, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): Text {
        switch (args) {
          case (#Simple_text(params)) {
            // Extract single parameter: message
            let param = params;
            // Add your processing logic here
            Debug.trap("Implement processing logic for simple_text")
          };
          case (_) {
            // Default fallback - provide appropriate default
            Debug.trap("Invalid args type for simple_text")
          };
        };
      }
    ));

    // update_profile validation
    inspector.inspect(inspector.createMethodGuardInfo<Result_1>(
      "update_profile",
      false, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): Result_1 {
        switch (args) {
          case (#Update_profile(params)) {
            // Extract multiple parameters
            let id = params.0;
            let updates = params.1;
            // Add your processing logic here
            Debug.trap("Implement processing logic for update_profile")
          };
          case (_) {
            // Default fallback - provide appropriate default
            Debug.trap("Invalid args type for update_profile")
          };
        };
      }
    ));

    // upload_document validation
    inspector.inspect(inspector.createMethodGuardInfo<Result>(
      "upload_document",
      false, // isQuery
      [
        #requireAuth // Add your validation rules here
      ],
      func(args: Args): Result {
        switch (args) {
          case (#Upload_document(params)) {
            // Extract single parameter: doc
            let param = params;
            // Add your processing logic here
            Debug.trap("Implement processing logic for upload_document")
          };
          case (_) {
            // Default fallback - provide appropriate default
            Debug.trap("Invalid args type for upload_document")
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
      #batch_create_users : ([UserProfile]);
      #clearInspectLogs : ();
      #clear_all_data : ();
      #create_profile : (UserProfile);
      #create_transaction : (TransactionRequest, ?Text);
      #execute_bulk_operation : (BulkOperation);
      #getInspectLogs : ();
      #get_call_logs : ();
      #get_profile : (Nat);
      #get_stats : ();
      #health_check : ();
      #search_users : (SearchFilter, [Nat]);
      #simple_numbers : (Nat, Int);
      #simple_text : (Text);
      #update_profile : (Nat, UserProfile);
      #upload_document : (DocumentUpload);
    }
  }) : Bool {
    let (methodName, isQuery, msgArgs) = switch (msg) {
      case (#batch_create_users params) ("batch_create_users", false, #Batch_create_users(params));
      case (#clearInspectLogs _) ("clearInspectLogs", false, #ClearInspectLogs(()));
      case (#clear_all_data _) ("clear_all_data", false, #Clear_all_data(()));
      case (#create_profile params) ("create_profile", false, #Create_profile(params));
      case (#create_transaction params) ("create_transaction", false, #Create_transaction(params));
      case (#execute_bulk_operation params) ("execute_bulk_operation", false, #Execute_bulk_operation(params));
      case (#getInspectLogs _) ("getInspectLogs", true, #GetInspectLogs(()));
      case (#get_call_logs _) ("get_call_logs", false, #Get_call_logs(()));
      case (#get_profile params) ("get_profile", true, #Get_profile(params));
      case (#get_stats _) ("get_stats", false, #Get_stats(()));
      case (#health_check _) ("health_check", true, #Health_check(()));
      case (#search_users params) ("search_users", false, #Search_users(params));
      case (#simple_numbers params) ("simple_numbers", false, #Simple_numbers(params));
      case (#simple_text params) ("simple_text", false, #Simple_text(params));
      case (#update_profile params) ("update_profile", false, #Update_profile(params));
      case (#upload_document params) ("upload_document", false, #Upload_document(params));
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