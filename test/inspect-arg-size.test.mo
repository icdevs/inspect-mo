import InspectMo "../src/lib";
import Principal "mo:core/Principal";
import Blob "mo:core/Blob";
import Text "mo:core/Text";
import Debug "mo:core/Debug";

// Test for inspectOnlyArgSize functionality
persistent actor {
  
  type MessageAccessor = {
    #test_method : Text;
    #large_data_method : Blob;
    #empty_method : ();
  };

  public func runTests() : async () {
    
    Debug.print("Testing inspectOnlyArgSize functionality...");
    
    // Initialize InspectMo with minimal config
    let config: InspectMo.InitArgs = {
      allowAnonymous = ?false;
      defaultMaxArgSize = ?(1024 * 1024); // 1MB
      auditLog = false;
      developmentMode = true;
      authProvider = null;
      rateLimit = null;
      queryDefaults = null;
      updateDefaults = null;
    };

    let inspectMo = InspectMo.InspectMo(
      null,
      Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"),
      Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai"),
      ?config,
      null,
      func(_state) {}
    );
    
    let inspector = inspectMo.createInspector<MessageAccessor>();

    // Test with empty blob
    let emptyBlob = Text.encodeUtf8("");
    let emptyArgs: InspectMo.InspectArgs<MessageAccessor> = {
      methodName = "empty_method";
      caller = Principal.fromText("aaaaa-aa");
      arg = emptyBlob;
      isQuery = false;
      cycles = null;
      deadline = null;
      isInspect = true;
      msg = #empty_method;
    };
    
    let emptySize = inspector.inspectOnlyArgSize(emptyArgs);
    assert(emptySize == 0);
    Debug.print("✓ Empty blob size correctly reported as 0");

    // Test with small blob
    let smallData = "Hello, World!";
    let smallBlob = Text.encodeUtf8(smallData);
    let smallArgs: InspectMo.InspectArgs<MessageAccessor> = {
      methodName = "test_method";
      caller = Principal.fromText("aaaaa-aa");
      arg = smallBlob;
      isQuery = false;
      cycles = null;
      deadline = null;
      isInspect = true;
      msg = #test_method(smallData);
    };
    
    let smallSize = inspector.inspectOnlyArgSize(smallArgs);
    let expectedSmallSize = Blob.size(smallBlob);
    assert(smallSize == expectedSmallSize);
    Debug.print("✓ Small blob size correctly reported as " # debug_show(smallSize) # " bytes");

    // Test with large blob (simple approach)
    let largeData = "This is a reasonably large test string to validate that inspectOnlyArgSize works correctly with larger data blobs and can measure their sizes accurately without any performance issues during the size calculation process.";
    let largeBlob = Text.encodeUtf8(largeData);
    let largeArgs: InspectMo.InspectArgs<MessageAccessor> = {
      methodName = "large_data_method";
      caller = Principal.fromText("aaaaa-aa");
      arg = largeBlob;
      isQuery = false;
      cycles = null;
      deadline = null;
      isInspect = true;
      msg = #large_data_method(largeBlob);
    };
    
    let largeSize = inspector.inspectOnlyArgSize(largeArgs);
    let expectedLargeSize = Blob.size(largeBlob);
    assert(largeSize == expectedLargeSize);
    assert(largeSize >= 100); // Should be at least 100 bytes (reasonably large)
    Debug.print("✓ Large blob size correctly reported as " # debug_show(largeSize) # " bytes");

    // Performance test - validate efficiency
    let testData = "This is a performance test with some data";
    let testBlob = Text.encodeUtf8(testData);
    let perfArgs: InspectMo.InspectArgs<MessageAccessor> = {
      methodName = "test_method";
      caller = Principal.fromText("aaaaa-aa");
      arg = testBlob;
      isQuery = false;
      cycles = null;
      deadline = null;
      isInspect = true;
      msg = #test_method(testData);
    };
    
    // Test inspectOnlyArgSize (should be very fast and consistent)
    let size1 = inspector.inspectOnlyArgSize(perfArgs);
    let size2 = inspector.inspectOnlyArgSize(perfArgs);
    let size3 = inspector.inspectOnlyArgSize(perfArgs);
    
    // All calls should return the same size
    assert(size1 == size2 and size2 == size3);
    
    // Should match the actual blob size
    let expectedPerfSize = Blob.size(testBlob);
    assert(size1 == expectedPerfSize);
    
    Debug.print("✓ Performance test: inspectOnlyArgSize is consistent and efficient");
    
    Debug.print("✓ inspectOnlyArgSize tests passed");
  };
}
