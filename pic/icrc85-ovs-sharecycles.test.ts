import { IDL } from "@dfinity/candid";
import { PocketIc, createIdentity, type CanisterFixture } from "@dfinity/pic";
import { Principal } from "@dfinity/principal";

// Decls for the sample main canister
import { idlFactory as mainIDLFactory, init as mainInit } from "../src/declarations/main/main.did.js";
import type { _SERVICE as MainService } from "../src/declarations/main/main.did";

type MainServiceExt = MainService & {
  enable_ovs_test: (args: [ { period_ns?: [bigint] } ] | []) => Promise<void>;
  get_ovs_handler_calls: () => Promise<bigint>;
  get_ovs_last_units: () => Promise<bigint>;
  get_ovs_last_namespace: () => Promise<string>;
  get_ovs_last_platform: () => Promise<string>;
};

const WASM_PATH = ".dfx/local/canisters/main/main.wasm";

// Time helpers in milliseconds for PocketIC setTime API
const ONE_DAY_MS = 24 * 60 * 60 * 1000;
const THIRTY_TWO_DAYS_MS = 32 * ONE_DAY_MS; // slightly beyond monthly threshold

describe("ICRC85 OVS cycle sharing triggers with time travel", () => {
  let pic: PocketIc;
  let main_fixture: CanisterFixture<MainService>;
  const admin = createIdentity("admin");

  beforeEach(async () => {
    pic = await PocketIc.create(process.env.PIC_URL, {
      processingTimeoutMs: 1000 * 60 * 5,
    });

    main_fixture = await pic.setupCanister<MainService>({
      sender: admin.getPrincipal(),
      idlFactory: mainIDLFactory,
      wasm: WASM_PATH,
      arg: IDL.encode(mainInit({ IDL }), [[]]),
    });
  });

  afterEach(async () => {
    await pic?.tearDown();
  });

  it("schedules after a day and triggers after ~a month (simulated)", async () => {
  main_fixture.actor.setIdentity(admin);
  const actor = main_fixture.actor as unknown as MainServiceExt;

    // Enable test mode so OVS uses in-canister handler rather than transferring cycles
    // Use a short 2-second period to simulate day/month progression reliably under PocketIC
  await actor.enable_ovs_test([{ period_ns: [2000000000n] }]);

    // Baseline
  let calls = await actor.get_ovs_handler_calls();
    expect(Number(calls)).toBe(0);

    // Advance roughly one day to allow any setup/scheduling to occur
    const startMs = await pic.getTime();
    await pic.setTime(startMs + ONE_DAY_MS);
    await pic.tick(2);

  // After a day, it's only scheduled; handler may not have fired yet
  calls = await actor.get_ovs_handler_calls();
  expect(Number(calls)).toBe(0);

    // Jump forward ~a month (slightly over) so the monthly share action triggers
    await pic.setTime(startMs + ONE_DAY_MS + THIRTY_TWO_DAYS_MS);
    await pic.tick(5);

  let callsAfterMonth = Number(await actor.get_ovs_handler_calls());
    expect(callsAfterMonth).toBeGreaterThanOrEqual(1);

    // Jump one more month and ensure count increases (monotonic, at least +1)
    await pic.setTime(startMs + ONE_DAY_MS + 2 * THIRTY_TWO_DAYS_MS);
    await pic.tick(5);
    const callsAfterTwoMonths = Number(await actor.get_ovs_handler_calls());
    expect(callsAfterTwoMonths).toBeGreaterThanOrEqual(callsAfterMonth + 1);

    // Sanity on mapped fields
  const units = await actor.get_ovs_last_units();
  const ns = await actor.get_ovs_last_namespace();
  const platform = await actor.get_ovs_last_platform();
    expect(Number(units)).toBeGreaterThanOrEqual(1);
    expect(ns.length).toBeGreaterThan(0);
  expect(platform.toLowerCase()).toBe("icp");
  }, 120_000);
});
