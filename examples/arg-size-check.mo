// arg-size-check.mo
// Simple example demonstrating inspectOnlyArgSize functionality
// This example shows how to use efficient argument size checking to prevent DoS attacks

import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Nat "mo:base/Nat";

persistent actor ArgSizeCheckExample {
  
  // Configuration constants for different request types
  private transient let MAX_SMALL_REQUEST_SIZE = 1024;     // 1KB for lightweight operations
  private transient let MAX_MEDIUM_REQUEST_SIZE = 10240;   // 10KB for standard operations  
  private transient let MAX_LARGE_REQUEST_SIZE = 102400;   // 100KB for bulk operations
  private transient let MAX_ABSOLUTE_SIZE = 1048576;       // 1MB absolute maximum

  // Message types for different operations
  public type SmallMessage = {
    action: Text;
    id: Nat;
  };

  public type MediumMessage = {
    action: Text;
    data: [Nat8];
    metadata: {
      timestamp: Int;
      user: Text;
      tags: [Text];
    };
  };

  public type LargeMessage = {
    action: Text;
    bulk_data: [Nat8];
    processing_options: {
      compression: Bool;
      encryption: Bool;
      batch_size: Nat;
    };
    callbacks: [Text];
  };

  // Performance tracking
  private var inspection_count : Nat = 0;
  private var rejection_count : Nat = 0;
  private var total_bytes_processed : Nat = 0;

  // System inspect message implementation
  system func inspect({
    arg : Blob;
    caller : Principal;
    msg : {
      #processSmallRequest : () -> (message : SmallMessage);
      #processMediumRequest : () -> (message : MediumMessage);
      #processLargeRequest : () -> (message : LargeMessage);
      #getPerformanceMetrics : () -> ();
      #testSmallMessage : () -> ();
      #testMediumMessage : () -> ();
      #testLargeMessage : () -> ();
      #demonstrateErrorHandling : () -> ();
    };
  }) : Bool {
    
    // Get argument size efficiently without parsing
    let argSize = arg.size();
    
    inspection_count += 1;
    total_bytes_processed += argSize;
    
    // Determine size limit based on method
    let sizeLimit = switch (msg) {
      case (#processSmallRequest(_)) MAX_SMALL_REQUEST_SIZE;
      case (#processMediumRequest(_)) MAX_MEDIUM_REQUEST_SIZE;
      case (#processLargeRequest(_)) MAX_LARGE_REQUEST_SIZE;
      case (#getPerformanceMetrics(_)) MAX_SMALL_REQUEST_SIZE;
      case (#testSmallMessage(_)) MAX_SMALL_REQUEST_SIZE;
      case (#testMediumMessage(_)) MAX_MEDIUM_REQUEST_SIZE;
      case (#testLargeMessage(_)) MAX_LARGE_REQUEST_SIZE;
      case (#demonstrateErrorHandling(_)) MAX_SMALL_REQUEST_SIZE;
    };

    let methodName = switch (msg) {
      case (#processSmallRequest(_)) "processSmallRequest";
      case (#processMediumRequest(_)) "processMediumRequest";
      case (#processLargeRequest(_)) "processLargeRequest";
      case (#getPerformanceMetrics(_)) "getPerformanceMetrics";
      case (#testSmallMessage(_)) "testSmallMessage";
      case (#testMediumMessage(_)) "testMediumMessage";
      case (#testLargeMessage(_)) "testLargeMessage";
      case (#demonstrateErrorHandling(_)) "demonstrateErrorHandling";
    };

    // Validate against absolute maximum first
    if (argSize > MAX_ABSOLUTE_SIZE) {
      rejection_count += 1;
      Debug.print("❌ Rejected oversized request: " # Nat.toText(argSize) # " bytes exceeds absolute max " # Nat.toText(MAX_ABSOLUTE_SIZE));
      false
    }
    // Then validate against method-specific limit
    else if (argSize > sizeLimit) {
      rejection_count += 1;
      Debug.print("❌ Rejected oversized request for " # methodName # ": " # Nat.toText(argSize) # " bytes exceeds limit " # Nat.toText(sizeLimit));
      false
    }
    else {
      Debug.print("✅ Size validation passed for " # methodName # ": " # Nat.toText(argSize) # " bytes within limit " # Nat.toText(sizeLimit));
      true
    }
  };

  // Example canister methods demonstrating different size categories
  
  public func processSmallRequest(message: SmallMessage): async Result.Result<Text, Text> {
    // This method expects small payloads (< 1KB)
    #ok("✅ Processed small request: " # message.action # " for ID " # Nat.toText(message.id))
  };

  public func processMediumRequest(message: MediumMessage): async Result.Result<Text, Text> {
    // This method can handle medium payloads (< 10KB)
    let dataSize = message.data.size();
    #ok("✅ Processed medium request: " # message.action # " with " # Nat.toText(dataSize) # " bytes of data")
  };

  public func processLargeRequest(message: LargeMessage): async Result.Result<Text, Text> {
    // This method can handle large payloads (< 100KB)
    let bulkDataSize = message.bulk_data.size();
    #ok("✅ Processed large request: " # message.action # " with " # Nat.toText(bulkDataSize) # " bytes of bulk data")
  };

  // Performance monitoring functions
  public query func getPerformanceMetrics(): async {
    inspection_count: Nat;
    rejection_count: Nat;
    total_bytes_processed: Nat;
    average_request_size: Nat;
    rejection_rate: Nat;
    size_limits: {
      small: Nat;
      medium: Nat;
      large: Nat;
      absolute_max: Nat;
    };
  } {
    {
      inspection_count = inspection_count;
      rejection_count = rejection_count;
      total_bytes_processed = total_bytes_processed;
      average_request_size = if (inspection_count > 0) {
        total_bytes_processed / inspection_count
      } else { 0 };
      rejection_rate = if (inspection_count > 0) {
        (rejection_count * 100) / inspection_count
      } else { 0 };
      size_limits = {
        small = MAX_SMALL_REQUEST_SIZE;
        medium = MAX_MEDIUM_REQUEST_SIZE;
        large = MAX_LARGE_REQUEST_SIZE;
        absolute_max = MAX_ABSOLUTE_SIZE;
      };
    }
  };

  // Test functions for demonstrating different scenarios
  public func testSmallMessage(): async Result.Result<Text, Text> {
    let testMsg: SmallMessage = {
      action = "test_small";
      id = 12345;
    };
    await processSmallRequest(testMsg)
  };

  public func testMediumMessage(): async Result.Result<Text, Text> {
    let testMsg: MediumMessage = {
      action = "test_medium";
      data = [1, 2, 3, 4, 5]; // Small for testing
      metadata = {
        timestamp = 1699999999;
        user = "test_user";
        tags = ["test", "medium", "example"];
      };
    };
    await processMediumRequest(testMsg)
  };

  public func testLargeMessage(): async Result.Result<Text, Text> {
    let testMsg: LargeMessage = {
      action = "test_large";
      bulk_data = [1, 2, 3]; // Small for testing - in real use this would be much larger
      processing_options = {
        compression = true;
        encryption = false;
        batch_size = 100;
      };
      callbacks = ["callback1", "callback2"];
    };
    await processLargeRequest(testMsg)
  };

  // Demonstrate error handling with different request sizes
  public func demonstrateErrorHandling(): async [Result.Result<Text, Text>] {
    [
      await testSmallMessage(),
      await testMediumMessage(), 
      await testLargeMessage(),
    ]
  };

  // System lifecycle hooks
  system func preupgrade() {
    Debug.print("🔄 Pre-upgrade: Processed " # Nat.toText(inspection_count) # " inspections, rejected " # Nat.toText(rejection_count));
  };

  system func postupgrade() {
    Debug.print("✅ Post-upgrade: ArgSizeCheck example restored with " # Nat.toText(total_bytes_processed) # " total bytes processed");
  };
}
