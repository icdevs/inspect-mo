/// Integration Points Documentation: ICRC16ValidationRule<T,M> with Inspector Framework
/// 
/// This document identifies and documents the integration points where ICRC16ValidationRule<T,M>
/// will connect with the existing Inspector.ValidationRule<T,M> framework in src/core/inspector.mo
///
/// Author: InspectMo v0.1.1 ICRC16 Integration
/// Task: 1.6 Inspector integration points

// ========================================
// CURRENT INSPECTOR ARCHITECTURE ANALYSIS
// ========================================

/*
Current ValidationRule<T,M> Structure (from types.mo):
- T: Raw message variant type (e.g. ArgsAccessor with field accessor functions)
- M: Message accessor type (e.g. specific method parameters)
- Rules processed via validateSingleRule<M>() in Inspector class
- Integration via createMethodGuardInfo<M>() for method registration

Existing Validation Rules:
#textSize(accessor: M -> Text, min: ?Nat, max: ?Nat)
#blobSize(accessor: M -> Blob, min: ?Nat, max: ?Nat)  
#natValue(accessor: M -> Nat, min: ?Nat, max: ?Nat)
#intValue(accessor: M -> Int, min: ?Int, max: ?Int)
#requirePermission(Text)
#blockIngress
#blockAll
#allowedCallers(Map.Map<Principal, ()>)
#blockedCallers(Map.Map<Principal, ()>)
#requireAuth
#requireRole(Text)
#rateLimit(RateLimitRule)
#customCheck((CustomCheckArgs<T>) -> GuardResult)
#dynamicAuth((DynamicAuthArgs<T>) -> GuardResult)
*/

// ========================================
// ICRC16 VALIDATION RULE ARCHITECTURE
// ========================================

/*
ICRC16ValidationRule<T,M> Structure (from icrc16_validation_rules.mo):
- T: Same as ValidationRule<T,M> (raw message variant type)
- M: Extends to support CandyShared and [PropertyShared] accessor types
- Processed via validateICRC16Rule() function
- Requires CandyTypes.CandyShared input data

ICRC16 Validation Rules:
#candyType(accessor: M -> CandyShared, expectedType: Text)
#candySize(accessor: M -> CandyShared, min: ?Nat, max: ?Nat)
#candyDepth(accessor: M -> CandyShared, maxDepth: Nat)
#candyPattern(accessor: M -> CandyShared, pattern: Text)
#candyRange(accessor: M -> CandyShared, min: ?Int, max: ?Int)
#candyStructure(accessor: M -> CandyShared, context: ICRC16ValidationContext)
#propertyExists(accessor: M -> [PropertyShared], propertyName: Text)
#propertyType(accessor: M -> [PropertyShared], propertyName: Text, expectedType: Text)
#propertySize(accessor: M -> [PropertyShared], propertyName: Text, min: ?Nat, max: ?Nat)
#arrayLength(accessor: M -> CandyShared, min: ?Nat, max: ?Nat)
#arrayItemType(accessor: M -> CandyShared, expectedType: Text)
#mapKeyExists(accessor: M -> CandyShared, key: Text)
#mapSize(accessor: M -> CandyShared, min: ?Nat, max: ?Nat)
#customCandyCheck(accessor: M -> CandyShared, validator: CandyShared -> Result<(), Text>)
#nestedValidation(accessor: M -> CandyShared, rules: [ICRC16ValidationRule<T,M>])
*/

// ========================================
// INTEGRATION POINT 1: TYPE SYSTEM EXTENSION
// ========================================

/*
Challenge: Extend ValidationRule<T,M> to include ICRC16ValidationRule<T,M> variants
Solution: Add ICRC16 variants to the existing ValidationRule<T,M> union type

Location: src/migrations/v000_001_000/types.mo
Required Changes:
1. Add CandyTypes import for CandyShared and PropertyShared
2. Extend ValidationRule<T,M> with ICRC16 variants
3. Add ICRC16ValidationContext type definition

Integration Pattern:
- Maintain backward compatibility by adding new variants to existing type
- ICRC16 rules coexist with traditional validation rules
- Same T,M type parameters ensure type safety
*/

// ========================================
// INTEGRATION POINT 2: VALIDATION PROCESSING EXTENSION
// ========================================

/*
Challenge: Extend validateSingleRule<M>() to process ICRC16ValidationRule variants
Solution: Add ICRC16 rule processing cases to existing validation switch

Location: src/core/inspector.mo - validateSingleRule<M>() function
Required Changes:
1. Import ICRC16Rules module
2. Add switch cases for each ICRC16ValidationRule variant
3. Call validateICRC16Rule() for ICRC16 rule processing
4. Maintain existing rule processing logic

Integration Pattern:
- Extend existing switch statement with ICRC16 cases
- Delegate to validateICRC16Rule() for specialized processing
- Preserve existing error handling patterns
- Maintain consistent error message format
*/

// ========================================
// INTEGRATION POINT 3: RULE BUILDER FUNCTIONS
// ========================================

/*
Challenge: Provide convenient rule creation functions for ICRC16 rules
Solution: Add ICRC16 rule builders alongside existing rule builders

Location: src/core/inspector.mo - Validation Rule Builder Functions section
Required Changes:
1. Add candyType<T,M>(), candySize<T,M>(), etc. builder functions
2. Mirror existing pattern of textSize<T,M>(), blobSize<T,M>() functions
3. Provide comprehensive ICRC16 rule creation API

Integration Pattern:
- Follow existing naming convention (candyType vs textSize)
- Maintain same function signature pattern
- Return ValidationRule<T,M> type for consistency
- Group ICRC16 builders in dedicated section
*/

// ========================================
// INTEGRATION POINT 4: INSPECTOR CLASS EXTENSION
// ========================================

/*
Challenge: Ensure Inspector<T> class can handle ICRC16 rules seamlessly
Solution: No changes needed - existing createMethodGuardInfo works with extended ValidationRule<T,M>

Location: src/core/inspector.mo - Inspector<T> class
Required Changes: None (automatic compatibility)

Integration Pattern:
- createMethodGuardInfo<M>() already works with ValidationRule<T,M>[]
- Extended ValidationRule<T,M> includes ICRC16 variants automatically
- inspector.guard() and inspector.inspect() methods work unchanged
- Full backward compatibility maintained
*/

// ========================================
// INTEGRATION POINT 5: DEPENDENCY MANAGEMENT
// ========================================

/*
Challenge: Import ICRC16 modules and CandyTypes without circular dependencies
Solution: Strategic import placement and module organization

Location: Multiple files require coordinated imports
Required Changes:
1. src/migrations/v000_001_000/types.mo: Add CandyTypes import
2. src/core/inspector.mo: Import ICRC16Rules module
3. src/utils/icrc16_validation_rules.mo: Import types via MigrationTypes.Current

Integration Pattern:
- Use MigrationTypes.Current for type consistency
- Avoid direct imports from migrations folder
- Maintain clear module hierarchy
- Prevent circular import issues
*/

// ========================================
// INTEGRATION POINT 6: ERROR HANDLING CONSISTENCY
// ========================================

/*
Challenge: Ensure ICRC16 validation errors follow existing error format patterns
Solution: Standardize error message format across validation types

Location: src/utils/icrc16_validation_rules.mo - validateICRC16Rule() function
Required Changes:
1. Standardize error message prefixes (e.g., "candyType:", "propertyExists:")
2. Match existing error format from validateSingleRule()
3. Ensure consistent error propagation

Integration Pattern:
- Follow "ruleName: specific error message" format
- Use debug_show() for complex value display
- Maintain GuardResult = Result.Result<(), Text> return type
- Preserve error context and meaningful messages
*/

// ========================================
// INTEGRATION POINT 7: TESTING INFRASTRUCTURE
// ========================================

/*
Challenge: Integrate ICRC16 validation testing with existing test framework
Solution: Extend existing test patterns to cover ICRC16 scenarios

Location: test/ directory - various test files
Required Changes:
1. Create ICRC16-specific test scenarios in existing test files
2. Test integration between traditional and ICRC16 rules
3. Validate error handling consistency
4. Performance testing with CandyShared data

Integration Pattern:
- Use existing async test framework
- Follow established test naming conventions
- Test both isolated ICRC16 rules and mixed rule scenarios
- Validate backward compatibility
*/

// ========================================
// INTEGRATION IMPLEMENTATION PLAN
// ========================================

/*
Phase 1: Type System Integration
1. Extend ValidationRule<T,M> with ICRC16 variants in types.mo
2. Add required imports and type definitions
3. Validate compilation and type compatibility

Phase 2: Processing Integration  
1. Extend validateSingleRule<M>() with ICRC16 rule cases
2. Import ICRC16Rules module in inspector.mo
3. Implement delegated validation processing

Phase 3: API Integration
1. Add ICRC16 rule builder functions
2. Update module exports for new functions
3. Ensure consistent API surface

Phase 4: Testing Integration
1. Create comprehensive integration tests
2. Test mixed traditional + ICRC16 rule scenarios
3. Validate performance and compatibility
4. Verify error handling consistency

Phase 5: Documentation Integration
1. Update API documentation
2. Provide usage examples
3. Document migration patterns for existing users
*/

// ========================================
// BACKWARD COMPATIBILITY GUARANTEES
// ========================================

/*
The integration maintains strict backward compatibility:

1. Existing ValidationRule<T,M> variants unchanged
2. Inspector<T> class API remains identical
3. createMethodGuardInfo<M>() signature unchanged
4. Error handling patterns consistent
5. Performance characteristics preserved
6. No breaking changes to public API

Users can adopt ICRC16 validation incrementally:
- Mix traditional and ICRC16 rules in same method
- Use existing Inspector workflow
- Leverage same registration patterns
- Maintain existing error handling
*/

// ========================================
// INTEGRATION BENEFITS
// ========================================

/*
This integration approach provides:

1. Unified Validation Framework: Single API for all validation needs
2. Type Safety: Full compile-time validation with T,M type parameters
3. Incremental Adoption: Can add ICRC16 rules to existing methods
4. Performance: Minimal overhead through pattern matching
5. Extensibility: Easy to add more ICRC16 rule types in future
6. Consistency: Same error handling and processing patterns
7. Testability: Integrated with existing test infrastructure
*/

module {
  // This file serves as documentation - no executable code
}
