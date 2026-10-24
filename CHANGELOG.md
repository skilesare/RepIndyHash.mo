# 0.1.2

- No GitHub dependencies, so the package installs and builds with mops 3 without a `base-0.7.3` package alias.
- Dropped `encoding` and `array` (aviate-labs, GitHub). The library never imported them; only the test used `encoding`'s `Hex.decode`, now a small test-local helper.
- Replaced the GitHub `motoko_numbers` v1.1.0 dependency with a vendored copy of the signed-LEB128 encoder it supplied (`src/vendored/motoko_numbers_1_1_0`, MIT, see NOTICE). The function bodies are unchanged.
- `base` now comes from the Mops registry (0.16.0) instead of the `motoko-base#moc-0.10.0` GitHub tag.
- Hashes are byte-identical to 0.1.1: 6,300 test vectors (every Nat in 0..1100 and every Int in -1100..1100, +-2^k and +-(2^k+-1) for k <= 300, Text, every single-byte Blob and longer Blobs, nested Arrays and Maps) produce the same output under 0.1.1 and 0.1.2.

# v0.1.0 

Initial Release - Alpha, not validated