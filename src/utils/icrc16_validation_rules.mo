/// ICRC16 CandyShared validation rules for InspectMo
/// Extends ValidationRule<T,M> pattern with ICRC16-specific validation types
///
/// This module provides specialized validation rules for ICRC16 CandyShared data structures,
/// enabling type-safe validation of complex nested data in system inspect functions.

import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Array "mo:base/Array";
import CandyTypes "mo:candy/types";
import MigrationTypes "../migrations/types";
import Utils "./icrc16";

module {
  public type CandyShared = CandyTypes.CandyShared;
  public type PropertyShared = CandyTypes.PropertyShared;
  
  /// ICRC16-specific validation context
  public type ICRC16ValidationContext = {
    maxDepth: Nat;          // Maximum nesting depth allowed
    maxSize: Nat;           // Maximum total size allowed
    allowedTypes: [Text];   // Allowed CandyShared variant types
    strictMode: Bool;       // Enable strict validation
  };
  
  /// ICRC16-specific validation rule types extending ValidationRule<T,M>
  public type ICRC16ValidationRule<T,M> = {
    // Core ICRC16 rules
    #candyType: (accessor: M -> CandyShared, expectedType: Text);
    #candySize: (accessor: M -> CandyShared, min: ?Nat, max: ?Nat);
    #candyDepth: (accessor: M -> CandyShared, maxDepth: Nat);
    #candyPattern: (accessor: M -> CandyShared, pattern: Text);
    #candyRange: (accessor: M -> CandyShared, min: ?Int, max: ?Int);
    #candyStructure: (accessor: M -> CandyShared, context: ICRC16ValidationContext);
    
    // PropertyShared-specific rules
    #propertyExists: (accessor: M -> [PropertyShared], propertyName: Text);
    #propertyType: (accessor: M -> [PropertyShared], propertyName: Text, expectedType: Text);
    #propertySize: (accessor: M -> [PropertyShared], propertyName: Text, min: ?Nat, max: ?Nat);
    
    // Array/collection validation
    #arrayLength: (accessor: M -> CandyShared, min: ?Nat, max: ?Nat);
    #arrayItemType: (accessor: M -> CandyShared, expectedType: Text);
    #mapKeyExists: (accessor: M -> CandyShared, key: Text);
    #mapSize: (accessor: M -> CandyShared, min: ?Nat, max: ?Nat);
    
    // Complex validation
    #customCandyCheck: (accessor: M -> CandyShared, validator: CandyShared -> Result.Result<(), Text>);
    #nestedValidation: (accessor: M -> CandyShared, rules: [ICRC16ValidationRule<T,M>]);
  };
  
  /// Validate an ICRC16 validation rule
  public func validateICRC16Rule<T,M>(
    rule: ICRC16ValidationRule<T,M>, 
    typedArgs: M,
    caller: Principal,
    methodName: Text
  ) : Result.Result<(), Text> {
    switch (rule) {
      case (#candyType(accessor, expectedType)) {
        let candyValue = accessor(typedArgs);
        let context = { path = methodName; depth = 0; maxDepth = 10; strictMode = false };
        switch (Utils.validateType(candyValue, [expectedType], context)) {
          case (#ok()) { #ok() };
          case (#err(error)) { 
            switch (error) {
              case (#InvalidType(details)) { #err("candyType: " # details.expected # " expected, got " # details.found) };
              case (#InvalidSize(details)) { #err("candyType: size error - " # details.path) };
              case (#InvalidPattern(details)) { #err("candyType: pattern error - " # details.path) };
              case (#OutOfRange(details)) { #err("candyType: range error - " # details.path) };
              case (#MissingProperty(details)) { #err("candyType: missing property - " # details.property) };
              case (#CustomError(details)) { #err("candyType: " # details.message) };
            }
          };
        };
      };
      
      case (#candySize(accessor, min, max)) {
        let candyValue = accessor(typedArgs);
        let context = { path = methodName; depth = 0; maxDepth = 10; strictMode = false };
        let config = { min = min; max = max };
        switch (Utils.validateSize(candyValue, config, context)) {
          case (#ok()) { #ok() };
          case (#err(error)) { 
            switch (error) {
              case (#InvalidSize(details)) { 
                let actual = debug_show(details.actual);
                let range = debug_show(details.min) # " to " # debug_show(details.max);
                #err("candySize: size " # actual # " outside range " # range)
              };
              case (_) { #err("candySize: validation error") };
            }
          };
        };
      };
      
      case (#candyDepth(accessor, maxDepth)) {
        let candyValue = accessor(typedArgs);
        switch (candyValue) {
          case (#Class(properties)) {
            let context = { path = methodName; depth = 0; maxDepth = maxDepth; strictMode = false };
            let config = {
              requiredProperties = [];
              optionalProperties = [];
              allowAdditionalProperties = true;
              maxDepth = ?maxDepth;
            };
            switch (Utils.validateStructure(properties, config, context)) {
              case (#ok()) { #ok() };
              case (#err(errors)) { 
                if (errors.size() > 0) {
                  switch (errors[0]) {
                    case (#InvalidType(details)) { #err("candyDepth: " # details.found # " at " # details.path) };
                    case (#InvalidSize(details)) { #err("candyDepth: size error at " # details.path) };
                    case (#InvalidPattern(details)) { #err("candyDepth: pattern error at " # details.path) };
                    case (#OutOfRange(details)) { #err("candyDepth: range error at " # details.path) };
                    case (#MissingProperty(details)) { #err("candyDepth: missing property " # details.property) };
                    case (#CustomError(details)) { #err("candyDepth: " # details.message) };
                  }
                } else {
                  #err("candyDepth: validation failed")
                }
              };
            };
          };
          case (_) {
            #err("candyDepth: Value is not a Class type")
          };
        };
      };
      
      case (#candyPattern(accessor, pattern)) {
        let candyValue = accessor(typedArgs);
        switch (candyValue) {
          case (#Text(text)) {
            let context = { path = methodName; depth = 0; maxDepth = 10; strictMode = false };
            let config = {
              minLength = null;
              maxLength = null;
              pattern = ?pattern;
              allowedValues = null;
            };
            switch (Utils.validateTextPattern(text, config, context)) {
              case (#ok()) { #ok() };
              case (#err(error)) { 
                switch (error) {
                  case (#InvalidPattern(details)) { #err("candyPattern: pattern '" # details.pattern # "' failed for value '" # details.value # "'") };
                  case (_) { #err("candyPattern: validation error") };
                }
              };
            };
          };
          case (_) {
            #err("candyPattern: Value is not a Text type")
          };
        };
      };
      
      case (#candyRange(accessor, min, max)) {
        let candyValue = accessor(typedArgs);
        let context = { path = methodName; depth = 0; maxDepth = 10; strictMode = false };
        
        // Convert Int values to CandyShared for range validation
        let minCandy = switch (min) {
          case (?value) ?#Int(value);
          case (null) null;
        };
        let maxCandy = switch (max) {
          case (?value) ?#Int(value);
          case (null) null;
        };
        
        let config = { min = minCandy; max = maxCandy };
        switch (Utils.validateRange(candyValue, config, context)) {
          case (#ok()) { #ok() };
          case (#err(error)) { 
            switch (error) {
              case (#OutOfRange(details)) { #err("candyRange: value out of range at " # details.path) };
              case (_) { #err("candyRange: validation error") };
            }
          };
        };
      };
      
      case (#candyStructure(accessor, icrcContext)) {
        let candyValue = accessor(typedArgs);
        switch (candyValue) {
          case (#Class(properties)) {
            let context = { path = methodName; depth = 0; maxDepth = icrcContext.maxDepth; strictMode = icrcContext.strictMode };
            let config = {
              requiredProperties = [];
              optionalProperties = [];
              allowAdditionalProperties = true;
              maxDepth = ?icrcContext.maxDepth;
            };
            switch (Utils.validateStructure(properties, config, context)) {
              case (#ok()) { #ok() };
              case (#err(errors)) { 
                if (errors.size() > 0) {
                  switch (errors[0]) {
                    case (#InvalidType(details)) { #err("candyStructure: " # details.found # " at " # details.path) };
                    case (#InvalidSize(details)) { #err("candyStructure: size error at " # details.path) };
                    case (#InvalidPattern(details)) { #err("candyStructure: pattern error at " # details.path) };
                    case (#OutOfRange(details)) { #err("candyStructure: range error at " # details.path) };
                    case (#MissingProperty(details)) { #err("candyStructure: missing property " # details.property) };
                    case (#CustomError(details)) { #err("candyStructure: " # details.message) };
                  }
                } else {
                  #err("candyStructure: validation failed")
                }
              };
            };
          };
          case (_) {
            #err("candyStructure: Value is not a Class type")
          };
        };
      };
      
      case (#propertyExists(accessor, propertyName)) {
        let properties = accessor(typedArgs);
        var found = false;
        for (prop in properties.vals()) {
          if (prop.name == propertyName) {
            found := true;
          };
        };
        if (found) {
          #ok()
        } else {
          #err("propertyExists: Property '" # propertyName # "' not found")
        };
      };
      
      case (#propertyType(accessor, propertyName, expectedType)) {
        let properties = accessor(typedArgs);
        var result: ?Result.Result<(), Text> = null;
        for (prop in properties.vals()) {
          if (prop.name == propertyName) {
            let context = { path = methodName # "." # propertyName; depth = 0; maxDepth = 10; strictMode = false };
            switch (Utils.validateType(prop.value, [expectedType], context)) {
              case (#ok()) { result := ?#ok() };
              case (#err(error)) { 
                switch (error) {
                  case (#InvalidType(details)) { result := ?#err(details.expected # " expected, got " # details.found) };
                  case (_) { result := ?#err("type validation failed") };
                }
              };
            };
          };
        };
        switch (result) {
          case (?validation) { validation };
          case (null) {
            #err("propertyType: Property '" # propertyName # "' not found")
          };
        };
      };
      
      case (#propertySize(accessor, propertyName, min, max)) {
        let properties = accessor(typedArgs);
        var result: ?Result.Result<(), Text> = null;
        for (prop in properties.vals()) {
          if (prop.name == propertyName) {
            let context = { path = methodName # "." # propertyName; depth = 0; maxDepth = 10; strictMode = false };
            let config = { min = min; max = max };
            switch (Utils.validateSize(prop.value, config, context)) {
              case (#ok()) { result := ?#ok() };
              case (#err(error)) { 
                switch (error) {
                  case (#InvalidSize(details)) { 
                    let actual = debug_show(details.actual);
                    result := ?#err("size " # actual # " outside range")
                  };
                  case (_) { result := ?#err("size validation failed") };
                }
              };
            };
          };
        };
        switch (result) {
          case (?validation) { validation };
          case (null) {
            #err("propertySize: Property '" # propertyName # "' not found")
          };
        };
      };
      
      case (#arrayLength(accessor, min, max)) {
        let candyValue = accessor(typedArgs);
        switch (candyValue) {
          case (#Array(arr)) {
            let length = arr.size();
            switch (min, max) {
              case (?minLen, ?maxLen) {
                if (length < minLen or length > maxLen) {
                  #err("arrayLength: Array length " # debug_show(length) # " outside range [" # debug_show(minLen) # ", " # debug_show(maxLen) # "]")
                } else {
                  #ok()
                };
              };
              case (?minLen, null) {
                if (length < minLen) {
                  #err("arrayLength: Array length " # debug_show(length) # " below minimum " # debug_show(minLen))
                } else {
                  #ok()
                };
              };
              case (null, ?maxLen) {
                if (length > maxLen) {
                  #err("arrayLength: Array length " # debug_show(length) # " above maximum " # debug_show(maxLen))
                } else {
                  #ok()
                };
              };
              case (null, null) {
                #ok()
              };
            };
          };
          case (_) {
            #err("arrayLength: Value is not an array")
          };
        };
      };
      
      case (#arrayItemType(accessor, expectedType)) {
        let candyValue = accessor(typedArgs);
        switch (candyValue) {
          case (#Array(arr)) {
            for (item in arr.vals()) {
              let context = { path = methodName # "[item]"; depth = 0; maxDepth = 10; strictMode = false };
              switch (Utils.validateType(item, [expectedType], context)) {
                case (#ok()) { /* continue */ };
                case (#err(error)) {
                  switch (error) {
                    case (#InvalidType(details)) { 
                      return #err("arrayItemType: " # details.expected # " expected, got " # details.found); 
                    };
                    case (_) { return #err("arrayItemType: validation error") };
                  }
                };
              };
            };
            #ok()
          };
          case (_) {
            #err("arrayItemType: Value is not an array")
          };
        };
      };
      
      case (#mapKeyExists(accessor, key)) {
        let candyValue = accessor(typedArgs);
        switch (candyValue) {
          case (#Map(map)) {
            var found = false;
            for ((mapKey, _) in map.vals()) {
              if (mapKey == key) {
                found := true;
              };
            };
            if (found) {
              #ok()
            } else {
              #err("mapKeyExists: Key '" # key # "' not found in map")
            };
          };
          case (_) {
            #err("mapKeyExists: Value is not a map")
          };
        };
      };
      
      case (#mapSize(accessor, min, max)) {
        let candyValue = accessor(typedArgs);
        switch (candyValue) {
          case (#Map(map)) {
            let size = map.size();
            switch (min, max) {
              case (?minSize, ?maxSize) {
                if (size < minSize or size > maxSize) {
                  #err("mapSize: Map size " # debug_show(size) # " outside range [" # debug_show(minSize) # ", " # debug_show(maxSize) # "]")
                } else {
                  #ok()
                };
              };
              case (?minSize, null) {
                if (size < minSize) {
                  #err("mapSize: Map size " # debug_show(size) # " below minimum " # debug_show(minSize))
                } else {
                  #ok()
                };
              };
              case (null, ?maxSize) {
                if (size > maxSize) {
                  #err("mapSize: Map size " # debug_show(size) # " above maximum " # debug_show(maxSize))
                } else {
                  #ok()
                };
              };
              case (null, null) {
                #ok()
              };
            };
          };
          case (_) {
            #err("mapSize: Value is not a map")
          };
        };
      };
      
      case (#customCandyCheck(accessor, validator)) {
        let candyValue = accessor(typedArgs);
        switch (validator(candyValue)) {
          case (#ok()) { #ok() };
          case (#err(msg)) { #err("customCandyCheck: " # msg) };
        };
      };
      
      case (#nestedValidation(accessor, rules)) {
        let candyValue = accessor(typedArgs);
        for (nestedRule in rules.vals()) {
          switch (validateICRC16Rule(nestedRule, typedArgs, caller, methodName)) {
            case (#ok()) { /* continue */ };
            case (#err(msg)) {
              return #err("nestedValidation: " # msg);
            };
          };
        };
        #ok()
      };
    };
  };
  
  // Convenience functions for creating ICRC16 validation rules
  
  /// Create a CandyShared type validation rule
  public func candyType<T,M>(
    accessor: M -> CandyShared, 
    expectedType: Text
  ) : ICRC16ValidationRule<T,M> {
    #candyType(accessor, expectedType)
  };
  
  /// Create a CandyShared size validation rule
  public func candySize<T,M>(
    accessor: M -> CandyShared, 
    min: ?Nat, 
    max: ?Nat
  ) : ICRC16ValidationRule<T,M> {
    #candySize(accessor, min, max)
  };
  
  /// Create a CandyShared depth validation rule
  public func candyDepth<T,M>(
    accessor: M -> CandyShared, 
    maxDepth: Nat
  ) : ICRC16ValidationRule<T,M> {
    #candyDepth(accessor, maxDepth)
  };
  
  /// Create a CandyShared pattern validation rule
  public func candyPattern<T,M>(
    accessor: M -> CandyShared, 
    pattern: Text
  ) : ICRC16ValidationRule<T,M> {
    #candyPattern(accessor, pattern)
  };
  
  /// Create a CandyShared range validation rule
  public func candyRange<T,M>(
    accessor: M -> CandyShared, 
    min: ?Int, 
    max: ?Int
  ) : ICRC16ValidationRule<T,M> {
    #candyRange(accessor, min, max)
  };
  
  /// Create a CandyShared structure validation rule
  public func candyStructure<T,M>(
    accessor: M -> CandyShared, 
    context: ICRC16ValidationContext
  ) : ICRC16ValidationRule<T,M> {
    #candyStructure(accessor, context)
  };
  
  /// Create a property existence validation rule
  public func propertyExists<T,M>(
    accessor: M -> [PropertyShared], 
    propertyName: Text
  ) : ICRC16ValidationRule<T,M> {
    #propertyExists(accessor, propertyName)
  };
  
  /// Create a property type validation rule
  public func propertyType<T,M>(
    accessor: M -> [PropertyShared], 
    propertyName: Text, 
    expectedType: Text
  ) : ICRC16ValidationRule<T,M> {
    #propertyType(accessor, propertyName, expectedType)
  };
  
  /// Create a property size validation rule
  public func propertySize<T,M>(
    accessor: M -> [PropertyShared], 
    propertyName: Text, 
    min: ?Nat, 
    max: ?Nat
  ) : ICRC16ValidationRule<T,M> {
    #propertySize(accessor, propertyName, min, max)
  };
  
  /// Create an array length validation rule
  public func arrayLength<T,M>(
    accessor: M -> CandyShared, 
    min: ?Nat, 
    max: ?Nat
  ) : ICRC16ValidationRule<T,M> {
    #arrayLength(accessor, min, max)
  };
  
  /// Create an array item type validation rule
  public func arrayItemType<T,M>(
    accessor: M -> CandyShared, 
    expectedType: Text
  ) : ICRC16ValidationRule<T,M> {
    #arrayItemType(accessor, expectedType)
  };
  
  /// Create a map key existence validation rule
  public func mapKeyExists<T,M>(
    accessor: M -> CandyShared, 
    key: Text
  ) : ICRC16ValidationRule<T,M> {
    #mapKeyExists(accessor, key)
  };
  
  /// Create a map size validation rule
  public func mapSize<T,M>(
    accessor: M -> CandyShared, 
    min: ?Nat, 
    max: ?Nat
  ) : ICRC16ValidationRule<T,M> {
    #mapSize(accessor, min, max)
  };
  
  /// Create a custom CandyShared validation rule
  public func customCandyCheck<T,M>(
    accessor: M -> CandyShared, 
    validator: CandyShared -> Result.Result<(), Text>
  ) : ICRC16ValidationRule<T,M> {
    #customCandyCheck(accessor, validator)
  };
  
  /// Create a nested validation rule
  public func nestedValidation<T,M>(
    accessor: M -> CandyShared, 
    rules: [ICRC16ValidationRule<T,M>]
  ) : ICRC16ValidationRule<T,M> {
    #nestedValidation(accessor, rules)
  };
}
