import CandyTypes "mo:candy/types";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Option "mo:base/Option";

module ICRC16Validator {
  type CandyShared = CandyTypes.CandyShared;
  type PropertyShared = CandyTypes.PropertyShared;

  // ========================================
  // Map Validation Functions (Outer Accessors)
  // ========================================

  /// Validate that a Map contains all required keys
  public func validateMapRequiredKeys(candy: CandyShared, requiredKeys: [Text]) : Bool {
    switch (candy) {
      case (#Map(entries)) {
        Array.foldLeft<Text, Bool>(requiredKeys, true, func(acc, requiredKey) {
          acc and Option.isSome(Array.find<(Text, CandyShared)>(entries, func((key, _)) { key == requiredKey }))
        })
      };
      case (_) false;
    }
  };

  /// Validate that a Map contains only allowed keys
  public func validateMapAllowedKeys(candy: CandyShared, allowedKeys: [Text]) : Bool {
    switch (candy) {
      case (#Map(entries)) {
        Array.foldLeft<(Text, CandyShared), Bool>(entries, true, func(acc, (key, _)) {
          acc and Option.isSome(Array.find<Text>(allowedKeys, func(allowedKey) { allowedKey == key }))
        })
      };
      case (_) false;
    }
  };

  /// Validate the number of entries in a Map
  public func validateMapEntryCount(candy: CandyShared, min: ?Nat, max: ?Nat) : Bool {
    switch (candy) {
      case (#Map(entries)) {
        let count = entries.size();
        let minOk = switch (min) {
          case (?minVal) count >= minVal;
          case (null) true;
        };
        let maxOk = switch (max) {
          case (?maxVal) count <= maxVal;
          case (null) true;
        };
        minOk and maxOk
      };
      case (_) false;
    }
  };

  /// Get a value from a Map by key
  public func getMapValue(candy: CandyShared, key: Text) : ?CandyShared {
    switch (candy) {
      case (#Map(entries)) {
        switch (Array.find<(Text, CandyShared)>(entries, func((entryKey, _)) { entryKey == key })) {
          case (?(_, value)) ?value;
          case (null) null;
        }
      };
      case (_) null;
    }
  };

  // ========================================
  // Map Validation Functions (Inner Accessors)
  // ========================================

  /// Validate that a Map entries array contains all required keys
  public func validateMapInnerRequiredKeys(entries: [(Text, CandyShared)], requiredKeys: [Text]) : Bool {
    Array.foldLeft<Text, Bool>(requiredKeys, true, func(acc, requiredKey) {
      acc and Option.isSome(Array.find<(Text, CandyShared)>(entries, func((key, _)) { key == requiredKey }))
    })
  };

  /// Validate that a Map entries array contains only allowed keys
  public func validateMapInnerAllowedKeys(entries: [(Text, CandyShared)], allowedKeys: [Text]) : Bool {
    Array.foldLeft<(Text, CandyShared), Bool>(entries, true, func(acc, (key, _)) {
      acc and Option.isSome(Array.find<Text>(allowedKeys, func(allowedKey) { allowedKey == key }))
    })
  };

  /// Validate the number of entries in a Map entries array
  public func validateMapInnerEntryCount(entries: [(Text, CandyShared)], min: ?Nat, max: ?Nat) : Bool {
    let count = entries.size();
    let minOk = switch (min) {
      case (?minVal) count >= minVal;
      case (null) true;
    };
    let maxOk = switch (max) {
      case (?maxVal) count <= maxVal;
      case (null) true;
    };
    minOk and maxOk
  };

  /// Get a value from Map entries array by key
  public func getMapInnerValue(entries: [(Text, CandyShared)], key: Text) : ?CandyShared {
    switch (Array.find<(Text, CandyShared)>(entries, func((entryKey, _)) { entryKey == key })) {
      case (?(_, value)) ?value;
      case (null) null;
    }
  };

  // ========================================
  // ValueMap Validation Functions (Outer Accessors)
  // ========================================

  /// Compare two CandyShared values for equality (simplified)
  private func candyEquals(a: CandyShared, b: CandyShared) : Bool {
    // This is a simplified equality check - in practice you might want more robust comparison
    switch (a, b) {
      case (#Text(textA), #Text(textB)) textA == textB;
      case (#Nat(natA), #Nat(natB)) natA == natB;
      case (#Int(intA), #Int(intB)) intA == intB;
      case (#Bool(boolA), #Bool(boolB)) boolA == boolB;
      case (#Blob(blobA), #Blob(blobB)) blobA == blobB;
      case (#Principal(principalA), #Principal(principalB)) principalA == principalB;
      // Add more cases as needed
      case (_, _) false; // Different types or unsupported comparison
    }
  };

  /// Validate that a ValueMap contains all required keys
  public func validateValueMapRequiredKeys(candy: CandyShared, requiredKeys: [CandyShared]) : Bool {
    switch (candy) {
      case (#ValueMap(entries)) {
        Array.foldLeft<CandyShared, Bool>(requiredKeys, true, func(acc, requiredKey) {
          acc and Option.isSome(Array.find<(CandyShared, CandyShared)>(entries, func((key, _)) { candyEquals(key, requiredKey) }))
        })
      };
      case (_) false;
    }
  };

  /// Validate that a ValueMap contains only allowed keys
  public func validateValueMapAllowedKeys(candy: CandyShared, allowedKeys: [CandyShared]) : Bool {
    switch (candy) {
      case (#ValueMap(entries)) {
        Array.foldLeft<(CandyShared, CandyShared), Bool>(entries, true, func(acc, (key, _)) {
          acc and Option.isSome(Array.find<CandyShared>(allowedKeys, func(allowedKey) { candyEquals(allowedKey, key) }))
        })
      };
      case (_) false;
    }
  };

  /// Validate the number of entries in a ValueMap
  public func validateValueMapEntryCount(candy: CandyShared, min: ?Nat, max: ?Nat) : Bool {
    switch (candy) {
      case (#ValueMap(entries)) {
        let count = entries.size();
        let minOk = switch (min) {
          case (?minVal) count >= minVal;
          case (null) true;
        };
        let maxOk = switch (max) {
          case (?maxVal) count <= maxVal;
          case (null) true;
        };
        minOk and maxOk
      };
      case (_) false;
    }
  };

  /// Get a value from a ValueMap by key
  public func getValueMapValue(candy: CandyShared, key: CandyShared) : ?CandyShared {
    switch (candy) {
      case (#ValueMap(entries)) {
        switch (Array.find<(CandyShared, CandyShared)>(entries, func((entryKey, _)) { candyEquals(entryKey, key) })) {
          case (?(_, value)) ?value;
          case (null) null;
        }
      };
      case (_) null;
    }
  };

  // ========================================
  // ValueMap Validation Functions (Inner Accessors)
  // ========================================

  /// Validate that a ValueMap entries array contains all required keys
  public func validateValueMapInnerRequiredKeys(entries: [(CandyShared, CandyShared)], requiredKeys: [CandyShared]) : Bool {
    Array.foldLeft<CandyShared, Bool>(requiredKeys, true, func(acc, requiredKey) {
      acc and Option.isSome(Array.find<(CandyShared, CandyShared)>(entries, func((key, _)) { candyEquals(key, requiredKey) }))
    })
  };

  /// Validate that a ValueMap entries array contains only allowed keys
  public func validateValueMapInnerAllowedKeys(entries: [(CandyShared, CandyShared)], allowedKeys: [CandyShared]) : Bool {
    Array.foldLeft<(CandyShared, CandyShared), Bool>(entries, true, func(acc, (key, _)) {
      acc and Option.isSome(Array.find<CandyShared>(allowedKeys, func(allowedKey) { candyEquals(allowedKey, key) }))
    })
  };

  /// Validate the number of entries in a ValueMap entries array
  public func validateValueMapInnerEntryCount(entries: [(CandyShared, CandyShared)], min: ?Nat, max: ?Nat) : Bool {
    let count = entries.size();
    let minOk = switch (min) {
      case (?minVal) count >= minVal;
      case (null) true;
    };
    let maxOk = switch (max) {
      case (?maxVal) count <= maxVal;
      case (null) true;
    };
    minOk and maxOk
  };

  /// Get a value from ValueMap entries array by key
  public func getValueMapInnerValue(entries: [(CandyShared, CandyShared)], key: CandyShared) : ?CandyShared {
    switch (Array.find<(CandyShared, CandyShared)>(entries, func((entryKey, _)) { candyEquals(entryKey, key) })) {
      case (?(_, value)) ?value;
      case (null) null;
    }
  };

  // ========================================
  // Class Validation Functions (Outer Accessors)
  // ========================================

  /// Validate that a Class contains all required properties
  public func validateClassRequiredProperties(candy: CandyShared, requiredProperties: [Text]) : Bool {
    switch (candy) {
      case (#Class(properties)) {
        Array.foldLeft<Text, Bool>(requiredProperties, true, func(acc, requiredProp) {
          acc and Option.isSome(Array.find<PropertyShared>(properties, func(prop) { prop.name == requiredProp }))
        })
      };
      case (_) false;
    }
  };

  /// Validate that a Class contains only allowed properties
  public func validateClassAllowedProperties(candy: CandyShared, allowedProperties: [Text]) : Bool {
    switch (candy) {
      case (#Class(properties)) {
        Array.foldLeft<PropertyShared, Bool>(properties, true, func(acc, prop) {
          acc and Option.isSome(Array.find<Text>(allowedProperties, func(allowedProp) { allowedProp == prop.name }))
        })
      };
      case (_) false;
    }
  };

  /// Validate the number of properties in a Class
  public func validateClassPropertyCount(candy: CandyShared, min: ?Nat, max: ?Nat) : Bool {
    switch (candy) {
      case (#Class(properties)) {
        let count = properties.size();
        let minOk = switch (min) {
          case (?minVal) count >= minVal;
          case (null) true;
        };
        let maxOk = switch (max) {
          case (?maxVal) count <= maxVal;
          case (null) true;
        };
        minOk and maxOk
      };
      case (_) false;
    }
  };

  /// Get a property from a Class by name
  public func getClassProperty(candy: CandyShared, propertyName: Text) : ?PropertyShared {
    switch (candy) {
      case (#Class(properties)) {
        Array.find<PropertyShared>(properties, func(prop) { prop.name == propertyName })
      };
      case (_) null;
    }
  };

  // ========================================
  // Class Validation Functions (Inner Accessors)
  // ========================================

  /// Validate that a properties array contains all required properties
  public func validateClassInnerRequiredProperties(properties: [PropertyShared], requiredProperties: [Text]) : Bool {
    Array.foldLeft<Text, Bool>(requiredProperties, true, func(acc, requiredProp) {
      acc and Option.isSome(Array.find<PropertyShared>(properties, func(prop) { prop.name == requiredProp }))
    })
  };

  /// Validate that a properties array contains only allowed properties
  public func validateClassInnerAllowedProperties(properties: [PropertyShared], allowedProperties: [Text]) : Bool {
    Array.foldLeft<PropertyShared, Bool>(properties, true, func(acc, prop) {
      acc and Option.isSome(Array.find<Text>(allowedProperties, func(allowedProp) { allowedProp == prop.name }))
    })
  };

  /// Validate the number of properties in a properties array
  public func validateClassInnerPropertyCount(properties: [PropertyShared], min: ?Nat, max: ?Nat) : Bool {
    let count = properties.size();
    let minOk = switch (min) {
      case (?minVal) count >= minVal;
      case (null) true;
    };
    let maxOk = switch (max) {
      case (?maxVal) count <= maxVal;
      case (null) true;
    };
    minOk and maxOk
  };

  /// Get a property from properties array by name
  public func getClassInnerProperty(properties: [PropertyShared], propertyName: Text) : ?PropertyShared {
    Array.find<PropertyShared>(properties, func(prop) { prop.name == propertyName })
  };

  // ========================================
  // Utility Functions
  // ========================================

  /// Get the type name of a CandyShared value
  public func getCandyType(candy: CandyShared) : Text {
    switch (candy) {
      case (#Text(_)) "Text";
      case (#Nat(_)) "Nat";
      case (#Nat8(_)) "Nat8";
      case (#Nat16(_)) "Nat16";
      case (#Nat32(_)) "Nat32";
      case (#Nat64(_)) "Nat64";
      case (#Int(_)) "Int";
      case (#Int8(_)) "Int8";
      case (#Int16(_)) "Int16";
      case (#Int32(_)) "Int32";
      case (#Int64(_)) "Int64";
      case (#Float(_)) "Float";
      case (#Bool(_)) "Bool";
      case (#Blob(_)) "Blob";
      case (#Class(_)) "Class";
      case (#Principal(_)) "Principal";
      case (#Array(_)) "Array";
      case (#Map(_)) "Map";
      case (#ValueMap(_)) "ValueMap";
      case (#Nats(_)) "Nats";
      case (#Ints(_)) "Ints";
      case (#Floats(_)) "Floats";
      case (#Option(_)) "Option";
      case (#Set(_)) "Set";
      case (#Bytes(_)) "Bytes";
    }
  };

  /// Estimate the size of a CandyShared value (rough approximation)
  public func estimateCandySize(candy: CandyShared) : Nat {
    switch (candy) {
      case (#Text(text)) text.size() * 4; // Rough estimate for UTF-8
      case (#Nat(_)) 8; // 64-bit number
      case (#Nat8(_)) 1; // 8-bit number
      case (#Nat16(_)) 2; // 16-bit number
      case (#Nat32(_)) 4; // 32-bit number
      case (#Nat64(_)) 8; // 64-bit number
      case (#Int(_)) 8; // 64-bit number
      case (#Int8(_)) 1; // 8-bit number
      case (#Int16(_)) 2; // 16-bit number
      case (#Int32(_)) 4; // 32-bit number
      case (#Int64(_)) 8; // 64-bit number
      case (#Float(_)) 8; // 64-bit float
      case (#Bool(_)) 1; // Boolean
      case (#Blob(blob)) blob.size();
      case (#Principal(_)) 29; // Principal size
      case (#Array(arr)) {
        Array.foldLeft<CandyShared, Nat>(arr, 0, func(acc, item) { acc + estimateCandySize(item) })
      };
      case (#Map(entries)) {
        Array.foldLeft<(Text, CandyShared), Nat>(entries, 0, func(acc, (key, value)) { 
          acc + key.size() * 4 + estimateCandySize(value) 
        })
      };
      case (#ValueMap(entries)) {
        Array.foldLeft<(CandyShared, CandyShared), Nat>(entries, 0, func(acc, (key, value)) { 
          acc + estimateCandySize(key) + estimateCandySize(value) 
        })
      };
      case (#Class(properties)) {
        Array.foldLeft<PropertyShared, Nat>(properties, 0, func(acc, prop) { 
          acc + prop.name.size() * 4 + estimateCandySize(prop.value) + 1 // +1 for immutable flag
        })
      };
      case (#Nats(nats)) nats.size() * 8;
      case (#Ints(ints)) ints.size() * 8;
      case (#Floats(floats)) floats.size() * 8;
      case (#Bytes(bytes)) bytes.size();
      case (#Set(set)) {
        Array.foldLeft<CandyShared, Nat>(set, 0, func(acc, item) { acc + estimateCandySize(item) })
      };
      case (#Option(opt)) {
        switch (opt) {
          case (?value) estimateCandySize(value);
          case (null) 1; // Null option
        }
      };
    }
  };

  // ========================================
  // Nested Validation Functions
  // ========================================

  /// Validate nested Map using a path (array of keys)
  public func validateNestedMap(candy: CandyShared, path: [Text], validator: (CandyShared) -> Bool) : Bool {
    func traverse(current: CandyShared, pathIndex: Nat) : Bool {
      if (pathIndex >= path.size()) {
        validator(current) // End of path, validate current value
      } else {
        let nextKey = path[pathIndex];
        switch (getMapValue(current, nextKey)) {
          case (?nextValue) traverse(nextValue, pathIndex + 1);
          case (null) false; // Path not found
        }
      }
    };
    traverse(candy, 0)
  };

  /// Validate nested ValueMap using a path (array of CandyShared keys)
  public func validateNestedValueMap(candy: CandyShared, path: [CandyShared], validator: (CandyShared) -> Bool) : Bool {
    func traverse(current: CandyShared, pathIndex: Nat) : Bool {
      if (pathIndex >= path.size()) {
        validator(current) // End of path, validate current value
      } else {
        let nextKey = path[pathIndex];
        switch (getValueMapValue(current, nextKey)) {
          case (?nextValue) traverse(nextValue, pathIndex + 1);
          case (null) false; // Path not found
        }
      }
    };
    traverse(candy, 0)
  };

  /// Validate nested Class using a path (array of property names)
  public func validateNestedClass(candy: CandyShared, path: [Text], validator: (CandyShared) -> Bool) : Bool {
    func traverse(current: CandyShared, pathIndex: Nat) : Bool {
      if (pathIndex >= path.size()) {
        validator(current) // End of path, validate current value
      } else {
        let nextProp = path[pathIndex];
        switch (getClassProperty(current, nextProp)) {
          case (?prop) traverse(prop.value, pathIndex + 1);
          case (null) false; // Path not found
        }
      }
    };
    traverse(candy, 0)
  };
}
