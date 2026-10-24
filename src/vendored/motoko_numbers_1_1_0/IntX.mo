// Vendored into rep-indy-hash 0.1.2 from https://github.com/edjCase/motoko_numbers at v1.1.0
// (commit 773953141f976ccdfc2e6a2c451b841a53bb39a0). MIT License, Copyright (c) 2022 Ethan Celletti;
// the full license text is in NOTICE at the root of the rep-indy-hash package.
// Only the functions rep-indy-hash uses are copied; their bodies are unchanged.
// Source: src/IntX.mo, lines 118-141 (encodeInt).

import Buffer "mo:base/Buffer";
import Int "mo:base/Int";
import Util "./Util";

module {
  public func encodeInt(buffer : Buffer.Buffer<Nat8>, value : Int, encoding : { #signedLEB128 }) {
    switch (encoding) {
      case (#signedLEB128) {
        if (value == 0) {
          buffer.add(0);
          return;
        };
        // Signed LEB128 - https://en.wikipedia.org/wiki/LEB128#Signed_LEB128
        //         11110001001000000  Binary encoding of 123456
        //   00001_11100010_01000000  As a 21-bit number (multiple of 7)
        //   11110_00011101_10111111  Negating all bits (one's complement)
        //   11110_00011101_11000000  Adding one (two's complement) (Binary encoding of signed -123456)
        // 1111000  0111011  1000000  Split into 7-bit groups
        //01111000 10111011 11000000  Add high 1 bits on all but last (most significant) group to form bytes
        let positiveValue = Int.abs(value);
        var bits : [Bool] = Util.natToLeastSignificantBits(positiveValue, 7, true);
        if (value < 0) {
          // If negative, then get twos compliment
          bits := Util.twosCompliment(bits);
        };
        Util.invariableLengthBytesEncode(buffer, bits);
      };
    };
  };
};
