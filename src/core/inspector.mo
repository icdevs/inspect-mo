// Core InspectMo library - main entry point with Class Plus integration
import MigrationTypes "../migrations/types";

import SizeValidator "./size_validator";
import RateLimiter "../security/rate_limiter";
import ICRC16Rules "../utils/icrc16_validation_rules";
import CandyTypes "mo:candy/types";

// Class Plus and infrastructure imports

import MigrationLib "../migrations";
import ClassPlusLib "mo:class-plus";
// removed unused imports
import D "mo:core/Debug";
import Star "mo:star/star";
import ovsfixed "mo:ovs-fixed";
import Int "mo:core/Int";
// removed unused imports
import Principal "mo:core/Principal";
import Blob "mo:core/Blob";
import Nat "mo:core/Nat";
import Text "mo:core/Text";
import Array "mo:core/Array";
import Result "mo:core/Result";
// removed unused imports
import TimerToolLib "mo:timer-tool";
// removed unused imports

// Basic validation imports
import BTree "mo:core/Map";
import Runtime "mo:core/Runtime";
import Map "mo:core/Map";

module {

  let Types = MigrationTypes.Current;
  // ========================================
  // CLASS-PLUS INFRASTRUCTURE (PRESERVED)
  // ========================================

  public let Migration = MigrationLib;
  public let TT = MigrationLib.TimerTool;
  public type State = MigrationTypes.State;
  public type CurrentState = MigrationTypes.Current.State;
  public type Environment = MigrationTypes.Current.Environment;
  public type Stats = MigrationTypes.Current.Stats;
  public type InitArgs = MigrationTypes.Current.InitArgs;
  public type RateLimitConfig = RateLimiter.RateLimitConfig;
  public type AuthProvider = MigrationTypes.Current.AuthProvider;

  public let init = Migration.migrate;

  public func initialState() : State {#v0_0_0(#data)};
  public let currentStateVersion = #v0_1_0(#id);


  public let ICRC85_Timer_Namespace = "icrc85:ovs:shareaction:inspect-mo";
  public let ICRC85_Payment_Namespace = "org.icdevs.libraries.inspect-mo";

  public let EmptyGuardBlob : Blob = "";

  // ========================================
  // INSPECTMO LIBRARY API
  // ========================================

  // Re-export core types
  public type ValidationRule<T,M> = Types.ValidationRule<T,M>;
  public type GuardResult = Types.GuardResult;
  public type InspectArgs<T> = Types.InspectArgs<T>;
  public type CustomCheckArgs<T> = Types.CustomCheckArgs<T>;
  public type DynamicAuthArgs<T> = Types.DynamicAuthArgs<T>;

  /// Initialize a new inspector with Class Plus integration
  public func Init<system>(config : {
    manager: ClassPlusLib.ClassPlusInitializationManager;
    initialState: State;
    args : ?InitArgs;  // Use stable args for actor initialization

    pullEnvironment : ?(() -> Environment);
    onInitialize: ?(InspectMo -> async*());
    onStorageChange : ((State) ->());
    
  }) :()-> InspectMo {

  let envToUse = switch(config.pullEnvironment) {
    case (?pullEnv) ?pullEnv;
    case null {
      Runtime.trap("InspectMo: No Environment Provided");
    };
  };

  let instance = ClassPlusLib.ClassPlus<system,
      InspectMo, 
      State,
      InitArgs,
      Environment>({
        manager = config.manager;
        initialState = config.initialState;
        args = config.args;
        pullEnvironment = envToUse;
        onInitialize = config.onInitialize;
        onStorageChange = config.onStorageChange;
        constructor = func(stored, instantiator, canister, args, environment, storageChanged) {
          InspectMo(stored, instantiator, canister, args, environment, storageChanged)
        };
      }).get;

    // Use default OneDay wait for initial share action (not the ICRC85 period)
    // The period is used for recurring actions, not the initial delay
      ovsfixed.initialize_cycleShare<system>({
        namespace = ICRC85_Timer_Namespace;
        icrc_85_state = instance().state.icrc85;
        wait = null; // Use default OneDay initial wait from ovs-fixed
        registerExecutionListenerAsync = instance().environment.tt.registerExecutionListenerAsync;
        setActionSync = instance().environment.tt.setActionSync;  
        existingIndex = instance().environment.tt.getState().actionIdIndex;
        handler = instance().handleIcrc85Action;
      });

    instance;
  };

  /// Main InspectMo class with integrated Inspector functionality
  public class InspectMo(
    stored: ?State, 
    instantiator: Principal, 
    canister: Principal, 
    args: ?InitArgs,  // Full InitArgs (converted from stable + additional args)
    environment_passed: ?Environment,
    storageChanged: (State) -> ()
  ) {

    public let debug_channel = {
      var announce = true;
    }; 

    let inspect_config : InitArgs = switch(args){
      case(?val) val;
      case(null) {
        {
          allowAnonymous = ?false;
          defaultMaxArgSize = ?1024;
          authProvider = null;
          rateLimit = null;
          queryDefaults = null;
          updateDefaults = null;
          developmentMode = true;
          auditLog = false;
        };
      };
    };

    // Environment can change over time (e.g., tests enabling ICRC85 options).
    // Keep a mutable copy and provide a refresher.
    public var environment : Environment = switch(environment_passed) {
      case (?env) env;
      case null {
        Runtime.trap("CANISTER: TimerTool Environment: No Environment Provided");
      };
    };


    let d = switch(environment.log){
      case(?v) v.log_debug; // Commented out for test compatibility
      case null { func(a:Text, b:Text){ D.print(a # " " # b) } }
    };

    public var state : CurrentState = switch(stored){
      case(null) {
        switch(init(initialState(),currentStateVersion, null, instantiator, canister)) {
          case(#v0_1_0(#data(foundState))) foundState;
          case(#v0_1_0(#id)) Runtime.trap("Migration returned ID instead of data");
          case(#v0_0_0(_)) Runtime.trap("Unexpected migration to v0_0_0");
        };
      };
      case(?val) {
        switch(init(val, currentStateVersion, null, instantiator, canister)) {
          case(#v0_1_0(#data(foundState))) foundState;
          case(#v0_1_0(#id)) Runtime.trap("Migration returned ID instead of data");
          case(#v0_0_0(_)) Runtime.trap("Unexpected migration to v0_0_0");
        };
      };
    };

    storageChanged(#v0_1_0(#data(state)));

    

    // ========================================
    // INSPECTOR CORE FUNCTIONALITY
    // ========================================

    /// Core Inspector instance with method registration
    public class Inspector<T>(config: InitArgs) {
      // Private state for method registration
      public let inspectRules = BTree.empty<Text, Types.MethodGuardInfo<T>>();

      public let guardRules = BTree.empty<Text, Types.MethodGuardInfo<T>>();

      /// Register a method with boundary validation rules
      public func guard(item: Types.MethodGuardInfo<T>) : () {
        ignore BTree.insert(guardRules, Text.compare, item.methodName, item);
      };

      /// Register a method with boundary validation rules
      public func inspect(item: Types.MethodGuardInfo<T>) : () {
        ignore BTree.insert(inspectRules, Text.compare, item.methodName, item);
      };

      public func createMethodGuardInfo<M>(methodName: Text, isQuery: Bool, rules: [ValidationRule<T,M>], msgAccessor: (T) -> M) : Types.MethodGuardInfo<T> {
          {
          methodName = methodName;
          isQuery = isQuery;

          validator = func(msg: Types.InspectArgs<T>) : Result.Result<(), Text> {
            let typedArgs: M = msgAccessor(msg.msg);

            // run each rule and collect errors
            label proc for (rule in rules.vals()) {
              switch (validateSingleRule<M>(rule, msg, typedArgs)) {
                case (#ok) { /* ok */ };
                case (#err(errMsg)) { return #err(errMsg) };
              };
            };
            // all passed
            #ok
            
          };
        };
      };

     
      
      /// Main inspect function for boundary validation
      /// Enhanced inspect_message validation with typed message handling
      /// 
      /// Type Flow:
      /// - Inspector<T>: T is the ArgsAccessor type containing field accessor functions
      /// - inspectCheck: Called from system inspect_message with parsed message
      /// - msgAccessor: Function that extracts typed parameters from message
      /// - Validation: accessor functions in T extract fields for validation
      public func inspectCheck(args: Types.InspectArgs<T>) : Types.GuardResult {
        switch (BTree.get(inspectRules, Text.compare, args.methodName)) {
          case (?guardInfo) { 
            switch (guardInfo.validator(args)) {
              case (#ok) { #ok };
              case (#err(msg)) { 
                D.print("InspectMo: Validation failed for " # args.methodName # ": " # msg);
                #err("InspectMo: Validation failed for " # args.methodName # ": " # msg)
              };
            };
          };
          case null { 
            // No registration found - apply defaults based on call type
            applyDefaults(args)
          };
        }
      };
      
      
      
      /// Runtime validation check with typed context
      public func guardCheck(args: Types.InspectArgs<T>) : Types.GuardResult {
         state.icrc85.activeActions += 1;
         switch (BTree.get(guardRules, Text.compare, args.methodName)) {
          case (?guardInfo) { 
            switch (guardInfo.validator(args)) {
              case (#ok) { #ok };
              case (#err(msg)) { 
                D.print("InspectMo: Validation failed for " # args.methodName # ": " # msg);
                #err("InspectMo: Validation failed for " # args.methodName # ": " # msg)
              };
            };
          };
          case null { 
            // No registration found - apply defaults based on call type
            applyDefaults(args)
          };
        }
      
      };
      
      // Validate a single boundary rule
      private func validateSingleRule<M>(rule: Types.ValidationRule<T,M>, args: Types.InspectArgs<T>, typedArgs: M) : Result.Result<(),Text> {
        switch (rule) {
          case (#requireAuth) {
            if(not Principal.isAnonymous(args.caller)) {
              #ok
            } else {
              #err("requireAuth: Caller is anonymous")
            };
          };
          case (#blockAll) {
            #err("blockAll: Always reject")
          };
          case (#blockIngress) {
            if(args.isInspect){
              #err("blockIngress: Always reject")
            } else {
              #ok // Allow canister-to-canister, block ingress
            };
          };
          case (#requirePermission(permission)) {
            // Use configured auth provider if available
            let permitted = switch (config.authProvider) {
              case (?provider) {
                provider.checkPermission(args.caller, permission)
              };
              case null {
                // Fallback: just require authentication
                not Principal.isAnonymous(args.caller)
              };
            };
            if (permitted) {
              #ok
            } else {
              #err("requirePermission: Permission check failed for " # permission)
            };
          };
          case (#requireRole(role)) {
            // Use configured auth provider if available
            let allowed = switch (config.authProvider) {
              case (?provider) {
                provider.checkRole(args.caller, role)
              };
              case null {
                // Fallback: just require authentication
                not Principal.isAnonymous(args.caller)
              };
            };
            if (allowed) {
              #ok
            } else {
              #err("requireRole: role check failed for " # role)
            };
          };
              
          case (#allowedCallers(principals)) {
            // Check if caller is in whitelist
            switch(Map.get(principals, Principal.compare, args.caller)) {
              case (?_) {
                #ok
              };
              case null {
                #err("allowedCallers: Caller is not whitelisted")
              };
            };
          };
          case (#blockedCallers(principals)) {
            // Check if caller is NOT in blacklist
            switch(Map.get(principals, Principal.compare, args.caller)) {
              case (?_) {
                #err("blockedCallers: Caller is blacklisted")
              };
              case null {
                #ok
              };
            };
          };
          case (#textSize(accessor, min, max)) {
            // Use message accessor to get typed args, then call rule accessor
           
                let params = typedArgs;
                let text = accessor(params);
                switch(min,max){
                  case (?minSize, ?maxSize) {
                    if(text.size() < minSize or text.size() > maxSize) {
                      #err("textSize: text size out of bounds" # debug_show(text.size())) // Reject: text size out of bounds
                    } else {
                      #ok // Allow: exact validation happens at runtime with msgAccessor
                    };
                  };
                  case (?minSize, null) {
                    if(text.size() < minSize) {
                      #err("textSize: text size too small" # debug_show(text.size())) // Reject: text size too small
                    } else {
                      #ok // Allow: exact validation happens at runtime with msgAccessor
                    };
                  };
                  case (null, null) {
                    #ok // Allow: no size limits
                  };
                  case (null, ?maxSize) {
                    if(text.size() > maxSize) {
                      #err("textSize: text size too large" # debug_show(text.size())) // Reject: text size too large
                    } else {
                      #ok // Allow: exact validation happens at runtime with msgAccessor
                    };
                  };
                };
             
            
          };
          case (#blobSize(accessor, min, max)) {
            // Use message accessor to get typed args, then call rule accessor
           
                let params = typedArgs;
                let blob = accessor(params);
                switch(min,max){
                  case (?minSize, ?maxSize) {
                    if(blob.size() < minSize or blob.size() > maxSize) {
                      #err("blobSize: blob size out of bounds" # debug_show(blob.size())) // Reject: blob size out of bounds
                    } else {
                      #ok // Allow: blob size within bounds
                    };
                  };
                  case (?minSize, null) {
                    if(blob.size() < minSize) {
                      #err("blobSize: blob size too small" # debug_show(blob.size())) // Reject: blob size too small
                    } else {
                      #ok // Allow: blob size meets minimum
                    };
                  };
                  case (null, null) {
                    #ok // Allow: no size limits
                  };
                  case (null, ?maxSize) {
                    if(blob.size() > maxSize) {
                      #err("blobSize: blob size too large" # debug_show(blob.size())) // Reject: blob size too large
                    } else {
                       #ok // Allow: blob size under maximum
                    };
                  };
                };
              
          };
          case (#natValue(accessor, min, max)) {
            // Use message accessor to get typed args, then call rule accessor
            
                let params = typedArgs;
                let natValue = accessor(params);
                switch(min,max){
                  case (?minVal, ?maxVal) {
                    if(natValue < minVal or natValue > maxVal) {
                      #err("nat value out of bounds" # debug_show(natValue)) // Reject: nat value out of bounds
                    } else {
                      #ok // Allow: nat value within bounds
                    };
                  };
                  case (?minVal, null) {
                    if(natValue < minVal) {
                      #err("nat value too small" # debug_show(natValue)) // Reject: nat value too small
                    } else {
                      #ok // Allow: nat value meets minimum
                    };
                  };
                  case (null, null) {
                    #ok // Allow: no value limits
                  };
                  case (null, ?maxVal) {
                    if(natValue > maxVal) {
                      #err("nat value too large" # debug_show(natValue)) // Reject: nat value too large
                    } else {
                      #ok // Allow: nat value under maximum
                    };
                  };
                };
              
          };
          case (#intValue(accessor, min, max)) {
            // Use message accessor to get typed args, then call rule accessor
            
            
                let params = typedArgs;
                let intValue = accessor(params);
                switch(min,max){
                  case (?minVal, ?maxVal) {
                    if(intValue < minVal or intValue > maxVal) {
                      #err("int value out of bounds" # debug_show(intValue)) // Reject: int value out of bounds
                    } else {
                      #ok // Allow: int value within bounds
                    };
                  };
                  case (?minVal, null) {
                    if(intValue < minVal) {
                      #err("int value too small" # debug_show(intValue)) // Reject: int value too small
                    } else {
                      #ok // Allow: int value meets minimum
                    };
                  };
                  case (null, null) {
                    #ok // Allow: no value limits
                  };
                  case (null, ?maxVal) {
                    if(intValue > maxVal) {
                      #err("int value too large" # debug_show(intValue)) // Reject: int value too large
                    } else {
                      #ok // Allow: int value under maximum
                    };
                  };
                };
             
          };
      case (#rateLimit(_rateLimitRule)) {
            // Use RateLimiter if available in environment
            #ok;
          };
          case (#customCheck(checkFunc)) {
            // Execute custom check function with typed arguments
            let customArgs : Types.CustomCheckArgs<T> = {
              args = args.msg;
              caller = args.caller;
              cycles = args.cycles;
              deadline = args.deadline;
            };
            checkFunc(customArgs)
          };
          case (#dynamicAuth(authFunc)) {
            // Execute dynamic auth function with typed arguments
            let authArgs : Types.DynamicAuthArgs<T> = {
              args = args.msg;
              caller = ?args.caller;
              permissions = config.authProvider;
            };
            authFunc(authArgs)
          };
          
                    // ICRC16 CandyShared validation cases - simplified validation logic
          case (#candyType(accessor, expectedType)) {
            let params = typedArgs;
            let candy = accessor(params);
            // Simple type validation based on CandyShared structure
            let actualType = switch (candy) {
              case (#Int(_)) "Int";
              case (#Nat(_)) "Nat";
              case (#Nat8(_)) "Nat8";
              case (#Nat16(_)) "Nat16"; 
              case (#Nat32(_)) "Nat32";
              case (#Nat64(_)) "Nat64";
              case (#Int8(_)) "Int8";
              case (#Int16(_)) "Int16";
              case (#Int32(_)) "Int32";
              case (#Int64(_)) "Int64";
              case (#Text(_)) "Text";
              case (#Bool(_)) "Bool";
              case (#Float(_)) "Float";
              case (#Principal(_)) "Principal";
              case (#Blob(_)) "Blob";
              case (#Class(_)) "Class";
              case (#Array(_)) "Array";
              case (#Option(_)) "Option";
              case (#Bytes(_)) "Bytes";
              case (#Floats(_)) "Floats";
              case (_) "Unknown";
            };
            if (actualType == expectedType) {
              #ok
            } else {
              #err("candyType: Expected " # expectedType # ", got " # actualType)
            }
          };
          case (#candySize(accessor, min, max)) {
            let params = typedArgs;
            let candy = accessor(params);
            // Estimate serialized size based on candy type
            let size = switch (candy) {
              case (#Text(text)) text.size();
              case (#Blob(blob)) blob.size();
              case (#Bytes(bytes)) bytes.size();
              case (#Array(arr)) arr.size() * 8; // Rough estimate
              case (#Floats(floats)) floats.size() * 8;
              case (#Int(_)) 8;
              case (#Nat(_)) 8;
              case (_) 8; // Default size estimate
            };
            switch (min, max) {
              case (?minSize, ?maxSize) {
                if (size < minSize or size > maxSize) {
                  #err("candySize: Size " # debug_show(size) # " not in range [" # debug_show(minSize) # ", " # debug_show(maxSize) # "]")
                } else { #ok }
              };
              case (?minSize, null) {
                if (size < minSize) {
                  #err("candySize: Size " # debug_show(size) # " below minimum " # debug_show(minSize))
                } else { #ok }
              };
              case (null, ?maxSize) {
                if (size > maxSize) {
                  #err("candySize: Size " # debug_show(size) # " above maximum " # debug_show(maxSize))
                } else { #ok }
              };
              case (null, null) { #ok };
            }
          };
          case (#candyDepth(accessor, maxDepth)) {
            let params = typedArgs;
            let candy = accessor(params);
            // Simple depth calculation for nested structures
            func calculateDepth(c: ICRC16Rules.CandyShared) : Nat {
              switch (c) {
                case (#Array(arr)) {
                  var maxSubDepth = 0;
                  for (item in arr.vals()) {
                    let subDepth = calculateDepth(item);
                    if (subDepth > maxSubDepth) {
                      maxSubDepth := subDepth;
                    };
                  };
                  1 + maxSubDepth
                };
                case (_) 1;
              }
            };
            let depth = calculateDepth(candy);
            if (depth <= maxDepth) {
              #ok
            } else {
              #err("candyDepth: Depth " # debug_show(depth) # " exceeds maximum " # debug_show(maxDepth))
            }
          };
          case (#candyPattern(accessor, pattern)) {
            let params = typedArgs;
            let candy = accessor(params);
            // Simple pattern matching for text values
            switch (candy) {
              case (#Text(text)) {
                // Basic pattern matching - just check if pattern is contained in text
                if (Text.contains(text, #text pattern)) {
                  #ok
                } else {
                  #err("candyPattern: Text '" # text # "' does not match pattern '" # pattern # "'")
                }
              };
              case (_) {
                #err("candyPattern: Pattern validation only supported for Text values")
              };
            }
          };
          case (#candyRange(accessor, min, max)) {
            let params = typedArgs;
            let candy = accessor(params);
            // Range validation for numeric values
            switch (candy) {
              case (#Int(value)) {
                switch (min, max) {
                  case (?minVal, ?maxVal) {
                    if (value < minVal or value > maxVal) {
                      #err("candyRange: Value " # debug_show(value) # " not in range [" # debug_show(minVal) # ", " # debug_show(maxVal) # "]")
                    } else { #ok }
                  };
                  case (?minVal, null) {
                    if (value < minVal) {
                      #err("candyRange: Value " # debug_show(value) # " below minimum " # debug_show(minVal))
                    } else { #ok }
                  };
                  case (null, ?maxVal) {
                    if (value > maxVal) {
                      #err("candyRange: Value " # debug_show(value) # " above maximum " # debug_show(maxVal))
                    } else { #ok }
                  };
                  case (null, null) { #ok };
                }
              };
              case (#Nat(value)) {
                let intValue = Int.fromNat(value);
                switch (min, max) {
                  case (?minVal, ?maxVal) {
                    if (intValue < minVal or intValue > maxVal) {
                      #err("candyRange: Value " # debug_show(intValue) # " not in range [" # debug_show(minVal) # ", " # debug_show(maxVal) # "]")
                    } else { #ok }
                  };
                  case (?minVal, null) {
                    if (intValue < minVal) {
                      #err("candyRange: Value " # debug_show(intValue) # " below minimum " # debug_show(minVal))
                    } else { #ok }
                  };
                  case (null, ?maxVal) {
                    if (intValue > maxVal) {
                      #err("candyRange: Value " # debug_show(intValue) # " above maximum " # debug_show(maxVal))
                    } else { #ok }
                  };
                  case (null, null) { #ok };
                }
              };
              case (_) {
                #err("candyRange: Range validation only supported for Int and Nat values")
              };
            }
          };
          case (#candyStructure(accessor, _context)) {
            let params = typedArgs;
            let _candy = accessor(params);
            // Basic structure validation
            #ok // TODO: Implement comprehensive structure validation
          };
          case (#propertyExists(accessor, propertyName)) {
            let params = typedArgs;
            let properties = accessor(params);
            // Check if property exists in PropertyShared array
            let found = Array.find<ICRC16Rules.PropertyShared>(properties, func(prop) {
              prop.name == propertyName
            });
            switch (found) {
              case (?_) { #ok };
              case null { #err("propertyExists: Property '" # propertyName # "' not found") };
            }
          };
          case (#propertyType(accessor, propertyName, expectedType)) {
            let params = typedArgs;
            let properties = accessor(params);
            // Find property and validate its type
            let found = Array.find<ICRC16Rules.PropertyShared>(properties, func(prop) {
              prop.name == propertyName
            });
            switch (found) {
              case (?prop) {
                let actualType = switch (prop.value) {
                  case (#Int(_)) "Int";
                  case (#Nat(_)) "Nat";
                  case (#Text(_)) "Text";
                  case (#Bool(_)) "Bool";
                  case (#Array(_)) "Array";
                  case (_) "Unknown";
                };
                if (actualType == expectedType) {
                  #ok
                } else {
                  #err("propertyType: Property '" # propertyName # "' expected type " # expectedType # ", got " # actualType)
                }
              };
              case null { #err("propertyType: Property '" # propertyName # "' not found") };
            }
          };
          case (#propertySize(accessor, propertyName, min, max)) {
            let params = typedArgs;
            let properties = accessor(params);
            // Find property and validate its size
            let found = Array.find<ICRC16Rules.PropertyShared>(properties, func(prop) {
              prop.name == propertyName
            });
            switch (found) {
              case (?prop) {
                let size = switch (prop.value) {
                  case (#Text(text)) text.size();
                  case (#Blob(blob)) blob.size();
                  case (#Array(arr)) arr.size();
                  case (_) 8; // Default size
                };
                switch (min, max) {
                  case (?minSize, ?maxSize) {
                    if (size < minSize or size > maxSize) {
                      #err("propertySize: Property '" # propertyName # "' size " # debug_show(size) # " not in range [" # debug_show(minSize) # ", " # debug_show(maxSize) # "]")
                    } else { #ok }
                  };
                  case (?minSize, null) {
                    if (size < minSize) {
                      #err("propertySize: Property '" # propertyName # "' size " # debug_show(size) # " below minimum " # debug_show(minSize))
                    } else { #ok }
                  };
                  case (null, ?maxSize) {
                    if (size > maxSize) {
                      #err("propertySize: Property '" # propertyName # "' size " # debug_show(size) # " above maximum " # debug_show(maxSize))
                    } else { #ok }
                  };
                  case (null, null) { #ok };
                }
              };
              case null { #err("propertySize: Property '" # propertyName # "' not found") };
            }
          };
          case (#arrayLength(accessor, min, max)) {
            let params = typedArgs;
            let candy = accessor(params);
            // Validate array length
            switch (candy) {
              case (#Array(arr)) {
                let length = arr.size();
                switch (min, max) {
                  case (?minLen, ?maxLen) {
                    if (length < minLen or length > maxLen) {
                      #err("arrayLength: Array length " # debug_show(length) # " not in range [" # debug_show(minLen) # ", " # debug_show(maxLen) # "]")
                    } else { #ok }
                  };
                  case (?minLen, null) {
                    if (length < minLen) {
                      #err("arrayLength: Array length " # debug_show(length) # " below minimum " # debug_show(minLen))
                    } else { #ok }
                  };
                  case (null, ?maxLen) {
                    if (length > maxLen) {
                      #err("arrayLength: Array length " # debug_show(length) # " above maximum " # debug_show(maxLen))
                    } else { #ok }
                  };
                  case (null, null) { #ok };
                }
              };
              case (_) {
                #err("arrayLength: Array length validation only supported for Array values")
              };
            }
          };
          case (#arrayItemType(accessor, expectedType)) {
            let params = typedArgs;
            let candy = accessor(params);
            // Validate array item types
            switch (candy) {
              case (#Array(arr)) {
                for (item in arr.vals()) {
                  let actualType = switch (item) {
                    case (#Int(_)) "Int";
                    case (#Nat(_)) "Nat";
                    case (#Text(_)) "Text";
                    case (#Bool(_)) "Bool";
                    case (_) "Unknown";
                  };
                  if (actualType != expectedType) {
                    return #err("arrayItemType: Array contains item of type " # actualType # ", expected " # expectedType);
                  };
                };
                #ok
              };
              case (_) {
                #err("arrayItemType: Array item type validation only supported for Array values")
              };
            }
          };
          case (#mapKeyExists(accessor, _key)) {
            let params = typedArgs;
            let _candy = accessor(params);
            // Basic map key existence check - simplified for now
            #ok // TODO: Implement proper map key validation
          };
          case (#mapSize(accessor, _min, _max)) {
            let params = typedArgs;
            let _candy = accessor(params);
            // Basic map size check - simplified for now
            #ok // TODO: Implement proper map size validation
          };
          case (#customCandyCheck(accessor, validator)) {
            let params = typedArgs;
            let candy = accessor(params);
            // Execute custom validator function
            validator(candy)
          };
          case (#nestedValidation(accessor, rules)) {
            let params = typedArgs;
            let _ = accessor(params);
            // Execute nested validation rules
            for (nestedRule in rules.vals()) {
              switch (validateSingleRule<M>(nestedRule, args, typedArgs)) {
                case (#ok) { /* continue */ };
                case (#err(errMsg)) { return #err("nestedValidation: " # errMsg) };
              };
            };
            #ok
          };
        }
      };
      
      private func applyDefaults<M>(args: Types.InspectArgs<T>) : Types.GuardResult {
        if (args.isQuery) {
          // Apply query defaults
          switch (config.queryDefaults) {
            case (?queryConfig) {
              switch (queryConfig.allowAnonymous) {
                case (?false) { 
                  if (not Principal.isAnonymous(args.caller)) {
                    #ok
                  } else {
                    #err("Anonymous callers not allowed")
                  }
                };
                case _ { #ok };
              }
            };
            case null { #ok }; // Default allow queries
          }
        } else {
          // Apply update defaults
          switch (config.updateDefaults) {
            case (?updateConfig) {
              switch (updateConfig.allowAnonymous) {
                case (?false) { 
                  if (not Principal.isAnonymous(args.caller)) {
                    #ok
                  } else {
                    #err("Anonymous callers not allowed")
                  }
                };
                case _ { #ok };
              }
            };
            case null { 
              // Fallback to global config
              switch (config.allowAnonymous) {
                case (?false) { 
                  if (not Principal.isAnonymous(args.caller)) {
                    #ok
                  } else {
                    #err("Anonymous callers not allowed")
                  }
                };
                case _ { #ok };
              }
            };
          }
        }
      };

      /// Efficient argument size checking without parsing overhead
      /// Provides access to raw blob size in inspect context
      /// Perfect for boundary validation where size matters more than content
      public func inspectOnlyArgSize(args: Types.InspectArgs<T>) : Nat {
        Blob.size(args.arg)
      };
    };

    /// Create a new inspector instance using the InspectMo's configuration
    public func createInspector<T>() : Inspector<T> {
      Inspector<T>(inspect_config)
    };

    /// Create a new inspector instance with custom configuration (merged with InspectMo config)
    public func createInspectorWithConfig<T>(additionalConfig: {
      authProvider: ?Types.AuthProvider;
      // Add other fields that might be customized per inspector
    }) : Inspector<T> {
      let mergedConfig : InitArgs = {
        allowAnonymous = inspect_config.allowAnonymous;
        defaultMaxArgSize = inspect_config.defaultMaxArgSize;
        authProvider = additionalConfig.authProvider; // Override with provided auth provider
        rateLimit = inspect_config.rateLimit;
        queryDefaults = inspect_config.queryDefaults;
        updateDefaults = inspect_config.updateDefaults;
        developmentMode = inspect_config.developmentMode;
        auditLog = inspect_config.auditLog;
      };
      Inspector<T>(mergedConfig)
    };

  ///////////
  // ICRC85 ovs
  //////////

    public func handleIcrc85Action<system>(id: TT.ActionId, action: TT.Action) : async* Star.Star<TT.ActionId, TT.Error> {
      if (action.actionType == ICRC85_Timer_Namespace) {
        await* ovsfixed.standardShareCycles({
          icrc_85_state = state.icrc85;
          icrc_85_environment = switch (environment.advanced) {
                case (?adv) {
                  switch (adv.icrc85) {
                    case (?icrc85Opt) ?icrc85Opt;
                    case null null;
                  };
                };
                case null null;
              };
            
          setActionSync = environment.tt.setActionSync;
          timerNamespace = ICRC85_Timer_Namespace;
          paymentNamespace = ICRC85_Payment_Namespace;
          baseCycles = 1_000_000_000_000; // 1 XDR
          maxCycles = 100_000_000_000_000; // 100 XDR
          actionDivisor = 10000;
          actionMultiplier = 200_000_000_000; // .2 XDR
        });
        #awaited(id)
      } else {
        #awaited(id)
      }
    };

  };

  // ========================================
  // CONVENIENCE FUNCTIONS FOR LIBRARY USERS  
  // ========================================
  
  /// Initialize a new inspector with the given configuration
  /// Note: For full ICRC85 support, use InspectMo.Init() with Class Plus
  /// This is a simplified entry point for basic usage
  
  // ========================================
  // Validation Rule Builder Functions
  // ========================================
  
  /// Create a text size validation rule
  public func textSize<T,M>(
    accessor: M -> Text, 
    min: ?Nat, 
    max: ?Nat
  ) : ValidationRule<T,M> {
    #textSize(accessor, min, max)
  };
  
  /// Create a blob size validation rule
  public func blobSize<T,M>(
    accessor: M -> Blob, 
    min: ?Nat, 
    max: ?Nat
  ) : ValidationRule<T,M> {
    #blobSize(accessor, min, max)
  };
  
  /// Create a nat value range validation rule
  public func natValue<T,M>(
    accessor: M -> Nat, 
    min: ?Nat, 
    max: ?Nat
  ) : ValidationRule<T,M> {
    #natValue(accessor, min, max)
  };

  /// Create an int value range validation rule
  public func intValue<T,M>(
    accessor: M -> Int, 
    min: ?Int, 
    max: ?Int
  ) : ValidationRule<T,M> {
    #intValue(accessor, min, max)
  };
  
  /// Require a specific permission
  public func requirePermission<T,M>(permission: Text) : ValidationRule<T,M> {
    #requirePermission(permission)
  };
  
  /// Require authenticated caller (non-anonymous)
  public func requireAuth<T,M>() : ValidationRule<T,M> {
    #requireAuth
  };
  
  /// Require a specific role
  public func requireRole<T,M>(role: Text) : ValidationRule<T,M> {
    #requireRole(role)
  };
  
  /// Block all ingress calls at boundary
  public func blockIngress<T,M>() : ValidationRule<T,M> {
    #blockIngress
  };
  
  /// Block all calls at boundary
  public func blockAll<T,M>() : ValidationRule<T,M> {
    #blockAll
  };
  
  // ========================================
  // ICRC16 CandyShared Validation Rule Builder Functions
  // ========================================
  
  /// Create a CandyShared type validation rule
  public func candyType<T,M>(
    accessor: M -> CandyTypes.CandyShared,
    expectedType: Text
  ) : ValidationRule<T,M> {
    #candyType(accessor, expectedType)
  };
  
  /// Create a CandyShared size validation rule
  public func candySize<T,M>(
    accessor: M -> CandyTypes.CandyShared,
    min: ?Nat,
    max: ?Nat
  ) : ValidationRule<T,M> {
    #candySize(accessor, min, max)
  };
  
  /// Create a CandyShared depth validation rule
  public func candyDepth<T,M>(
    accessor: M -> CandyTypes.CandyShared,
    maxDepth: Nat
  ) : ValidationRule<T,M> {
    #candyDepth(accessor, maxDepth)
  };
  
  /// Create a CandyShared pattern validation rule
  public func candyPattern<T,M>(
    accessor: M -> CandyTypes.CandyShared,
    pattern: Text
  ) : ValidationRule<T,M> {
    #candyPattern(accessor, pattern)
  };
  
  /// Create a CandyShared range validation rule
  public func candyRange<T,M>(
    accessor: M -> CandyTypes.CandyShared,
    min: ?Int,
    max: ?Int
  ) : ValidationRule<T,M> {
    #candyRange(accessor, min, max)
  };
  
  /// Create a CandyShared structure validation rule
  public func candyStructure<T,M>(
    accessor: M -> CandyTypes.CandyShared,
    context: Types.ICRC16ValidationContext
  ) : ValidationRule<T,M> {
    #candyStructure(accessor, context)
  };
  
  /// Create a PropertyShared existence validation rule
  public func propertyExists<T,M>(
    accessor: M -> [CandyTypes.PropertyShared],
    propertyName: Text
  ) : ValidationRule<T,M> {
    #propertyExists(accessor, propertyName)
  };
  
  /// Create a PropertyShared type validation rule
  public func propertyType<T,M>(
    accessor: M -> [CandyTypes.PropertyShared],
    propertyName: Text,
    expectedType: Text
  ) : ValidationRule<T,M> {
    #propertyType(accessor, propertyName, expectedType)
  };
  
  /// Create a PropertyShared size validation rule
  public func propertySize<T,M>(
    accessor: M -> [CandyTypes.PropertyShared],
    propertyName: Text,
    min: ?Nat,
    max: ?Nat
  ) : ValidationRule<T,M> {
    #propertySize(accessor, propertyName, min, max)
  };
  
  /// Create an array length validation rule
  public func arrayLength<T,M>(
    accessor: M -> CandyTypes.CandyShared,
    min: ?Nat,
    max: ?Nat
  ) : ValidationRule<T,M> {
    #arrayLength(accessor, min, max)
  };
  
  /// Create an array item type validation rule
  public func arrayItemType<T,M>(
    accessor: M -> CandyTypes.CandyShared,
    expectedType: Text
  ) : ValidationRule<T,M> {
    #arrayItemType(accessor, expectedType)
  };
  
  /// Create a map key existence validation rule
  public func mapKeyExists<T,M>(
    accessor: M -> CandyTypes.CandyShared,
    key: Text
  ) : ValidationRule<T,M> {
    #mapKeyExists(accessor, key)
  };
  
  /// Create a map size validation rule
  public func mapSize<T,M>(
    accessor: M -> CandyTypes.CandyShared,
    min: ?Nat,
    max: ?Nat
  ) : ValidationRule<T,M> {
    #mapSize(accessor, min, max)
  };
  
  /// Create a custom CandyShared validation rule
  public func customCandyCheck<T,M>(
    accessor: M -> CandyTypes.CandyShared,
    validator: CandyTypes.CandyShared -> Result.Result<(), Text>
  ) : ValidationRule<T,M> {
    #customCandyCheck(accessor, validator)
  };
  
  /// Create a nested ICRC16 validation rule
  public func nestedValidation<T,M>(
    accessor: M -> CandyTypes.CandyShared,
    rules: [ValidationRule<T,M>]
  ) : ValidationRule<T,M> {
    #nestedValidation(accessor, rules)
  };
  
  // ========================================
  // Runtime Validation Rule Builder Functions
  // ========================================
  
  /// Create a dynamic authorization rule
  public func dynamicAuth<T,M>(
    checkFunc: (DynamicAuthArgs<T>) -> GuardResult
  ) : ValidationRule<T,M> {
    #dynamicAuth(checkFunc)
  };
  
  /// Create a custom business logic check
  public func customCheck<T,M>(
    checkFunc: (CustomCheckArgs<T>) -> GuardResult
  ) : ValidationRule<T,M> {
    #customCheck(checkFunc)
  };
  
  /// Create a runtime blob size check
  public func blobSizeCheck<T,M>(
    extractBlob: M -> Blob, 
    min: ?Nat, 
    max: ?Nat
  ) : ValidationRule<T,M> {
    #blobSize(extractBlob, min, max)
  };
  
  /// Create a runtime text size check
  public func textSizeCheck<T,M>(
    extractText: M -> Text, 
    min: ?Nat, 
    max: ?Nat
  ) : ValidationRule<T,M> {
    #textSize(extractText, min, max)
  };
  
  
  // ========================================
  // Utility Functions
  // ========================================
  
  
  
  /// Validate text size directly
  public let validateTextSize = SizeValidator.validateTextSize;
  
  /// Validate blob size directly  
  public let validateBlobSize = SizeValidator.validateBlobSize;
  
  /// Validate nat value range directly
  public let validateNatValue = SizeValidator.validateNatValue;
  
  /// Validate int value range directly
  public let validateIntValue = SizeValidator.validateIntValue;
}