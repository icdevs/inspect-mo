import { describe, it, expect, beforeAll, afterAll } from '@jest/globals';
import { PocketIc } from '@dfinity/pic';
import type { Actor, CanisterFixture } from '@dfinity/pic';
import { IDL } from '@dfinity/candid';
import { readFileSync } from 'fs';
import { resolve } from 'path';

// Define the canister service interface
interface ValidationUtilsTestService {
  testAppendValidationRules: () => Promise<boolean>;
  testCombineValidationRules: () => Promise<boolean>;
  testValidationRuleBuilder: () => Promise<boolean>;
  testPredefinedRuleSets: () => Promise<boolean>;
  runAllTests: () => Promise<Array<string>>;
  getTestResults: () => Promise<Array<string>>;
  clearTestResults: () => Promise<void>;
}

// IDL factory for validation utils test canister
const validationUtilsTestIDLFactory = ({ IDL }: { IDL: any }) => {
  return IDL.Service({
    'testAppendValidationRules': IDL.Func([], [IDL.Bool], []),
    'testCombineValidationRules': IDL.Func([], [IDL.Bool], []),
    'testValidationRuleBuilder': IDL.Func([], [IDL.Bool], []),
    'testPredefinedRuleSets': IDL.Func([], [IDL.Bool], []),
    'runAllTests': IDL.Func([], [IDL.Vec(IDL.Text)], []),
    'getTestResults': IDL.Func([], [IDL.Vec(IDL.Text)], ['query']),
    'clearTestResults': IDL.Func([], [], []),
  });
};

describe('ValidationRule Array Utilities - PocketIC Integration Tests', () => {
  let pic: PocketIc;
  let actor: Actor<ValidationUtilsTestService>;
  let canisterFixture: CanisterFixture<ValidationUtilsTestService>;

  beforeAll(async () => {
    pic = await PocketIc.create(process.env.PIC_URL);
    
    // Read the WASM file
    const wasmPath = resolve(__dirname, '../.dfx/local/canisters/validation_utils_test/validation_utils_test.wasm');
    const wasmModule = readFileSync(wasmPath);
    
    // Deploy the canister
    canisterFixture = await pic.setupCanister<ValidationUtilsTestService>({
      idlFactory: validationUtilsTestIDLFactory,
      wasm: wasmModule.buffer,
    });
    
    actor = canisterFixture.actor;
  });

  afterAll(async () => {
    await pic?.tearDown();
  });

  describe('Individual ValidationRule Array Utilities Tests', () => {
    it('should pass appendValidationRule tests', async () => {
      const result = await actor.testAppendValidationRules();
      expect(result).toBe(true);
    });

    it('should pass combineValidationRules tests', async () => {
      const result = await actor.testCombineValidationRules();
      expect(result).toBe(true);
    });

    it('should pass ValidationRuleBuilder tests', async () => {
      const result = await actor.testValidationRuleBuilder();
      expect(result).toBe(true);
    });

    it('should pass predefined rule sets tests', async () => {
      const result = await actor.testPredefinedRuleSets();
      expect(result).toBe(true);
    });
  });

  describe('Comprehensive Test Suite', () => {
    beforeEach(async () => {
      // Clear test results before each test
      await actor.clearTestResults();
    });

    it('should run all tests and pass', async () => {
      const results = await actor.runAllTests();
      
      // Verify all tests passed
      expect(results).toHaveLength(5); // 4 individual tests + 1 overall summary
      
      // Check individual test results
      expect(results[0]).toContain('appendValidationRules: PASSED');
      expect(results[1]).toContain('combineValidationRules: PASSED');
      expect(results[2]).toContain('ValidationRuleBuilder: PASSED');
      expect(results[3]).toContain('PredefinedRuleSets: PASSED');
      expect(results[4]).toContain('Overall: PASSED');
      expect(results[4]).toContain('ALL TESTS PASSED');
    });

    it('should maintain test results across calls', async () => {
      // Run individual tests
      await actor.testAppendValidationRules();
      await actor.testCombineValidationRules();
      
      // Check that results are accumulated
      const results = await actor.getTestResults();
      expect(results.length).toBeGreaterThanOrEqual(2);
      expect(results[0]).toContain('appendValidationRules: PASSED');
      expect(results[1]).toContain('combineValidationRules: PASSED');
    });

    it('should clear test results properly', async () => {
      // Run a test to generate results
      await actor.testAppendValidationRules();
      let results = await actor.getTestResults();
      expect(results.length).toBeGreaterThan(0);
      
      // Clear results
      await actor.clearTestResults();
      results = await actor.getTestResults();
      expect(results).toHaveLength(0);
    });
  });

  describe('ValidationRule Array Utilities Functionality Validation', () => {
    it('should validate that appendValidationRule works correctly', async () => {
      // This test verifies the core functionality through the canister
      const result = await actor.testAppendValidationRules();
      expect(result).toBe(true);
      
      // Get detailed results to verify specific functionality
      const results = await actor.getTestResults();
      const appendTest = results.find((r: string) => r.includes('appendValidationRules'));
      expect(appendTest).toContain('PASSED');
      expect(appendTest).toContain('All append tests passed');
    });

    it('should validate that combineValidationRules works correctly', async () => {
      const result = await actor.testCombineValidationRules();
      expect(result).toBe(true);
      
      const results = await actor.getTestResults();
      const combineTest = results.find((r: string) => r.includes('combineValidationRules'));
      expect(combineTest).toContain('PASSED');
      expect(combineTest).toContain('All combine tests passed');
    });

    it('should validate that ValidationRuleBuilder works correctly', async () => {
      const result = await actor.testValidationRuleBuilder();
      expect(result).toBe(true);
      
      const results = await actor.getTestResults();
      const builderTest = results.find((r: string) => r.includes('ValidationRuleBuilder'));
      expect(builderTest).toContain('PASSED');
      expect(builderTest).toContain('All builder tests passed');
    });

    it('should validate that predefined rule sets work correctly', async () => {
      const result = await actor.testPredefinedRuleSets();
      expect(result).toBe(true);
      
      const results = await actor.getTestResults();
      const predefinedTest = results.find((r: string) => r.includes('PredefinedRuleSets'));
      expect(predefinedTest).toContain('PASSED');
      expect(predefinedTest).toContain('Basic rule set tests passed');
    });
  });

  describe('Performance and Reliability Tests', () => {
    it('should handle multiple sequential test runs without issues', async () => {
      // Run all tests multiple times to check for state issues
      for (let i = 0; i < 3; i++) {
        await actor.clearTestResults();
        const results = await actor.runAllTests();
        
        // Each run should pass
        expect(results).toHaveLength(5);
        expect(results[4]).toContain('ALL TESTS PASSED');
      }
    });

    it('should complete tests in reasonable time', async () => {
      const startTime = Date.now();
      await actor.runAllTests();
      const endTime = Date.now();
      
      // Tests should complete within 10 seconds (generous for PocketIC)
      const duration = endTime - startTime;
      expect(duration).toBeLessThan(10000);
    });

    it('should handle concurrent test calls gracefully', async () => {
      // Clear results first
      await actor.clearTestResults();
      
      // Run multiple tests concurrently
      const promises = [
        actor.testAppendValidationRules(),
        actor.testCombineValidationRules(),
        actor.testValidationRuleBuilder(),
        actor.testPredefinedRuleSets(),
      ];
      
      const results = await Promise.all(promises);
      
      // All should pass
      results.forEach((result: boolean) => {
        expect(result).toBe(true);
      });
      
      // Check accumulated results
      const testResults = await actor.getTestResults();
      expect(testResults.length).toBeGreaterThanOrEqual(4);
    });
  });

  describe('Error Handling and Edge Cases', () => {
    it('should handle empty test result queries gracefully', async () => {
      await actor.clearTestResults();
      const results = await actor.getTestResults();
      expect(results).toEqual([]);
    });

    it('should maintain test result integrity', async () => {
      await actor.clearTestResults();
      
      // Run a specific test
      await actor.testAppendValidationRules();
      const results1 = await actor.getTestResults();
      
      // Run another test  
      await actor.testCombineValidationRules();
      const results2 = await actor.getTestResults();
      
      // Results should accumulate, not replace
      expect(results2.length).toBe(results1.length + 1);
      expect(results2[0]).toBe(results1[0]); // First result should remain
    });
  });

  describe('Integration with ValidationRule System', () => {
    it('should validate that all utility functions integrate properly', async () => {
      // Clear results and run comprehensive test
      await actor.clearTestResults();
      const allResults = await actor.runAllTests();
      
      // Verify comprehensive functionality
      expect(allResults).toHaveLength(5); // Should be exactly 5: 4 tests + 1 summary
      
      // Check that each component is working
      const testTypes = [
        'appendValidationRules',
        'combineValidationRules', 
        'ValidationRuleBuilder',
        'PredefinedRuleSets',
        'Overall'
      ];
      
      testTypes.forEach((testType, index) => {
        expect(allResults[index]).toContain(testType);
        expect(allResults[index]).toContain('PASSED');
      });
      
      // Final validation
      expect(allResults[4]).toContain('ALL TESTS PASSED');
    });

    it('should demonstrate ValidationRule Array Utilities end-to-end functionality', async () => {
      // Clear and run the comprehensive test suite
      await actor.clearTestResults();
      const results = await actor.runAllTests();
      
      // Validate that all ValidationRule Array Utilities are working:
      // 1. appendValidationRule - Adding rules to arrays
      // 2. combineValidationRules - Combining multiple arrays  
      // 3. ValidationRuleBuilder - Builder pattern functionality
      // 4. Predefined rule sets - Ready-made validation sets
      
      const testSummary = results[4]; // Overall summary
      expect(testSummary).toContain('SUMMARY: ALL TESTS PASSED');
      
      // This confirms the ValidationRule Array Utilities are production-ready
      console.log('✅ ValidationRule Array Utilities fully validated in PocketIC environment');
      console.log('✅ All utility functions working correctly in real canister deployment');
    });
  });
});
