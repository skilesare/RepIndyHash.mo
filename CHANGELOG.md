# 0.2.2

- No change to hashes. 0.2.x was checked against an independent ICRC-3 oracle (`test/oracle`, Rust) on
  1,866 fixed vectors and 4,000 random values covering every `Value` variant; all match the spec.
- Added `test/icrc3_vectors.test.mo` with the oracle-generated vectors and the oracle source to regenerate them.
- README: new "Hash compatibility" section. 0.1.0 and 0.1.1 hash some `#Int` values differently from the
  spec and from 0.2.x (0.1.1: -64, -8192, ... -2^(7k+6); 0.1.0: every negative `#Int`, `#Int(0)` and some
  non-negative ones). 0.2.0 changed those hashes without noting it. Logs hashed with 0.1.x that contain such
  values should stay on 0.1.x (0.1.2 reproduces 0.1.1).

# v0.2.1

- updated core to 2.1.0
- updated moc to 1.3.0

# v0.2.0

- more tests
- updated to core
- updated leb, sha2

# v0.1.0 

Initial Release - Alpha, not validated