import { IDL } from "@dfinity/candid";
import { PocketIc, createIdentity, type CanisterFixture } from "@dfinity/pic";
import { idlFactory as mainIDLFactory, init as mainInit } from "../src/declarations/main/main.did.js";
import type { _SERVICE as MainService } from "../src/declarations/main/main.did";

// Overlay only for convenience; keep intersection style to align with ActorMethod typing
type MainServiceExt = MainService & {
  enable_ovs_test: (args: [ { period_ns?: [bigint] } ] | []) => Promise<void>;
  get_ovs_history: () => Promise<Array<{ ts: bigint; mode: string; namespace: string; platform: string; units: bigint }>>;
  clear_ovs_history: () => Promise<void>;
};

const WASM_PATH = ".dfx/local/canisters/main/main.wasm";
const TWO_SECONDS_NS = 2_000_000_000n;
const ONE_DAY_MS = 24 * 60 * 60 * 1000;
const THIRTY_TWO_DAYS_MS = 32 * ONE_DAY_MS;

async function jump(pic: PocketIc, deltaMs: number, ticks = 3) {
  const now = await pic.getTime();
  await pic.setTime(now + deltaMs);
  await pic.tick(ticks);
}

describe("ICRC85 OVS stop/restart behavior", () => {
  let pic: PocketIc;
  let main_fixture: CanisterFixture<MainService>;
  const admin = createIdentity("admin");

  beforeEach(async () => {
    pic = await PocketIc.create(process.env.PIC_URL, { processingTimeoutMs: 60_000 });
    main_fixture = await pic.setupCanister<MainService>({
      sender: admin.getPrincipal(),
      idlFactory: mainIDLFactory,
      wasm: WASM_PATH,
      arg: IDL.encode(mainInit({ IDL }), [[]]),
    });
  });

  afterEach(async () => { await pic?.tearDown(); });

  it("does not fire while stopped and resumes after restart", async () => {
    main_fixture.actor.setIdentity(admin);
    const actor = main_fixture.actor as unknown as MainServiceExt;

    await actor.clear_ovs_history();
    await actor.enable_ovs_test([{ period_ns: [TWO_SECONDS_NS] }]);

    // Allow scheduling
    await jump(pic, ONE_DAY_MS, 2);

  // Get history before stopping
  const beforeStop = (await actor.get_ovs_history()).length;

  // Stop the canister
  await pic.stopCanister({ canisterId: main_fixture.canisterId, sender: admin.getPrincipal() });

  // Advance a long time while stopped (no events should be recorded)
  await jump(pic, THIRTY_TWO_DAYS_MS, 1);

  // Start the canister to check history hasn't grown during stopped period
  await pic.startCanister({ canisterId: main_fixture.canisterId, sender: admin.getPrincipal() });
  const duringStop = (await actor.get_ovs_history()).length;
  expect(duringStop).toBe(beforeStop);

  // Advance slightly beyond a period to allow a run post-restart
  await jump(pic, THIRTY_TWO_DAYS_MS, 5);

  const afterRestart = (await actor.get_ovs_history()).length;
  // Expect at least one event after restart, and none during stopped period
  expect(afterRestart).toBeGreaterThan(beforeStop);
  }, 120_000);
});
