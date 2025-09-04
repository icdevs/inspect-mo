import {test} "mo:test/async";
import Debug "mo:core/Debug";

persistent actor PermissionIntegrationNewMinimalTest {

public func runTests() : async () {
  await test("minimal test", func() : async () {
    Debug.print("Testing minimal case...");
  });
};

public func test() : async () {
  await runTests();
};

};
