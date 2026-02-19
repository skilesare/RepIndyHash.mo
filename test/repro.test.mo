
import ReIndy "../src/lib";
import Blob "mo:core/Blob";
import Text "mo:core/Text";
import Int "mo:core/Int";
import Nat8 "mo:core/Nat8";
import Nat "mo:core/Nat";
import Test "mo:test";
import Debug "mo:core/Debug";
import Sha256 "mo:sha2/Sha256";
import Iter "mo:core/Iter";
import Runtime "mo:core/Runtime";

func toHex(blob : Blob) : Text {
  var s = "";
  for (b in Blob.toArray(blob).vals()) {
    let n = Nat8.toNat(b);
    let hex = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"];
    s #= hex[n / 16];
    s #= hex[n % 16];
  };
  s
};

Test.test("Verify Hashes", func() {
  // Test 1: SHA-256 of "Hello, World!"
  let input1 = "Hello, World!";
  let blob1 = Text.encodeUtf8(input1);
  let hash1 = Sha256.fromBlob(#sha256, blob1);
  let hex1 = toHex(hash1);
  Debug.print("Hash 1 (Hello, World!): " # hex1);

  let expected1 = "dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f";
  if (hex1 == expected1) {
    Debug.print("Hash 1 matches expected value.");
  } else {
    Debug.print("Hash 1 DOES NOT match expected value.");
  };

  // Test 2: Int(-42) as LEB128 then generic hash
  // Using ReIndy which implements this logic
  let val2 : ReIndy.Value = #Int(-42);
  let hash_bytes2 = ReIndy.hash_val(val2);
  let hash2 = Blob.fromArray(hash_bytes2);
  let hex2 = toHex(hash2);
  Debug.print("Hash 2 (Int(-42)): " # hex2);
  let expected2 = "de5a6f78116eca62d7fc5ce159d23ae6b889b365a1739ad2cf36f925a140d0cc";
  if (hex2 == expected2) {
    Debug.print("Hash 2 matches expected value.");
  } else {
    Runtime.trap("Hash 2 DOES NOT match expected value.");
  };
});
