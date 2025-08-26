import {test} "mo:test/async";
import Debug "mo:core/Debug";
import Blob "mo:core/Blob";
import Text "mo:core/Text";
import Principal "mo:core/Principal";
import OVSFixed "mo:ovs-fixed";

// Unit test to ensure ICRC85 OVS shareCycles executes the provided handler
// without attempting to actually transfer cycles.

await test("icrc85 shareCycles uses handler and schedules", func() : async () {
  Debug.print("Starting ICRC85 OVS shareCycles handler test");

  // Capture values the handler sees
  var called : Bool = false;
  var seenPairs : ?[(Text, OVSFixed.Value)] = null;

  let env : OVSFixed.ICRC85Environment = ?{
    kill_switch = ?false;
  handler = ?(func (pairs: [(Text, OVSFixed.Map)]) : () {
      // Expect a single tuple: ("icrc85:ovs:shareaction", payloadMap)
      called := true;
      if (pairs.size() == 1 and pairs[0].0 == "icrc85:ovs:shareaction") {
        seenPairs := ?pairs[0].1;
      };
  });
    period = ?1; // tiny period for scheduling
    asset = ?"cycles";
    platform = ?"icp";
    tree = ?["inspect-mo", "test"];
    collector = ?Principal.fromText("aaaaa-aa") // dummy principal text ok for tests
  };

  // A no-op scheduler just records that it was invoked
  var scheduled : Bool = false;
  let schedule = func <system>(period: Nat) : async* () {
    Debug.print("schedule called with period=" # debug_show(period));
    scheduled := true;
  };

  // Execute shareCycles via the library
  await* OVSFixed.shareCycles<system>({
    environment = env;
    cycles = 123_456_789; // arbitrary
    actions = 42;         // arbitrary
    namespace = "org.icdevs.libraries.inspect-mo";
    schedule = schedule;
  });

  // Assertions: handler called and schedule called
  assert called;
  assert scheduled;

  // Validate essential fields in the mapped payload
  switch (seenPairs) {
    case (?m) {
      // Convert map to simpler view for assertions
      var have_period = false;
      var have_principal = false;
      var have_asset = false;
      var have_platform = false;
      var have_units = false;
      label chk for ((k, v) in m.vals()) {
        switch (k, v) {
          case ("report_period", #Nat(_)) { have_period := true };
          case ("principal", #Text(_)) { have_principal := true };
          case ("asset", #Text("cycles")) { have_asset := true };
          case ("platform", #Text("icp")) { have_platform := true };
          case ("units", #Nat(42)) { have_units := true };
          case (_) {};
        };
      };
      assert have_period and have_principal and have_asset and have_platform and have_units;
    };
    case null { assert false };
  };

  Debug.print("ICRC85 OVS shareCycles handler test passed");
});
