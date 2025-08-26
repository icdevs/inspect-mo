import { IDL } from "@dfinity/candid";
import { PocketIc, createIdentity, type CanisterFixture } from "@dfinity/pic";
import { idlFactory as mainIDLFactory, init as mainInit } from "../src/declarations/main/main.did.js";
import type { _SERVICE as MainService } from "../src/declarations/main/main.did";

type MainServiceExt = MainService & {
  enable_ovs_test: (args: [ { period_ns?: [bigint] } ] | []) => Promise<void>;
  get_ovs_history: () => Promise<Array<{ ts: bigint; mode: string; namespace: string; platform: string; units: bigint }>>;
  clear_ovs_history: () => Promise<void>;
};

const WASM_PATH = ".dfx/local/canisters/main/main.wasm";
const TWO_SECONDS_NS = 2_000_000_000n;
const ONE_DAY_MS = 24 * 60 * 60 * 1000;
const THIRTY_TWO_DAYS_MS = 32 * ONE_DAY_MS; // slightly beyond monthly threshold

// Helper to advance time and tick a few times
async function jump(pic: PocketIc, deltaMs: number, ticks = 3) {
  const now = await pic.getTime();
  await pic.setTime(now + deltaMs);
  await pic.tick(ticks);
}

describe("ICRC85 OVS history accumulates over multiple periods", () => {
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

  it("records events for several months (simulated by short period)", async () => {
    main_fixture.actor.setIdentity(admin);
    const actor = main_fixture.actor as unknown as MainServiceExt;

    await actor.clear_ovs_history();
    await actor.enable_ovs_test([{ period_ns: [TWO_SECONDS_NS] }]);

    // Let scheduling settle
    await jump(pic, ONE_DAY_MS, 2);

    // Simulate ~3 months by advancing 3 big jumps separated by ticks
    for (let i = 0; i < 3; i++) {
      await jump(pic, THIRTY_TWO_DAYS_MS, 5);
    }

    const history = await actor.get_ovs_history();
    expect(history.length).toBeGreaterThanOrEqual(3);

    // Ensure history length is monotonically increasing when we add more time
    const before = history.length;
    await jump(pic, THIRTY_TWO_DAYS_MS, 5);
    const after = (await actor.get_ovs_history()).length;
    expect(after).toBeGreaterThanOrEqual(before + 1);

    for (const e of history) {
      expect(typeof e.mode).toBe("string");
      expect(e.mode === "handler" || e.mode === "notify").toBe(true);
      expect(e.namespace.length).toBeGreaterThan(0);
      expect(e.platform.toLowerCase()).toBe("icp");
      expect(Number(e.units)).toBeGreaterThanOrEqual(1);
      expect(Number(e.ts)).toBeGreaterThan(0);
    }
  }, 120_000);
});
