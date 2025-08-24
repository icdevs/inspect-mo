import Principal "mo:core/Principal";
import Debug "mo:core/Debug";

let anon1 = Principal.fromText("2vxsx-fae");
let anon2 = Principal.anonymous();

Debug.print("anon1 (2vxsx-fae): " # Principal.toText(anon1));
Debug.print("anon1 isAnonymous: " # debug_show(Principal.isAnonymous(anon1)));

Debug.print("anon2 (anonymous()): " # Principal.toText(anon2));  
Debug.print("anon2 isAnonymous: " # debug_show(Principal.isAnonymous(anon2)));

Debug.print("Are they equal: " # debug_show(Principal.equal(anon1, anon2)));
