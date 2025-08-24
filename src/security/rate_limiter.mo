/// Rate limiting implementation for InspectMo
/// Provides principal-based tracking, per-method limits, and role-based exemptions

import Map "mo:core/Map";
import Time "mo:core/Time";
import Principal "mo:core/Principal";
import Array "mo:core/Array";
import Result "mo:core/Result";
import Int "mo:core/Int";
import Text "mo:core/Text";

module {
  
  /// Time window for rate limiting (in nanoseconds)
  public type TimeWindow = {
    #Second: Nat;
    #Minute: Nat; 
    #Hour: Nat;
    #Day: Nat;
  };
  
  /// Rate limit configuration for a specific method or global
  public type RateLimitConfig = {
    maxRequests: Nat;
    timeWindow: TimeWindow;
    exemptRoles: [Text]; // Roles that bypass this limit
    exemptPrincipals: [Principal]; // Specific principals that bypass
  };
  
  /// Global rate limiter configuration
  public type RateLimiterConfig = {
    globalLimit: ?RateLimitConfig; // Global limit across all methods
    methodLimits: [(Text, RateLimitConfig)]; // Per-method limits
    cleanupInterval: Nat; // How often to cleanup old entries (minutes)
  };
  
  /// Call tracking entry
  public type CallEntry = {
    timestamp: Int;
    count: Nat;
  };
  
  /// Rate limit check result
  public type RateLimitResult = {
    #allowed;
    #denied: {
      limit: Nat;
      window: TimeWindow;
      retryAfter: Int; // Nanoseconds until next allowed call
    };
  };
  
  /// Role provider for checking user roles
  public type RoleProvider = {
    getUserRoles: (Principal) -> [Text];
  };
  
  /// Rate limiter state and functionality
  public class RateLimiter(config: RateLimiterConfig, roleProvider: ?RoleProvider) {
    
    // Principal -> Method -> [CallEntry]
    private var callHistory = Map.empty<Principal, Map.Map<Text, [CallEntry]>>();
    private var lastCleanup = Time.now();
    
    /// Convert time window to nanoseconds
    private func timeWindowToNanos(window: TimeWindow) : Int {
      switch (window) {
        case (#Second(n)) n * 1_000_000_000;
        case (#Minute(n)) n * 60 * 1_000_000_000;
        case (#Hour(n)) n * 60 * 60 * 1_000_000_000;
        case (#Day(n)) n * 24 * 60 * 60 * 1_000_000_000;
      }
    };
    
    /// Check if principal has exempt role
    private func hasExemptRole(principal: Principal, exemptRoles: [Text]) : Bool {
      switch (roleProvider) {
        case (?provider) {
          let userRoles = provider.getUserRoles(principal);
          Array.find<Text>(exemptRoles, func(exemptRole) {
            Array.find<Text>(userRoles, func(userRole) {
              userRole == exemptRole
            }) != null
          }) != null
        };
        case null false;
      }
    };
    
    /// Check if principal is explicitly exempt
    private func isExemptPrincipal(principal: Principal, exemptPrincipals: [Principal]) : Bool {
      Array.find<Principal>(exemptPrincipals, func(p) {
        Principal.equal(p, principal)
      }) != null
    };
    
    /// Count valid calls within time window
    private func countCallsInWindow(entries: [CallEntry], windowStart: Int) : Nat {
      Array.foldLeft<CallEntry, Nat>(entries, 0, func(acc, entry) {
        if (entry.timestamp >= windowStart) acc + entry.count else acc
      })
    };
    
    /// Clean up old entries beyond time window
    private func filterValidEntries(entries: [CallEntry], windowStart: Int) : [CallEntry] {
      Array.filter<CallEntry>(entries, func(entry) {
        entry.timestamp >= windowStart
      })
    };
    
    /// Check rate limit for a specific configuration
    private func checkRateLimit(
      principal: Principal, 
      methodName: Text, 
      limitConfig: RateLimitConfig
    ) : RateLimitResult {
      
      // Check exemptions first
      if (hasExemptRole(principal, limitConfig.exemptRoles) or 
          isExemptPrincipal(principal, limitConfig.exemptPrincipals)) {
        return #allowed;
      };
      
      let now = Time.now();
      let windowStart = now - timeWindowToNanos(limitConfig.timeWindow);
      
      // Get or create method history for principal
      let principalHistory = switch (Map.get(callHistory, Principal.compare, principal)) {
        case (?history) history;
        case null Map.empty<Text, [CallEntry]>();
      };
      
      let methodEntries = switch (Map.get(principalHistory, Text.compare, methodName)) {
        case (?entries) entries;
        case null [];
      };
      
      // Count calls in current window
      let validEntries = filterValidEntries(methodEntries, windowStart);
      let currentCount = countCallsInWindow(validEntries, windowStart);
      
      if (currentCount >= limitConfig.maxRequests) {
        // Calculate retry after time
        let oldestValidEntry = Array.foldLeft<CallEntry, ?CallEntry>(validEntries, null, func(acc, entry) {
          switch (acc) {
            case null ?entry;
            case (?oldest) {
              if (entry.timestamp < oldest.timestamp) ?entry else ?oldest
            };
          }
        });
        
        let retryAfter = switch (oldestValidEntry) {
          case (?entry) entry.timestamp + timeWindowToNanos(limitConfig.timeWindow) - now;
          case null 0;
        };
        
        #denied({
          limit = limitConfig.maxRequests;
          window = limitConfig.timeWindow;
          retryAfter = Int.abs(retryAfter);
        })
      } else {
        #allowed
      }
    };
    
    /// Record a successful call
    public func recordCall(principal: Principal, methodName: Text) : () {
      let now = Time.now();
      
      // Get or create principal history
      let principalHistory = switch (Map.get(callHistory, Principal.compare, principal)) {
        case (?history) history;
        case null {
          let newHistory = Map.empty<Text, [CallEntry]>();
          ignore Map.insert(callHistory, Principal.compare, principal, newHistory);
          newHistory
        };
      };
      
      // Get current method entries
      let currentEntries = switch (Map.get(principalHistory, Text.compare, methodName)) {
        case (?entries) entries;
        case null [];
      };
      
      // Add new entry
      let newEntry : CallEntry = { timestamp = now; count = 1 };
      let updatedEntries = Array.concat(currentEntries, [newEntry]);
      
      // Update method history (this modifies principalHistory in place)
      ignore Map.insert(principalHistory, Text.compare, methodName, updatedEntries);
      
      // Cleanup if needed
      if (now - lastCleanup > config.cleanupInterval * 60 * 1_000_000_000) {
        cleanup();
        lastCleanup := now;
      };
    };
    
    /// Check if call is allowed under rate limits
    public func checkCall(principal: Principal, methodName: Text) : RateLimitResult {
      
      // Check method-specific limits first
      for ((method, limitConfig) in config.methodLimits.vals()) {
        if (method == methodName) {
          switch (checkRateLimit(principal, methodName, limitConfig)) {
            case (#denied(info)) return #denied(info);
            case (#allowed) { /* Continue to global check */ };
          };
        };
      };
      
      // Check global limit
      switch (config.globalLimit) {
        case (?globalConfig) {
          checkRateLimit(principal, methodName, globalConfig)
        };
        case null #allowed;
      }
    };
    
    /// Clean up old entries beyond all time windows
    public func cleanup() : () {
      let now = Time.now();
      let maxWindow = 24 * 60 * 60 * 1_000_000_000; // 24 hours in nanoseconds
      let cutoff = now - maxWindow;
      
      let newCallHistory = Map.empty<Principal, Map.Map<Text, [CallEntry]>>();
      
      for ((principal, methodHistory) in Map.entries(callHistory)) {
        let newMethodHistory = Map.empty<Text, [CallEntry]>();
        var hasValidEntries = false;
        
        for ((method, entries) in Map.entries(methodHistory)) {
          let validEntries = filterValidEntries(entries, cutoff);
          if (validEntries.size() > 0) {
            ignore Map.insert(newMethodHistory, Text.compare, method, validEntries);
            hasValidEntries := true;
          };
        };
        
        if (hasValidEntries) {
          ignore Map.insert(newCallHistory, Principal.compare, principal, newMethodHistory);
        };
      };
      
      callHistory := newCallHistory;
    };
    
    /// Get current statistics
    public func getStats() : {
      totalPrincipals: Nat;
      totalMethods: Nat;
      totalCalls: Nat;
    } {
      var totalPrincipals = 0;
      var totalMethods = 0;
      var totalCalls = 0;
      
      for ((principal, methodHistory) in Map.entries(callHistory)) {
        totalPrincipals += 1;
        for ((method, entries) in Map.entries(methodHistory)) {
          totalMethods += 1;
          totalCalls += entries.size();
        };
      };
      
      { totalPrincipals; totalMethods; totalCalls }
    };
  };
  
  /// Create a basic rate limiter with simple configuration
  public func createSimpleRateLimiter(
    maxRequestsPerMinute: Nat,
    roleProvider: ?RoleProvider
  ) : RateLimiter {
    let config : RateLimiterConfig = {
      globalLimit = ?{
        maxRequests = maxRequestsPerMinute;
        timeWindow = #Minute(1);
        exemptRoles = ["admin", "system"];
        exemptPrincipals = [];
      };
      methodLimits = [];
      cleanupInterval = 60; // 1 hour
    };
    RateLimiter(config, roleProvider)
  };
  
  /// Create rate limiter with method-specific limits
  public func createMethodRateLimiter(
    globalLimit: ?RateLimitConfig,
    methodLimits: [(Text, RateLimitConfig)],
    roleProvider: ?RoleProvider
  ) : RateLimiter {
    let config : RateLimiterConfig = {
      globalLimit;
      methodLimits;
      cleanupInterval = 60;
    };
    RateLimiter(config, roleProvider)
  };
}
