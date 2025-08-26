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
const ONE_WEEK_MS = 7 * ONE_DAY_MS;
const SEVEN_POINT_FIVE_DAYS_MS = Math.floor(7.5 * ONE_DAY_MS); // slightly beyond a week

async function jump(pic: PocketIc, deltaMs: number, ticks = 3) {
  const now = await pic.getTime();
  await pic.setTime(now + deltaMs);
  await pic.tick(ticks);
}

describe("ICRC85 OVS upgrade/reinstall cadence (weekly post-upgrade)", () => {
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

  it("fires again after a reinstall/upgrade and then weekly (simulated)", async () => {
    main_fixture.actor.setIdentity(admin);
    const actor = main_fixture.actor as unknown as MainServiceExt;

    await actor.clear_ovs_history();
    await actor.enable_ovs_test([{ period_ns: [TWO_SECONDS_NS] }]);

    // Allow initial scheduling
    await jump(pic, ONE_DAY_MS, 2);

    // Trigger at least once pre-upgrade
    await jump(pic, 31 * ONE_DAY_MS, 5);
    const before = await actor.get_ovs_history();
    expect(before.length).toBeGreaterThanOrEqual(1);

    // Simulate code upgrade via reinstall (state may reset depending on setup)
    await pic.upgradeCanisterOrtho({
      canisterId: main_fixture.canisterId,
      wasm: WASM_PATH,
      arg: IDL.encode(mainInit({ IDL }), [[]]),
      sender: admin.getPrincipal(),
    });

  // Re-enable env (dynamic env may need to be pushed again post-upgrade)
  await actor.enable_ovs_test([{ period_ns: [TWO_SECONDS_NS] }]);

  // After upgrade, advance slightly beyond a week and ensure it fires again
  const beforeUpgradeCount = (await actor.get_ovs_history()).length;
  await jump(pic, SEVEN_POINT_FIVE_DAYS_MS, 5);
  const after = await actor.get_ovs_history();
  // After reinstall, ensure we see at least one new event post-upgrade
  expect(after.length).toBeGreaterThan(beforeUpgradeCount);
  }, 120_000);
});
