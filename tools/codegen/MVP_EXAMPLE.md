# InspectMo Codegen MVP Solution: Delegated Field Extraction

## 🎯 Problem Solved

The MVP solution solves the complex type handling issue by **delegating field extraction to the user** while still providing the InspectMo validation framework.

## 🔧 How It Works

Instead of trying to automatically parse nested record structures, the tool generates **delegated accessor functions** that accept user-provided extraction logic.

### Generated Helper Functions

```motoko
/// For each complex type, you get these helper functions:
public func getRecordText(
  record: Record,
  extractor: (Record) -> Text
): Text {
  extractor(record)
};

public func getRecordNat(
  record: Record, 
  extractor: (Record) -> Nat
): Nat {
  extractor(record)
};

// Also: getRecordInt, getRecordBool, getRecordBlob, getRecordPrincipal
// Plus: getRecordOptText, getRecordTextArray, getRecordNatArray
```

## 📝 Usage Example

### 1. **Define Your Types** (copy from .did file)

```motoko
// Copy these from your Candid interface
public type UserProfile = {
  id: Nat;
  name: Text;
  email: Text;
  age: Nat;
  preferences: {
    theme: Text;
    notifications: Bool;
  };
  tags: [Text];
};

public type TransactionRequest = {
  amount: Nat;
  currency: Text;
  recipient: Principal;
  memo: ?Text;
};
```

### 2. **Use Delegated Accessors in Validation**

```motoko
import GeneratedInspect "./mvp-solution";

// Setup validation using delegated extraction
let inspector = GeneratedInspect.createValidatorInspector();

// Add validation rules that use delegated accessors
inspector.inspect(inspector.createMethodGuardInfo<Result<Nat, Text>>(
  "create_profile",
  false, // isQuery
  [
    // Validate profile name length using delegated accessor
    InspectMo.textSize(
      func(args: GeneratedInspect.Args): Text {
        let profile = GeneratedInspect.getCreate_profileProfile(args);
        GeneratedInspect.getRecordText(profile, func(p: UserProfile): Text { p.name })
      },
      ?1,   // min length
      ?100  // max length
    ),
    
    // Validate profile email format
    InspectMo.textPattern(
      func(args: GeneratedInspect.Args): Text {
        let profile = GeneratedInspect.getCreate_profileProfile(args);
        GeneratedInspect.getRecordText(profile, func(p: UserProfile): Text { p.email })
      },
      "*@*.*"  // simple email pattern
    ),
    
    // Validate age range
    InspectMo.natValue(
      func(args: GeneratedInspect.Args): Nat {
        let profile = GeneratedInspect.getCreate_profileProfile(args);
        GeneratedInspect.getRecordNat(profile, func(p: UserProfile): Nat { p.age })
      },
      ?13,   // min age
      ?120   // max age
    ),
    
    // Validate tag array size
    InspectMo.arraySize(
      func(args: GeneratedInspect.Args): [Text] {
        let profile = GeneratedInspect.getCreate_profileProfile(args);
        GeneratedInspect.getRecordTextArray(profile, func(p: UserProfile): [Text] { p.tags })
      },
      ?0,   // min tags
      ?10   // max tags  
    ),
    
    #requireAuth
  ],
  func(args: GeneratedInspect.Args): Result<Nat, Text> {
    // Your method implementation here
    switch (args) {
      case (#Create_profile(profile)) {
        // Implementation logic
        #ok(123) // return user ID
      };
      case (_) { #err("Invalid args") };
    }
  }
));
```

### 3. **Nested Field Access**

```motoko
// Access nested fields like profile.preferences.theme
let userTheme = GeneratedInspect.getRecordText(
  profile,
  func(p: UserProfile): Text { 
    p.preferences.theme 
  }
);

// Validate nested boolean field
InspectMo.boolValue(
  func(args: GeneratedInspect.Args): Bool {
    let profile = GeneratedInspect.getCreate_profileProfile(args);
    GeneratedInspect.getRecordBool(
      profile, 
      func(p: UserProfile): Bool { p.preferences.notifications }
    )
  },
  ?true  // must be true
)
```

## ✅ **Benefits of This MVP Approach**

1. **🔥 Immediate Usability**: Works with complex types right away
2. **💪 Full Type Safety**: User-provided extractors are type-checked
3. **🎯 Complete Validation**: All InspectMo size/pattern validators work
4. **🔧 Flexible**: Handles any nested structure depth
5. **📝 Clear**: User controls exactly which fields to extract
6. **⚡ Fast**: No complex parsing - simple function delegation

## 🚀 **Integration Workflow**

Note: For v0.1.0 there are no Motoko prebuild hooks. Use the local ts-node CLI directly.

```bash
# 1. Generate boilerplate with ts-node
npx ts-node tools/codegen/src/cli.ts complex_canister.did -o inspect-boilerplate.mo

# 2. Copy type definitions from .did to your canister
# 3. Import the generated module
# 4. Use delegated accessors in validation rules
# 5. Customize as needed
```

## 🎉 **Result: Complex Type Validation That "Just Works"**

```motoko
// ✅ This now works perfectly:
InspectMo.textSize(getRecordText(profile, func(p) { p.email }), ?5, ?100)
InspectMo.natRange(getRecordNat(profile, func(p) { p.age }), ?13, ?120)  
InspectMo.arraySize(getRecordTextArray(profile, func(p) { p.tags }), ?0, ?10)

// ✅ Instead of broken generated code:
InspectMo.textSize(getProfileEmailText, ?5, ?100) // ❌ doesn't exist
```

This MVP solution provides **immediate value** while we work on full auto-generation in future iterations!
