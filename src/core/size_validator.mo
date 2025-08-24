import Text "mo:core/Text";
import Blob "mo:core/Blob";
import Array "mo:core/Array";
import Debug "mo:core/Debug";

/// Enhanced size validation utilities with performance optimizations
module {
  
  /// Early termination: Check if value fails max before expensive operations
  public func earlyMaxCheck<T>(getValue: () -> T, getSize: T -> Nat, max: ?Nat) : {#ok: T; #tooLarge} {
    switch (max) {
      case (?maxSize) {
        let value = getValue();
        let size = getSize(value);
        if (size > maxSize) {
          #tooLarge
        } else {
          #ok(value)
        }
      };
      case null {
        #ok(getValue())
      };
    }
  };
  
  /// Lazy text size validation with early termination
  public func validateTextSizeLazy(getText: () -> Text, min: ?Nat, max: ?Nat) : Bool {
    // Early termination: check max first if provided
    switch (max) {
      case (?maxSize) {
        let text = getText();
        let size = Text.encodeUtf8(text).size();
        
        // Early termination if too large
        if (size > maxSize) { return false };
        
        // Check min constraint
        switch (min) {
          case (?minSize) { size >= minSize };
          case null { true };
        }
      };
      case null {
        // No max constraint, just check min
        let text = getText();
        switch (min) {
          case (?minSize) {
            let size = Text.encodeUtf8(text).size();
            size >= minSize
          };
          case null { true };
        }
      };
    }
  };
  
  /// Enhanced text size validation with early termination
  public func validateTextSize(text: Text, min: ?Nat, max: ?Nat) : Bool {
    validateTextSizeLazy(func() { text }, min, max)
  };
  
  /// Lazy blob size validation (already O(1) but with early termination pattern)
  public func validateBlobSizeLazy(getBlob: () -> Blob, min: ?Nat, max: ?Nat) : Bool {
    // Early termination: check max first if provided
    switch (max) {
      case (?maxSize) {
        let blob = getBlob();
        let size = blob.size();
        
        // Early termination if too large
        if (size > maxSize) { return false };
        
        // Check min constraint
        switch (min) {
          case (?minSize) { size >= minSize };
          case null { true };
        }
      };
      case null {
        // No max constraint, just check min
        let blob = getBlob();
        switch (min) {
          case (?minSize) { blob.size() >= minSize };
          case null { true };
        }
      };
    }
  };
  
  /// Enhanced blob size validation
  public func validateBlobSize(blob: Blob, min: ?Nat, max: ?Nat) : Bool {
    validateBlobSizeLazy(func() { blob }, min, max)
  };
  
  /// Enhanced nat value validation with early termination
  public func validateNatValue(value: Nat, min: ?Nat, max: ?Nat) : Bool {
    // Early termination: check max first (more likely to fail)
    switch (max) {
      case (?maxVal) {
        if (value > maxVal) { return false };
      };
      case null {};
    };
    
    // Check min constraint
    switch (min) {
      case (?minVal) { value >= minVal };
      case null { true };
    }
  };
  
  /// Enhanced int value validation with early termination
  public func validateIntValue(value: Int, min: ?Int, max: ?Int) : Bool {
    // Early termination: check max first (more likely to fail)
    switch (max) {
      case (?maxVal) {
        if (value > maxVal) { return false };
      };
      case null {};
    };
    
    // Check min constraint
    switch (min) {
      case (?minVal) { value >= minVal };
      case null { true };
    }
  };
  
  /// Improved nat size estimation algorithm using bit-based calculation
  public func estimateNatSize(n: Nat) : Nat {
    if (n == 0) { return 1 };
    
    // Calculate bit length manually since Nat.bitLength may not be available
    var temp = n;
    var bits = 0;
    while (temp > 0) {
      temp := temp / 2;
      bits += 1;
    };
    
    // LEB128 uses 7 bits per byte with continuation bit
    let bytesNeeded = (bits + 6) / 7; // Ceiling division
    
    // Add minimal overhead for Candid encoding
    bytesNeeded + 1
  };
  
  /// Estimate size of complex data structures
  public func estimateCompoundSize(elements: [Nat]) : Nat {
    var totalSize = 0;
    
    // Array overhead (length encoding)
    totalSize += estimateNatSize(Array.size(elements));
    
    // Sum element sizes
    for (element in elements.vals()) {
      totalSize += estimateNatSize(element);
    };
    
    totalSize
  };
  
  /// Fast size validation with short-circuit evaluation
  public func validateSizesBatch(
    checks: [(getText: () -> Text, min: ?Nat, max: ?Nat)]
  ) : Bool {
    // Early termination: fail fast on first violation
    for ((getText, min, max) in checks.vals()) {
      if (not validateTextSizeLazy(getText, min, max)) {
        return false;
      };
    };
    true
  };
  
  /// Memory-efficient size checking for large data
  public func validateSizeStreamingBlob(
    blob: Blob, 
    maxSize: Nat, 
    chunkSize: Nat
  ) : {#ok; #tooLarge; #error: Text} {
    let totalSize = blob.size();
    
    // Early termination: check total size first
    if (totalSize > maxSize) {
      return #tooLarge;
    };
    
    // For very large blobs, we could implement streaming validation
    // For now, the total size check is sufficient since Blob.size() is O(1)
    #ok
  };
  
  /// Fast estimation for common size patterns
  public func estimateTypicalSizes() : {
    smallText: Nat;    // ~100 chars
    mediumText: Nat;   // ~1KB
    largeText: Nat;    // ~10KB
    smallBlob: Nat;    // ~1KB
    mediumBlob: Nat;   // ~100KB
    largeBlob: Nat;    // ~1MB
  } {
    {
      smallText = 100;
      mediumText = 1024;
      largeText = 10 * 1024;
      smallBlob = 1024;
      mediumBlob = 100 * 1024;
      largeBlob = 1024 * 1024;
    }
  };
}
