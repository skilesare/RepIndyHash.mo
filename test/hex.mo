// Test-only hex decoder (replaces `mo:encoding/Hex`, which 0.1.1 took from a GitHub dependency).
import Array "mo:base/Array";
import Char "mo:base/Char";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import Nat8 "mo:base/Nat8";
import Result "mo:base/Result";

module {
  func nibble(c : Char) : ?Nat8 {
    let n = Char.toNat32(c);
    if (n >= 48 and n <= 57) return ?Nat8.fromNat(Nat32.toNat(n - 48));
    if (n >= 97 and n <= 102) return ?Nat8.fromNat(Nat32.toNat(n - 87));
    if (n >= 65 and n <= 70) return ?Nat8.fromNat(Nat32.toNat(n - 55));
    null;
  };

  public func decode(t : Text) : Result.Result<[Nat8], Text> {
    let cs = Text.toArray(t);
    if (cs.size() % 2 != 0) return #err("odd length");
    let out = Array.init<Nat8>(cs.size() / 2, 0);
    var i = 0;
    while (i < out.size()) {
      switch (nibble(cs[2 * i]), nibble(cs[2 * i + 1])) {
        case (?h, ?l) { out[i] := h * 16 + l };
        case _ { return #err("invalid hex") };
      };
      i += 1;
    };
    #ok(Array.freeze(out));
  };
};
