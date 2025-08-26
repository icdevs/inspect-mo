# Testing Strategy for InspectMo

## Overview

InspectMo uses a dual testing approach to ensure comprehensive coverage of both static logic and time-dependent functionality.

## Testing Environments

### 1. Mops Test (Static Logic)
**Location:** `test/*.test.mo`  
**Purpose:** Fast unit tests for business logic, validation rules, and type checking  
**Strengths:**
- Fast execution (< 5 seconds)
- Pure Motoko environment
- Perfect for logic validation
- CI/CD friendly

**Limitations:**
- ❌ Time-based functionality is unreliable
- ❌ No realistic time progression
- ❌ Cannot test session timeouts
- ❌ Rate limit window testing is inaccurate

### 2. PIC.js Integration Tests (Time-Based Features)
**Location:** `pic/*.test.ts`  
**Purpose:** Realistic canister testing with time control  
**Strengths:**
- ✅ Accurate time progression with `pic.advanceTime()`
- ✅ Real canister environment
- ✅ Session timeout testing
- ✅ Rate limit window validation
- ✅ Multi-user time-based scenarios

## Current Test Coverage

### Mops Tests (✅ Completed)
```
✓ test/debug.test.mo           - Debug utilities
✓ test/rate-limiter.test.mo    - Rate limiting logic (non-time-based)
✓ test/auth.test.mo            - Authentication logic
✓ test/async-validation.test.mo - Async validation patterns
✓ test/validation.test.mo      - Core validation rules
✓ test/basic.test.mo           - Basic functionality
✓ test/permission-integration.test.mo - Permission system integration
✓ test/main.test.mo            - Main library interface
✓ test/sample.test.mo          - Sample usage patterns
```

### PIC.js Tests (📝 Template Created)
```
📋 pic/time-based-integration.test.ts - Time-based feature testing template
📋 pic/main/main.test.ts              - Main integration tests
```

## Principal-Based Authentication Testing

### Authentication Strategy
Our authentication approach focuses on **trusting IC-verified principals** and implementing authorization logic based on business requirements.

#### Test Principals

**User Principal (Self-Authenticating):**
```
s6bzd-46mcd-mlbx5-cq2jv-m2mhx-nhj6y-erh6g-y73vq-fnfe6-zax3q-mqe
```
- Length: > 10 bytes ✅
- No canister suffix ✅
- Self-authenticating format ✅

**Canister Principal:**
```
rrkah-fqaaa-aaaaa-aaaaq-cai
```
- Ends with `-cai` ✅
- Shorter format ✅
- Opaque canister ID ✅

**Anonymous Principal:**
```
Principal.anonymous() // 2vxsx-fae
```
- Special anonymous identifier ✅

### Detection Logic
```motoko
public func isSelfAuthenticating(principal: Principal) : Bool {
  let principalText = Principal.toText(principal);
  let bytes = Principal.toBlob(principal);
  
  // Self-authenticating principals are longer than canister principals
  // and don't end with canister-specific suffixes
  bytes.size() > 10 and not Text.endsWith(principalText, #text "-cai")
};
```

## Time-Based Features Requiring PIC.js

### 1. User Statistics
```motoko
type UserStats = {
  totalUsers: Nat;
  activeUsers: Nat;
  newUsersToday: Nat; // ⏰ Time-dependent
};
```

**PIC.js Test Strategy:**
- Create users on day 1
- Advance time by 25 hours
- Add new users on day 2
- Verify `newUsersToday` counts only day 2 users

### 2. Session Management
```motoko
type IIConfig = {
  sessionTimeout: Int; // ⏰ Time-dependent
  autoCreateUser: Bool;
  defaultUserRole: Text;
};
```

**PIC.js Test Strategy:**
- Authenticate user
- Verify `isAuthenticated()` returns `true`
- Advance time beyond session timeout
- Call `cleanup()`
- Verify `isAuthenticated()` returns `false`

### 3. Rate Limiting
```motoko
type RateLimitRule = {
  maxPerMinute: ?Nat; // ⏰ Time-dependent
  maxPerHour: ?Nat;   // ⏰ Time-dependent
  maxPerDay: ?Nat;    // ⏰ Time-dependent
};
```

**PIC.js Test Strategy:**
- Configure strict rate limit (2 per minute)
- Make 2 calls (succeed)
- Make 3rd call (fail)
- Advance time by 61 seconds
- Make call again (succeed)

### 4. User Profile Timestamps
```motoko
type UserProfile = {
  principal: Principal;
  firstSeen: Int;  // ⏰ Time-dependent
  lastSeen: Int;   // ⏰ Time-dependent
  loginCount: Nat;
};
```

**PIC.js Test Strategy:**
- Authenticate user (loginCount = 1)
- Advance time by 1 hour
- Authenticate again (loginCount = 2)
- Verify `lastSeen > firstSeen`

## Running Tests

### Quick Validation (Mops)
```bash
mops test
# Fast feedback for logic validation
# ✅ All 9 tests passing
```

### Comprehensive Testing (PIC.js)
```bash
cd pic
npm test
# Full integration testing with time control
# 📋 Template ready for implementation
```

## Development Workflow

1. **Write Logic in Motoko** → Test with `mops test`
2. **Add Time Features** → Create PIC.js tests
3. **CI/CD Pipeline** → Run both test suites
4. **Pre-deployment** → Comprehensive PIC.js validation

## Notes for Contributors

- ✅ **Mops tests are fast and complete** for business logic
- ⚠️ **Time-based assertions in mops are unreliable** - use PIC.js
- 📝 **PIC.js templates are ready** - need actual canister interface
- 🎯 **Focus on principal type detection** instead of delegation verification
- 🔧 **Use real long principals** for realistic self-authenticating testing

### Orthogonal upgrades (PIC.js)
- Current limitation: standard PIC.js does not expose an orthogonal upgrade helper yet. Track https://github.com/dfinity/pic-js/issues/146.
- Workarounds we use in tests until upstream support lands:
  - Use a local helper that calls `install_code` with `mode = upgrade` and options: `wasm_memory_persistence = keep` and `skip_pre_upgrade = None` (encoded as Opt Some/None appropriately). In our local fork this is exposed as `upgradeCanisterOrtho`.
  - If a helper is unavailable, simulate upgrade cadence with stop/start and verify post-restart timers fire on the expected weekly schedule.


This dual approach ensures both fast development cycles and comprehensive validation of time-dependent security features.
