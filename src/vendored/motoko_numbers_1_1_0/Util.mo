// Vendored into rep-indy-hash 0.1.2 from https://github.com/edjCase/motoko_numbers at v1.1.0
// (commit 773953141f976ccdfc2e6a2c451b841a53bb39a0). MIT License, Copyright (c) 2022 Ethan Celletti;
// the full license text is in NOTICE at the root of the rep-indy-hash package.
// Only the functions rep-indy-hash uses are copied; their bodies are unchanged.
// Source: src/Util.mo, lines 11-33, 35-57 and 75-94.

import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";
import Nat8 "mo:base/Nat8";

module {
  public func natToLeastSignificantBits(value: Nat, byteLength: Nat, hasSign: Bool) : [Bool] {
    let buffer = Buffer.Buffer<Bool>(64);
    var remainingValue: Nat = value;
    while (remainingValue > 0) {
      let bit: Bool = remainingValue % 2 == 1;
      buffer.add(bit);
      remainingValue /= 2;
    };
    while (buffer.size() % byteLength != 0) {
      buffer.add(false); // Pad 0's for full byte
    };
    if (hasSign) {
        let mostSignificantBit: Bool = buffer.get(buffer.size() - 1);
        if (mostSignificantBit) {
            // If most significant bit is a 1, overflow to another byte
            for (i in Iter.range(1, byteLength)) {
                buffer.add(false);
            };
        };
    };
    // Least Sigficant Bit first
    Buffer.toArray(buffer);
  };

  public func invariableLengthBytesEncode(buffer: Buffer.Buffer<Nat8>, bits: [Bool]) {
    
    let byteCount: Nat = (bits.size() / 7) + (if (bits.size() % 7 != 0) 1 else 0); // 7, not 8, the 8th bit is to indicate end of number
    
    label f for (byteIndex in Iter.range(0, byteCount - 1))
    {
        var byte: Nat8 = 0;
        for (bitOffset in Iter.range(0, 6)) {
            let bit: Bool = bits[byteIndex * 7 + bitOffset];
            if (bit) {
                // Set bit
                byte := Nat8.bitset(byte, bitOffset);
            };
        };
        let hasMoreBits = bits.size() > (byteIndex + 1) * 7;
        if (hasMoreBits)
        {
            // Have most left of byte be 1 if there is another byte
            byte := Nat8.bitset(byte, 7);
        };
        buffer.add(byte);
    };
  };

  public func twosCompliment(bits: [Bool]): [Bool] {
    // Ones compliment, flip all bits
    let flippedBits = Array.map(bits, func(b: Bool): Bool { not b });
    
    // Twos compliment, add 1
    let lastIndex: Nat = flippedBits.size() - 1;
    let varBits: [var Bool] = Array.thaw(flippedBits);

    // Loop through adding 1 to the LSB, and carry the 1 if neccessary
    label l for (n in Iter.range(0, lastIndex)) {
        varBits[n] := not varBits[n]; // flip
        if (varBits[n]) {
            // If flipped to 1, end
            break l;
        } else {
            // If flipped to 0, carry the one till the first 0
        };
    };
    Array.freeze(varBits);
  };
};
