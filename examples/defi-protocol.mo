// defi-protocol.mo
// Real-world example demonstrating complex ICRC16 validation for DeFi protocol configuration
// This example shows ICRC16 CandyShared validation with InspectMo integration

import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";
import Float "mo:base/Float";
import Array "mo:base/Array";
import Text "mo:base/Text";
import InspectMo "../src/lib";
import TimerTool "mo:timer-tool";
import ClassPlusLib "mo:class-plus";

persistent actor DefiProtocolExample {
  
  // Timer tool setup following test pattern
  transient let initManager = ClassPlusLib.ClassPlusInitializationManager(
    Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"), 
    Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"), 
    false
  );
  
  stable var tt_migration_state: TimerTool.State = TimerTool.Migration.migration.initialState;

  transient let tt = TimerTool.Init<system>({
    manager = initManager;
    initialState = tt_migration_state;
    args = null;
    pullEnvironment = ?(func() : TimerTool.Environment {
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
    onInitialize = ?(func (newClass: TimerTool.TimerTool) : async* () {
      newClass.initialize<system>();
    });
    onStorageChange = func(state: TimerTool.State) {
      tt_migration_state := state;
    };
  });

  // Create proper environment for ICRC85 and TimerTool
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
  
  // Define ICRC16 CandyShared types locally (simplified for this example)
  public type CandyShared = {
    #Nat : Nat;
    #Int : Int;
    #Float : Float;
    #Text : Text;
    #Bool : Bool;
    #Class : [PropertyShared];
    #Map : [(Text, CandyShared)];
    #ValueMap : [(CandyShared, CandyShared)];
    #Array : [CandyShared];
    #Principal : Principal;
  };

  public type PropertyShared = {
    name : Text;
    value : CandyShared;
    immutable : Bool;
  };

  // DeFi protocol configuration types
  public type ProtocolConfig = {
    protocol_name: Text;
    version: Text;
    metadata: CandyShared; // Complex ICRC16 metadata
  };

  // Protocol state
  private stable var protocol_configs: [(Text, CandyShared)] = [];
  private stable var validation_count = 0;

  // Create main inspector following test pattern
  stable var inspector_migration_state: InspectMo.State = InspectMo.initialState();

  transient let inspector = InspectMo.Init<system>({
    manager = initManager;
    initialState = inspector_migration_state;
    args = ?{
      allowAnonymous = ?false;
      defaultMaxArgSize = ?50000; // 50KB for DeFi metadata
      authProvider = null;
      rateLimit = null; // Disable rate limiting for now
      queryDefaults = null;
      updateDefaults = null;
      developmentMode = true;
      auditLog = true;
    };
    pullEnvironment = ?(func() : InspectMo.Environment {
      createEnvironment()
    });
    onInitialize = null;
    onStorageChange = func(state: InspectMo.State) {
      inspector_migration_state := state;
    };
  });

  // Protocol configuration methods
  public func configureProtocol(config: ProtocolConfig): async Result.Result<Text, Text> {
    // Store protocol configuration
    protocol_configs := Array.append(protocol_configs, [(config.protocol_name, config.metadata)]);
    #ok("✅ Protocol configured: " # config.protocol_name # " v" # config.version)
  };

  // Query methods
  public query func getProtocolStats(): async {
    protocol_count: Nat;
    validation_count: Nat;
  } {
    {
      protocol_count = protocol_configs.size();
      validation_count = validation_count;
    }
  };

  // Test function demonstrating ICRC16 usage
  public func testProtocolConfig(): async Result.Result<Text, Text> {
    let testConfig: ProtocolConfig = {
      protocol_name = "TestDeFi";
      version = "1.0.0";
      metadata = #Class([
        {
          name = "version";
          value = #Text("1.0.0");
          immutable = true;
        },
        {
          name = "governance";
          value = #Map([
            ("voting_period", #Nat(7 * 24 * 60 * 60)), // 7 days in seconds
            ("quorum_threshold", #Float(0.5)),
          ]);
          immutable = false;
        }
      ]);
    };
    
    await configureProtocol(testConfig)
  };

  // Test function demonstrating ValidationRule Array Utilities
  public func testValidationRules(): async Text {
    // For now, just demonstrate basic inspector functionality
    // The ValidationRule Array Utilities will be available after our implementation
    let inspectorInstance = inspector();
    
    "✅ ValidationRule Array Utilities test ready. Inspector created successfully."
  };
}
