import { Principal } from "@dfinity/principal";
import { IDL } from "@dfinity/candid";
import { PocketIc, createIdentity } from "@dfinity/pic";
import type { Actor, CanisterFixture } from "@dfinity/pic";

// Test canister service interface
interface TestCanisterService {
  // Query methods (should NOT go through inspect)
  health_check: () => Promise<string>;
  get_call_counts: () => Promise<Array<[string, bigint]>>;
  
  // Update methods that will test inspectOnlyArgSize
  test_small_args: (data: string) => Promise<{ 'ok'?: string; 'err'?: string }>;
  test_large_args: (data: string) => Promise<{ 'ok'?: string; 'err'?: string }>;
  test_size_validation: (data: string) => Promise<{ 'ok'?: string; 'err'?: string }>;
  
  // Method that uses inspectOnlyArgSize directly
  get_last_arg_size: () => Promise<bigint>;
  
  // Reset utilities
  reset_call_counts: () => Promise<void>;
}

// IDL factory for test canister
const testCanisterIDLFactory = ({ IDL }: { IDL: any }) => {
  const Result = IDL.Variant({ 'ok': IDL.Text, 'err': IDL.Text });
  
  return IDL.Service({
    'health_check': IDL.Func([], [IDL.Text], ['query']),
    'get_call_counts': IDL.Func([], [IDL.Vec(IDL.Tuple(IDL.Text, IDL.Nat))], ['query']),
    'test_small_args': IDL.Func([IDL.Text], [Result], []),
    'test_large_args': IDL.Func([IDL.Text], [Result], []),
    'test_size_validation': IDL.Func([IDL.Text], [Result], []),
    'get_last_arg_size': IDL.Func([], [IDL.Nat], ['query']),
    'reset_call_counts': IDL.Func([], [], [])
  });
};

const testCanisterInit = ({ IDL }: { IDL: any }) => [];

export const TEST_CANISTER_WASM_PATH = ".dfx/local/canisters/test_canister/test_canister.wasm";

let pic: PocketIc;
let testCanister: CanisterFixture<TestCanisterService>;

// Test identities
const userIdentity = createIdentity("testuser");
const adminIdentity = createIdentity("admin");

describe("InspectMo ArgSize PIC.js Integration Tests", () => {
  beforeEach(async () => {
    // Increased timeout for PocketIC setup
    pic = await PocketIc.create(process.env.PIC_URL, {
      processingTimeoutMs: 1000 * 60 * 10, // Increased to 10 minutes
    });
    
    // Setup test canister
    testCanister = await pic.setupCanister<TestCanisterService>({
      sender: adminIdentity.getPrincipal(),
      idlFactory: testCanisterIDLFactory,
      wasm: TEST_CANISTER_WASM_PATH,
      arg: IDL.encode(testCanisterInit({ IDL }), []),
    });

    // Reset call counts before each test
    testCanister.actor.setIdentity(userIdentity);
    await testCanister.actor.reset_call_counts();
  }, 30000); // 30 second timeout for setup

  afterEach(async () => {
    if (pic) {
      await pic.tearDown();
    }
  }, 10000); // 10 second timeout for cleanup

  describe("inspectOnlyArgSize Basic Functionality", () => {
    test("should handle small arguments correctly", async () => {
      const smallData = "small";
      
      // This should pass inspection
      const result = await testCanister.actor.test_small_args(smallData);
      
      expect(result).toHaveProperty('ok');
      expect(result.ok).toContain('success');
      
      // Check that the arg size was measured correctly
      const argSize = await testCanister.actor.get_last_arg_size();
      expect(argSize).toBeGreaterThan(0n);
      expect(argSize).toBeLessThan(100n); // Should be small
    });

    test("should handle large arguments correctly", async () => {
      // Create a large string (1KB+)
      const largeData = "x".repeat(1500);
      
      // This should still work but with larger arg size
      const result = await testCanister.actor.test_large_args(largeData);
      
      expect(result).toHaveProperty('ok');
      expect(result.ok).toContain('success');
      
      // Check that the arg size was measured correctly
      const argSize = await testCanister.actor.get_last_arg_size();
      expect(argSize).toBeGreaterThan(1000n); // Should be large
    });

    test("should measure different argument sizes consistently", async () => {
      const testSizes = [
        { data: "tiny", expectedMin: 0n, expectedMax: 50n },
        { data: "x".repeat(100), expectedMin: 90n, expectedMax: 150n },
        { data: "x".repeat(500), expectedMin: 450n, expectedMax: 550n }
      ];

      for (const testCase of testSizes) {
        const result = await testCanister.actor.test_size_validation(testCase.data);
        
        expect(result).toHaveProperty('ok');
        
        const argSize = await testCanister.actor.get_last_arg_size();
        expect(argSize).toBeGreaterThanOrEqual(testCase.expectedMin);
        expect(argSize).toBeLessThanOrEqual(testCase.expectedMax);
      }
    });
  });

  describe("inspectOnlyArgSize Performance", () => {
    test("should be consistent across multiple calls with same data", async () => {
      const testData = "consistency test data";
      const argSizes: bigint[] = [];

      // Make multiple calls with the same data
      for (let i = 0; i < 5; i++) {
        await testCanister.actor.test_size_validation(testData);
        
        const argSize = await testCanister.actor.get_last_arg_size();
        argSizes.push(argSize);
      }

      // All sizes should be identical
      const firstSize = argSizes[0];
      for (const size of argSizes) {
        expect(size).toBe(firstSize);
      }
      
      expect(firstSize).toBeGreaterThan(0n);
    });

    test("should handle empty arguments", async () => {
      const result = await testCanister.actor.test_size_validation("");
      
      expect(result).toHaveProperty('ok');
      
      const argSize = await testCanister.actor.get_last_arg_size();
      // Empty string should still have some encoding overhead
      expect(argSize).toBeGreaterThanOrEqual(0n);
      expect(argSize).toBeLessThan(50n); // But should be small
    });
  });

  describe("inspectOnlyArgSize with Different Callers", () => {
    test("should work regardless of caller identity", async () => {
      const testData = "caller test data";
      
      // Call with user identity
      testCanister.actor.setIdentity(userIdentity);
      const userResult = await testCanister.actor.test_size_validation(testData);
      expect(userResult).toHaveProperty('ok');
      const userArgSize = await testCanister.actor.get_last_arg_size();
      
      // Call with admin identity  
      testCanister.actor.setIdentity(adminIdentity);
      const adminResult = await testCanister.actor.test_size_validation(testData);
      expect(adminResult).toHaveProperty('ok');
      const adminArgSize = await testCanister.actor.get_last_arg_size();
      
      // Arg sizes should be identical regardless of caller
      expect(userArgSize).toBe(adminArgSize);
      expect(userArgSize).toBeGreaterThan(0n);
    });
  });

  describe("inspectOnlyArgSize Integration", () => {
    test("should work in real canister environment", async () => {
      // Reset call counts
      await testCanister.actor.reset_call_counts();
      
      // Health check should work (query)
      const health = await testCanister.actor.health_check();
      expect(health).toContain('healthy');
      
      // Test with various arg sizes in real environment
      const testCases = [
        "small",
        "medium sized test data",
        "this is a much longer string that should demonstrate the inspectOnlyArgSize functionality working correctly in a real canister environment with PIC.js testing"
      ];
      
      for (const testData of testCases) {
        const result = await testCanister.actor.test_size_validation(testData);
        
        expect(result).toHaveProperty('ok');
        expect(result.ok).toContain('success');
        
        const argSize = await testCanister.actor.get_last_arg_size();
        expect(argSize).toBeGreaterThan(0n);
        
        // Sanity check: longer strings should have larger arg sizes
        if (testData.length > 50) {
          expect(argSize).toBeGreaterThan(50n);
        }
      }
      
      // Check that calls were counted correctly
      const callCounts = await testCanister.actor.get_call_counts();
      expect(callCounts.length).toBeGreaterThan(0);
      
      // Should have test_size_validation calls
      const testSizeValidationCount = callCounts.find(([method]: [string, bigint]) => method === 'test_size_validation');
      expect(testSizeValidationCount).toBeDefined();
      expect(testSizeValidationCount![1]).toBe(BigInt(testCases.length));
    });

    test("should demonstrate practical usage", async () => {
      // Simulate a real-world scenario where we want to limit argument size
      const normalData = "normal user data";
      const oversizedData = "x".repeat(10000); // Very large data
      
      // Normal data should pass
      const normalResult = await testCanister.actor.test_size_validation(normalData);
      expect(normalResult).toHaveProperty('ok');
      
      const normalSize = await testCanister.actor.get_last_arg_size();
      expect(normalSize).toBeLessThan(1000n);
      
      // Oversized data should still work (we're just measuring, not enforcing limits in this test)
      const oversizedResult = await testCanister.actor.test_size_validation(oversizedData);
      expect(oversizedResult).toHaveProperty('ok');
      
      const oversizedSize = await testCanister.actor.get_last_arg_size();
      expect(oversizedSize).toBeGreaterThan(5000n);
      
      // Demonstrate the size difference
      expect(oversizedSize).toBeGreaterThan(normalSize * 10n);
    });
  });
});
