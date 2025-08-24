import InspectMo "../src/core/inspector";
import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Text "mo:base/Text";

persistent actor ComplexTestWithInspection {
  
  // Import the complex types (normally these would be defined in your canister)
  // For testing, we'll define simplified versions that match our generated code
  type UserProfile = {
    id: Nat;
    name: Text;
    email: Text;
    tags: [Text];
    metadata: [{ key: Text; value: Text }];
    settings: { notifications: Bool; theme: Text };
    preferences: {
      language: { #en; #es; #fr };
      region: ?[Text];
    };
  };

  type TransactionRequest = {
    from: Text;
    to: Text;
    amount: Nat;
    currency: Text;
    description: ?[Text];
  };

  type DocumentUpload = {
    filename: Text;
    content: [Nat8];
    contentType: Text;
    size: Nat;
    metadata: [{ key: Text; value: Text }];
  };

  type BulkOperation = {
    operationType: { #batchUpdate; #batchDelete; #batchCreate };
    targets: [Text];
    data: [{ key: Text; value: Text }];
    options: {
      dryRun: Bool;
      validateOnly: Bool;
      rollbackOnError: Bool;
    };
  };

  type SearchFilter = {
    searchQuery: Text;
    tags: [Text];
    dateRange: ?{ start: Text; end: Text };
    sortBy: { #name; #date; #relevance };
  };

  // Args union type for ErasedValidator pattern
  type Args = {
    #CreateProfile: UserProfile;
    #CreateTransaction: (TransactionRequest, ?[Text]);
    #BatchCreateUsers: [UserProfile];
    #SimpleNumbers: (Nat, Int);
    #SimpleText: Text;
    #UploadDocument: DocumentUpload;
    #ExecuteBulkOperation: BulkOperation;
    #UpdateProfile: (Nat, UserProfile);
    #SearchUsers: (SearchFilter, [Nat]);
    #ClearAllData: ();
    #GetCallLogs: ();
    #GetStats: ();
    #None: ();
  };
  
  // Storage for testing
  private stable var profiles : [UserProfile] = [];
  private stable var callCount : Nat = 0;

  // Accessor functions for ErasedValidator pattern
  transient func getProfileName(args: Args): Text {
    switch (args) {
      case (#CreateProfile(profile)) profile.name;
      case (#UpdateProfile(_, profile)) profile.name;
      case (_) "";
    };
  };

  transient func getProfileEmail(args: Args): Text {
    switch (args) {
      case (#CreateProfile(profile)) profile.email;
      case (#UpdateProfile(_, profile)) profile.email;
      case (_) "";
    };
  };

  transient func getDocumentContent(args: Args): Blob {
    switch (args) {
      case (#UploadDocument(doc)) Text.encodeUtf8(debug_show(doc.content));
      case (_) Text.encodeUtf8("");
    };
  };

  transient func getDocumentFilename(args: Args): Text {
    switch (args) {
      case (#UploadDocument(doc)) doc.filename;
      case (_) "";
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

  // Setup validation rules using the ErasedValidator pattern
  do {
    // Profile creation validation
    validatorInspector.inspect(validatorInspector.createMethodGuardInfo<UserProfile>(
      "create_profile",
      false, // isQuery
      [
        #requireAuth
      ],
      func(args: Args): UserProfile {
        switch (args) {
          case (#CreateProfile(profile)) profile;
          case (_) {
            {
              id = 0;
              name = "";
              email = "";
              tags = [];
              metadata = [];
              settings = { notifications = false; theme = "" };
              preferences = { language = #en; region = null };
            }
          };
        };
      }
    ));

    // Document upload validation
    validatorInspector.inspect(validatorInspector.createMethodGuardInfo<DocumentUpload>(
      "upload_document",
      false, // isQuery
      [
        #requireAuth
      ],
      func(args: Args): DocumentUpload {
        switch (args) {
          case (#UploadDocument(doc)) doc;
          case (_) {
            {
              filename = "";
              content = [];
              contentType = "";
              size = 0;
              metadata = [];
            }
          };
        };
      }
    ));
  };

  // System inspect function - uses ErasedValidator pattern
  system func inspect({
    arg : Blob;
    caller : Principal;
    msg :
      {
        #batch_create_users : () -> (userList : [UserProfile]);
        #clear_all_data : () -> ();
        #create_profile : () -> (profile : UserProfile);
        #create_transaction : () -> (req : TransactionRequest, notes : ?[Text]);
        #execute_bulk_operation : () -> (op : BulkOperation);
        #get_call_logs : () -> ();
        #get_profile : () -> (id : Nat);
        #get_stats : () -> ();
        #health_check : () -> ();
        #search_users : () -> (filters : SearchFilter, userIds : [Nat]);
        #simple_numbers : () -> (count : Nat, balance : Int);
        #simple_text : () -> (message : Text);
        #update_profile : () -> (id : Nat, updates : UserProfile);
        #upload_document : () -> (doc : DocumentUpload)
      }
  }) : Bool {
    // Extract method name and determine if it's a query
    let (methodName, isQuery) = switch (msg) {
      case (#create_profile _) ("create_profile", false);
      case (#create_transaction _) ("create_transaction", false);
      case (#batch_create_users _) ("batch_create_users", false);
      case (#simple_text _) ("simple_text", false);
      case (#simple_numbers _) ("simple_numbers", false);
      case (#clear_all_data _) ("clear_all_data", false);
      case (#upload_document _) ("upload_document", false);
      case (#execute_bulk_operation _) ("execute_bulk_operation", false);
      case (#update_profile _) ("update_profile", false);
      case (#search_users _) ("search_users", false);
      case (#get_call_logs _) ("get_call_logs", false);
      case (#get_stats _) ("get_stats", false);
      case (#get_profile _) ("get_profile", true); // Query method
      case (#health_check _) ("health_check", true); // Query method
      case (_) ("unknown_method", false);
    };
    
    callCount += 1;
    Debug.print("🔍 INSPECT: Method '" # methodName # "' called by " # Principal.toText(caller) # " (call #" # debug_show(callCount) # ")");
    
    // Create inspect arguments for ErasedValidator pattern
    let inspectArgs : InspectMo.InspectArgs<Args> = {
      methodName = methodName;
      caller = caller;
      arg = arg;
      msg = #None(()); // For basic implementation, could be enhanced with parsing
      isQuery = isQuery;
      isInspect = true;
      cycles = ?0;
      deadline = null;
    };
    
    // Use inspector to validate the call
    let result = validatorInspector.inspectCheck(inspectArgs);
    Debug.print("✅ INSPECT: " # methodName # " validation result: " # debug_show(result));
    
    // Return validation result
    switch (result) {
      case (#ok) { 
        Debug.print("✅ Call approved");
        true 
      };
      case (#err(reason)) { 
        Debug.print("❌ Call rejected: " # reason);
        false 
      };
    }
  };

  // Canister methods (same as complex_test_canister for compatibility)
  
  public func create_profile(profile: UserProfile) : async Result.Result<Nat, Text> {
    profiles := Array.append<UserProfile>(profiles, [profile]);
    #ok(profiles.size() - 1)
  };

  public func create_transaction(req: TransactionRequest, notes: ?[Text]) : async Result.Result<Text, Text> {
    let txId = "tx_" # debug_show(callCount);
    #ok(txId)
  };

  public func batch_create_users(userList: [UserProfile]) : async Result.Result<Nat, Text> {
    profiles := Array.append<UserProfile>(profiles, userList);
    #ok(userList.size())
  };

  public func simple_numbers(count: Nat, balance: Int) : async Result.Result<Int, Text> {
    #ok(balance + count)
  };

  public func simple_text(message: Text) : async Result.Result<Nat, Text> {
    #ok(message.size())
  };

  public func upload_document(doc: DocumentUpload) : async Result.Result<Text, Text> {
    let docId = "doc_" # debug_show(callCount);
    #ok(docId)
  };

  public func execute_bulk_operation(op: BulkOperation) : async Result.Result<Nat, Text> {
    #ok(op.targets.size())
  };

  public func update_profile(id: Nat, updates: UserProfile) : async Result.Result<(), Text> {
    if (id < profiles.size()) {
      // Would update profile in real implementation
      #ok(())
    } else {
      #err("Profile not found")
    }
  };

  public func search_users(filters: SearchFilter, userIds: [Nat]) : async Result.Result<[UserProfile], Text> {
    // Simple search implementation for testing
    let filtered = if (userIds.size() > 0) {
      // Filter by specific IDs
      []
    } else {
      // Search by filters
      []
    };
    #ok(filtered)
  };

  public func clear_all_data() : async Result.Result<(), Text> {
    profiles := [];
    callCount := 0;
    #ok(())
  };

  public func get_call_logs() : async Result.Result<[{ method: Text; caller: Text; timestamp: Nat }], Text> {
    #ok([])
  };

  public func get_stats() : async Result.Result<{ callCount: Nat; profileCount: Nat }, Text> {
    #ok({ callCount = callCount; profileCount = profiles.size() })
  };

  // Query methods
  public query func get_profile(id: Nat) : async Result.Result<UserProfile, Text> {
    if (id < profiles.size()) {
      #ok(profiles[id])
    } else {
      #err("Profile not found")
    }
  };

  public query func health_check() : async { status: Text; timestamp: Nat } {
    { status = "healthy"; timestamp = 0 }
  };
}
