// Core InspectMo library - main entry point with Class Plus integration
import MigrationTypes "../migrations/types";

import SizeValidator "./size_validator";
import RateLimiter "../security/rate_limiter";

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
// removed unused imports
import TimerToolLib "mo:timer-tool";
// removed unused imports

// Basic validation imports
import Result "mo:core/Result";
import BTree "mo:core/Map";
import Text "mo:core/Text";
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

  let instance = ClassPlusLib.ClassPlus<system,
      InspectMo, 
      State,
      InitArgs,
      Environment>({
        manager = config.manager;
        initialState = config.initialState;
        args = config.args;
        pullEnvironment = config.pullEnvironment;
        onInitialize = config.onInitialize;
        onStorageChange = config.onStorageChange;
        constructor = func(stored, instantiator, canister, args, environment, storageChanged) {
          InspectMo(stored, instantiator, canister, args, environment, storageChanged)
        };
      }).get;
    
    // Only initialize ICRC85 cycle sharing if environment is provided
    switch(instance().environment) {
      case (?env) {
        let initialWait : ?Nat = do? { env.advanced!.icrc85!.period! };
        ovsfixed.initialize_cycleShare<system>({
          namespace = ICRC85_Timer_Namespace;
          icrc_85_state = instance().state.icrc85;
          wait = initialWait; // Use provided period as initial wait when available
          registerExecutionListenerAsync = env.tt.registerExecutionListenerAsync;
          setActionSync = env.tt.setActionSync;  
          existingIndex = env.tt.getState().actionIdIndex;
          handler = instance().handleIcrc85Action;
        });
      };
      case null {
        // Skip ICRC85 initialization for testing
      };
    };

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
    public var environment : ?Environment = environment_passed;

    // Compatibility no-op; kept for API stability if callers invoke it.
    public func refreshEnvironment() : () { };

    // New: allow the environment to be updated by the embedding canister
    public func setEnvironment(env: ?Environment) : () {
      environment := env;
    };

    // let d = environment.log.log_debug; // Commented out for test compatibility

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
            switch (environment) {
        case (?_env) {
                // TODO: Implement rate limiting with environment
                #ok  // Placeholder for now
              };
              case null {
                #ok  // No rate limiting without environment
              };
            };
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
          icrc_85_environment = switch(environment) {
            case (?env) {
              switch (env.advanced) {
                case (?adv) {
                  switch (adv.icrc85) {
                    case (?icrc85Opt) ?icrc85Opt;
                    case null null;
                  };
                };
                case null null;
              };
            };
            case null null;
          };
          setActionSync = switch(environment) {
            case (?env) env.tt.setActionSync;
            case null func<system>(_time: TimerToolLib.Time, _action: TimerToolLib.ActionRequest) : TimerToolLib.ActionId { {id = 0; time = 0} /* mock ID */ };
          };
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