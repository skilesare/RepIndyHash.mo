// Byte-identity regression test for 0.1.2: hashes 2460 values (Nat/Int sign and LEB128 length
// boundaries, Text, Blob, nested Array/Map) and compares the SHA-256 of all the hashes, in order,
// with the digest that rep-indy-hash 0.1.1 produced for exactly these values. (The release check
// compared all 6,300 outputs of a larger run of this generator, 0..1100 / -1100..1100 / 2^300, line by line.)
import RIH "../src";
import Sha256 "mo:sha2/Sha256";
import Buffer "mo:base/Buffer";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Debug "mo:base/Debug";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Iter "mo:base/Iter";
import Text "mo:base/Text";

var count = 0;
let digits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'];
func hex(bs : [Nat8]) : Text {
  var t = "";
  for (b in bs.vals()) { t #= Text.fromChar(digits[Nat8.toNat(b / 16)]) # Text.fromChar(digits[Nat8.toNat(b % 16)]) };
  t;
};
let all = Buffer.Buffer<Nat8>(2460 * 32);
func h(_label : Text, v : RIH.Value) { count += 1; for (b in RIH.hash_val(v).vals()) all.add(b) };

// Nat: every value 0..300, powers of two +-1 up to 2^140, and a few huge ones.
for (n in Iter.range(0, 300)) { h("Nat " # Nat.toText(n), #Nat(n)) };
var p2 : Nat = 1;
for (k in Iter.range(0, 140)) {
  h("Nat 2^" # Nat.toText(k), #Nat(p2));
  h("Nat 2^" # Nat.toText(k) # "+1", #Nat(p2 + 1));
  if (p2 > 0) h("Nat 2^" # Nat.toText(k) # "-1", #Nat(p2 - 1));
  p2 *= 2;
};
h("Nat 10^100", #Nat(10 ** 100));

// Int: every value -300..300, +-(2^k), +-(2^k +- 1) up to 2^140 (sign-boundary cases).
var i : Int = -300;
while (i <= 300) { h("Int " # Int.toText(i), #Int(i)); i += 1 };
var q : Int = 1;
for (k in Iter.range(0, 140)) {
  for (d in [-1, 0, 1].vals()) {
    h("Int 2^" # Nat.toText(k) # "+" # Int.toText(d), #Int(q + d));
    h("Int -(2^" # Nat.toText(k) # "+" # Int.toText(d) # ")", #Int(-(q + d)));
  };
  q *= 2;
};
h("Int -10^100", #Int(-(10 ** 100)));
h("Int -123456", #Int(-123456));

// Text and Blob.
for (t in ["", "a", "Hello, World!", "é漢字🍬", "\00", "name", "message"].vals()) { h("Text " # debug_show t, #Text(t)) };
for (len in [0, 1, 2, 31, 32, 33, 55, 56, 63, 64, 65, 255, 256, 4096].vals()) {
  h("Blob len " # Nat.toText(len), #Blob(Blob.fromArray(Array.tabulate<Nat8>(len, func i = Nat8.fromNat((i * 37 + 11) % 256)))));
};
for (b in Iter.range(0, 255)) { h("Blob [" # Nat.toText(b) # "]", #Blob(Blob.fromArray([Nat8.fromNat(b)]))) };

// Arrays and Maps (ICRC-3 shapes, nesting, empty, duplicates, unsorted keys).
h("Array []", #Array([]));
h("Array [Nat 0]", #Array([#Nat(0)]));
h("Array mixed", #Array([#Nat(1), #Int(-1), #Text("x"), #Blob("\ff"), #Array([]), #Map([])]));
h("Array nested", #Array([#Array([#Array([#Int(-64)])])]));
h("Map []", #Map([]));
h("Map dup", #Map([("name", #Text("foo")), ("name", #Text("bar")), ("message", #Text("Hello World!"))]));
h("Map unsorted", #Map([("z", #Nat(1)), ("a", #Nat(2)), ("m", #Int(-3))]));
h("Map icrc1 tx", #Map([
  ("from", #Blob("\00\ab\cd\ef\00\12\34\00\56\78\9a\00\bc\de\f0\00\01\23\45\67\89\00\ab\cd\ef\01")),
  ("to", #Blob("\00\ab\0d\ef\00\12\34\00\56\78\9a\00\bc\de\f0\00\01\23\45\67\89\00\ab\cd\ef\01")),
  ("amount", #Nat(42)), ("created_at", #Nat(1699218263)), ("memo", #Nat(0)),
]));
h("Map icrc3 block", #Map([
  ("btype", #Text("1xfer")), ("ts", #Nat(1_700_000_000_000_000_000)), ("phash", #Blob("\01\02\03")),
  ("tx", #Map([("amt", #Nat(100)), ("from", #Array([#Blob("\aa")])), ("to", #Array([#Blob("\bb"), #Blob("\cc")])), ("fee", #Int(-1))])),
]));

let digest = hex(Blob.toArray(Sha256.fromArray(#sha256, Buffer.toArray(all))));
Debug.print("vectors=" # Nat.toText(count) # " digest=" # digest);
assert count == 2460;
assert digest == "607b5c56d0d4dc296459a4261805cb565c8634bbd0010ed9242ddeb21f8d93f4"; // rep-indy-hash 0.1.1

