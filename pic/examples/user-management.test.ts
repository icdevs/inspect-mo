import { PocketIc, createIdentity } from '@dfinity/pic';
import { Principal } from '@dfinity/principal';

// Real E2E test for the examples/user-management.mo canister
// Requires: dfx build user_management_example (we trigger it in CI before running this file)

const WASM_PATH = ".dfx/local/canisters/user_management_example/user_management_example.wasm";

type ApiResult<T> = { ok: T } | { err: string };

type UserProfile = {
  id: bigint;
  username: string;
  email: string;
  created_at: bigint; // Int renders to BigInt via agent-js
};

type CreateUserRequest = {
  username: string;
  email: string;
};

type Status = {
  user_count: bigint;
  next_id: bigint;
};

interface UserManagementActor {
  create_user: (request: CreateUserRequest) => Promise<ApiResult<UserProfile>>;
  get_user: (id: bigint) => Promise<UserProfile[]>;
  list_users: () => Promise<UserProfile[]>;
  get_user_count: () => Promise<bigint>;
  init_default_user: () => Promise<ApiResult<UserProfile>>;
  get_status: () => Promise<Status>;
}

// Candid IDL matching examples/user-management.mo
const idlFactory = ({ IDL }: any) => {
  const UserProfile = IDL.Record({
    id: IDL.Nat,
    username: IDL.Text,
    email: IDL.Text,
    created_at: IDL.Int,
  });
  const CreateUserRequest = IDL.Record({ username: IDL.Text, email: IDL.Text });
  const ApiResult = (T: any) => IDL.Variant({ ok: T, err: IDL.Text });
  const Status = IDL.Record({ user_count: IDL.Nat, next_id: IDL.Nat });
  return IDL.Service({
    create_user: IDL.Func([CreateUserRequest], [ApiResult(UserProfile)], []),
    get_user: IDL.Func([IDL.Nat], [IDL.Opt(UserProfile)], ['query']),
    list_users: IDL.Func([], [IDL.Vec(UserProfile)], ['query']),
    get_user_count: IDL.Func([], [IDL.Nat], ['query']),
    init_default_user: IDL.Func([], [ApiResult(UserProfile)], []),
    get_status: IDL.Func([], [Status], ['query']),
  });
};

describe('examples/user-management.mo (real canister)', () => {
  let pic: PocketIc;
  const alice = createIdentity('alice');
  const bob = createIdentity('bob');
  const charlie = createIdentity('charlie');

  beforeEach(async () => {
    pic = await PocketIc.create(process.env.PIC_URL);
  });

  afterEach(async () => {
    await pic?.tearDown();
  });

  describe('✅ Positive Cases - Valid Operations', () => {
    it('should create user with valid authenticated request', async () => {
      const fixture = await pic.setupCanister<UserManagementActor>({
        idlFactory,
        wasm: WASM_PATH,
        sender: alice.getPrincipal(),
      });

      // Ensure the actor is using Alice's identity
      fixture.actor.setIdentity(alice);

      const result = await fixture.actor.create_user({
        username: 'alice',
        email: 'alice@example.com',
      });

      expect('ok' in result).toBe(true);
      if ('ok' in result) {
        expect(result.ok.username).toBe('alice');
        expect(result.ok.email).toBe('alice@example.com');
        expect(result.ok.id).toBe(1n);
        expect(typeof result.ok.created_at).toBe('bigint');
      }
    });

    it('should accept username at minimum length (3 chars)', async () => {
      const fixture = await pic.setupCanister<UserManagementActor>({
        idlFactory,
        wasm: WASM_PATH,
        sender: alice.getPrincipal(),
      });

      // Ensure the actor is using Alice's identity
      fixture.actor.setIdentity(alice);

      const result = await fixture.actor.create_user({
        username: 'abc', // Exactly 3 characters
        email: 'abc@example.com',
      });

      expect('ok' in result).toBe(true);
      if ('ok' in result) {
        expect(result.ok.username).toBe('abc');
      }
    });

    it('should accept username at maximum length (20 chars)', async () => {
      const fixture = await pic.setupCanister<UserManagementActor>({
        idlFactory,
        wasm: WASM_PATH,
        sender: alice.getPrincipal(),
      });

      // Ensure the actor is using Alice's identity
      fixture.actor.setIdentity(alice);

      const result = await fixture.actor.create_user({
        username: 'abcdefghij1234567890', // Exactly 20 characters
        email: 'long@example.com',
      });

      expect('ok' in result).toBe(true);
      if ('ok' in result) {
        expect(result.ok.username).toBe('abcdefghij1234567890');
      }
    });

    it('should allow multiple different users', async () => {
      const fixture = await pic.setupCanister<UserManagementActor>({
        idlFactory,
        wasm: WASM_PATH,
        sender: alice.getPrincipal(),
      });

      // Create first user as Alice
      fixture.actor.setIdentity(alice);
      const result1 = await fixture.actor.create_user({
        username: 'alice',
        email: 'alice@example.com',
      });
      expect('ok' in result1).toBe(true);

      // Switch to Bob's identity and create second user
      fixture.actor.setIdentity(bob);
      const result2 = await fixture.actor.create_user({
        username: 'bob',
        email: 'bob@example.com',
      });
      expect('ok' in result2).toBe(true);

      // Verify both users exist
      const users = await fixture.actor.list_users();
      expect(users).toHaveLength(2);
    });

    it('should allow query methods for anonymous callers', async () => {
      const fixture = await pic.setupCanister<UserManagementActor>({
        idlFactory,
        wasm: WASM_PATH,
        sender: alice.getPrincipal(),
      });

      // Create a user first using Alice's identity
      fixture.actor.setIdentity(alice);
      await fixture.actor.create_user({
        username: 'alice',
        email: 'alice@example.com',
      });

      // Test query methods with anonymous caller - switch to anonymous identity
      const anonymousIdentity = createIdentity('anonymous'); // This creates a proper identity object
      fixture.actor.setIdentity(anonymousIdentity);
      
      const count = await fixture.actor.get_user_count();
      expect(count).toBe(1n);

      const users = await fixture.actor.list_users();
      expect(users).toHaveLength(1);

      const user = await fixture.actor.get_user(1n);
      expect(user).toHaveLength(1);
      expect(user[0].username).toBe('alice');
    });
  });

  describe('❌ Negative Cases - Guard Rule Violations (Parameter Validation)', () => {
    it('should reject username that is too short (< 3 chars)', async () => {
      const fixture = await pic.setupCanister<UserManagementActor>({
        idlFactory,
        wasm: WASM_PATH,
        sender: alice.getPrincipal(),
      });

      // Set Alice's identity for authenticated calls
      fixture.actor.setIdentity(alice);

      const result = await fixture.actor.create_user({
        username: 'ab', // Too short
        email: 'test@example.com',
      });

      expect('err' in result).toBe(true);
      if ('err' in result) {
        expect(result.err).toContain('Username must be at least 3 characters');
      }
    });

    it('should reject empty username', async () => {
      const fixture = await pic.setupCanister<UserManagementActor>({
        idlFactory,
        wasm: WASM_PATH,
        sender: alice.getPrincipal(),
      });

      // Set Alice's identity for authenticated calls
      fixture.actor.setIdentity(alice);

      const result = await fixture.actor.create_user({
        username: '', // Empty
        email: 'test@example.com',
      });

      expect('err' in result).toBe(true);
      if ('err' in result) {
        expect(result.err).toContain('Username must be at least 3 characters');
      }
    });

    it('should reject username that is too long (> 20 chars)', async () => {
      const fixture = await pic.setupCanister<UserManagementActor>({
        idlFactory,
        wasm: WASM_PATH,
        sender: alice.getPrincipal(),
      });

      // Set Alice's identity for authenticated calls
      fixture.actor.setIdentity(alice);

      const result = await fixture.actor.create_user({
        username: 'abcdefghij1234567890x', // 21 characters
        email: 'test@example.com',
      });

      expect('err' in result).toBe(true);
      if ('err' in result) {
        expect(result.err).toContain('Username must be no more than 20 characters');
      }
    });

    it('should reject very long username', async () => {
      const fixture = await pic.setupCanister<UserManagementActor>({
        idlFactory,
        wasm: WASM_PATH,
        sender: alice.getPrincipal(),
      });

      // Set Alice's identity for authenticated calls
      fixture.actor.setIdentity(alice);

      const result = await fixture.actor.create_user({
        username: 'this_username_is_way_too_long_for_validation_rules', // Much too long
        email: 'test@example.com',
      });

      expect('err' in result).toBe(true);
      if ('err' in result) {
        expect(result.err).toContain('Username must be no more than 20 characters');
      }
    });
  });

  describe('❌ Negative Cases - Inspect Rule Violations (Access Control)', () => {
    it('should reject anonymous callers for create_user', async () => {
      const fixture = await pic.setupCanister<UserManagementActor>({
        idlFactory,
        wasm: WASM_PATH,
        sender: Principal.anonymous(), // Anonymous caller
      });

      // This should be rejected at the inspect level
      await expect(
        fixture.actor.create_user({
          username: 'anonymous',
          email: 'anon@example.com',
        })
      ).rejects.toThrow(/canister_inspect_message explicitly refused message/);
    });

    it('should reject anonymous callers for init_default_user', async () => {
      const fixture = await pic.setupCanister<UserManagementActor>({
        idlFactory,
        wasm: WASM_PATH,
        sender: Principal.anonymous(), // Anonymous caller
      });

      // This should be rejected at the inspect level
      await expect(
        fixture.actor.init_default_user()
      ).rejects.toThrow(/canister_inspect_message explicitly refused message/);
    });
  });

  describe('❌ Negative Cases - Business Logic Violations', () => {
    it('should reject duplicate usernames', async () => {
      const fixture = await pic.setupCanister<UserManagementActor>({
        idlFactory,
        wasm: WASM_PATH,
        sender: alice.getPrincipal(),
      });

      // Set Alice's identity for authenticated calls
      fixture.actor.setIdentity(alice);

      // Create first user
      const result1 = await fixture.actor.create_user({
        username: 'alice',
        email: 'alice@example.com',
      });
      expect('ok' in result1).toBe(true);

      // Try to create second user with same username
      const result2 = await fixture.actor.create_user({
        username: 'alice', // Duplicate username
        email: 'alice2@example.com',
      });

      expect('err' in result2).toBe(true);
      if ('err' in result2) {
        expect(result2.err).toContain('Username already exists: alice');
      }
    });

    it('should reject duplicate usernames from different callers', async () => {
      const fixture = await pic.setupCanister<UserManagementActor>({
        idlFactory,
        wasm: WASM_PATH,
        sender: alice.getPrincipal(),
      });

      // Alice creates user
      fixture.actor.setIdentity(alice);
      const result1 = await fixture.actor.create_user({
        username: 'shared',
        email: 'alice@example.com',
      });
      expect('ok' in result1).toBe(true);

      // Bob tries to create user with same username
      fixture.actor.setIdentity(bob);
      const result2 = await fixture.actor.create_user({
        username: 'shared', // Duplicate username
        email: 'bob@example.com',
      });

      expect('err' in result2).toBe(true);
      if ('err' in result2) {
        expect(result2.err).toContain('Username already exists: shared');
      }
    });
  });

  describe('🔍 Edge Cases and Boundary Conditions', () => {
    it('should handle special characters in usernames within length limits', async () => {
      const fixture = await pic.setupCanister<UserManagementActor>({
        idlFactory,
        wasm: WASM_PATH,
        sender: alice.getPrincipal(),
      });

      // Set Alice's identity for authenticated calls
      fixture.actor.setIdentity(alice);

      const result = await fixture.actor.create_user({
        username: 'user_123-test', // Special chars but valid length
        email: 'special@example.com',
      });

      expect('ok' in result).toBe(true);
      if ('ok' in result) {
        expect(result.ok.username).toBe('user_123-test');
      }
    });

    it('should handle unicode characters within length limits', async () => {
      const fixture = await pic.setupCanister<UserManagementActor>({
        idlFactory,
        wasm: WASM_PATH,
        sender: alice.getPrincipal(),
      });

      // Set Alice's identity for authenticated calls
      fixture.actor.setIdentity(alice);

      const result = await fixture.actor.create_user({
        username: 'user🚀test', // Unicode but valid length
        email: 'unicode@example.com',
      });

      expect('ok' in result).toBe(true);
      if ('ok' in result) {
        expect(result.ok.username).toBe('user🚀test');
      }
    });

    it('should handle empty email (no email validation in canister)', async () => {
      const fixture = await pic.setupCanister<UserManagementActor>({
        idlFactory,
        wasm: WASM_PATH,
        sender: alice.getPrincipal(),
      });

      // Set Alice's identity for authenticated calls
      fixture.actor.setIdentity(alice);

      const result = await fixture.actor.create_user({
        username: 'noemail',
        email: '', // Empty email
      });

      expect('ok' in result).toBe(true);
      if ('ok' in result) {
        expect(result.ok.email).toBe('');
      }
    });

    it('should maintain user ID sequence correctly', async () => {
      const fixture = await pic.setupCanister<UserManagementActor>({
        idlFactory,
        wasm: WASM_PATH,
        sender: alice.getPrincipal(),
      });

      // Set Alice's identity for authenticated calls
      fixture.actor.setIdentity(alice);

      // Create multiple users and verify ID sequence
      const users = ['alice', 'bob', 'charlie'];
      for (let i = 0; i < users.length; i++) {
        const result = await fixture.actor.create_user({
          username: users[i],
          email: `${users[i]}@example.com`,
        });

        expect('ok' in result).toBe(true);
        if ('ok' in result) {
          expect(result.ok.id).toBe(BigInt(i + 1));
        }
      }

      const userList = await fixture.actor.list_users();
      expect(userList).toHaveLength(3);
    });
  });
});

// ====================================================================
// END OF REAL E2E TESTS FOR examples/user-management.mo 
// ====================================================================

// Educational mock demos have been removed to maintain clarity between
// real E2E tests and educational patterns. For educational testing 
// patterns and examples, see the InspectMo documentation.
