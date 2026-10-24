// ICRC-3 value-hash oracle.
//
// For every case it computes:
//   spec : a direct transcription of ICRC-3 HASHINGVALUES.md with shortest-form
//          LEB128 / SLEB128 (IC interface spec "hash of map"), on arbitrary
//          precision integers. SLEB128 is cross-checked against the gimli
//          `leb128` crate for every value that fits in i64.
//   rust : DFINITY `icrc-ledger-types` (crates.io) `Value::hash`, or a reason
//          why that implementation cannot hash the case.
//
// Output (stdout):
//   default    TSV  label \t spec_hex \t rust_hex|NA:reason \t enc_hex \t motoko_literal
//   --motoko   the Motoko module test/icrc3_vectors.mo
//   FUZZ=<seed> 4000 random values instead of the fixed case list
//
// Regenerate the committed vectors:  cd test/oracle && cargo run --release -- --motoko > ../icrc3_vectors.mo
use candid::{Int as CInt, Nat as CNat};
use icrc_ledger_types::icrc::generic_value::Value as RV;
use num_bigint::{BigInt, BigUint, Sign};
use num_integer::Integer;
use num_traits::{ToPrimitive, Zero};
use sha2::{Digest, Sha256};
use std::collections::BTreeMap;

#[derive(Clone)]
enum V {
    Blob(Vec<u8>),
    Text(String),
    Nat(BigUint),
    Int(BigInt),
    Array(Vec<V>),
    Map(Vec<(String, V)>),
}

fn uleb(n: &BigUint) -> Vec<u8> {
    let mut out = vec![];
    let mut n = n.clone();
    let b128 = BigUint::from(128u32);
    loop {
        let (q, r) = n.div_rem(&b128);
        let byte = r.to_u8().unwrap();
        if q.is_zero() {
            out.push(byte);
            return out;
        }
        out.push(byte | 0x80);
        n = q;
    }
}

fn sleb(i: &BigInt) -> Vec<u8> {
    let mut out = vec![];
    let mut n = i.clone();
    let b128 = BigInt::from(128);
    loop {
        // floor division / modulo: low 7 bits of two's complement, arithmetic shift
        let (q, r) = n.div_mod_floor(&b128);
        let byte = r.to_u8().unwrap();
        let sign_bit = byte & 0x40 != 0;
        if (q.is_zero() && !sign_bit) || (q == BigInt::from(-1) && sign_bit) {
            out.push(byte);
            break;
        }
        out.push(byte | 0x80);
        n = q;
    }
    if let Some(x) = i.to_i64() {
        let mut g = vec![];
        leb128::write::signed(&mut g, x).unwrap();
        assert_eq!(g, out, "sleb disagrees with gimli leb128 for {x}");
    }
    out
}

fn enc(v: &V) -> Vec<u8> {
    match v {
        V::Blob(b) => b.clone(),
        V::Text(t) => t.as_bytes().to_vec(),
        V::Nat(n) => uleb(n),
        V::Int(i) => sleb(i),
        V::Array(a) => a.iter().flat_map(|x| spec_hash(x)).collect(),
        V::Map(m) => {
            let mut hs: Vec<([u8; 32], [u8; 32])> = m
                .iter()
                .map(|(k, x)| (Sha256::digest(k.as_bytes()).into(), spec_hash(x)))
                .collect();
            hs.sort();
            hs.iter().flat_map(|(a, b)| a.iter().chain(b.iter()).copied().collect::<Vec<_>>()).collect()
        }
    }
}

fn spec_hash(v: &V) -> [u8; 32] {
    Sha256::digest(enc(v)).into()
}

fn to_rust(v: &V) -> Result<RV, String> {
    Ok(match v {
        V::Blob(b) => RV::Blob(serde_bytes::ByteBuf::from(b.clone())),
        V::Text(t) => RV::Text(t.clone()),
        V::Nat(n) => RV::Nat(CNat(n.clone())),
        V::Int(i) => {
            if i.to_i128().is_none() {
                return Err("Int outside i128 (icrc-ledger-types panics)".into());
            }
            RV::Int(CInt(i.clone()))
        }
        V::Array(a) => RV::Array(a.iter().map(to_rust).collect::<Result<_, _>>()?),
        V::Map(m) => {
            let mut bm = BTreeMap::new();
            for (k, x) in m {
                if bm.insert(k.clone(), to_rust(x)?).is_some() {
                    return Err("duplicate map key (BTreeMap cannot represent)".into());
                }
            }
            RV::Map(bm)
        }
    })
}

fn mo_text(s: &str) -> String {
    let mut o = String::from("\"");
    for c in s.chars() {
        match c {
            '"' => o.push_str("\\\""),
            '\\' => o.push_str("\\\\"),
            ' '..='~' => o.push(c),
            _ => o.push_str(&format!("\\u{{{:x}}}", c as u32)),
        }
    }
    o.push('"');
    o
}

fn mo_blob(b: &[u8]) -> String {
    let mut o = String::from("\"");
    for x in b {
        o.push_str(&format!("\\{:02x}", x));
    }
    o.push('"');
    o
}

fn mo(v: &V) -> String {
    match v {
        V::Blob(b) => format!("#Blob({})", mo_blob(b)),
        V::Text(t) => format!("#Text({})", mo_text(t)),
        V::Nat(n) => format!("#Nat({})", n),
        V::Int(i) => {
            if i.sign() == Sign::Minus {
                format!("#Int({})", i)
            } else {
                format!("#Int(+{})", i)
            }
        }
        V::Array(a) => format!("#Array([{}])", a.iter().map(mo).collect::<Vec<_>>().join(", ")),
        V::Map(m) => format!(
            "#Map([{}])",
            m.iter().map(|(k, x)| format!("({}, {})", mo_text(k), mo(x))).collect::<Vec<_>>().join(", ")
        ),
    }
}

fn nat<T: Into<BigUint>>(x: T) -> V {
    V::Nat(x.into())
}
fn int<T: Into<BigInt>>(x: T) -> V {
    V::Int(x.into())
}
fn p2(k: u32) -> BigInt {
    BigInt::from(1) << k
}
fn text(s: &str) -> V {
    V::Text(s.into())
}
fn blob(b: &[u8]) -> V {
    V::Blob(b.to_vec())
}
fn map(kv: Vec<(&str, V)>) -> V {
    V::Map(kv.into_iter().map(|(k, v)| (k.to_string(), v)).collect())
}


struct Rng(u64);
impl Rng {
    fn next(&mut self) -> u64 { let mut x = self.0; x ^= x << 13; x ^= x >> 7; x ^= x << 17; self.0 = x; x }
    fn below(&mut self, n: u64) -> u64 { self.next() % n }
}
fn rand_big(r: &mut Rng) -> BigUint {
    let bits = match r.below(4) { 0 => r.below(8), 1 => r.below(70), 2 => r.below(140), _ => r.below(400) } as u32;
    let mut n = BigUint::from(0u32);
    for _ in 0..(bits / 32 + 1) { n = (n << 32u32) + BigUint::from(r.next() as u32); }
    let n = n % (BigUint::from(1u32) << bits.max(1));
    // bias towards 2^k boundaries
    match r.below(5) { 0 => BigUint::from(1u32) << bits, 1 => (BigUint::from(1u32) << bits) - 1u32, _ => n }
}
fn rand_val(r: &mut Rng, depth: u32) -> V {
    let k = if depth == 0 { r.below(4) } else { r.below(6) };
    match k {
        0 => V::Nat(rand_big(r)),
        1 => { let m = BigInt::from(rand_big(r)); V::Int(if r.below(2) == 0 { -m } else { m }) }
        2 => { let n = r.below(40) as usize; V::Text((0..n).map(|_| { let c = r.below(0x11000) as u32; char::from_u32(c).unwrap_or('x') }).collect()) }
        3 => { let n = r.below(80) as usize; V::Blob((0..n).map(|_| r.next() as u8).collect()) }
        4 => { let n = r.below(5) as usize; V::Array((0..n).map(|_| rand_val(r, depth - 1)).collect()) }
        _ => { let n = r.below(5) as usize; V::Map((0..n).map(|_| (["a","b","tx","phash","",&*format!("k{}", r.below(3))][r.below(6) as usize].to_string(), rand_val(r, depth - 1))).collect()) }
    }
}

fn cases() -> Vec<(String, V)> {
    let mut c: Vec<(String, V)> = vec![];
    let mut add = |l: String, v: V| c.push((l, v));

    // ---- Nat ----
    for n in 0u32..=300 {
        add(format!("Nat {n}"), nat(n));
    }
    for k in [7u32, 8, 14, 21, 28, 31, 32, 35, 49, 56, 63, 64, 70, 127, 128, 200, 256, 300] {
        let p = BigUint::from(1u32) << k;
        add(format!("Nat 2^{k}-1"), V::Nat(&p - 1u32));
        add(format!("Nat 2^{k}"), V::Nat(p.clone()));
        add(format!("Nat 2^{k}+1"), V::Nat(&p + 1u32));
    }
    add("Nat 624485".into(), nat(624485u32));
    add("Nat 1677770607672807382".into(), nat(1677770607672807382u64));
    add("Nat 1699218263".into(), nat(1699218263u64));
    add("Nat 10^30".into(), V::Nat(BigUint::from(10u32).pow(30)));
    add("Nat 10^100".into(), V::Nat(BigUint::from(10u32).pow(100)));

    // ---- Int ----
    for i in -300i32..=300 {
        add(format!("Int {i}"), int(i));
    }
    for k in 1u32..=140 {
        let p = p2(k);
        for (d, dl) in [(-1i32, "-1"), (0, ""), (1, "+1")] {
            let x: BigInt = &p + BigInt::from(d);
            add(format!("Int 2^{k}{dl}"), V::Int(x.clone()));
            add(format!("Int -(2^{k}{dl})"), V::Int(-x));
        }
    }
    add("Int -123456".into(), int(-123456));
    add("Int -10^30".into(), V::Int(-BigInt::from(10).pow(30)));
    add("Int -10^100".into(), V::Int(-BigInt::from(10).pow(100)));
    add("Int 10^100".into(), V::Int(BigInt::from(10).pow(100)));
    add("Int -2^200".into(), V::Int(-p2(200)));
    add("Int -(2^300+12345)".into(), V::Int(-(p2(300) + BigInt::from(12345))));

    // ---- Text ----
    for t in [
        "",
        "a",
        "Hello, World!",
        "\u{e9}\u{6f22}\u{5b57}\u{1f36c}",
        "e\u{301}",
        "\u{0}",
        "a\u{0}b",
        "\u{7f}\u{80}\u{7ff}\u{800}\u{ffff}\u{10000}\u{10ffff}",
        "name",
        "\"quoted\\",
    ] {
        add(format!("Text {:?}", t), text(t));
    }
    add("Text 1000 x 'ab\u{e9}'".into(), V::Text("ab\u{e9}".repeat(1000)));

    // ---- Blob ----
    for len in [0usize, 1, 2, 31, 32, 33, 55, 56, 63, 64, 65, 127, 128, 255, 256, 4096, 16384] {
        let b: Vec<u8> = (0..len).map(|i| ((i * 37 + 11) % 256) as u8).collect();
        add(format!("Blob len {len}"), V::Blob(b));
    }
    for b in [0u8, 1, 0x7f, 0x80, 0xff] {
        add(format!("Blob [{b:#04x}]"), blob(&[b]));
    }
    add("Blob 01020304".into(), blob(&[1, 2, 3, 4]));

    // ---- Array ----
    add("Array []".into(), V::Array(vec![]));
    add("Array [Nat 0]".into(), V::Array(vec![nat(0u32)]));
    add(
        "Array spec [Nat 3, Text foo, Blob 0506]".into(),
        V::Array(vec![nat(3u32), text("foo"), blob(&[5, 6])]),
    );
    add("Array [[[]]]".into(), V::Array(vec![V::Array(vec![V::Array(vec![])])]));
    add("Array [[[Int -64]]]".into(), V::Array(vec![V::Array(vec![V::Array(vec![int(-64)])])]));
    add("Array [Int 64]".into(), V::Array(vec![int(64)]));
    add(
        "Array mixed".into(),
        V::Array(vec![
            nat(1u32),
            int(-1),
            text("x"),
            blob(&[0xff]),
            V::Array(vec![]),
            V::Map(vec![]),
            map(vec![("k", int(-8192))]),
        ]),
    );
    add("Array 100 Nats".into(), V::Array((0u32..100).map(nat).collect()));
    add("Array order [1,2]".into(), V::Array(vec![nat(1u32), nat(2u32)]));
    add("Array order [2,1]".into(), V::Array(vec![nat(2u32), nat(1u32)]));

    // ---- Map ----
    add("Map []".into(), V::Map(vec![]));
    add("Map {a: Nat 1}".into(), map(vec![("a", nat(1u32))]));
    add("Map {\"\": Text \"\"}".into(), map(vec![("", text(""))]));
    let k1 = vec![0x00u8, 0xab, 0xcd, 0xef, 0x00, 0x12, 0x34, 0x00, 0x56, 0x78, 0x9a, 0x00, 0xbc, 0xde, 0xf0, 0x00, 0x01, 0x23, 0x45, 0x67, 0x89, 0x00, 0xab, 0xcd, 0xef, 0x01];
    let mut k2 = k1.clone();
    k2[2] = 0x0d;
    add(
        "Map spec icrc1 tx".into(),
        map(vec![
            ("from", V::Blob(k1.clone())),
            ("to", V::Blob(k2.clone())),
            ("amount", nat(42u32)),
            ("created_at", nat(1699218263u64)),
            ("memo", nat(0u32)),
        ]),
    );
    add(
        "Map interface-spec request".into(),
        map(vec![
            ("request_type", text("call")),
            ("canister_id", blob(b"\x00\x00\x00\x00\x00\x00\x04\xD2")),
            ("method_name", text("hello")),
            ("arg", blob(b"DIDL\x00\xFD*")),
        ]),
    );
    add(
        "Map hello world".into(),
        map(vec![("name", text("foo")), ("message", text("Hello World!")), ("answer", nat(42u32))]),
    );
    add(
        "Map hello world permuted".into(),
        map(vec![("answer", nat(42u32)), ("name", text("foo")), ("message", text("Hello World!"))]),
    );
    add(
        "Map unsorted keys".into(),
        map(vec![("z", nat(1u32)), ("a", nat(2u32)), ("m", int(-3))]),
    );
    add(
        "Map nested".into(),
        map(vec![
            ("outer", map(vec![("inner", map(vec![("x", int(-64)), ("y", int(64))]))])),
            ("list", V::Array(vec![map(vec![]), map(vec![("a", blob(&[]))])])),
        ]),
    );
    add(
        "Map icrc3 block 1xfer".into(),
        map(vec![
            ("btype", text("1xfer")),
            ("ts", nat(1_700_000_000_000_000_000u64)),
            ("phash", V::Blob((0u8..32).collect())),
            (
                "tx",
                map(vec![
                    ("amt", nat(100u32)),
                    ("from", V::Array(vec![blob(&[0xaa])])),
                    ("to", V::Array(vec![blob(&[0xbb]), blob(&[0xcc])])),
                    ("fee", nat(10_000u32)),
                ]),
            ),
        ]),
    );
    add(
        "Map block with Int -64 / 64 / -8192 / 8192".into(),
        map(vec![
            ("btype", text("x")),
            ("a", int(-64)),
            ("b", int(64)),
            ("c", int(-8192)),
            ("d", int(8192)),
            ("e", int(-65)),
        ]),
    );
    add(
        "Map dup keys (name foo/bar)".into(),
        map(vec![("name", text("foo")), ("name", text("bar")), ("message", text("Hello World!"))]),
    );
    add(
        "Map dup keys (name bar/foo)".into(),
        map(vec![("name", text("bar")), ("name", text("foo")), ("message", text("Hello World!"))]),
    );
    add("Map dup identical entries".into(), map(vec![("k", nat(1u32)), ("k", nat(1u32))]));
    add(
        "Map 50 keys".into(),
        V::Map((0..50).map(|i| (format!("key{i}"), int(i * -13))).collect()),
    );
    c
}

fn main() {
    let motoko = std::env::args().any(|a| a == "--motoko");
    let all: Vec<(String, V)> = match std::env::var("FUZZ") {
        Ok(seed) => {
            let mut r = Rng(seed.parse::<u64>().unwrap() | 1);
            (0..4000).map(|i| (format!("fuzz {i}"), rand_val(&mut r, 3))).collect()
        }
        Err(_) => cases(),
    };
    if motoko {
        println!("// GENERATED by test/oracle (`cargo run --release -- --motoko > ../icrc3_vectors.mo`). Do not edit.");
        println!("// Expected hashes follow ICRC-3 HASHINGVALUES.md with shortest-form LEB128/SLEB128 (IC interface spec).");
        println!("// Where DFINITY icrc-ledger-types 0.2.0 `Value::hash` disagrees, or cannot hash the value, a comment says so.");
        println!("module {{");
        println!("  public type Value = {{ #Blob : Blob; #Text : Text; #Nat : Nat; #Int : Int; #Array : [Value]; #Map : [(Text, Value)] }};");
        println!("  public let cases : [(Text, Value, Text)] = [");
    }
    for (label, v) in all {
        let spec = hex::encode(spec_hash(&v));
        let rust = match to_rust(&v) {
            Ok(r) => match std::panic::catch_unwind(|| r.hash()) {
                Ok(h) => hex::encode(h),
                Err(_) => "NA:panic".into(),
            },
            Err(e) => format!("NA:{e}"),
        };
        if motoko {
            if let Some(why) = rust.strip_prefix("NA:") {
                println!("    // icrc-ledger-types: not hashable ({why})");
            } else if rust != spec {
                println!("    // icrc-ledger-types: {rust} (it hashes Int >= 0 as unsigned LEB128)");
            }
            println!("    ({}, {}, \"{}\"),", mo_text(&label), mo(&v), spec);
        } else {
            let e = match &v {
                V::Nat(_) | V::Int(_) => hex::encode(enc(&v)),
                _ => "-".into(),
            };
            println!("{}\t{}\t{}\t{}\t{}", label, spec, rust, e, mo(&v));
        }
    }
    if motoko {
        println!("  ];");
        println!("}}");
    }
}
