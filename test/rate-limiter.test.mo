import {test} "mo:test/async";
import Debug "mo:core/Debug";
import Principal "mo:core/Principal";
import RateLimiter "../src/security/rate_limiter";
import Time "mo:core/Time";

/// Test rate limiting functionality

await test("basic rate limiting", func() : async () {
  Debug.print("Testing basic rate limiting...");
  
  // Create a simple rate limiter: 2 requests per minute
  let rateLimiter = RateLimiter.createSimpleRateLimiter(2, null);
  let testPrincipal = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
  
  // First call should be allowed
  let result1 = rateLimiter.checkCall(testPrincipal, "test_method");
  switch (result1) {
    case (#allowed) {
      rateLimiter.recordCall(testPrincipal, "test_method");
      Debug.print("✓ First call allowed");
    };
    case (#denied(info)) {
      assert false; // Should not be denied
    };
  };
  
  // Second call should be allowed  
  let result2 = rateLimiter.checkCall(testPrincipal, "test_method");
  switch (result2) {
    case (#allowed) {
      rateLimiter.recordCall(testPrincipal, "test_method");
      Debug.print("✓ Second call allowed");
    };
    case (#denied(info)) {
      assert false; // Should not be denied
    };
  };
  
  // Third call should be denied (exceeds 2 per minute)
  let stats = rateLimiter.getStats();
  Debug.print("Before third call - Stats: " # debug_show(stats));
  
  let result3 = rateLimiter.checkCall(testPrincipal, "test_method");
  Debug.print("Third call result: " # debug_show(result3));
  switch (result3) {
    case (#allowed) {
      assert false; // Should be denied
    };
    case (#denied(info)) {
      Debug.print("✓ Third call correctly denied - limit: " # debug_show(info.limit));
    };
  };
  
  Debug.print("✓ Basic rate limiting test passed");
});

await test("method-specific rate limiting", func() : async () {
  Debug.print("Testing method-specific rate limiting...");
  
  let globalLimit : RateLimiter.RateLimitConfig = {
    maxRequests = 10;
    timeWindow = #Minute(1);
    exemptRoles = [];
    exemptPrincipals = [];
  };
  
  let methodLimits : [(Text, RateLimiter.RateLimitConfig)] = [
    ("restrictive_method", {
      maxRequests = 1;
      timeWindow = #Minute(1);
      exemptRoles = [];
      exemptPrincipals = [];
    })
  ];
  
  let rateLimiter = RateLimiter.createMethodRateLimiter(?globalLimit, methodLimits, null);
  let testPrincipal = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
  
  // Test normal method (should use global limit)
  let result1 = rateLimiter.checkCall(testPrincipal, "normal_method");
  switch (result1) {
    case (#allowed) {
      rateLimiter.recordCall(testPrincipal, "normal_method");
      Debug.print("✓ Normal method call allowed");
    };
    case (#denied(_)) assert false;
  };
  
  // Test restrictive method - first call allowed
  let result2 = rateLimiter.checkCall(testPrincipal, "restrictive_method");
  switch (result2) {
    case (#allowed) {
      rateLimiter.recordCall(testPrincipal, "restrictive_method");
      Debug.print("✓ Restrictive method first call allowed");
    };
    case (#denied(_)) assert false;
  };
  
  // Test restrictive method - second call denied
  let result3 = rateLimiter.checkCall(testPrincipal, "restrictive_method");
  switch (result3) {
    case (#allowed) assert false;
    case (#denied(info)) {
      Debug.print("✓ Restrictive method second call denied - limit: " # debug_show(info.limit));
    };
  };
  
  Debug.print("✓ Method-specific rate limiting test passed");
});

await test("rate limiter statistics", func() : async () {
  Debug.print("Testing rate limiter statistics...");
  
  let rateLimiter = RateLimiter.createSimpleRateLimiter(5, null);
  let principal1 = Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai");
  let principal2 = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");
  
  // Record some calls
  rateLimiter.recordCall(principal1, "method1");
  rateLimiter.recordCall(principal1, "method2");
  rateLimiter.recordCall(principal2, "method1");
  
  let stats = rateLimiter.getStats();
  Debug.print("Stats - Principals: " # debug_show(stats.totalPrincipals) # 
             ", Methods: " # debug_show(stats.totalMethods) # 
             ", Calls: " # debug_show(stats.totalCalls));
  
  assert stats.totalPrincipals >= 2;
  assert stats.totalCalls >= 3;
  Debug.print("✓ Rate limiter statistics test passed");
});
