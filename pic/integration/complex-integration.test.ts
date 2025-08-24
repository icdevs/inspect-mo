import { Principal } from "@dfinity/principal";
import { IDL } from "@dfinity/candid";
import {
  PocketIc,
  createIdentity
} from "@dfinity/pic";
import type {
  Actor,
  CanisterFixture
} from "@dfinity/pic";

// Runtime import: include the .js extension
import { idlFactory as complexTestIDLFactory } from "../../src/declarations/complex_test_canister/complex_test_canister.did.js";
import { init as complexTestInit } from "../../src/declarations/complex_test_canister/complex_test_canister.did.js";

// Type-only import: import types from the candid interface without the extension
import type { _SERVICE as ComplexTestService, UserProfile, TransactionRequest, DocumentUpload } from "../../src/declarations/complex_test_canister/complex_test_canister.did";
  
export const WASM_PATH = ".dfx/local/canisters/complex_test_canister/complex_test_canister.wasm";

let pic: PocketIc;
let complex_test_fixture: CanisterFixture<ComplexTestService>;
const admin = createIdentity("admin");

describe("Week 9: Complex Parameter Integration with Generated InspectMo Module", () => {
  beforeEach(async () => {
    pic = await PocketIc.create(process.env.PIC_URL, {
      processingTimeoutMs: 1000 * 60 * 5,
    });

    complex_test_fixture = await pic.setupCanister<ComplexTestService>({
      sender: admin.getPrincipal(),
      idlFactory: complexTestIDLFactory,
      wasm: WASM_PATH
    });
  });

  afterEach(async () => {
    await pic.tearDown();
  });

  it('should extract UserProfile from create_profile call', async () => {
    complex_test_fixture.actor.setIdentity(admin);

    // Prepare test data using the generated types
    const userProfile : UserProfile = {
      id: 123n,
      name: 'Alice Johnson',
      email: 'alice@example.com',
      age : [30n],
      tags: ['developer', 'blockchain'],
     
      preferences: {
        theme: "test",
        notifications: true
      }
    } ;

    // Make the canister call using the typed actor
    const result = await complex_test_fixture.actor.create_profile(userProfile);

    console.log("create_profile result:", result);
    if ('ok' in result) {
      expect(result.ok).toBeDefined();
    } else {
      fail(`Expected result to have 'ok' property, but got: ${JSON.stringify(result)}`);
    }
  });

  it('should extract complex tuple from create_transaction call', async () => {
    complex_test_fixture.actor.setIdentity(admin);

    const transactionRequest : TransactionRequest = {
      amount: 100n,
      currency: 'ICP',
      recipient: Principal.fromText('aaaaa-aa'),
      memo: ['Transfer for services'],
      metadata: [['Approved by manager', 'High priority']]
    };

    const result = await complex_test_fixture.actor.create_transaction(transactionRequest, ["some notes"]);

    console.log("create_transaction result:", result);
    if ('ok' in result) {
      expect(result.ok).toBeDefined();
    } else {
      fail(`Expected result to have 'ok' property, but got: ${JSON.stringify(result)}`);
    }
  });

  it('should extract array of UserProfiles from batch_create_users', async () => {
    complex_test_fixture.actor.setIdentity(admin);

    const userProfiles: UserProfile[] = [
      {
      id: 1n,
      name: 'User One',
      email: 'user1@test.com',
      age: [25n],
      tags: ['test'],
      preferences: { 
        theme: 'light', 
        notifications: false 
      }
      },
      {
      id: 2n,
      name: 'User Two',
      email: 'user2@test.com',
      age: [30n],
      tags: ['admin'],
      preferences: { 
        theme: 'dark', 
        notifications: true 
      }
      }
    ];

    const result = await complex_test_fixture.actor.batch_create_users(userProfiles);

    console.log("batch_create_users result:", result);
    if ('ok' in result) {
      expect(result.ok).toBeDefined();
    } else {
      fail(`Expected result to have 'ok' property, but got: ${JSON.stringify(result)}`);
    }
  });

  it('should extract simple tuple from simple_numbers call', async () => {
    complex_test_fixture.actor.setIdentity(admin);

    const result = await complex_test_fixture.actor.simple_numbers(42n, -17n);

    console.log("simple_numbers result:", result);
    expect(typeof result).toBe('string');
    expect(result).toContain('42');
    expect(result).toContain('-17');
  });

  it('should handle no-parameter methods like clear_all_data', async () => {
    complex_test_fixture.actor.setIdentity(admin);

    const result = await complex_test_fixture.actor.clear_all_data();

    console.log("clear_all_data result:", result);
    expect(result).toBeNull(); // clear_all_data returns void, which serializes as null
  });

  it('should handle document upload with binary data', async () => {
    complex_test_fixture.actor.setIdentity(admin);

    const documentUpload : DocumentUpload = {
      filename: 'important-doc.pdf',
      content: new Uint8Array([1, 2, 3, 4, 5]), // Mock binary data
      mimetype: 'application/pdf',
      tags: ['legal', 'important'],
      permissions: {
        read: [admin.getPrincipal()],
        write: [admin.getPrincipal()]
      }
    };

    const result = await complex_test_fixture.actor.upload_document(documentUpload);

    console.log("upload_document result:", result);
    if ('ok' in result) {
      expect(result.ok).toBeDefined();
    } else {
      fail(`Expected result to have 'ok' property, but got: ${JSON.stringify(result)}`);
    }
  });

  it('complete workflow: complex types → extraction → validation → success', async () => {
    complex_test_fixture.actor.setIdentity(admin);

    // This test demonstrates the full workflow:
    // 1. Canister receives update call with complex parameters
    // 2. Generated MessageAccessor extracts parameters correctly
    // 3. Generated guard functions validate business logic  
    // 4. Inspect function makes allow/deny decision
    // 5. Method executes successfully
    
    const bulkOperation = {
      operation: { 
        'create': {
          id: 999n,
          name: 'Test User',
          email: 'test@example.com',
          age: [25n] as [] | [bigint],
          tags: ['test'],
          preferences: {
            theme: 'dark',
            notifications: true
          }
        } as UserProfile
      },
      batchId: 'batch-' + Date.now(),
      timestamp: BigInt(Date.now())
    };

    const result = await complex_test_fixture.actor.execute_bulk_operation(bulkOperation);

    console.log("execute_bulk_operation result:", result);
    
    // If the call succeeds, it means:
    // 1. ✅ Message was properly parsed by generated accessor
    // 2. ✅ Guard function received correct BulkOperation type
    // 3. ✅ Business logic validation passed
    // 4. ✅ Inspect function allowed the call
    if ('ok' in result) {
      expect(result.ok).toBeDefined();
    } else {
      fail(`Expected result to have 'ok' property, but got: ${JSON.stringify(result)}`);
    }
  });
});
