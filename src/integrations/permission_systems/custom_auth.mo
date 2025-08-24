/// Custom Authentication Adapter Interface for InspectMo
/// Provides a flexible interface for implementing custom authentication systems

import Principal "mo:core/Principal";
import Array "mo:core/Array";
import Text "mo:core/Text";
import Time "mo:core/Time";
import Result "mo:core/Result";
import Int "mo:core/Int";

import Types "../../migrations/v000_001_000/types";
import Auth "../../security/auth";

module {
  
  /// Generic authentication context
  public type AuthContext = {
    caller: Principal;
    origin: ?Text;
    timestamp: Int;
    metadata: [(Text, Text)];
  };
  
  /// Authentication challenge for custom auth flows
  public type AuthChallenge = {
    challengeId: Text;
    challengeType: Text; // e.g., "signature", "proof", "token"
    expiresAt: Int;
    data: [(Text, Text)]; // Challenge-specific data
  };
  
  /// Authentication response
  public type AuthResponse = {
    challengeId: Text;
    response: Text; // The actual response/proof
    metadata: [(Text, Text)];
  };
  
  /// Custom authentication result
  public type CustomAuthResult = {
    #success: {
      principal: Principal;
      roles: [Text];
      permissions: [Text];
      sessionData: [(Text, Text)];
    };
    #challenge: AuthChallenge;
    #failure: Text;
    #retry: { after: Int; reason: Text };
  };
  
  /// Custom authentication provider interface
  public type CustomAuthProvider = {
    /// Initiate authentication process
    authenticate: (AuthContext) -> async* CustomAuthResult;
    
    /// Verify authentication challenge response
    verifyChallenge: (AuthResponse) -> async* CustomAuthResult;
    
    /// Validate existing session
    validateSession: (Principal) -> async* Bool;
    
    /// Get user roles for a principal
    getUserRoles: (Principal) -> async* [Text];
    
    /// Get user permissions for a principal
    getUserPermissions: (Principal) -> async* [Text];
    
    /// Logout/invalidate session
    logout: (Principal) -> async* Bool;
    
    /// Provider-specific configuration
    getProviderInfo: () -> {
      name: Text;
      version: Text;
      supportedChallengeTypes: [Text];
      features: [Text];
    };
  };
  
  /// Custom adapter class that integrates custom auth providers with InspectMo
  public class CustomAuthAdapter(
    provider: CustomAuthProvider,
    permissionSystem: Auth.PermissionSystem,
    defaultSessionTimeout: ?Int
  ) {
    
    /// Create a validation rule that uses the custom auth provider
    public func createCustomAuthRule() : Types.ValidationRule<Any, Any> {
      #requireAuth // Use standard auth requirement - provider handles the details
    };
    
    /// Authenticate using the custom provider
    public func authenticate(context: AuthContext) : async* CustomAuthResult {
      await* provider.authenticate(context)
    };
    
    /// Verify challenge using the custom provider
    public func verifyChallenge(response: AuthResponse) : async* CustomAuthResult {
      await* provider.verifyChallenge(response)
    };
    
    /// Create session after successful authentication
    public func createSession(
      principal: Principal,
      roles: [Text],
      permissions: [Text],
      sessionData: [(Text, Text)]
    ) : Auth.UserSession {
      let session = permissionSystem.createSession(
        principal,
        roles,
        sessionData,
        defaultSessionTimeout
      );
      session
    };
    
    /// Validate session through provider
    public func validateSession(principal: Principal) : async* Bool {
      switch (permissionSystem.getSession(principal)) {
        case (?_) await* provider.validateSession(principal);
        case null false;
      }
    };
    
    /// Enhanced authentication with session creation
    public func authenticateAndCreateSession(context: AuthContext) : async* {
      #success: Auth.UserSession;
      #challenge: AuthChallenge;
      #failure: Text;
      #retry: { after: Int; reason: Text };
    } {
      switch (await* authenticate(context)) {
        case (#success({ principal; roles; permissions; sessionData })) {
          let session = createSession(principal, roles, permissions, sessionData);
          #success(session)
        };
        case (#challenge(challenge)) #challenge(challenge);
        case (#failure(reason)) #failure(reason);
        case (#retry(info)) #retry(info);
      }
    };
    
    /// Get provider information
    public func getProviderInfo() : {
      name: Text;
      version: Text;
      supportedChallengeTypes: [Text];
      features: [Text];
    } {
      provider.getProviderInfo()
    };
    
    /// Logout through provider and revoke session
    public func logout(principal: Principal) : async* Bool {
      let providerResult = await* provider.logout(principal);
      let sessionRevoked = permissionSystem.revokeSession(principal);
      providerResult and sessionRevoked
    };
  };
  
  /// Helper functions for implementing custom auth providers
  
  /// Create a simple token-based auth provider
  public func createTokenAuthProvider(
    validateToken: (Text) -> async* ?{
      principal: Principal;
      roles: [Text];
      permissions: [Text];
    },
    providerName: Text
  ) : CustomAuthProvider {
    {
      authenticate = func(context: AuthContext) : async* CustomAuthResult {
        // Look for token in metadata
        switch (Array.find<(Text, Text)>(context.metadata, func((key, _)) { key == "token" })) {
          case (?(_, token)) {
            switch (await* validateToken(token)) {
              case (?{principal; roles; permissions}) {
                #success({
                  principal;
                  roles;
                  permissions;
                  sessionData = [("authType", "token"), ("tokenHash", token)];
                })
              };
              case null #failure("Invalid token");
            }
          };
          case null {
            #challenge({
              challengeId = "token_" # Int.toText(Time.now());
              challengeType = "token";
              expiresAt = Time.now() + 300_000_000_000; // 5 minutes
              data = [("instruction", "Provide valid token in response field")];
            })
          };
        }
      };
      
      verifyChallenge = func(response: AuthResponse) : async* CustomAuthResult {
        switch (await* validateToken(response.response)) {
          case (?{principal; roles; permissions}) {
            #success({
              principal;
              roles;
              permissions;
              sessionData = [("authType", "token"), ("challengeId", response.challengeId)];
            })
          };
          case null #failure("Invalid token in challenge response");
        }
      };
      
      validateSession = func(principal: Principal) : async* Bool {
        // Simple validation - just check if principal is not anonymous
        not Principal.isAnonymous(principal)
      };
      
      getUserRoles = func(principal: Principal) : async* [Text] {
        ["user"] // Default role
      };
      
      getUserPermissions = func(principal: Principal) : async* [Text] {
        ["read"] // Default permission
      };
      
      logout = func(principal: Principal) : async* Bool {
        true // Token-based auth doesn't need special logout
      };
      
      getProviderInfo = func() : {
        name: Text;
        version: Text;
        supportedChallengeTypes: [Text];
        features: [Text];
      } {
        {
          name = providerName;
          version = "1.0.0";
          supportedChallengeTypes = ["token"];
          features = ["stateless", "fast"];
        }
      };
    }
  };
  
  /// Create a signature-based auth provider
  public func createSignatureAuthProvider(
    verifySignature: (Principal, Text, Text) -> async* Bool,
    providerName: Text
  ) : CustomAuthProvider {
    {
      authenticate = func(context: AuthContext) : async* CustomAuthResult {
        let challengeId = "sig_" # Int.toText(Time.now());
        let challenge = "Authenticate with principal: " # Principal.toText(context.caller) # " at " # Int.toText(context.timestamp);
        
        #challenge({
          challengeId;
          challengeType = "signature";
          expiresAt = Time.now() + 600_000_000_000; // 10 minutes
          data = [("challenge", challenge), ("principal", Principal.toText(context.caller))];
        })
      };
      
      verifyChallenge = func(response: AuthResponse) : async* CustomAuthResult {
        // Extract challenge and principal from challenge ID or metadata
        let principal = switch (Array.find<(Text, Text)>(response.metadata, func((key, _)) { key == "principal" })) {
          case (?(_, principalText)) Principal.fromText(principalText);
          case null return #failure("Missing principal in challenge response");
        };
        
        let challenge = switch (Array.find<(Text, Text)>(response.metadata, func((key, _)) { key == "challenge" })) {
          case (?(_, challengeText)) challengeText;
          case null return #failure("Missing challenge in response metadata");
        };
        
        let isValid = await* verifySignature(principal, challenge, response.response);
        if (isValid) {
          #success({
            principal;
            roles = ["user"];
            permissions = ["read", "write"];
            sessionData = [("authType", "signature"), ("challengeId", response.challengeId)];
          })
        } else {
          #failure("Invalid signature")
        }
      };
      
      validateSession = func(principal: Principal) : async* Bool {
        not Principal.isAnonymous(principal)
      };
      
      getUserRoles = func(principal: Principal) : async* [Text] {
        ["user"]
      };
      
      getUserPermissions = func(principal: Principal) : async* [Text] {
        ["read", "write"]
      };
      
      logout = func(principal: Principal) : async* Bool {
        true
      };
      
      getProviderInfo = func() : {
        name: Text;
        version: Text;
        supportedChallengeTypes: [Text];
        features: [Text];
      } {
        {
          name = providerName;
          version = "1.0.0";
          supportedChallengeTypes = ["signature"];
          features = ["secure", "challenge-response"];
        }
      };
    }
  };
}
