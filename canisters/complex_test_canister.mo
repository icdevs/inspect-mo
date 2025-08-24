/// Complex Test canister for advanced InspectMo testing
/// This canister has complex parameter types to test code generation thoroughly
import InspectMo "../src/core/inspector";
import Principal "mo:core/Principal";
import Debug "mo:core/Debug";
import Result "mo:core/Result";
import Array "mo:core/Array";
import Time "mo:core/Time";
import Text "mo:core/Text";

persistent actor ComplexTestCanister {
  
  // Args union for ErasedValidator pattern with all complex types
  type Args = {
    #SimpleText: Text;
    #SimpleNumbers: (Nat, Int);
    #TupleParams: (Text, Nat, Bool);
    #NestedTuples: ((Text, Nat), (Bool, Text));
    #CreateProfile: UserProfile;
    #UpdateProfile: (Nat, UserProfile);
    #BatchCreateUsers: [UserProfile];
    #SearchUsers: (SearchFilter, [Nat]);
    #UpdateMultipleTags: [(Nat, [Text])];
    #ExecuteBulkOperation: BulkOperation;
    #UploadDocument: DocumentUpload;
    #ProcessBinaryData: (Blob, (Text, Nat));
    #CreateTransaction: (TransactionRequest, ?Text);
    #UpdatePreferences: (Nat, ?Text, ?Bool);
    #ComplexOperation: (UserProfile, [BulkOperation], {batchSize: Nat; timeout: ?Nat; retryOnFailure: Bool}, [(Text, Text)]);
    #GetProfile: Nat;
    #None: ();
  };
  
  // Complex types for testing
  public type UserProfile = {
    id: Nat;
    name: Text;
    email: Text;
    age: ?Nat;
    preferences: {
      theme: Text;
      notifications: Bool;
    };
    tags: [Text];
  };

  public type TransactionRequest = {
    amount: Nat;
    currency: Text;
    recipient: Principal;
    memo: ?Text;
    metadata: [(Text, Text)];
  };

  public type DocumentUpload = {
    filename: Text;
    content: Blob;
    mimetype: Text;
    tags: [Text];
    permissions: {
      read: [Principal];
      write: [Principal];
    };
  };

  public type SearchFilter = {
    keywords: [Text];
    categories: [Text];
    dateRange: ?(Int, Int);
    priceRange: ?(Nat, Nat);
    sortBy: Text;
    ascending: Bool;
  };

  public type BulkOperation = {
    operation: {
      #create: UserProfile;
      #update: (Nat, UserProfile);
      #delete: Nat;
      #archive: [Nat];
    };
    batchId: Text;
    timestamp: Int;
  };

  // Storage
  private var profiles : [(Nat, UserProfile)] = [];
  private var documents : [(Text, DocumentUpload)] = [];
  private var transactions : [TransactionRequest] = [];
  private var callLogs : [(Text, Int)] = [];

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

  // Accessor functions for complex types
  transient func getSimpleText(args: Args): Text {
    switch (args) {
      case (#SimpleText(text)) text;
      case (_) "";
    }
  };

  transient func getProfileName(args: Args): Text {
    switch (args) {
      case (#CreateProfile(profile)) profile.name;
      case (#UpdateProfile(_, profile)) profile.name;
      case (#ComplexOperation(profile, _, _, _)) profile.name;
      case (_) "";
    }
  };

  transient func getProfileEmail(args: Args): Text {
    switch (args) {
      case (#CreateProfile(profile)) profile.email;
      case (#UpdateProfile(_, profile)) profile.email;
      case (#ComplexOperation(profile, _, _, _)) profile.email;
      case (_) "";
    }
  };

  transient func getDocumentContent(args: Args): Blob {
    switch (args) {
      case (#UploadDocument(doc)) doc.content;
      case (#ProcessBinaryData(blob, _)) blob;
      case (_) Text.encodeUtf8("");
    }
  };

  transient func getDocumentFilename(args: Args): Text {
    switch (args) {
      case (#UploadDocument(doc)) doc.filename;
      case (_) "";
    }
  };

  // Helper to log calls
  private func logCall(methodName: Text) : () {
    callLogs := Array.concat<(Text,Int)>(callLogs,[(methodName, Time.now())]);
  };

  // Configure key validation rules for complex methods
  transient let _ = do {
        // Profile creation validation (using simpler rules for demonstration)
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
              age = null;
              preferences = { theme = ""; notifications = false };
              tags = [];
            }
          };
        };
      }
    ));

    // Document upload validation (using simpler rules for demonstration)
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
              content = Text.encodeUtf8("");
              mimetype = "";
              tags = [];
              permissions = { read = []; write = [] }
            }
          };
        };
      }
    ));
  };

  // ===== SIMPLE PARAMETER METHODS =====
  
  public query func health_check() : async Text {
    "Complex canister is healthy"
  };

  public func simple_text(message: Text) : async Text {
    logCall("simple_text");
    "Received: " # message
  };

  public func simple_numbers(count: Nat, balance: Int) : async Text {
    logCall("simple_numbers");
    "Count: " # debug_show(count) # ", Balance: " # debug_show(balance)
  };

  // ===== TUPLE PARAMETER METHODS =====
  
  public func tuple_params(userInfo: (Text, Nat, Bool)) : async Text {
    logCall("tuple_params");
    let (name, age, active) = userInfo;
    "User: " # name # ", Age: " # debug_show(age) # ", Active: " # debug_show(active)
  };

  public func nested_tuples(data: ((Text, Nat), (Bool, Text))) : async Text {
    logCall("nested_tuples");
    let ((name, id), (verified, status)) = data;
    "Nested data processed"
  };

  // ===== RECORD PARAMETER METHODS =====
  
  public func create_profile(profile: UserProfile) : async Result.Result<Nat, Text> {
    logCall("create_profile");
    
    // Validate profile
    if (profile.name.size() == 0) {
      return #err("Name cannot be empty");
    };
    if (profile.email.size() < 5) {
      return #err("Invalid email");
    };
    
    profiles := Array.concat<(Nat, UserProfile)>(profiles,[(profile.id, profile)]);
    #ok(profile.id)
  };

  public func update_profile(id: Nat, updates: UserProfile) : async Result.Result<(), Text> {
    logCall("update_profile");
    // Implementation would update the profile
    #ok(())
  };

  // ===== ARRAY/LIST PARAMETER METHODS =====
  
  public func batch_create_users(userList: [UserProfile]) : async Result.Result<[Nat], Text> {
    logCall("batch_create_users");
    if (userList.size() == 0) {
      return #err("Empty user list");
    };
    if (userList.size() > 100) {
      return #err("Too many users in batch");
    };
    
    let ids = Array.map<UserProfile, Nat>(userList, func(profile) { profile.id });
    #ok(ids)
  };

  public func search_users(filters: SearchFilter, userIds: [Nat]) : async [UserProfile] {
    logCall("search_users");
    // Implementation would search users
    []
  };

  public func update_multiple_tags(updates: [(Nat, [Text])]) : async Result.Result<(), Text> {
    logCall("update_multiple_tags");
    // Validate bulk operation
    if (updates.size() > 50) {
      return #err("Too many updates in single call");
    };
    #ok(())
  };

  // ===== VARIANT PARAMETER METHODS =====
  
  public func execute_bulk_operation(op: BulkOperation) : async Result.Result<Text, Text> {
    logCall("execute_bulk_operation");
    
    switch (op.operation) {
      case (#create(profile)) {
        if (profile.name.size() == 0) {
          #err("Cannot create user with empty name")
        } else {
          #ok("User created: " # profile.name)
        }
      };
      case (#update(id, profile)) {
        #ok("User " # debug_show(id) # " updated")
      };
      case (#delete(id)) {
        #ok("User " # debug_show(id) # " deleted")
      };
      case (#archive(ids)) {
        if (ids.size() > 20) {
          #err("Cannot archive more than 20 users at once")
        } else {
          #ok(debug_show(ids.size()) # " users archived")
        }
      };
    }
  };

  // ===== BLOB/BINARY DATA METHODS =====
  
  public func upload_document(doc: DocumentUpload) : async Result.Result<Text, Text> {
    logCall("upload_document");
    
    if (doc.content.size() == 0) {
      return #err("Empty document");
    };
    if (doc.content.size() > 10_000_000) { // 10MB limit
      return #err("Document too large");
    };
    if (doc.filename.size() == 0) {
      return #err("Filename required");
    };
    
    documents := Array.concat<(Text, DocumentUpload)>(documents ,[(doc.filename, doc)]);
    #ok("Document uploaded: " # doc.filename)
  };

  public func process_binary_data(data: Blob, metadata: (Text, Nat)) : async Result.Result<Text, Text> {
    logCall("process_binary_data");
    let (description, version) = metadata;
    
    if (data.size() == 0) {
      #err("No data provided")
    } else if (data.size() > 1_000_000) {
      #err("Data too large")
    } else {
      #ok("Processed " # debug_show(data.size()) # " bytes of " # description)
    }
  };

  // ===== OPTIONAL PARAMETER METHODS =====
  
  public func create_transaction(req: TransactionRequest, notes: ?Text) : async Result.Result<Text, Text> {
    logCall("create_transaction");
    
    if (req.amount == 0) {
      return #err("Amount must be greater than 0");
    };
    
    transactions := Array.concat<TransactionRequest>(transactions ,[req]);
    
    let noteText = switch (notes) {
      case (?note) { " with notes: " # note };
      case null { "" };
    };
    
    #ok("Transaction created for " # debug_show(req.amount) # " " # req.currency # noteText)
  };

  public func update_preferences(userId: Nat, theme: ?Text, notifications: ?Bool) : async Result.Result<(), Text> {
    logCall("update_preferences");
    // Implementation would update user preferences
    #ok(())
  };

  // ===== COMPLEX MIXED PARAMETER METHODS =====
  
  public func complex_operation(
    user: UserProfile, 
    actions: [BulkOperation],
    settings: {
      batchSize: Nat;
      timeout: ?Nat;
      retryOnFailure: Bool;
    },
    metadata: [(Text, Text)]
  ) : async Result.Result<Text, Text> {
    logCall("complex_operation");
    
    if (actions.size() == 0) {
      return #err("No actions specified");
    };
    if (actions.size() > settings.batchSize) {
      return #err("Too many actions for batch size");
    };
    if (user.name.size() == 0) {
      return #err("Invalid user");
    };
    
    #ok("Complex operation completed for " # user.name # " with " # debug_show(actions.size()) # " actions")
  };

  // ===== UTILITY/QUERY METHODS =====
  
  public query func get_profile(id: Nat) : async ?UserProfile {
    switch (Array.find<(Nat, UserProfile)>(profiles, func((profileId, _)) { profileId == id })) {
      case (?(_, profile)) { ?profile };
      case null { null };
    }
  };

  public query func get_call_logs() : async [(Text, Int)] {
    callLogs
  };

  public query func get_stats() : async {
    profileCount: Nat;
    documentCount: Nat;
    transactionCount: Nat;
    callCount: Nat;
  } {
    {
      profileCount = profiles.size();
      documentCount = documents.size();
      transactionCount = transactions.size();
      callCount = callLogs.size();
    }
  };

  public func clear_all_data() : async () {
    profiles := [];
    documents := [];
    transactions := [];
    callLogs := [];
  };

  // ===== SYSTEM INSPECT (demonstrating InspectMo integration) =====
  
  private var inspectLogs : [Text] = [];
  
  system func inspect({
    arg : Blob;
    caller : Principal;
    msg :
      {
        #batch_create_users : () -> (userList : [UserProfile]);
        #clearInspectLogs : () -> ();
        #clear_all_data : () -> ();
        #complex_operation :
          () ->
            (user : UserProfile, actions : [BulkOperation],
             settings : {
                          batchSize : Nat;
                          retryOnFailure : Bool;
                          timeout : ?Nat
                        },
             metadata : [(Text, Text)]);
        #create_profile : () -> (profile : UserProfile);
        #create_transaction : () -> (req : TransactionRequest, notes : ?Text);
        #execute_bulk_operation : () -> (op : BulkOperation);
        #getInspectLogs : () -> ();
        #get_call_logs : () -> ();
        #get_profile : () -> (id : Nat);
        #get_stats : () -> ();
        #health_check : () -> ();
        #nested_tuples : () -> (data : ((Text, Nat), (Bool, Text)));
        #process_binary_data : () -> (data : Blob, metadata : (Text, Nat));
        #search_users : () -> (filters : SearchFilter, userIds : [Nat]);
        #simple_numbers : () -> (count : Nat, balance : Int);
        #simple_text : () -> (message : Text);
        #tuple_params : () -> (userInfo : (Text, Nat, Bool));
        #update_multiple_tags : () -> (updates : [(Nat, [Text])]);
        #update_preferences :
          () -> (userId : Nat, theme : ?Text, notifications : ?Bool);
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
      case (#get_profile _) ("get_profile", true); // Query method
      case (#get_call_logs _) ("get_call_logs", true); // Query method
      case (#get_stats _) ("get_stats", true); // Query method
      case (#health_check _) ("health_check", true); // Query method
      case (#getInspectLogs _) ("getInspectLogs", true); // Query method
      case (_) ("unknown_method", false);
    };
    
    Debug.print("🔍 INSPECT: Method '" # methodName # "' called by " # Principal.toText(caller));
    
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
    
    // Store the inspection log for testing
    let newLogs = Array.concat(inspectLogs, [methodName]);
    inspectLogs := newLogs;
    
    // Return validation result
    switch (result) {
      case (#ok) { true };
      case (#err(_)) { false };
    }
  };

  // Helper method to retrieve inspect logs for testing
  public query func getInspectLogs() : async [Text] {
    inspectLogs
  };

  // Helper method to clear inspect logs for testing  
  public func clearInspectLogs() : async () {
    inspectLogs := [];
  };
}
