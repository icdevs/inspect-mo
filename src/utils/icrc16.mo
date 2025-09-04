/**
 * ICRC16 Utilities Module
 * 
 * Provides validation utilities, data transformation functions, and error handling
 * for ICRC16 CandyShared data structures in InspectMo.
 */

import Debug "mo:base/Debug";
import Text "mo:base/Text";
import Array "mo:base/Array";
import CandyTypes "mo:candy/types";

module {
  
  // Re-export types for convenience
  public type CandyShared = CandyTypes.CandyShared;
  public type PropertyShared = CandyTypes.PropertyShared;
  
  // Result type for validation
  public type Result<T, E> = {
    #ok : T;
    #err : E;
  };
  
  // Validation error types
  public type ValidationError = {
    #InvalidType : { expected: Text; found: Text; path: Text };
    #OutOfRange : { min: ?CandyShared; max: ?CandyShared; value: CandyShared; path: Text };
    #InvalidSize : { min: ?Nat; max: ?Nat; actual: Nat; path: Text };
    #MissingProperty : { property: Text; path: Text };
    #InvalidPattern : { pattern: Text; value: Text; path: Text };
    #CustomError : { message: Text; path: Text };
  };
  
  // Validation context for tracking path and depth
  public type ValidationContext = {
    path: Text;
    depth: Nat;
    maxDepth: Nat;
    strictMode: Bool;
  };
  
  // Configuration types for validation rules
  public type SizeConfig = {
    min: ?Nat;
    max: ?Nat;
  };
  
  public type RangeConfig = {
    min: ?CandyShared;
    max: ?CandyShared;
  };
  
  public type TextPatternConfig = {
    minLength: ?Nat;
    maxLength: ?Nat;
    pattern: ?Text; // Simplified pattern matching
    allowedValues: ?[Text];
  };
  
  public type StructureConfig = {
    requiredProperties: [Text];
    optionalProperties: [Text];
    allowAdditionalProperties: Bool;
    maxDepth: ?Nat;
  };
  
  // Core validation functions
  
  /**
   * Get the type name of a CandyShared value
   */
  public func getTypeName(value: CandyShared) : Text {
    switch (value) {
      case (#Int(_)) "Int";
      case (#Int8(_)) "Int8";
      case (#Int16(_)) "Int16";
      case (#Int32(_)) "Int32";
      case (#Int64(_)) "Int64";
      case (#Nat(_)) "Nat";
      case (#Nat8(_)) "Nat8";
      case (#Nat16(_)) "Nat16";
      case (#Nat32(_)) "Nat32";
      case (#Nat64(_)) "Nat64";
      case (#Float(_)) "Float";
      case (#Text(_)) "Text";
      case (#Bool(_)) "Bool";
      case (#Blob(_)) "Blob";
      case (#Class(_)) "Class";
      case (#Principal(_)) "Principal";
      case (#Option(_)) "Option";
      case (#Array(_)) "Array";
      case (#Map(_)) "Map";
      case (#ValueMap(_)) "ValueMap";
      case (#Set(_)) "Set";
      case (#Bytes(_)) "Bytes";
      case (#Nats(_)) "Nats";
      case (#Ints(_)) "Ints";
      case (#Floats(_)) "Floats";
    }
  };
  
  /**
   * Validate that a CandyShared value matches expected type
   */
  public func validateType(
    value: CandyShared,
    expectedTypes: [Text],
    context: ValidationContext
  ) : Result<(), ValidationError> {
    let actualType = getTypeName(value);
    let isValidType = Array.find(expectedTypes, func(t: Text) : Bool { t == actualType });
    
    switch (isValidType) {
      case (?_) #ok(());
      case (null) {
        #err(#InvalidType({
          expected = Text.join(", ", expectedTypes.vals());
          found = actualType;
          path = context.path;
        }))
      };
    }
  };
  
  /**
   * Validate size constraints for arrays, maps, and text
   */
  public func validateSize(
    value: CandyShared,
    config: SizeConfig,
    context: ValidationContext
  ) : Result<(), ValidationError> {
    let size = switch (value) {
      case (#Text(text)) text.size();
      case (#Array(arr)) arr.size();
      case (#Map(map)) map.size();
      case (#ValueMap(vmap)) vmap.size();
      case (#Set(set)) set.size();
      case (#Bytes(bytes)) bytes.size();
      case (#Nats(nats)) nats.size();
      case (#Ints(ints)) ints.size();
      case (#Floats(floats)) floats.size();
      case (#Class(props)) props.size();
      case (_) 0; // Other types don't have meaningful size
    };
    
    // Check minimum size
    switch (config.min) {
      case (?minSize) {
        if (size < minSize) {
          return #err(#InvalidSize({
            min = config.min;
            max = config.max;
            actual = size;
            path = context.path;
          }));
        };
      };
      case (null) {};
    };
    
    // Check maximum size
    switch (config.max) {
      case (?maxSize) {
        if (size > maxSize) {
          return #err(#InvalidSize({
            min = config.min;
            max = config.max;
            actual = size;
            path = context.path;
          }));
        };
      };
      case (null) {};
    };
    
    #ok(())
  };
  
  /**
   * Validate text patterns and constraints
   */
  public func validateTextPattern(
    text: Text,
    config: TextPatternConfig,
    context: ValidationContext
  ) : Result<(), ValidationError> {
    
    // Check length constraints
    let lengthResult = validateSize(#Text(text), {
      min = config.minLength;
      max = config.maxLength;
    }, context);
    
    switch (lengthResult) {
      case (#err(error)) return #err(error);
      case (#ok(())) {};
    };
    
    // Check allowed values
    switch (config.allowedValues) {
      case (?allowedList) {
        let isAllowed = Array.find(allowedList, func(allowed: Text) : Bool { allowed == text });
        switch (isAllowed) {
          case (null) {
            return #err(#InvalidPattern({
              pattern = "allowed values: " # Text.join(", ", allowedList.vals());
              value = text;
              path = context.path;
            }));
          };
          case (?_) {};
        };
      };
      case (null) {};
    };
    
    // Simple pattern matching (basic regex-like functionality)
    switch (config.pattern) {
      case (?pattern) {
        let isValid = matchesPattern(text, pattern);
        if (not isValid) {
          return #err(#InvalidPattern({
            pattern = pattern;
            value = text;
            path = context.path;
          }));
        };
      };
      case (null) {};
    };
    
    #ok(())
  };
  
  /**
   * Validate numeric range constraints
   */
  public func validateRange(
    value: CandyShared,
    config: RangeConfig,
    context: ValidationContext
  ) : Result<(), ValidationError> {
    
    // Check minimum value
    switch (config.min) {
      case (?minVal) {
        if (not isGreaterOrEqual(value, minVal)) {
          return #err(#OutOfRange({
            min = config.min;
            max = config.max;
            value = value;
            path = context.path;
          }));
        };
      };
      case (null) {};
    };
    
    // Check maximum value
    switch (config.max) {
      case (?maxVal) {
        if (not isLessOrEqual(value, maxVal)) {
          return #err(#OutOfRange({
            min = config.min;
            max = config.max;
            value = value;
            path = context.path;
          }));
        };
      };
      case (null) {};
    };
    
    #ok(())
  };
  
  /**
   * Validate Class structure
   */
  public func validateStructure(
    properties: [PropertyShared],
    config: StructureConfig,
    context: ValidationContext
  ) : Result<(), [ValidationError]> {
    var errors: [ValidationError] = [];
    
    // Check depth limit
    switch (config.maxDepth) {
      case (?maxDepth) {
        if (context.depth > maxDepth) {
          return #err([#CustomError({
            message = "Maximum nesting depth exceeded: " # debug_show(maxDepth);
            path = context.path;
          })]);
        };
      };
      case (null) {};
    };
    
    // Extract property names
    let propertyNames = Array.map(properties, func(prop: PropertyShared) : Text { prop.name });
    
    // Check required properties
    for (required in config.requiredProperties.vals()) {
      let hasProperty = Array.find(propertyNames, func(name: Text) : Bool { name == required });
      switch (hasProperty) {
        case (null) {
          errors := Array.append(errors, [#MissingProperty({
            property = required;
            path = context.path;
          })]);
        };
        case (?_) {};
      };
    };
    
    // Check for additional properties if not allowed
    if (not config.allowAdditionalProperties) {
      let allowedProperties = Array.append(config.requiredProperties, config.optionalProperties);
      for (prop in properties.vals()) {
        let isAllowed = Array.find(allowedProperties, func(allowed: Text) : Bool { allowed == prop.name });
        switch (isAllowed) {
          case (null) {
            errors := Array.append(errors, [#CustomError({
              message = "Additional property not allowed: " # prop.name;
              path = context.path;
            })]);
          };
          case (?_) {};
        };
      };
    };
    
    if (errors.size() > 0) {
      #err(errors)
    } else {
      #ok(())
    }
  };
  
  /**
   * Get property value from Class by name
   */
  public func getProperty(properties: [PropertyShared], name: Text) : ?CandyShared {
    let prop = Array.find(properties, func(p: PropertyShared) : Bool { p.name == name });
    switch (prop) {
      case (?p) ?p.value;
      case (null) null;
    }
  };
  
  /**
   * Create a validation context
   */
  public func createContext(path: Text, maxDepth: Nat) : ValidationContext {
    {
      path = path;
      depth = 0;
      maxDepth = maxDepth;
      strictMode = true;
    }
  };
  
  /**
   * Create a child context for nested validation
   */
  public func childContext(parent: ValidationContext, childPath: Text) : ValidationContext {
    {
      path = if (parent.path == "") childPath else parent.path # "." # childPath;
      depth = parent.depth + 1;
      maxDepth = parent.maxDepth;
      strictMode = parent.strictMode;
    }
  };
  
  // Helper functions for comparisons
  
  private func matchesPattern(text: Text, pattern: Text) : Bool {
    // Simplified pattern matching - in a real implementation,
    // this would use proper regex or more sophisticated matching
    switch (pattern) {
      case ("alphanumeric") {
        // Check if text contains only alphanumeric characters
        isAlphanumeric(text)
      };
      case ("email") {
        // Basic email validation
        isValidEmail(text)
      };
      case (_) true; // Default to true for unknown patterns
    }
  };
  
  private func isAlphanumeric(text: Text) : Bool {
    // Simple check for alphanumeric characters
    text.size() > 0 and not Text.contains(text, #text(" "))
  };
  
  private func isValidEmail(text: Text) : Bool {
    // Very basic email validation
    Text.contains(text, #text("@")) and Text.contains(text, #text("."))
  };
  
  private func isGreaterOrEqual(a: CandyShared, b: CandyShared) : Bool {
    compareValues(a, b) >= 0
  };
  
  private func isLessOrEqual(a: CandyShared, b: CandyShared) : Bool {
    compareValues(a, b) <= 0
  };
  
  private func compareValues(a: CandyShared, b: CandyShared) : Int {
    // Simplified comparison - in practice, this would handle all numeric types
    switch (a, b) {
      case (#Nat(x), #Nat(y)) {
        if (x < y) -1 else if (x > y) 1 else 0
      };
      case (#Int(x), #Int(y)) {
        if (x < y) -1 else if (x > y) 1 else 0
      };
      case (#Nat64(x), #Nat64(y)) {
        if (x < y) -1 else if (x > y) 1 else 0
      };
      case (#Int64(x), #Int64(y)) {
        if (x < y) -1 else if (x > y) 1 else 0
      };
      case (#Float(x), #Float(y)) {
        if (x < y) -1 else if (x > y) 1 else 0
      };
      case (_, _) 0; // Different types or unsupported comparison
    }
  };
  
  /**
   * Format validation error for display
   */
  public func formatError(error: ValidationError) : Text {
    switch (error) {
      case (#InvalidType(details)) {
        "Invalid type at " # details.path # ": expected " # details.expected # ", found " # details.found
      };
      case (#OutOfRange(details)) {
        "Value out of range at " # details.path # ": validation failed"
      };
      case (#InvalidSize(details)) {
        "Invalid size at " # details.path # ": validation failed" # 
        " (expected min: " # (switch(details.min) { case (?m) "specified"; case null "none" }) # 
        ", max: " # (switch(details.max) { case (?m) "specified"; case null "none" }) # ")"
      };
      case (#MissingProperty(details)) {
        "Missing required property at " # details.path # ": " # details.property
      };
      case (#InvalidPattern(details)) {
        "Pattern mismatch at " # details.path # ": '" # details.value # "' does not match pattern '" # details.pattern # "'"
      };
      case (#CustomError(details)) {
        details.message # " at " # details.path
      };
    }
  };
}
