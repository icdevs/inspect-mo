# Inspect-Mo: Implementation Examples

This document provides comprehensive real-world examples demonstrating how to use the Inspect-Mo library to secure different types of Motoko canisters.

**✅ API Status Update**: Example 1 below demonstrates the **current ErasedValidator API** which is the working, tested implementation. This is the recommended approach for all new development.

**⚠️ Legacy Examples**: Examples 2-4 show older API patterns and are kept for reference. They will be updated to the current API in future revisions. For now, use Example 1 as your template.

**🎯 Current Working API Features**:
- ErasedValidator pattern with `inspector.createMethodGuardInfo<T>()`
- Simple Args union types for type safety
- Dynamic type alias generation (only imports types that exist)
- Full actor class support
- Clean camelCase function naming

## Example 1: Large Data Upload Protection (Current API ✅)

**Scenario**: File upload canister vulnerable to 2MB payload attacks

```motoko
import InspectMo "mo:inspect-mo";
import Principal "mo:core/Principal";
import Debug "mo:core/Debug";
import Error "mo:core/Error";
import Array "mo:core/Array";
import Blob "mo:core/Blob";

actor FileUploader {

  type MessageAccessor = {
    #upload_metadata : (Text); // metadata
    #upload_file : (Blob);     // file data
    #get_file_info : (Text);   // fileId
  };

  // Initialize with configuration
  private let config: InspectMo.InitArgs = {
    allowAnonymous = ?false;
    defaultMaxArgSize = ?1_000_000; // 1MB default
    authProvider = null;
    rateLimit = null;
    queryDefaults = ?{
      allowAnonymous = true;
      maxArgSize = 10_000;
      rateLimit = null;
    };
    updateDefaults = ?{
      allowAnonymous = false;
      maxArgSize = 1_000_000;
      rateLimit = null;
    };
    developmentMode = false;
    auditLog = true;
  };

  private let inspectMo = InspectMo.InspectMo(
    null, // migration state
    Principal.fromActor(FileUploader), // instantiator
    Principal.fromActor(FileUploader), // canister principal
    ?config,
    null, // environment
    func(state) {} // state callback
  );
  
  private let inspector = inspectMo.createInspector<MessageAccessor>();

  // Allow small metadata uploads using ErasedValidator pattern
  let metadataInspectInfo = inspector.createMethodGuardInfo<Text>(
    "upload_metadata",
    false, // isQuery
    [
      InspectMo.textSize<MessageAccessor, Text>(
        func(metadata: Text): Text { metadata }, // accessor for single Text parameter
        null, ?5_000 // max 5KB metadata
      ),
      InspectMo.requireAuth<MessageAccessor, Text>()
    ],
    func(msg: MessageAccessor) : Text = switch(msg) {
      case (#upload_metadata(metadata)) metadata;
      case (_) Debug.trap("Wrong message type");
    }
  );
  inspector.inspect(metadataInspectInfo);
  
  public shared(msg) func upload_metadata(metadata: Text): async () {
    // Implementation
  };

  // Restrict large file uploads  
  let fileInspectInfo = inspector.createMethodGuardInfo<Blob>(
    "upload_file",
    false,
    [
      InspectMo.blobSize<MessageAccessor, Blob>(
        func(file: Blob): Blob { file }, // accessor for single Blob parameter  
        ?1, ?1_000_000 // 1 byte to 1MB max files
      ),
      InspectMo.requireAuth<MessageAccessor, Blob>()
    ],
    func(msg: MessageAccessor) : Blob = switch(msg) {
      case (#upload_file(file)) file;
      case (_) Debug.trap("Wrong message type");
    }
  );
  inspector.inspect(fileInspectInfo);
  
  // Add business logic validation for file uploads
  let fileGuardInfo = inspector.createMethodGuardInfo<Blob>(
    "upload_file",
    false,
    [
      InspectMo.customCheck<MessageAccessor, Blob>(
        func(args: InspectMo.CustomCheckArgs<MessageAccessor>): InspectMo.GuardResult {
          switch (args.args) {
            case (#upload_file(file)) {
              // Check file type by magic bytes
              if (file.size() >= 4) {
                let header = Array.subArray(Blob.toArray(file), 0, 4);
                // Example: Check for PNG header
                if (header == [0x89, 0x50, 0x4E, 0x47]) { #ok }
                else { #err("Only PNG files allowed") }
              } else {
                #err("File too small to validate")
              }
            };
            case (_) #err("Invalid message variant");
          }
        }
      )
    ],
    func(msg: MessageAccessor) : Blob = switch(msg) {
      case (#upload_file(file)) file;
      case (_) Debug.trap("Wrong message type");
    }
  );
  inspector.guard(fileGuardInfo);
          // Check file type by magic bytes
          if (file.size() >= 4) {
            let header = Array.subArray(Blob.toArray(file), 0, 4);
            // Example: Check for PNG header
            if (header == [0x89, 0x50, 0x4E, 0x47]) { #ok }
            else { #err("Only PNG files allowed") }
          } else {
            #err("File too small to validate")
          }
        }
      )
    ],
    func(msg: MessageAccessor) : Blob = switch(msg) {
      case (#upload_file(file)) file;
      case (_) Debug.trap("Wrong message type");
    }
  ));
  
  public shared(msg) func upload_file(file: Blob): async Text {
    // Guard validation check
    let args : InspectMo.InspectArgs<MessageAccessor> = {
      methodName = "upload_file";
      caller = msg.caller;
      arg = to_candid(file);
      isQuery = false;
      cycles = null;
      deadline = null;
      isInspect = false;
      msg = #upload_file(file);
    };
    
    switch (inspector.guardCheck(args)) {
      case (#ok) { 
        // Implementation: store file and return ID
        "file-id-123"
      };
      case (#err(errMsg)) { throw Error.reject(errMsg) };
    }
  };
    };
    developmentMode = false;
    auditLog = true;
  };

  private let inspectMo = InspectMo.InspectMo(
    null, // migration state
    Principal.fromActor(FileUploader),
    Principal.fromActor(FileUploader),
    ?config,
    null, // environment
    func(state) {} // state callback
  );
  
  private let inspector = inspectMo.createInspector<MessageAccessor>();

  // Allow small metadata uploads
  inspector.inspect("upload_metadata", [
    InspectMo.textSize<Text>(Types.getMetadata, max = ?5_000), // 5KB max for metadata
    InspectMo.requireAuth()
  ], Types.uploadMetadataAccessor);
  
  public shared(msg) func upload_metadata(metadata: Text): async () {
    // Implementation
  };

  // Restrict large file uploads
  inspector.inspect("upload_file", [
    InspectMo.blobSize<Blob>(Types.getFileData, min = ?1, max = ?1_000_000), // 1MB max files
    InspectMo.requireRole("uploader")
  ], Types.uploadFileAccessor);
  
  inspector.guard("upload_file", [
    InspectMo.customCheck<Blob>(func(args: InspectMo.CustomCheckArgs<Blob>): InspectMo.GuardResult { 
      if (isValidFileFormat(args.args)) { #ok }
      else { #err("Invalid file format") }
    })
  ]);
  
  public shared(msg) func upload_file(file: Blob): async FileId {
    switch (inspector.guardCheck("upload_file", file, msg.caller, null, null)) {
      case (#ok) { 
        // Implementation
        { id = 1 } // Mock FileId
      };
      case (#err(error)) { 
        Debug.trap("Validation failed: " # error) 
      };
    }
  };

  // Query method for file info - different defaults
  inspector.inspect("get_file_info", [
    InspectMo.textSize<Text>(Types.getFileId, max = ?100) // Small file ID only
  ], Types.getFileInfoAccessor);
  
  public query func get_file_info(fileId: Text): async ?FileInfo {
    // Implementation
    null // Mock
  };

  system func inspect({
    caller : Principal;
    arg : Blob;
    msg : MessageAccessor
  }) : Bool {
    Types.inspectHelper(msg, inspector)
  };
}

// Types module with accessor functions (generated by the local codegen tool)
module Types {
  public func getMetadata(metadata: Text): Text { metadata };
  public func getFileData(file: Blob): Blob { file };
  public func getFileId(fileId: Text): Text { fileId };
  
  // Message accessor functions
  public func uploadMetadataAccessor(msg: MessageAccessor) : Result.Result<(Text, Text), Text> {
    switch (msg) {
      case (#upload_metadata(metadata)) { 
        #ok(("upload_metadata", metadata)) 
      };
      case (_) { #err("Wrong message type") };
    }
  };

  public func uploadFileAccessor(msg: MessageAccessor) : Result.Result<(Text, Blob), Text> {
    switch (msg) {
      case (#upload_file(file)) { 
        #ok(("upload_file", file)) 
      };
      case (_) { #err("Wrong message type") };
    }
  };

  public func getFileInfoAccessor(msg: MessageAccessor) : Result.Result<(Text, Text), Text> {
    switch (msg) {
      case (#get_file_info(fileId)) { 
        #ok(("get_file_info", fileId)) 
      };
      case (_) { #err("Wrong message type") };
    }
  };

  // Integration helper
  public func inspectHelper(
    msg: MessageAccessor,
    inspector: InspectMo.Inspector<MessageAccessor>
  ) : Bool {
    let methodName = switch (msg) {
      case (#upload_metadata _) { "upload_metadata" };
      case (#upload_file _) { "upload_file" };
      case (#get_file_info _) { "get_file_info" };
    };
    
    inspector.inspectCheck({
      caller = inspector.getCaller();
      arg = inspector.getArgBlob();
      methodName = methodName;
      isQuery = (methodName == "get_file_info");
      msg = msg;
      isIngress = true;
      parsedArgs = null;
      argSizes = [];
      argTypes = [];
    })
  };
}
      case (#err(msg)) { throw Error.reject(msg) };
    };
    // Implementation
  };

  // Query method for file info - different defaults
  inspector.inspect("get_file_info", [
    InspectMo.textSize<Text>(Types.getFileId, max = ?100) // Small file ID only
  ]);
  public query func get_file_info(fileId: Text): async ?FileInfo {
    // Implementation
  };

  system func inspect({
    caller : Principal;
    arg : Blob;
    msg : InspectMessage
  }) : Bool {
    let (methodName, isQuery) = switch (msg) {
      case (#upload_metadata _) { ("upload_metadata", false) };
      case (#upload_file _) { ("upload_file", false) };
      case (#get_file_info _) { ("get_file_info", true) };
    };
    
    let inspectArgs : InspectMo.InspectArgs = {
      caller = caller;
      arg = arg;
      methodName = methodName;
      isQuery = isQuery;
      isIngress = true;
      msg = msg;
      argTypes = [];
    };
    
    inspector.inspectCheck(inspectArgs)
  };
}

// Types module with accessor functions
module Types {
  public func getMetadata(metadata: Text): Text { metadata };
  public func getFileData(file: Blob): Blob { file };
  public func getFileId(fileId: Text): Text { fileId };
}
```

## Example 2: Multi-tier Authorization System

**⚠️ EXAMPLE ONLY: This RBAC implementation is for demonstration purposes and is not production-ready.**

**Scenario**: DeFi canister with different permission levels

```motoko
import InspectMo "mo:inspect-mo";
import Permissions "mo:rbac-permissions"; // ⚠️ Example integration only
import Types "types"; // Generated by the local codegen tool
import Principal "mo:core/Principal";
import Debug "mo:core/Debug";

actor DeFiCanister {
  // NOTE: This permission system is an example and has performance limitations
  private var permissions = Permissions.init();
  
  type MessageAccessor = {
    #get_balance : (Principal);          // account
    #get_history : (Principal);          // account
    #transfer : (Principal, Nat);        // to, amount
    #bulk_transfer : ([(Principal, Nat)]); // transfers
    #admin_set_fee : (Nat);              // newFee
    #admin_pause_transfers : ();
  };
  
  private let config: InspectMo.InitArgs = {
    allowAnonymous = ?false;
    defaultMaxArgSize = ?10_000;
    authProvider = ?permissions; // ⚠️ Example integration pattern
    rateLimit = null;
    
    // Queries can be more permissive
    queryDefaults = ?{
      allowAnonymous = true;
      maxArgSize = 1_000;
    };
    
    // Updates require authentication
    updateDefaults = ?{
      allowAnonymous = false;
      maxArgSize = 10_000;
    };
    developmentMode = false;
    auditLog = true;
  };

  private let inspectMo = InspectMo.InspectMo(
    null,
    Principal.fromActor(DeFiCanister),
    Principal.fromActor(DeFiCanister),
    ?config,
    null,
    func(state) {}
  );
  
  private let inspector = inspectMo.createInspector<MessageAccessor>();

  // Public read operations - uses query defaults (anonymous allowed)
  inspector.inspect("get_balance", [], Types.getBalanceAccessor);
  public query func get_balance(account: Principal): async Nat {
    // Implementation
    0 // Mock
  };

  inspector.inspect("get_history", [], Types.getHistoryAccessor);
  public query func get_history(account: Principal): async [Transaction] {
    // Implementation
    [] // Mock
  };

  // User operations - specific permissions required
  inspector.inspect("transfer", [
    InspectMo.requirePermission("transfer"),
    InspectMo.natValue<(Principal, Nat)>(Types.getTransferAmount, max = ?1_000_000) // Reasonable transfer amount
  ], Types.transferAccessor);
  
  inspector.guard("transfer", [
    InspectMo.dynamicAuth<(Principal, Nat)>(func(args: InspectMo.DynamicAuthArgs<(Principal, Nat)>): InspectMo.GuardResult {
      // Complex business logic validation
      if (hasValidBalance(args.caller, args.args.1)) { #ok }
      else { #err("Insufficient balance") }
    })
  ]);
  
  public shared(msg) func transfer(to: Principal, amount: Nat): async TransferResult {
    switch (inspector.guardCheck("transfer", (to, amount), msg.caller, null, null)) {
      case (#ok) { 
        // Implementation
        #ok({ txId = 1 }) // Mock
      };
      case (#err(error)) { 
        #err(error)
      };
    }
  };

  // Bulk operations - higher limits for certain roles
  inspector.inspect("bulk_transfer", [
    InspectMo.requirePermission("bulk_transfer"),
    InspectMo.customCheck<[(Principal, Nat)]>(func(args: InspectMo.CustomCheckArgs<[(Principal, Nat)]>): InspectMo.GuardResult {
      if (args.args.size() <= 100) { #ok } // Max 100 transfers per batch
      else { #err("Too many transfers in batch") }
    })
  ], Types.bulkTransferAccessor);
  
  public shared(msg) func bulk_transfer(transfers: [(Principal, Nat)]): async [TransferResult] {
    switch (inspector.guardCheck("bulk_transfer", transfers, msg.caller, null, null)) {
      case (#ok) { 
        // Implementation
        [] // Mock
      };
      case (#err(error)) { 
        Debug.trap("Validation failed: " # error)
      };
    }
  };

  // Admin operations - strict permissions
  inspector.inspect("admin_set_fee", [
    InspectMo.requireRole("admin"),
    InspectMo.natValue<Nat>(func (fee: Nat): Nat { fee }, max = ?1000)
  ], Types.adminSetFeeAccessor);
  
  inspector.guard("admin_set_fee", [
    InspectMo.requireRole("admin") // Double-check at runtime too
  ]);
  
  public shared(msg) func admin_set_fee(newFee: Nat): async AdminResult {
    switch (inspector.guardCheck("admin_set_fee", newFee, msg.caller, null, null)) {
      case (#ok) { 
        // Implementation
        #ok
      };
      case (#err(error)) { 
        #err(error)
      };
    }
  };

  inspector.inspect("admin_pause_transfers", [
    InspectMo.requireRole("admin")
  ], Types.adminPauseTransfersAccessor);
  
  public shared(msg) func admin_pause_transfers(): async AdminResult {
    switch (inspector.guardCheck("admin_pause_transfers", (), msg.caller, null, null)) {
      case (#ok) { 
        // Implementation
        #ok
      };
      case (#err(error)) { 
        #err(error)
      };
    }
  };

  system func inspect({
    caller : Principal;
    arg : Blob;
    msg : MessageAccessor
  }) : Bool {
    Types.inspectHelper(msg, inspector)
  };
}

// Types module with accessor functions (generated by the local codegen tool)
module Types {
  public func getTransferAmount(args: (Principal, Nat)): Nat { args.1 };
  public func getBulkTransfers(transfers: [(Principal, Nat)]): [(Principal, Nat)] { transfers };
  
  // Message accessor functions
  public func getBalanceAccessor(msg: MessageAccessor) : Result.Result<(Text, Principal), Text> {
    switch (msg) {
      case (#get_balance(account)) { #ok(("get_balance", account)) };
      case (_) { #err("Wrong message type") };
    }
  };

  public func transferAccessor(msg: MessageAccessor) : Result.Result<(Text, (Principal, Nat)), Text> {
    switch (msg) {
      case (#transfer(to, amount)) { #ok(("transfer", (to, amount))) };
      case (_) { #err("Wrong message type") };
    }
  };

  // Additional accessor functions...
  public func inspectHelper(
    msg: MessageAccessor,
    inspector: InspectMo.Inspector<MessageAccessor>
  ) : Bool {
    let methodName = switch (msg) {
      case (#get_balance _) { "get_balance" };
      case (#get_history _) { "get_history" };
      case (#transfer _) { "transfer" };
      case (#bulk_transfer _) { "bulk_transfer" };
      case (#admin_set_fee _) { "admin_set_fee" };
      case (#admin_pause_transfers _) { "admin_pause_transfers" };
    };
    
    inspector.inspectCheck({
      caller = inspector.getCaller();
      arg = inspector.getArgBlob();
      methodName = methodName;
      isQuery = (methodName == "get_balance" or methodName == "get_history");
      msg = msg;
      isIngress = true;
      parsedArgs = null;
      argSizes = [];
      argTypes = [];
    })
  };
}
    InspectMo.requirePermission("transfer"),
    InspectMo.natValue<(Principal, Nat)>(Types.getTransferAmount, max = ?1_000_000) // Reasonable transfer amount
  public func transfer(to: Principal, amount: Nat): async TransferResult {
    switch (inspector.guardCheck("transfer", to, amount)) {
      case (#ok) { /* Perform transfer */ };
      case (#err(msg)) { return #err("Validation failed: " # msg) };
    };
    // Implementation
  };

  // Bulk operations - higher limits for certain roles
  inspector.inspect("bulk_transfer", [
    InspectMo.requirePermission("bulk_transfer"),
    InspectMo.arraySize<([(Principal, Nat)])>(Types.getTransfers, max = ?100),
    InspectMo.composite<([(Principal, Nat)])>(Types.getTransfers, func (transfers: [(Principal, Nat)]): [Result.Result<(), Text>] {
      let validator = InspectMo.arrayElementValidator<(Principal, Nat)>(
        InspectMo.natValue<(Principal, Nat)>(func (transfer: (Principal, Nat)): Nat { transfer.1 }, max = ?100_000)
      );
      validator(transfers)
    })
  ]);
  public func bulk_transfer(transfers: [(Principal, Nat)]): async [TransferResult] {
    switch (inspector.guardCheck("bulk_transfer", transfers)) {
      case (#ok) { /* Perform bulk transfer */ };
      case (#err(msg)) { return [#err("Validation failed: " # msg)] };
    };
    // Implementation
  };

  // Admin operations - strict permissions
  inspector.inspect("admin_set_fee", [
    InspectMo.requirePermission("admin"),
    InspectMo.natValue<(Nat)>(func (fee: Nat): Nat { fee }, max = ?1000)
  ]);
  public func admin_set_fee(newFee: Nat): async AdminResult {
    switch (inspector.guardCheck("admin_set_fee", newFee)) {
      case (#ok) { /* Set fee */ };
      case (#err(msg)) { return #err("Validation failed: " # msg) };
    };
    // Implementation
  };

  inspector.inspect("admin_pause_transfers", [
    InspectMo.requirePermission("admin")
  ]);
  public func admin_pause_transfers(): async AdminResult {
    switch (inspector.guardCheck("admin_pause_transfers")) {
      case (#ok) { /* Pause transfers */ };
      case (#err(msg)) { return #err("Validation failed: " # msg) };
    };
    // Implementation
  };

  system func inspect({
    caller : Principal;
    arg : Blob;
    msg : InspectMessage
  }) : Bool {
    let (methodName, isQuery) = switch (msg) {
      case (#get_balance _) { ("get_balance", true) };
      case (#get_history _) { ("get_history", true) };
      case (#transfer _) { ("transfer", false) };
      case (#bulk_transfer _) { ("bulk_transfer", false) };
      case (#admin_set_fee _) { ("admin_set_fee", false) };
      case (#admin_pause_transfers _) { ("admin_pause_transfers", false) };
    };
    
    let inspectArgs : InspectMo.InspectArgs = {
      caller = caller;
      arg = arg;
      methodName = methodName;
      isQuery = isQuery;
      isIngress = true;
      msg = msg;
      argTypes = [];
    };
    
    inspector.inspectCheck(inspectArgs)
  };
}

// Types module with accessor functions
module Types {
  public func getTransferAmount(to: Principal, amount: Nat): Nat { amount };
  public func getTransfers(transfers: [(Principal, Nat)]): [(Principal, Nat)] { transfers };
}
```

## Example 3: Social Media Canister

**Scenario**: Social platform with user-generated content and moderation

```motoko
import InspectMo "mo:inspect-mo";
import Map "mo:core/HashMap";
import Types "types";

actor SocialCanister {
  // Dynamic state for runtime validation
  private var userProfiles = Map.HashMap<Principal, UserProfile>(10, Principal.equal, Principal.hash);
  private var moderators = Map.HashMap<Principal, Bool>(5, Principal.equal, Principal.hash);
  private var bannedUsers = Map.HashMap<Principal, Bool>(10, Principal.equal, Principal.hash);
  
  type InspectMessage = {
    #get_posts : () -> (limit: Nat);
    #get_user_profile : () -> (user: Principal);
    #register_user : () -> (username: Text, bio: Text);
    #create_post : () -> (content: Text);
    #like_post : () -> (postId: Nat);
    #follow_user : () -> (user: Principal);
    #moderate_post : () -> (postId: Nat, action: Text);
  };
  
  private let inspector = InspectMo.init<InspectMessage>({
    allowAnonymous = ?false;
    defaultMaxArgSize = ?50_000; // 50KB default
    
    queryDefaults = ?{
      allowAnonymous = ?true;
      maxArgSize = ?10_000;
    };
    updateDefaults = ?{
      allowAnonymous = ?false;
      maxArgSize = ?100_000; // Allow larger posts
    };
  });

  // Public read operations - anonymous access allowed
  inspector.inspect("get_posts", [
    InspectMo.natValue<(Nat)>(func (limit: Nat): Nat { limit }, max = ?100)
  ]);
  public query func get_posts(limit: Nat): async [Post] {
    // Implementation
  };

  inspector.inspect("get_user_profile", []);
  public query func get_user_profile(user: Principal): async ?UserProfile {
    // Implementation
  };

  // User registration - basic validation
  inspector.inspect("register_user", [
    InspectMo.textSize<(Text, Text)>(Types.getUsername, min = ?3, max = ?30),
    InspectMo.textSize<(Text, Text)>(Types.getBio, min = ?0, max = ?500),
    InspectMo.requireAuth()
  public shared(msg) func register_user(username: Text, bio: Text): async Result<(), Text> {
    switch (inspector.guardCheck("register_user", username, bio)) {
      case (#ok) { 
        if (not isUsernameAvailable(username)) {
          return #err("Username already taken");
        };
        // Continue with registration
      };
      case (#err(msg)) { return #err("Validation failed: " # msg) };
    };
    // Implementation
  };

  // Post creation - comprehensive content validation
  inspector.inspect("create_post", [
    InspectMo.textSize<(Text)>(func (content: Text): Text { content }, min = ?1, max = ?5_000),
    InspectMo.requireAuth()
  ]);
  public shared(msg) func create_post(content: Text): async Result<PostId, Text> {
    switch (inspector.guardCheck("create_post", content)) {
      case (#ok) { 
        if (bannedUsers.get(msg.caller) == ?true) {
          return #err("User is banned from posting");
        };
        if (not canUserPostToday(msg.caller)) {
          return #err("Daily post limit exceeded");
        };
        // Continue with post creation
      };
      case (#err(msg)) { return #err("Validation failed: " # msg) };
    };
    // Implementation
  };

  // Social interactions - lightweight validation
  inspector.inspect("like_post", [
    InspectMo.natValue<(Nat)>(func (postId: Nat): Nat { postId }, max = ?1_000_000),
    InspectMo.requireAuth()
  ]);
  public shared(msg) func like_post(postId: Nat): async Result<(), Text> {
    switch (inspector.guardCheck("like_post", postId)) {
      case (#ok) { /* Like the post */ };
      case (#err(msg)) { return #err("Validation failed: " # msg) };
    };
    // Implementation
  };

  inspector.inspect("follow_user", [
    InspectMo.requireAuth()
  ]);
  public shared(msg) func follow_user(user: Principal): async Result<(), Text> {
    switch (inspector.guardCheck("follow_user", user)) {
      case (#ok) { /* Follow the user */ };
      case (#err(msg)) { return #err("Validation failed: " # msg) };
    };
    // Implementation
  };

  // Moderation - admin only
  inspector.inspect("moderate_post", [
    InspectMo.requirePermission("moderator"),
    InspectMo.natValue<(Nat, Text)>(Types.getPostId, max = ?1_000_000),
    InspectMo.textSize<(Nat, Text)>(Types.getModerationAction, min = ?1, max = ?20)
  public shared(msg) func moderate_post(postId: Nat, action: Text): async Result<(), Text> {
    switch (inspector.guardCheck("moderate_post", postId, action)) {
      case (#ok) { /* Perform moderation action */ };
      case (#err(msg)) { return #err("Validation failed: " # msg) };
    };
    // Implementation
  };

  system func inspect({
    caller : Principal;
    arg : Blob;
    msg : InspectMessage
  }) : Bool {
    let (methodName, isQuery) = switch (msg) {
      case (#get_posts _) { ("get_posts", true) };
      case (#get_user_profile _) { ("get_user_profile", true) };
      case (#register_user _) { ("register_user", false) };
      case (#create_post _) { ("create_post", false) };
      case (#like_post _) { ("like_post", false) };
      case (#follow_user _) { ("follow_user", false) };
      case (#moderate_post _) { ("moderate_post", false) };
    };
    
    let inspectArgs : InspectMo.InspectArgs = {
      caller = caller;
      arg = arg;
      methodName = methodName;
      isQuery = isQuery;
      isIngress = true;
      msg = msg;
      argTypes = [];
    };
    
    inspector.inspectCheck(inspectArgs)
// Types module with accessor functions
module Types {
  public func getUsername(username: Text, bio: Text): Text { username };
  public func getBio(username: Text, bio: Text): Text { bio };
  public func getPostId(postId: Nat, action: Text): Nat { postId };
  public func getModerationAction(postId: Nat, action: Text): Text { action };
}
```

## Example 4: NFT Marketplace

**Scenario**: NFT trading platform with complex business logic

```motoko
import InspectMo "mo:inspect-mo";
import Types "types";
    }
  }) : Bool {
    let (methodName, isQuery) = switch (msg) {
      case (#register_user _) { ("register_user", false) };
      case (#create_post _) { ("create_post", false) };
      case (#upload_image _) { ("upload_image", false) };
      case (#add_comment _) { ("add_comment", false) };
      case (#ban_user _) { ("ban_user", false) };
      case (#get_posts _) { ("get_posts", true) };
      case (#get_user_profile _) { ("get_user_profile", true) };
actor NFTMarketplace {
  
  type InspectMessage = {
    #get_nft_info : () -> (tokenId: Nat);
    #get_marketplace_stats : () -> ();
    #mint_nft : () -> (name: Text, image: Blob, metadata: Text);
    #list_for_sale : () -> (tokenId: Nat, price: Nat);
    #buy_nft : () -> (tokenId: Nat);
    #make_offer : () -> (tokenId: Nat, amount: Nat);
    #accept_offer : () -> (offerId: Nat);
    #set_royalty : () -> (tokenId: Nat, percentage: Nat);
  };
  
  private let inspector = InspectMo.init<InspectMessage>({
    allowAnonymous = ?false;
    
    queryDefaults = ?{
      allowAnonymous = ?true;
      maxArgSize = ?5_000;
    };
    updateDefaults = ?{
      allowAnonymous = ?false;
      maxArgSize = ?100_000; // Allow larger metadata
    };
  });

  // Public read operations
  inspector.inspect("get_nft_info", [
    InspectMo.natValue<(Nat)>(func (tokenId: Nat): Nat { tokenId }, max = ?1_000_000)
  ]);
  public query func get_nft_info(tokenId: Nat): async ?NFTInfo {
    // Implementation
  };

  inspector.inspect("get_marketplace_stats", []);
  public query func get_marketplace_stats(): async MarketplaceStats {
    // Implementation
  };

  // NFT minting with metadata validation
  inspector.inspect("mint_nft", [
    InspectMo.textSize<(Text, Blob, Text)>(Types.getNFTName, min = ?1, max = ?100),
    InspectMo.blobSize<(Text, Blob, Text)>(Types.getNFTImage, min = ?1000, max = ?5_000_000), // 1KB to 5MB
    InspectMo.textSize<(Text, Blob, Text)>(Types.getNFTMetadata, min = ?1, max = ?10_000),
    InspectMo.requirePermission("minter")
  ]);
  public shared(msg) func mint_nft(name: Text, imageData: Blob, metadata: Text): async Result<TokenId, Text> {
    switch (inspector.guardCheck("mint_nft", name, imageData, metadata)) {
      case (#ok) { 
        if (not isValidNFTName(name)) {
          return #err("Invalid NFT name");
        };
        if (not isValidImageFormat(imageData)) {
          return #err("Invalid image format");
        };
        // Continue with minting
      };
      case (#err(msg)) { return #err("Validation failed: " # msg) };
    };
    // Implementation
  };

  // NFT listing with price validation
  inspector.inspect("list_for_sale", [
    InspectMo.natValue<(Nat, Nat)>(Types.getTokenId, max = ?1_000_000),
    InspectMo.natValue<(Nat, Nat)>(Types.getListingPrice, min = ?1, max = ?1_000_000_000_000), // Max 1T tokens
    InspectMo.requireAuth()
  ]);
  public shared(msg) func list_for_sale(tokenId: Nat, price: Nat): async Result<ListingId, Text> {
    switch (inspector.guardCheck("list_for_sale", tokenId, price)) {
      case (#ok) { 
        if (not ownsToken(msg.caller, tokenId)) {
          return #err("You don't own this NFT");
        };
        // Continue with listing
      };
      case (#err(msg)) { return #err("Validation failed: " # msg) };
    };
    // Implementation
  };

  // NFT purchase with payment validation
  inspector.inspect("buy_nft", [
    InspectMo.natValue<(Nat)>(func (tokenId: Nat): Nat { tokenId }, max = ?1_000_000),
    InspectMo.requireAuth()
  ]);
  public shared(msg) func buy_nft(tokenId: Nat): async Result<(), Text> {
    switch (inspector.guardCheck("buy_nft", tokenId)) {
      case (#ok) { 
        if (not isValidListing(tokenId)) {
          return #err("Invalid listing");
        };
        if (not hasEnoughBalance(msg.caller, tokenId)) {
          return #err("Insufficient balance");
        };
        // Continue with purchase
      };
      case (#err(msg)) { return #err("Validation failed: " # msg) };
    };
    // Implementation
  };

  // Offer system with amount validation
  inspector.inspect("make_offer", [
    InspectMo.natValue<(Nat, Nat)>(Types.getTokenId, max = ?1_000_000),
    InspectMo.natValue<(Nat, Nat)>(Types.getOfferAmount, min = ?1, max = ?1_000_000_000_000),
    InspectMo.requireAuth()
  ]);
  public shared(msg) func make_offer(tokenId: Nat, amount: Nat): async Result<OfferId, Text> {
    switch (inspector.guardCheck("make_offer", tokenId, amount)) {
      case (#ok) { /* Make offer */ };
      case (#err(msg)) { return #err("Validation failed: " # msg) };
    };
    // Implementation
  };

  inspector.inspect("accept_offer", [
    InspectMo.natValue<(Nat)>(func (offerId: Nat): Nat { offerId }, max = ?1_000_000),
    InspectMo.requireAuth()
  ]);
  public shared(msg) func accept_offer(offerId: Nat): async Result<(), Text> {
    switch (inspector.guardCheck("accept_offer", offerId)) {
      case (#ok) { 
        if (not ownsTokenForOffer(msg.caller, offerId)) {
          return #err("You don't own the NFT for this offer");
        };
        // Continue with acceptance
      };
      case (#err(msg)) { return #err("Validation failed: " # msg) };
    };
    // Implementation
  };

  // Royalty management - creator or admin only
  inspector.inspect("set_royalty", [
    InspectMo.natValue<(Nat, Nat)>(Types.getTokenId, max = ?1_000_000),
    InspectMo.natValue<(Nat, Nat)>(Types.getRoyaltyPercentage, max = ?25), // Max 25% royalty
    InspectMo.requireAuth()
  public shared(msg) func set_royalty(tokenId: Nat, percentage: Nat): async Result<(), Text> {
    switch (inspector.guardCheck("set_royalty", tokenId, percentage)) {
      case (#ok) { 
        if (not (isTokenCreator(msg.caller, tokenId) or isAdmin(msg.caller))) {
          return #err("Only token creator or admin can set royalties");
        };
        // Set royalty
      };
      case (#err(msg)) { return #err("Validation failed: " # msg) };
    };
    // Implementation
  };

  system func inspect({
    caller : Principal;
    arg : Blob;
    msg : InspectMessage
  }) : Bool {
    let (methodName, isQuery) = switch (msg) {
      case (#get_nft_info _) { ("get_nft_info", true) };
      case (#get_marketplace_stats _) { ("get_marketplace_stats", true) };
      case (#mint_nft _) { ("mint_nft", false) };
      case (#list_for_sale _) { ("list_for_sale", false) };
      case (#buy_nft _) { ("buy_nft", false) };
      case (#make_offer _) { ("make_offer", false) };
      case (#accept_offer _) { ("accept_offer", false) };
      case (#set_royalty _) { ("set_royalty", false) };
    };
    
    let inspectArgs : InspectMo.InspectArgs = {
      caller = caller;
      arg = arg;
      methodName = methodName;
      isQuery = isQuery;
      isIngress = true;
      msg = msg;
      argTypes = [];
    };
    
    inspector.inspectCheck(inspectArgs)
  };
}

// Types module with accessor functions
module Types {
  public func getNFTName(name: Text, image: Blob, metadata: Text): Text { name };
  public func getNFTImage(name: Text, image: Blob, metadata: Text): Blob { image };
  public func getNFTMetadata(name: Text, image: Blob, metadata: Text): Text { metadata };
  public func getTokenId(tokenId: Nat, other: Nat): Nat { tokenId };
  public func getListingPrice(tokenId: Nat, price: Nat): Nat { price };
  public func getOfferAmount(tokenId: Nat, amount: Nat): Nat { amount };
  public func getRoyaltyPercentage(tokenId: Nat, percentage: Nat): Nat { percentage };
}
```

## Advanced Features

### Custom Validation Rules

You can create complex custom validation logic by combining multiple validators:

  // Batch operations for efficiency
  InspectMo.inspect(inspector, "batch_mint", [
    InspectMo.requireRole("admin")
  ]);
  InspectMo.guard([
    InspectMo.customCheck<[(Text, Blob)]>(func(args: CustomCheckArgs<[(Text, Blob)]>): GuardResult { 
      if (args.args.size() <= 50) { #ok } // Max 50 NFTs per batch
      else { #err("Too many NFTs in batch") }
    })
  ]);
  public shared(msg) func batch_mint(nfts: [(Text, Blob)]): async [TokenId] {
    switch (inspector.guard("batch_mint", msg.caller)) {
      case (#ok) { /* continue */ };
      case (#err(msg)) { throw Error.reject(msg) };
    };
    // Implementation
  };

  // Query methods - public access
  InspectMo.inspect(inspector, "get_nft_info", []);
  public query func get_nft_info(tokenId: TokenId): async ?NFTInfo {
    // Implementation
  };

  InspectMo.inspect(inspector, "get_listings", []);
  public query func get_listings(limit: Nat): async [Listing] {
    // Implementation
  };

  // Helper functions
  private func isValidNFTName(name: Text): Bool { true };
  private func isValidImageFormat(data: Blob): Bool { true };
  private func ownsToken(user: Principal, tokenId: TokenId): Bool { true };
  private func isValidListing(listingId: ListingId): Bool { true };
  private func hasEnoughBalance(user: Principal, listingId: ListingId): Bool { true };

  system func inspect({
    caller : Principal;
    arg : Blob;
    msg : {
      #mint_nft : (Text, Blob) -> TokenId;
      #list_nft : (TokenId, Nat) -> ListingId;
      #purchase_nft : ListingId -> Result<TokenId, Text>;
      #batch_mint : [(Text, Blob)] -> [TokenId];
      #get_nft_info : TokenId -> ?NFTInfo;
      #get_listings : Nat -> [Listing];
    }
  }) : Bool {
    let (methodName, isQuery) = switch (msg) {
      case (#mint_nft _) { ("mint_nft", false) };
      case (#list_nft _) { ("list_nft", false) };
      case (#purchase_nft _) { ("purchase_nft", false) };
      case (#batch_mint _) { ("batch_mint", false) };
      case (#get_nft_info _) { ("get_nft_info", true) };
      case (#get_listings _) { ("get_listings", true) };
    };
    
    let inspectArgs : InspectMo.InspectArgs = {
      caller = caller;
      arg = arg;
      methodName = methodName;
      isQuery = isQuery;
      isIngress = Principal.isAnonymous(caller);
      msg = msg;
      argTypes = [];
    };
    
    inspector.inspect(inspectArgs)
  };
}

// Types module with accessor functions  
module Types {
  public func getNFTName(name: Text, imageData: Blob): Text { name };
  public func getNFTImage(name: Text, imageData: Blob): Blob { imageData };
  public func getListingPrice(tokenId: TokenId, price: Nat): Nat { price };
}
```

## Common Patterns

### 1. User-Defined Accessor Functions
```motoko
// For methods with multiple parameters
public func getFirstParam(param1: T1, param2: T2): T1 { param1 };
public func getSecondParam(param1: T1, param2: T2): T2 { param2 };

// For single parameter methods
public func getSingleParam(param: T): T { param };

// For extracting from complex types
public func getUserId(user: User): Principal { user.id };
public func getUserName(user: User): Text { user.name };
```

### 2. Layered Security Approach
```motoko
// Layer 1: Boundary validation (fast, basic checks)
InspectMo.inspect(inspector, "method_name", [
  InspectMo.textSize<T>(accessor, min = ?1, max = ?1000),
  InspectMo.requireAuth()
]);

// Layer 2: Runtime validation (full context, business logic)
InspectMo.guard([
  InspectMo.dynamicAuth<T>(func(args: DynamicAuthArgs<T>): GuardResult { 
    // Check permissions against current state
  }),
  InspectMo.customCheck<T>(func(args: CustomCheckArgs<T>): GuardResult { 
    // Validate business rules
  })
]);
```

### 3. Error Handling Best Practices
```motoko
public func my_method(args: T): async Result<ReturnType, Text> {
  switch (inspector.guard("my_method", msg.caller)) {
    case (#ok) { 
      // Continue with implementation
      #ok(result)
    };
    case (#err(message)) { 
      // Log error for debugging
      Debug.print("Validation failed: " # message);
      #err(message)
    };
  };
};
```

## Example 5: Build System Integration

**Scenario**: Automating InspectMo code generation in a DFX-based project

### Project Structure
```
my-canister/
├── dfx.json
├── mops.toml
├── package.json
├── src/
│   ├── main.mo
│   ├── declarations/
│   │   ├── main/main.did
│   │   └── user_service/user_service.did
│   └── generated/
│       ├── main-inspect.mo        # Auto-generated
│       └── user_service-inspect.mo # Auto-generated
└── tools/
    └── codegen/                   # InspectMo CLI tool
```

### Setup Process

**1. Install Code Generation Tool**
```bash
# Add the InspectMo codegen tool to your project
git submodule add https://github.com/icdevs/inspect-mo.git tools/codegen
# OR copy the tools/codegen directory from inspect-mo project
```

### Codegen usage (manual)

Motoko canisters don’t support DFX prebuild hooks. Use manual code generation and run it yourself before building:

1. Ensure the codegen tool exists in `tools/codegen` (copy from this repo or add as a submodule).
2. Add a script in your `package.json`:

```json
{
  "scripts": {
    "codegen": "cd tools/codegen && npx ts-node src/cli.ts discover ../../ --generate"
  }
}
```

3. Run codegen before you build:

```bash
npm run codegen
dfx build
```

### Code Generation Flow

```bash
# Run discovery and generation
npm run codegen
# Then build your canisters
dfx build
```

**Discovery Output:**
```
🔍 Auto-discovering project structure in: ../../
📁 Found src/declarations - using as primary source for .did files

📊 Project Analysis:
   • 3 .did file(s) found
   • 45 .mo file(s) found
   • 12 InspectMo usage(s) detected

📄 Candid Files:
   • src/declarations/main/main.did
   • src/declarations/user_service/user_service.did
   • src/declarations/auth_service/auth_service.did

� Generating boilerplate for discovered .did files...
   ✅ Generated: ../../src/generated/main-inspect.mo
   ✅ Generated: ../../src/generated/user_service-inspect.mo
   ✅ Generated: ../../src/generated/auth_service-inspect.mo

✅ Discovery complete!
```

### Generated Code Example

**Generated: src/generated/user_service-inspect.mo**
```motoko
// Auto-generated InspectMo validation helpers for user_service
// Source: src/declarations/user_service/user_service.did
// Generated at: 2025-08-25T15:25:07Z

import InspectMo "mo:inspect-mo";

module UserServiceInspect {

  // Message type for user_service canister
  public type MessageAccessor = {
    #create_user : (Text, Text);     // (username, email)
    #update_profile : (Text, ?Text); // (bio, avatar_url)
    #get_user : (Principal);         // (user_id)
  };

  // Delegated accessor functions - implement these in your canister
  public func getUsername(args: (Text, Text)): Text { args.0 };
  public func getEmail(args: (Text, Text)): Text { args.1 };
  public func getBio(args: (Text, ?Text)): Text { args.0 };
  public func getAvatarUrl(args: (Text, ?Text)): ?Text { args.1 };
  public func getUserId(args: (Principal,)): Principal { args.0 };

  // Pre-configured validation rules for create_user
  public func validateCreateUser() : [InspectMo.ValidationRule<MessageAccessor, (Text, Text)>] {
    [
      InspectMo.textSize<MessageAccessor, (Text, Text)>(getUsername, ?3, ?50),  // Username 3-50 chars
      InspectMo.textSize<MessageAccessor, (Text, Text)>(getEmail, ?5, ?254),    // Email 5-254 chars
      InspectMo.requireAuth<MessageAccessor, (Text, Text)>()
    ]
  };

  // Pre-configured validation rules for update_profile  
  public func validateUpdateProfile() : [InspectMo.ValidationRule<MessageAccessor, (Text, ?Text)>] {
    [
      InspectMo.textSize<MessageAccessor, (Text, ?Text)>(getBio, ?1, ?500),     // Bio 1-500 chars
      InspectMo.requireAuth<MessageAccessor, (Text, ?Text)>()
    ]
  };

  // Message extraction helper
  public func extractMessage(method_name: Text, arg: Blob) : ?MessageAccessor {
    switch (method_name) {
      case ("create_user") {
        switch (from_candid(arg) : ?(Text, Text)) {
          case (?args) ?#create_user(args);
          case null null;
        }
      };
      case ("update_profile") {
        switch (from_candid(arg) : ?(Text, ?Text)) {
          case (?args) ?#update_profile(args);
          case null null;
        }
      };
      case ("get_user") {
        switch (from_candid(arg) : ?(Principal,)) {
          case (?args) ?#get_user(args.0);
          case null null;
        }
      };
      case (_) null;
    }
  };
}
```

### Using Generated Code

**In your user_service.mo:**
```motoko
import InspectMo "mo:inspect-mo";
import UserServiceInspect "../generated/user_service-inspect";

actor UserService {
  type MessageAccessor = UserServiceInspect.MessageAccessor;

  private let inspector = InspectMo.createInspector<MessageAccessor>();

  // Use generated validation rules
  let createUserInfo = inspector.createMethodGuardInfo<(Text, Text)>(
    "create_user",
    false, // isQuery
    UserServiceInspect.validateCreateUser(),
    func(msg: MessageAccessor) : (Text, Text) = switch(msg) {
      case (#create_user(username, email)) (username, email);
      case (_) Debug.trap("Wrong message type");
    }
  );
  inspector.inspect(createUserInfo);

  // Your implementation
  public shared(msg) func create_user(username: Text, email: Text): async () {
    // Validation happens automatically at boundary via inspect_message
    // Implementation here...
  };

  // System function using generated helper
  system func inspect({
    caller : Principal;
    method_name : Text;
    arg : Blob;
    msg : MessageAccessor;
  }) : Bool {
    switch (UserServiceInspect.extractMessage(method_name, arg)) {
      case (?extractedMsg) {
        let args : InspectMo.InspectArgs<MessageAccessor> = {
          methodName = method_name;
          caller = caller;
          arg = arg;
          isQuery = false;
          cycles = null;
          deadline = null;
          isInspect = true;
          msg = extractedMsg;
        };
        
        switch (inspector.inspectCheck(args)) {
          case (#ok) true;
          case (#err(_)) false;
        }
      };
      case null false; // Unknown method
    }
  };
}
```

### CI/CD Integration

**GitHub Actions Example:**
```yaml
name: Build and Test
on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '18'
          
      - name: Install DFX
        run: |
          wget -O dfx.tar.gz "https://github.com/dfinity/sdk/releases/download/0.15.1/dfx-0.15.1-x86_64-linux.tar.gz"
          tar -xzf dfx.tar.gz
          sudo mv dfx /usr/local/bin/
          
      - name: Build canisters
  run: npm run codegen && dfx build  # Manual codegen then build
        
      - name: Run tests
        run: |
          mops test
          npm test
```

### Mops Integration Limitation

**Important**: mops.toml does not support build hooks. For mops-only projects:

```bash
# Manual workflow required
npm run codegen  # Generate code first
mops test        # Then run tests
```

**package.json scripts for mops projects:**
```json
{
  "scripts": {
    "codegen": "cd tools/codegen && npx ts-node src/cli.ts discover ../../ --generate",
    "test": "npm run codegen && mops test",
    "build": "npm run codegen && echo 'Code generation complete'"
  }
}
```

This example demonstrates how InspectMo's build system integration streamlines the development workflow, automatically generating type-safe validation code whenever you build your canisters.

These examples demonstrate how Inspect-Mo can be used to secure various types of canisters while maintaining clean, readable code and excellent performance.
