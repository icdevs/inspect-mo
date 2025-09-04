import {test} "mo:test/async";
import InspectMo "../src/core/inspector";
import Principal "mo:core/Principal";
import Text "mo:core/Text";
import Debug "mo:core/Debug";
import Array "mo:core/Array";
import Nat "mo:core/Nat";
import ClassPlusLib "mo:class-plus";
import TT "mo:timer-tool";

/// Comprehensive runtime validation rules test suite using ErasedValidator pattern
/// Tests all runtime rule types and error handling

persistent actor {

// Runtime validation argument types
type EmailArgs = { email: Text };
type PasswordArgs = { password: Text };
type AdminArgs = { action: Text };
type JsonArgs = { data: Text };
type ConditionalArgs = { action: Text };
type ContentArgs = { content: Text };
type TextValidationArgs = { text: Text };
type BlobValidationArgs = { data: Blob };
type AuthTestArgs = { content: Text };
type CombinedArgs = { email: Text };
type ErrorTestArgs = { input: Text };

// Runtime Args union type
type Args = {
  #email_validation: EmailArgs;
  #password_validation: PasswordArgs;
  #admin_validation: AdminArgs;
  #json_validation: JsonArgs;
  #conditional_validation: ConditionalArgs;
  #content_validation: ContentArgs;
  #text_runtime: TextValidationArgs;
  #blob_runtime: BlobValidationArgs;
  #auth_test: AuthTestArgs;
  #combined_runtime: CombinedArgs;
  #error_test: ErrorTestArgs;
};

transient let testPrincipal = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
transient let adminPrincipal = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");

  // Timer tool setup following main.mo pattern
  transient let initManager = ClassPlusLib.ClassPlusInitializationManager(
    Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"), 
    Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"), 
    false
  );
  stable var tt_migration_state: TT.State = TT.Migration.migration.initialState;

  transient let tt = TT.Init<system>({
    manager = initManager;
    initialState = tt_migration_state;
    args = null;
    pullEnvironment = ?(func() : TT.Environment {
      {      
        advanced = ?{
          icrc85 = ?{
            asset = null;
            collector = null;
            handler = null;
            kill_switch = null;
            period = ?3600;
            platform = null;
            tree = null;
          };
        };
        reportExecution = null;
        reportError = null;
        syncUnsafe = null;
        reportBatch = null;
      };
    });
    onInitialize = ?(func (newClass: TT.TimerTool) : async* () {
      newClass.initialize<system>();
    });
    onStorageChange = func(state: TT.State) {
      tt_migration_state := state;
    };
  });

  // Create proper environment for ICRC85 and TimerTool following main.mo pattern
  func createEnvironment() : InspectMo.Environment {
    {
      tt = tt();
      advanced = ?{
        icrc85 = ?{
          asset = null;
          collector = null;
          handler = null;
          kill_switch = null;
          period = ?3600;
          platform = null;
          tree = null;
        };
      };
      log = null;
    };
  };

  // Create main inspector following main.mo pattern
  stable var inspector_migration_state: InspectMo.State = InspectMo.initialState();

  transient let inspector = InspectMo.Init<system>({
    manager = initManager;
    initialState = inspector_migration_state;
    args = ?{
      allowAnonymous = ?true; // Allow for runtime testing
      defaultMaxArgSize = ?1024;
      authProvider = null;
      rateLimit = null;
      queryDefaults = null;
      updateDefaults = null;
      developmentMode = true;
      auditLog = false;
    };
    pullEnvironment = ?(func() : InspectMo.Environment {
      createEnvironment()
    });
    onInitialize = null;
    onStorageChange = func(state: InspectMo.State) {
      inspector_migration_state := state;
    };
  });

transient let defaultConfig : InspectMo.InitArgs = {
  allowAnonymous = ?true; // Allow for runtime testing
  defaultMaxArgSize = ?1024;
  authProvider = null;
  rateLimit = null;
  queryDefaults = null;
  updateDefaults = null;
  developmentMode = true;
  auditLog = false;
};

  // Create test inspector variants for different configs

  // Create test inspector variants for different configs
  private func createTestInspector() : InspectMo.InspectMo {
    // For tests, we can just return the main inspector since it has proper environment
    inspector()
  };

// Helper functions for default args
let defaultEmailArgs : EmailArgs = { email = "default@example.com" };
let defaultPasswordArgs : PasswordArgs = { password = "defaultpass" };
let defaultAdminArgs : AdminArgs = { action = "default" };
let defaultJsonArgs : JsonArgs = { data = "{}" };
let defaultConditionalArgs : ConditionalArgs = { action = "read" };
let defaultContentArgs : ContentArgs = { content = "default" };
let defaultTextValidationArgs : TextValidationArgs = { text = "default" };
let defaultBlobValidationArgs : BlobValidationArgs = { data = Text.encodeUtf8("default") };
let defaultAuthTestArgs : AuthTestArgs = { content = "default" };
let defaultCombinedArgs : CombinedArgs = { email = "default@example.com" };
let defaultErrorTestArgs : ErrorTestArgs = { input = "default" };

Debug.print("🎉 ALL RUNTIME VALIDATION TESTS COMPLETED! 🎉");

public func runTests() : async () {
  await test("customCheck runtime validation - business logic", func() : async () {
  Debug.print("Testing customCheck runtime validation...");
  
  let inspector = createTestInspector();
  let customInspector = inspector.createInspector<Args>();
  
  // Test custom business logic validation
  customInspector.inspect(customInspector.createMethodGuardInfo<EmailArgs>(
    "email_validation",
    false,
    [
      #customCheck(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (args.args) {
          case (#email_validation(emailArgs)) {
            let email = emailArgs.email;
            if (Text.contains(email, #text "@") and Text.contains(email, #text ".")) {
              #ok
            } else {
              #err("CUSTOM_ERROR: Invalid email format")
            }
          };
          case (_) #err("Invalid argument type");
        };
      })
    ],
    func(args: Args): EmailArgs {
      switch (args) {
        case (#email_validation(emailArgs)) emailArgs;
        case (_) defaultEmailArgs;
      }
    }
  ));
  
  customInspector.inspect(customInspector.createMethodGuardInfo<PasswordArgs>(
    "password_strength",
    false,
    [
      #customCheck(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (args.args) {
          case (#password_validation(passwordArgs)) {
            let password = passwordArgs.password;
            if (Text.size(password) >= 8) {
              #ok
            } else {
              #err("CUSTOM_ERROR: Password must be at least 8 characters")
            }
          };
          case (_) #err("Invalid argument type");
        };
      })
    ],
    func(args: Args): PasswordArgs {
      switch (args) {
        case (#password_validation(passwordArgs)) passwordArgs;
        case (_) defaultPasswordArgs;
      }
    }
  ));
  
  customInspector.inspect(customInspector.createMethodGuardInfo<AdminArgs>(
    "admin_only",
    false,
    [
      #customCheck(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        if (args.caller == adminPrincipal) {
          #ok
        } else {
          #err("CUSTOM_ERROR: Admin access required")
        }
      })
    ],
    func(args: Args): AdminArgs {
      switch (args) {
        case (#admin_validation(adminArgs)) adminArgs;
        case (_) defaultAdminArgs;
      }
    }
  ));
  
  // Test valid cases
  let validEmailArgs : InspectMo.InspectArgs<Args> = {
    methodName = "email_validation";
    caller = testPrincipal;
    arg = Text.encodeUtf8("test email");
    msg = #email_validation({ email = "user@example.com" });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (customInspector.inspectCheck(validEmailArgs)) {
    case (#ok) Debug.print("✓ Valid email passed");
    case (#err(msg)) {
      Debug.print("❌ Valid email should have passed: " # msg);
      assert false;
    };
  };
  
  let validPasswordArgs : InspectMo.InspectArgs<Args> = {
    methodName = "password_strength";
    caller = testPrincipal;
    arg = Text.encodeUtf8("password test");
    msg = #password_validation({ password = "strongpassword123" });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (customInspector.inspectCheck(validPasswordArgs)) {
    case (#ok) Debug.print("✓ Valid password passed");
    case (#err(msg)) {
      Debug.print("❌ Valid password should have passed: " # msg);
      assert false;
    };
  };
  
  let adminAccessArgs : InspectMo.InspectArgs<Args> = {
    methodName = "admin_only";
    caller = adminPrincipal;
    arg = Text.encodeUtf8("admin test");
    msg = #admin_validation({ action = "admin_action" });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (customInspector.inspectCheck(adminAccessArgs)) {
    case (#ok) Debug.print("✓ Admin access passed");
    case (#err(msg)) {
      Debug.print("❌ Admin access should have passed: " # msg);
      assert false;
    };
  };
  
  // Test invalid cases
  let invalidEmailArgs : InspectMo.InspectArgs<Args> = {
    methodName = "email_validation";
    caller = testPrincipal;
    arg = Text.encodeUtf8("invalid email");
    msg = #email_validation({ email = "invalid-email" });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (customInspector.inspectCheck(invalidEmailArgs)) {
    case (#err(msg)) {
      assert(Text.contains(msg, #text "CUSTOM_ERROR"));
      Debug.print("✓ Email validation error: " # msg);
    };
    case (#ok) { 
      Debug.print("❌ Invalid email should have been rejected");
      assert false; 
    };
  };
  
  let weakPasswordArgs : InspectMo.InspectArgs<Args> = {
    methodName = "password_strength";
    caller = testPrincipal;
    arg = Text.encodeUtf8("weak password");
    msg = #password_validation({ password = "weak" });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (customInspector.inspectCheck(weakPasswordArgs)) {
    case (#err(msg)) {
      assert(Text.contains(msg, #text "CUSTOM_ERROR"));
      Debug.print("✓ Password validation error: " # msg);
    };
    case (#ok) { 
      Debug.print("❌ Weak password should have been rejected");
      assert false; 
    };
  };
  
  let nonAdminArgs : InspectMo.InspectArgs<Args> = {
    methodName = "admin_only";
    caller = testPrincipal;
    arg = Text.encodeUtf8("non-admin test");
    msg = #admin_validation({ action = "admin_action" });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (customInspector.inspectCheck(nonAdminArgs)) {
    case (#err(msg)) {
      assert(Text.contains(msg, #text "CUSTOM_ERROR"));
      Debug.print("✓ Admin validation error: " # msg);
    };
    case (#ok) { 
      Debug.print("❌ Non-admin should have been rejected");
      assert false; 
    };
  };
  
  Debug.print("✓ Custom check runtime validation tests passed");
});

await test("customCheck runtime validation - complex scenarios", func() : async () {
  Debug.print("Testing complex customCheck scenarios...");
  
  let inspector = createTestInspector();
  let complexInspector = inspector.createInspector<Args>();
  
  // Test JSON-like validation
  complexInspector.inspect(complexInspector.createMethodGuardInfo<JsonArgs>(
    "json_validation",
    false,
    [
      #customCheck(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (args.args) {
          case (#json_validation(jsonArgs)) {
            let data = jsonArgs.data;
            if (Text.startsWith(data, #text "{") and Text.endsWith(data, #text "}")) {
              #ok
            } else {
              #err("CUSTOM_ERROR: Invalid JSON format")
            }
          };
          case (_) #err("Invalid argument type");
        };
      })
    ],
    func(args: Args): JsonArgs {
      switch (args) {
        case (#json_validation(jsonArgs)) jsonArgs;
        case (_) defaultJsonArgs;
      }
    }
  ));
  
  // Test conditional validation based on caller
  complexInspector.inspect(complexInspector.createMethodGuardInfo<ConditionalArgs>(
    "conditional_access",
    false,
    [
      #customCheck(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (args.args) {
          case (#conditional_validation(conditionalArgs)) {
            let action = conditionalArgs.action;
            if (action == "read") {
              #ok // Anyone can read
            } else if (action == "write" and args.caller == adminPrincipal) {
              #ok // Only admin can write
            } else {
              #err("CUSTOM_ERROR: Insufficient permissions for " # action)
            }
          };
          case (_) #err("Invalid argument type");
        };
      })
    ],
    func(args: Args): ConditionalArgs {
      switch (args) {
        case (#conditional_validation(conditionalArgs)) conditionalArgs;
        case (_) defaultConditionalArgs;
      }
    }
  ));
  
  // Test argument length with caller context
  complexInspector.inspect(complexInspector.createMethodGuardInfo<ContentArgs>(
    "context_aware",
    false,
    [
      #customCheck(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (args.args) {
          case (#content_validation(contentArgs)) {
            let content = contentArgs.content;
            let maxLen = if (args.caller == adminPrincipal) 1000 else 100;
            if (Text.size(content) <= maxLen) {
              #ok
            } else {
              #err("CUSTOM_ERROR: Content too long for caller role")
            }
          };
          case (_) #err("Invalid argument type");
        };
      })
    ],
    func(args: Args): ContentArgs {
      switch (args) {
        case (#content_validation(contentArgs)) contentArgs;
        case (_) defaultContentArgs;
      }
    }
  ));
  
  // Test valid cases
  let validJsonArgs : InspectMo.InspectArgs<Args> = {
    methodName = "json_validation";
    caller = testPrincipal;
    arg = Text.encodeUtf8("json test");
    msg = #json_validation({ data = "{\"key\": \"value\"}" });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (complexInspector.inspectCheck(validJsonArgs)) {
    case (#ok) Debug.print("✓ Valid JSON passed");
    case (#err(msg)) {
      Debug.print("❌ Valid JSON should have passed: " # msg);
      assert false;
    };
  };
  
  let readAccessArgs : InspectMo.InspectArgs<Args> = {
    methodName = "conditional_access";
    caller = testPrincipal;
    arg = Text.encodeUtf8("read test");
    msg = #conditional_validation({ action = "read" });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (complexInspector.inspectCheck(readAccessArgs)) {
    case (#ok) Debug.print("✓ Read access passed");
    case (#err(msg)) {
      Debug.print("❌ Read access should have passed: " # msg);
      assert false;
    };
  };
  
  let adminWriteArgs : InspectMo.InspectArgs<Args> = {
    methodName = "conditional_access";
    caller = adminPrincipal;
    arg = Text.encodeUtf8("write test");
    msg = #conditional_validation({ action = "write" });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (complexInspector.inspectCheck(adminWriteArgs)) {
    case (#ok) Debug.print("✓ Admin write access passed");
    case (#err(msg)) {
      Debug.print("❌ Admin write access should have passed: " # msg);
      assert false;
    };
  };
  
  let contextAwareArgs : InspectMo.InspectArgs<Args> = {
    methodName = "context_aware";
    caller = testPrincipal;
    arg = Text.encodeUtf8("context test");
    msg = #content_validation({ content = "short content" });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (complexInspector.inspectCheck(contextAwareArgs)) {
    case (#ok) Debug.print("✓ Context aware validation passed");
    case (#err(msg)) {
      Debug.print("❌ Context aware validation should have passed: " # msg);
      assert false;
    };
  };
  
  // Test invalid cases
  let invalidJsonArgs : InspectMo.InspectArgs<Args> = {
    methodName = "json_validation";
    caller = testPrincipal;
    arg = Text.encodeUtf8("invalid json test");
    msg = #json_validation({ data = "not json" });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (complexInspector.inspectCheck(invalidJsonArgs)) {
    case (#err(msg)) {
      assert(Text.contains(msg, #text "CUSTOM_ERROR"));
      Debug.print("✓ Invalid JSON rejected: " # msg);
    };
    case (#ok) { 
      Debug.print("❌ Invalid JSON should have been rejected");
      assert false; 
    };
  };
  
  let userWriteArgs : InspectMo.InspectArgs<Args> = {
    methodName = "conditional_access";
    caller = testPrincipal;
    arg = Text.encodeUtf8("user write test");
    msg = #conditional_validation({ action = "write" });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (complexInspector.inspectCheck(userWriteArgs)) {
    case (#err(msg)) {
      assert(Text.contains(msg, #text "CUSTOM_ERROR"));
      Debug.print("✓ User write access rejected: " # msg);
    };
    case (#ok) { 
      Debug.print("❌ User write access should have been rejected");
      assert false; 
    };
  };
  
  Debug.print("✓ Complex customCheck scenarios passed");
});

/// ========================================
/// RUNTIME SIZE CHECK TESTS
/// ========================================

await test("textSizeCheck runtime validation", func() : async () {
  Debug.print("Testing textSizeCheck runtime validation...");
  
  let inspector = createTestInspector();
  let runtimeInspector = inspector.createInspector<Args>();
  
  // Test runtime text size checking
  runtimeInspector.inspect(runtimeInspector.createMethodGuardInfo<TextValidationArgs>(
    "runtime_text",
    false,
    [
      #textSize(func(args: TextValidationArgs): Text { args.text }, ?5, ?20)
    ],
    func(args: Args): TextValidationArgs {
      switch (args) {
        case (#text_runtime(textArgs)) textArgs;
        case (_) defaultTextValidationArgs;
      }
    }
  ));
  
  // Test with accessor that extracts part of text
  runtimeInspector.inspect(runtimeInspector.createMethodGuardInfo<TextValidationArgs>(
    "prefix_check",
    false,
    [
      #textSize(
        func(args: TextValidationArgs): Text { 
          // Extract first 10 characters for validation
          let chars = Text.toArray(args.text);
          if (chars.size() <= 10) {
            args.text
          } else {
            let first10 = Array.tabulate<Char>(10, func(i: Nat): Char { chars[i] });
            Text.fromArray(first10)
          }
        },
        ?1, ?10
      )
    ],
    func(args: Args): TextValidationArgs {
      switch (args) {
        case (#text_runtime(textArgs)) textArgs;
        case (_) defaultTextValidationArgs;
      }
    }
  ));
  
  // Test valid cases
  let validTextArgs : InspectMo.InspectArgs<Args> = {
    methodName = "runtime_text";
    caller = testPrincipal;
    arg = Text.encodeUtf8("text test");
    msg = #text_runtime({ text = "hello world" });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (runtimeInspector.inspectCheck(validTextArgs)) {
    case (#ok) Debug.print("✓ Valid runtime text passed");
    case (#err(msg)) {
      Debug.print("❌ Valid runtime text should have passed: " # msg);
      assert false;
    };
  };
  
  let prefixArgs : InspectMo.InspectArgs<Args> = {
    methodName = "prefix_check";
    caller = testPrincipal;
    arg = Text.encodeUtf8("prefix test");
    msg = #text_runtime({ text = "short" });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (runtimeInspector.inspectCheck(prefixArgs)) {
    case (#ok) Debug.print("✓ Prefix check passed");
    case (#err(msg)) {
      Debug.print("❌ Prefix check should have passed: " # msg);
      assert false;
    };
  };
  
  let longPrefixArgs : InspectMo.InspectArgs<Args> = {
    methodName = "prefix_check";
    caller = testPrincipal;
    arg = Text.encodeUtf8("long prefix test");
    msg = #text_runtime({ text = "this is a very long text but only first 10 chars matter" });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (runtimeInspector.inspectCheck(longPrefixArgs)) {
    case (#ok) Debug.print("✓ Long prefix check passed (truncated to 10 chars)");
    case (#err(msg)) {
      Debug.print("❌ Long prefix check should have passed: " # msg);
      assert false;
    };
  };
  
  // Test invalid cases
  let shortTextArgs : InspectMo.InspectArgs<Args> = {
    methodName = "runtime_text";
    caller = testPrincipal;
    arg = Text.encodeUtf8("short test");
    msg = #text_runtime({ text = "hi" });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (runtimeInspector.inspectCheck(shortTextArgs)) {
    case (#err(msg)) Debug.print("✓ Too short text rejected: " # msg);
    case (#ok) { 
      Debug.print("❌ Too short text should have been rejected");
      assert false; 
    };
  };
  
  let longTextArgs : InspectMo.InspectArgs<Args> = {
    methodName = "runtime_text";
    caller = testPrincipal;
    arg = Text.encodeUtf8("long text test");
    msg = #text_runtime({ text = "this text is definitely too long for the validation rule" });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (runtimeInspector.inspectCheck(longTextArgs)) {
    case (#err(msg)) Debug.print("✓ Too long text rejected: " # msg);
    case (#ok) { 
      Debug.print("❌ Too long text should have been rejected");
      assert false; 
    };
  };
  
  Debug.print("✓ TextSizeCheck runtime validation tests passed");
});

await test("blobSizeCheck runtime validation", func() : async () {
  Debug.print("Testing blobSizeCheck runtime validation...");
  
  let inspector = createTestInspector();
  let blobInspector = inspector.createInspector<Args>();
  
  // Test runtime blob size checking
  blobInspector.inspect(blobInspector.createMethodGuardInfo<BlobValidationArgs>(
    "runtime_blob",
    false,
    [
      #blobSize(func(args: BlobValidationArgs): Blob { args.data }, ?1, ?20)
    ],
    func(args: Args): BlobValidationArgs {
      switch (args) {
        case (#blob_runtime(blobArgs)) blobArgs;
        case (_) defaultBlobValidationArgs;
      }
    }
  ));
  
  // Create test blobs
  let smallBlob = Text.encodeUtf8("small");
  let mediumBlob = Text.encodeUtf8("medium sized blob");
  let largeBlob = Text.encodeUtf8("this is a very large blob that exceeds the size limit");
  
  // Test valid cases
  let validBlobArgs : InspectMo.InspectArgs<Args> = {
    methodName = "runtime_blob";
    caller = testPrincipal;
    arg = Text.encodeUtf8("blob test");
    msg = #blob_runtime({ data = smallBlob });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (blobInspector.inspectCheck(validBlobArgs)) {
    case (#ok) Debug.print("✓ Valid blob size passed");
    case (#err(msg)) {
      Debug.print("❌ Valid blob should have passed: " # msg);
      assert false;
    };
  };
  
  let mediumBlobArgs : InspectMo.InspectArgs<Args> = {
    methodName = "runtime_blob";
    caller = testPrincipal;
    arg = Text.encodeUtf8("medium blob test");
    msg = #blob_runtime({ data = mediumBlob });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (blobInspector.inspectCheck(mediumBlobArgs)) {
    case (#ok) Debug.print("✓ Medium blob size passed");
    case (#err(msg)) {
      Debug.print("❌ Medium blob should have passed: " # msg);
      assert false;
    };
  };
  
  // Test invalid cases
  let largeBlobArgs : InspectMo.InspectArgs<Args> = {
    methodName = "runtime_blob";
    caller = testPrincipal;
    arg = Text.encodeUtf8("large blob test");
    msg = #blob_runtime({ data = largeBlob });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (blobInspector.inspectCheck(largeBlobArgs)) {
    case (#err(msg)) Debug.print("✓ Too large blob rejected: " # msg);
    case (#ok) { 
      Debug.print("❌ Too large blob should have been rejected");
      assert false; 
    };
  };
  
  Debug.print("✓ BlobSizeCheck runtime validation tests passed");
});

/// ========================================
/// COMBINED RUNTIME RULES TESTS
/// ========================================

await test("combined runtime validation rules", func() : async () {
  Debug.print("Testing combined runtime validation rules...");
  
  let inspector = createTestInspector();
  let combinedInspector = inspector.createInspector<Args>();
  
  // Combine multiple runtime rules
  combinedInspector.inspect(combinedInspector.createMethodGuardInfo<CombinedArgs>(
    "complex_validation",
    false,
    [
      #textSize(func(args: CombinedArgs): Text { args.email }, ?5, ?100),
      #customCheck(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (args.args) {
          case (#combined_runtime(combinedArgs)) {
            if (Text.contains(combinedArgs.email, #text "@")) {
              #ok
            } else {
              #err("CUSTOM_ERROR: Invalid email format")
            }
          };
          case (_) #err("Invalid argument type");
        };
      }),
      #customCheck(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (args.caller) {
          case (caller) {
            if (caller != Principal.fromText("2vxsx-fae")) {
              #ok
            } else {
              #err("CUSTOM_ERROR: Anonymous access not allowed")
            }
          };
        }
      })
    ],
    func(args: Args): CombinedArgs {
      switch (args) {
        case (#combined_runtime(combinedArgs)) combinedArgs;
        case (_) defaultCombinedArgs;
      }
    }
  ));
  
  // Test valid case (all rules pass)
  let validCombinedArgs : InspectMo.InspectArgs<Args> = {
    methodName = "complex_validation";
    caller = testPrincipal;
    arg = Text.encodeUtf8("combined test");
    msg = #combined_runtime({ email = "user@example.com" });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (combinedInspector.inspectCheck(validCombinedArgs)) {
    case (#ok) Debug.print("✓ Combined validation passed");
    case (#err(msg)) {
      Debug.print("❌ Combined validation should have passed: " # msg);
      assert false;
    };
  };
  
  // Test invalid cases (each rule fails individually)
  
  // Size too small
  let shortEmailArgs : InspectMo.InspectArgs<Args> = {
    methodName = "complex_validation";
    caller = testPrincipal;
    arg = Text.encodeUtf8("short test");
    msg = #combined_runtime({ email = "a@b" });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (combinedInspector.inspectCheck(shortEmailArgs)) {
    case (#err(msg)) Debug.print("✓ Short email rejected: " # msg);
    case (#ok) { 
      Debug.print("❌ Short email should have been rejected");
      assert false; 
    };
  };
  
  // Missing @ symbol
  let noAtEmailArgs : InspectMo.InspectArgs<Args> = {
    methodName = "complex_validation";
    caller = testPrincipal;
    arg = Text.encodeUtf8("no at test");
    msg = #combined_runtime({ email = "valid length text" });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (combinedInspector.inspectCheck(noAtEmailArgs)) {
    case (#err(msg)) {
      assert(Text.contains(msg, #text "CUSTOM_ERROR"));
      Debug.print("✓ No @ symbol rejected: " # msg);
    };
    case (#ok) { 
      Debug.print("❌ No @ symbol should have been rejected");
      assert false; 
    };
  };
  
  // Anonymous caller
  let anonCombinedArgs : InspectMo.InspectArgs<Args> = {
    methodName = "complex_validation";
    caller = Principal.fromText("2vxsx-fae");
    arg = Text.encodeUtf8("anon test");
    msg = #combined_runtime({ email = "user@example.com" });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (combinedInspector.inspectCheck(anonCombinedArgs)) {
    case (#err(msg)) {
      assert(Text.contains(msg, #text "CUSTOM_ERROR"));
      Debug.print("✓ Anonymous caller rejected: " # msg);
    };
    case (#ok) { 
      Debug.print("❌ Anonymous caller should have been rejected");
      assert false; 
    };
  };
  
  Debug.print("✓ Combined runtime validation rules tests passed");
});

/// ========================================
/// ERROR HANDLING TESTS
/// ========================================

await test("runtime rule error handling and propagation", func() : async () {
  Debug.print("Testing runtime rule error handling...");
  
  let inspector = createTestInspector();
  let errorInspector = inspector.createInspector<Args>();
  
  // Test detailed error messages
  errorInspector.inspect(errorInspector.createMethodGuardInfo<ErrorTestArgs>(
    "detailed_errors",
    false,
    [
      #customCheck(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        switch (args.args) {
          case (#error_test(errorArgs)) {
            let input = errorArgs.input;
            if (Text.size(input) == 0) {
              #err("Input cannot be empty")
            } else if (Text.size(input) > 50) {
              #err("Input too long (max 50 characters)")
            } else if (Text.contains(input, #text "forbidden")) {
              #err("Forbidden content detected")
            } else {
              #ok
            }
          };
          case (_) #err("Invalid argument type");
        };
      })
    ],
    func(args: Args): ErrorTestArgs {
      switch (args) {
        case (#error_test(errorArgs)) errorArgs;
        case (_) defaultErrorTestArgs;
      }
    }
  ));
  
  // Test error propagation order
  errorInspector.inspect(errorInspector.createMethodGuardInfo<ErrorTestArgs>(
    "error_order",
    false,
    [
      #customCheck(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        #err("First error")
      }),
      #customCheck(func(args: InspectMo.CustomCheckArgs<Args>): InspectMo.GuardResult {
        #err("Second error - should not reach here")
      })
    ],
    func(args: Args): ErrorTestArgs {
      switch (args) {
        case (#error_test(errorArgs)) errorArgs;
        case (_) defaultErrorTestArgs;
      }
    }
  ));
  
  // Test specific error messages
  let emptyInputArgs : InspectMo.InspectArgs<Args> = {
    methodName = "detailed_errors";
    caller = testPrincipal;
    arg = Text.encodeUtf8("empty test");
    msg = #error_test({ input = "" });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (errorInspector.inspectCheck(emptyInputArgs)) {
    case (#err(msg)) {
      assert(Text.contains(msg, #text "Input cannot be empty"));
      Debug.print("✓ Empty input error: " # msg);
    };
    case (#ok) { 
      Debug.print("❌ Empty input should have been rejected");
      assert false; 
    };
  };
  
  let longInputArgs : InspectMo.InspectArgs<Args> = {
    methodName = "detailed_errors";
    caller = testPrincipal;
    arg = Text.encodeUtf8("long input test");
    msg = #error_test({ input = "this is a very long input that definitely exceeds the fifty character limit for testing purposes" });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (errorInspector.inspectCheck(longInputArgs)) {
    case (#err(msg)) {
      assert(Text.contains(msg, #text "Input too long"));
      Debug.print("✓ Long input error: " # msg);
    };
    case (#ok) { 
      Debug.print("❌ Long input should have been rejected");
      assert false; 
    };
  };
  
  let forbiddenInputArgs : InspectMo.InspectArgs<Args> = {
    methodName = "detailed_errors";
    caller = testPrincipal;
    arg = Text.encodeUtf8("forbidden test");
    msg = #error_test({ input = "forbidden content here" });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (errorInspector.inspectCheck(forbiddenInputArgs)) {
    case (#err(msg)) {
      assert(Text.contains(msg, #text "Forbidden content"));
      Debug.print("✓ Forbidden content error: " # msg);
    };
    case (#ok) { 
      Debug.print("❌ Forbidden content should have been rejected");
      assert false; 
    };
  };
  
  // Test error order (first error should be returned)
  let errorOrderArgs : InspectMo.InspectArgs<Args> = {
    methodName = "error_order";
    caller = testPrincipal;
    arg = Text.encodeUtf8("error order test");
    msg = #error_test({ input = "test" });
    isQuery = false;
    isInspect = false;
    cycles = ?0;
    deadline = null;
  };
  
  switch (errorInspector.inspectCheck(errorOrderArgs)) {
    case (#err(msg)) {
      assert(Text.contains(msg, #text "First error"));
      Debug.print("✓ First error returned: " # msg);
    };
    case (#ok) { 
      Debug.print("❌ Error order test should have failed");
      assert false; 
    };
  };
  
  Debug.print("✓ Runtime rule error handling tests passed");
});

  Debug.print("🎉 ALL RUNTIME VALIDATION TESTS COMPLETED! 🎉");
  };

}
