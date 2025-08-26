import { IDL } from "@dfinity/candid";
import { PocketIc, createIdentity, type CanisterFixture } from "@dfinity/pic";
import { idlFactory as mainIDLFactory, init as mainInit } from "../src/declarations/main/main.did.js";
import type { _SERVICE as MainService } from "../src/declarations/main/main.did";

type MainServiceExt = MainService & {
  enable_ovs_send_mode: (args: [ { period_ns?: [bigint]; collector_self?: [boolean] } ] | []) => Promise<void>;
  get_notify_calls: () => Promise<bigint>;
  get_notify_last_namespace: () => Promise<string>;
  get_notify_last_units: () => Promise<bigint>;
};

const WASM_PATH = ".dfx/local/canisters/main/main.wasm";

// Time helpers in milliseconds for PocketIC setTime API
const ONE_DAY_MS = 24 * 60 * 60 * 1000;
const THIRTY_TWO_DAYS_MS = 32 * ONE_DAY_MS; // go slightly beyond a month threshold

describe("ICRC85 OVS cycles send path (notify)", () => {
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

  it("sends cycles by calling icrc85_deposit_cycles_notify after ~a month", async () => {
    main_fixture.actor.setIdentity(admin);
    const actor = main_fixture.actor as unknown as MainServiceExt;

    // Enable send mode with short period (2s) and collector=self so we see notify
    await actor.enable_ovs_send_mode([{ period_ns: [2_000_000_000n], collector_self: [true] }]);

    const startMs = await pic.getTime();
    // Baseline
    expect(Number(await actor.get_notify_calls())).toBe(0);

    // Allow initial scheduling after a day
    await pic.setTime(startMs + ONE_DAY_MS);
    await pic.tick(2);
    expect(Number(await actor.get_notify_calls())).toBe(0);

    // Jump forward ~a month worth of time; tick to execute timers
  await pic.setTime(startMs + ONE_DAY_MS + THIRTY_TWO_DAYS_MS);
    await pic.tick(5);

    const calls = Number(await actor.get_notify_calls());
    expect(calls).toBeGreaterThanOrEqual(1);

  const ns = await actor.get_notify_last_namespace();
  const units = Number(await actor.get_notify_last_units());
  // Notify uses the payment namespace, not the timer namespace
  expect(ns).toBe("org.icdevs.libraries.inspect-mo");
    expect(units).toBeGreaterThanOrEqual(1);
  }, 120_000);
});
