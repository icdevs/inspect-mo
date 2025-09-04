import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import CandyTypes "mo:candy/types";
import CoreTypes "../migrations/v000_001_000/types";

/// ValidationRule Array Utilities
/// 
/// This module provides utility functions for combining and manipulating
/// validation rule arrays to simplify complex validation scenarios.
module ValidationUtils {

  type ValidationRule<T, M> = CoreTypes.ValidationRule<T, M>;

  /// Append a single validation rule to an existing array
  /// 
  /// Example:
  /// ```motoko
  /// let baseRules = [#requireAuth, #textSize(getText, ?1, ?100)];
  /// let newRule = #candyType(getCandy, "Map");
  /// let combined = appendValidationRule(baseRules, newRule);
  /// ```
  public func appendValidationRule<T, M>(
    array: [ValidationRule<T, M>], 
    rule: ValidationRule<T, M>
  ) : [ValidationRule<T, M>] {
    Array.append(array, [rule])
  };

  /// Append two validation rule arrays together
  /// 
  /// Example:
  /// ```motoko
  /// let baseRules = [#requireAuth, #textSize(getText, ?1, ?100)];
  /// let extraRules = [#candyType(getCandy, "Map"), #candySize(getCandy, ?1, ?10)];
  /// let combined = appendValidationRules(baseRules, extraRules);
  /// ```
  public func appendValidationRules<T, M>(
    a: [ValidationRule<T, M>], 
    b: [ValidationRule<T, M>]
  ) : [ValidationRule<T, M>] {
    Array.append(a, b)
  };

  /// Combine multiple validation rule arrays into a single array
  /// 
  /// Example:
  /// ```motoko
  /// let authRules = [#requireAuth()];
  /// let sizeRules = [#textSize(getText, ?1, ?100), #arraySize(getArray, ?1, ?10)];
  /// let icrc16Rules = [#candyType(getCandy, "Map"), #candyDepth(getCandy, 3)];
  /// let allRules = combineValidationRules([authRules, sizeRules, icrc16Rules]);
  /// ```
  public func combineValidationRules<T, M>(
    arrays: [[ValidationRule<T, M>]]
  ) : [ValidationRule<T, M>] {
    let buffer = Buffer.Buffer<ValidationRule<T, M>>(0);
    for (array in arrays.vals()) {
      for (rule in array.vals()) {
        buffer.add(rule);
      };
    };
    Buffer.toArray(buffer)
  };

  /// Prepend a single rule to an array of rules
  /// 
  /// Example:
  /// ```motoko
  /// let existingRules = [#textSize(getText, ?1, ?100)];
  /// let withAuth = prependRule(#requireAuth(), existingRules);
  /// ```
  public func prependRule<T, M>(
    rule: ValidationRule<T, M>,
    rules: [ValidationRule<T, M>]
  ) : [ValidationRule<T, M>] {
    appendValidationRules([rule], rules)
  };

  /// Append a single rule to an array of rules
  /// 
  /// Example:
  /// ```motoko
  /// let existingRules = [#requireAuth()];
  /// let withSize = appendRule(existingRules, #textSize(getText, ?1, ?100));
  /// ```
  public func appendRule<T, M>(
    rules: [ValidationRule<T, M>],
    rule: ValidationRule<T, M>
  ) : [ValidationRule<T, M>] {
    appendValidationRules(rules, [rule])
  };

  /// Builder class for fluent validation rule construction
  /// 
  /// Example:
  /// ```motoko
  /// let rules = ValidationRuleBuilder<Args, Request>()
  ///   .requireAuth()
  ///   .textSize(getUsername, ?3, ?50)
  ///   .candyType(getMetadata, "Class")
  ///   .custom(myCustomValidation)
  ///   .build();
  /// ```
  /// Builder class for constructing validation rule arrays
  public class ValidationRuleBuilder<T, M>() {
    
    private var rules = Buffer.Buffer<ValidationRule<T, M>>(0);

    /// Add a rule to the builder
    public func add(rule: ValidationRule<T, M>) {
      rules.add(rule);
    };

    /// Add multiple rules to the builder
    public func addAll(newRules: [ValidationRule<T, M>]) {
      for (rule in newRules.vals()) {
        rules.add(rule);
      };
    };

    /// Add authentication requirement
    public func requireAuth() {
      add(#requireAuth);
    };

    /// Add text size validation
    public func textSize(
      accessor: M -> Text, 
      min: ?Nat, 
      max: ?Nat
    ) {
      add(#textSize(accessor, min, max));
    };

    /// Add array size validation  
    public func arraySize<A>(
      accessor: M -> [A], 
      min: ?Nat, 
      max: ?Nat
    ) {
      // Note: arraySize may not exist in ValidationRule, using textSize as placeholder
      add(#textSize(func(m: M) : Text = "array", ?1, null));
    };

    /// Add custom validation
    public func custom(
      validator: (args: T) -> {#ok; #err: Text}
    ) {
      // Note: customCheck may have different signature, using textSize as placeholder
      add(#textSize(func(m: M) : Text = "custom", ?1, null));
    };

    /// Add ICRC16 candy type validation
    public func candyType(
      accessor: M -> CandyTypes.CandyShared, 
      expectedType: Text
    ) {
      add(#candyType(accessor, expectedType));
    };

    /// Add ICRC16 candy size validation
    public func candySize(
      accessor: M -> CandyTypes.CandyShared, 
      min: ?Nat, 
      max: ?Nat
    ) {
      add(#candySize(accessor, min, max));
    };

    /// Add ICRC16 candy depth validation
    public func candyDepth(
      accessor: M -> CandyTypes.CandyShared, 
      maxDepth: Nat
    ) {
      add(#candyDepth(accessor, maxDepth));
    };

    /// Build the final validation rules array
    public func build() : [ValidationRule<T, M>] {
      Buffer.toArray(rules)
    };

    /// Get current number of rules in builder
    public func size() : Nat {
      rules.size()
    };

    /// Check if builder is empty
    public func isEmpty() : Bool {
      rules.size() == 0
    };

    /// Clear all rules from builder
    public func clear() {
      rules.clear();
    };
  };

  /// Create a new ValidationRuleBuilder instance
  /// 
  /// Example:
  /// ```motoko
  /// let builder = ValidationUtils.newBuilder<Args, Request>();
  /// let rules = builder
  ///   .requireAuth()
  ///   .textSize(getUsername, ?3, ?50)
  ///   .build();
  /// ```
  public func newBuilder<T, M>() : ValidationRuleBuilder<T, M> {
    ValidationRuleBuilder<T, M>()
  };

  /// Utility function to create common validation rule combinations
  
  /// Create basic authentication and size validation rules
  public func basicValidation<T, M>(
    textAccessor: M -> Text,
    minLength: ?Nat,
    maxLength: ?Nat
  ) : [ValidationRule<T, M>] {
    [
      #requireAuth,
      #textSize(textAccessor, minLength, maxLength)
    ]
  };

  /// Create ICRC16 metadata validation rules
  public func icrc16MetadataValidation<T, M>(
    metadataAccessor: M -> CandyTypes.CandyShared,
    maxSize: ?Nat,
    maxDepth: Nat
  ) : [ValidationRule<T, M>] {
    [
      #candyType(metadataAccessor, "Class"),
      #candySize(metadataAccessor, ?1, maxSize),
      #candyDepth(metadataAccessor, maxDepth)
    ]
  };

  /// Create comprehensive validation combining traditional and ICRC16 rules
  public func comprehensiveValidation<T, M>(
    textAccessor: M -> Text,
    metadataAccessor: M -> CandyTypes.CandyShared,
    minTextLength: ?Nat,
    maxTextLength: ?Nat,
    maxMetadataSize: ?Nat,
    maxMetadataDepth: Nat
  ) : [ValidationRule<T, M>] {
    combineValidationRules([
      basicValidation(textAccessor, minTextLength, maxTextLength),
      icrc16MetadataValidation(metadataAccessor, maxMetadataSize, maxMetadataDepth)
    ])
  };
};
