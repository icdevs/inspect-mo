/// Complex Test canister for advanced InspectMo testing - simplified version
/// This canister has complex parameter types to test code generation thoroughly
import Principal "mo:core/Principal";
import Debug "mo:core/Debug";
import Result "mo:core/Result";
import Time "mo:core/Time";

actor ComplexTestCanister {
  
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

  // Simple storage
  private transient var profileCount: Nat = 0;
  private transient var documentCount: Nat = 0;
  private transient var transactionCount: Nat = 0;

  // ===== SIMPLE PARAMETER METHODS =====
  
  public query func health_check() : async Text {
    "Complex canister is healthy"
  };

  public func simple_text(message: Text) : async Text {
    "Received: " # message
  };

  public func simple_numbers(count: Nat, balance: Int) : async Text {
    "Count: " # debug_show(count) # ", Balance: " # debug_show(balance)
  };

  // ===== TUPLE PARAMETER METHODS =====
  
  public func tuple_params(userInfo: (Text, Nat, Bool)) : async Text {
    let (name, age, active) = userInfo;
    "User: " # name # ", Age: " # debug_show(age) # ", Active: " # debug_show(active)
  };

  public func nested_tuples(data: ((Text, Nat), (Bool, Text))) : async Text {
    let ((name, id), (verified, status)) = data;
    "Nested data: " # name # " (" # debug_show(id) # "), verified: " # debug_show(verified)
  };

  // ===== RECORD PARAMETER METHODS =====
  
  public func create_profile(profile: UserProfile) : async Result.Result<Nat, Text> {
    if (profile.name.size() == 0) {
      return #err("Name cannot be empty");
    };
    if (profile.email.size() < 5) {
      return #err("Invalid email");
    };
    
    profileCount += 1;
    #ok(profile.id)
  };

  public func update_profile(id: Nat, updates: UserProfile) : async Result.Result<(), Text> {
    if (updates.name.size() == 0) {
      #err("Name cannot be empty")
    } else {
      #ok(())
    }
  };

  // ===== ARRAY/LIST PARAMETER METHODS =====
  
  public func batch_create_users(userList: [UserProfile]) : async Result.Result<[Nat], Text> {
    if (userList.size() == 0) {
      return #err("Empty user list");
    };
    if (userList.size() > 100) {
      return #err("Too many users in batch");
    };
    
    #ok([1, 2, 3]) // Simplified response
  };

  public func search_users(filters: SearchFilter, userIds: [Nat]) : async [UserProfile] {
    [] // Empty result for testing
  };

  public func update_multiple_tags(updates: [(Nat, [Text])]) : async Result.Result<(), Text> {
    if (updates.size() > 50) {
      return #err("Too many updates in single call");
    };
    #ok(())
  };

  // ===== VARIANT PARAMETER METHODS =====
  
  public func execute_bulk_operation(op: BulkOperation) : async Result.Result<Text, Text> {
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
    if (doc.content.size() == 0) {
      return #err("Empty document");
    };
    if (doc.content.size() > 10_000_000) { // 10MB limit
      return #err("Document too large");
    };
    if (doc.filename.size() == 0) {
      return #err("Filename required");
    };
    
    documentCount += 1;
    #ok("Document uploaded: " # doc.filename)
  };

  public func process_binary_data(data: Blob, metadata: (Text, Nat)) : async Result.Result<Text, Text> {
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
    if (req.amount == 0) {
      return #err("Amount must be greater than 0");
    };
    
    transactionCount += 1;
    
    let noteText = switch (notes) {
      case (?note) { " with notes: " # note };
      case null { "" };
    };
    
    #ok("Transaction created for " # debug_show(req.amount) # " " # req.currency # noteText)
  };

  public func update_preferences(userId: Nat, theme: ?Text, notifications: ?Bool) : async Result.Result<(), Text> {
    #ok(()) // Simplified implementation
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
  
  public query func get_stats() : async {
    profileCount: Nat;
    documentCount: Nat;
    transactionCount: Nat;
  } {
    {
      profileCount = profileCount;
      documentCount = documentCount;
      transactionCount = transactionCount;
    }
  };

  public func clear_all_data() : async () {
    profileCount := 0;
    documentCount := 0;
    transactionCount := 0;
  };
}
