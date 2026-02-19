
import ReIndy "../src/lib";
import Blob "mo:core/Blob";
import Debug "mo:core/Debug";
import Runtime "mo:core/Runtime";
import Array "mo:core/Array";
import Int "mo:core/Int";
import Text "mo:core/Text";
import List "mo:core/List";
import Char "mo:core/Char";
import Nat8 "mo:core/Nat8";
import Nat32 "mo:core/Nat32";
import Test "mo:test";

func hexVal(c : Char) : Nat8 {
    if (c >= '0' and c <= '9') return Nat8.fromNat32(Char.toNat32(c) - Char.toNat32('0'));
    if (c >= 'a' and c <= 'f') return Nat8.fromNat32(Char.toNat32(c) - Char.toNat32('a') + 10);
    if (c >= 'A' and c <= 'F') return Nat8.fromNat32(Char.toNat32(c) - Char.toNat32('A') + 10);
    Runtime.trap("Invalid hex char: " # debug_show(c));
    0
};

func fromHex(t : Text) : Blob {
    let iter = t.chars();
    let buffer = List.empty<Nat8>();
    
    label l while (true) {
        switch(iter.next()) {
            case(null) { break l; };
            case(?c1) {
                switch(iter.next()) {
                    case(null) { Runtime.trap("Odd length hex string"); };
                    case(?c2) {
                            List.add(buffer, hexVal(c1) * 16 + hexVal(c2));
                    };
                };
            };
        };
    };
    Blob.fromArray(List.toArray(buffer))
};

Test.test("simple object", func() {
    let val : ReIndy.Value = #Map([
        ("name", #Text("foo")),
        ("answer", #Nat(42)),
        ("message", #Text("Hello World!"))
    ]);

    // calculated via independent implementation or verified correct
    let expectedHex = "b0c6f9191e37dceafdfc47fbfc7e9cc95f21c7b985c2f7ba5855015c2a8f13ac";
    
    let result = Blob.fromArray(ReIndy.hash_val(val));
    Test.expect.blob(result).equal(fromHex(expectedHex));
});

Test.test("double key (not possible in Map but checking sort)", func() {
    // Technically Map keys must be unique but implementation allows dups if they exist, 
    // sorting them deterministically.
    let val : ReIndy.Value = #Map([
        ("name", #Text("foo")),
        ("name", #Text("bar")),
        ("message", #Text("Hello World!"))
    ]);
    let expectedHex = "435f77c9bdeca5dba4a4b8a34e4f732b4311f1fc252ec6d4e8ee475234b170f9";

    let result = Blob.fromArray(ReIndy.hash_val(val));
    Test.expect.blob(result).equal(fromHex(expectedHex));
});

Test.test("independent of order", func() {
        let val1 : ReIndy.Value = #Map([
        ("name", #Text("foo")),
        ("message", #Text("Hello World!")),
        ("answer", #Nat(42))
    ]);
    
        let val2 : ReIndy.Value = #Map([
        ("answer", #Nat(42)),
        ("name", #Text("foo")),
        ("message", #Text("Hello World!"))
    ]);

    let res1 = Blob.fromArray(ReIndy.hash_val(val1));
    let res2 = Blob.fromArray(ReIndy.hash_val(val2));
    
    Test.expect.blob(res1).equal(res2);
});

Test.test("blobs", func() {
    // Testing blob hash (should be sha256(blob))
        let val : ReIndy.Value = #Blob(Blob.fromArray([1, 2, 3]));
        // SHA256([1,2,3]) = 039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81
        let expectedHex = "039058c6f2c0cb492c533b0a4d14ef77cc0f78abccced5287d84a1a2011cfb81";
        
        let result = Blob.fromArray(ReIndy.hash_val(val));
        Test.expect.blob(result).equal(fromHex(expectedHex));
});

Test.test("ICRC-3 vectors: Nat(42)", func() {
    let val : ReIndy.Value = #Nat(42);
    let expected = fromHex("684888c0ebb17f374298b65ee2807526c066094c701bcc7ebbe1c1095f494fc1");
    let result = Blob.fromArray(ReIndy.hash_val(val));
    Test.expect.blob(result).equal(expected);
});

Test.test("ICRC-3 vectors: Int(-42)", func() {
    let val : ReIndy.Value = #Int(-42);
    let expected = fromHex("de5a6f78116eca62d7fc5ce159d23ae6b889b365a1739ad2cf36f925a140d0cc");
    let result = Blob.fromArray(ReIndy.hash_val(val));
    Test.expect.blob(result).equal(expected);
});

Test.test("ICRC-3 vectors: Text('Hello, World!')", func() {
    let val : ReIndy.Value = #Text("Hello, World!");
    let expected = fromHex("dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f");
    let result = Blob.fromArray(ReIndy.hash_val(val));
    Test.expect.blob(result).equal(expected);
});

Test.test("ICRC-3 vectors: Blob(1,2,3,4)", func() {
    let val : ReIndy.Value = #Blob(Blob.fromArray([1, 2, 3, 4]));
    let expected = fromHex("9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a");
    let result = Blob.fromArray(ReIndy.hash_val(val));
    Test.expect.blob(result).equal(expected);
});

Test.test("ICRC-3 vectors: Array", func() {
    let val : ReIndy.Value = #Array([
        #Nat(3),
        #Text("foo"),
        #Blob(fromHex("0506"))
    ]);
    let expected = fromHex("514a04011caa503990d446b7dec5d79e19c221ae607fb08b2848c67734d468d6");
    let result = Blob.fromArray(ReIndy.hash_val(val));
    Test.expect.blob(result).equal(expected);
});

Test.test("ICRC-3 vectors: Map", func() {
    // Map([
    //   ("from", Blob(b'\x00\xab\xcd\xef\x00\x12\x34\x00\x56\x78\x9a\x00\xbc\xde\xf0\x00\x01\x23\x45\x67\x89\x00\xab\xcd\xef\x01')),
    //   ("to", Blob(b'\x00\xab\x0d\xef\x00\x12\x34\x00\x56\x78\x9a\x00\xbc\xde\xf0\x00\x01\x23\x45\x67\x89\x00\xab\xcd\xef\x01')),
    //   ("amount", Nat(42)),
    //   ("created_at", Nat(1699218263)),
    //   ("memo", Nat(0))
    // ])

    let fromBlob = fromHex("00abcdef0012340056789a00bcdef000012345678900abcdef01");
    let toBlob = fromHex("00ab0def0012340056789a00bcdef000012345678900abcdef01");

    let val : ReIndy.Value = #Map([
        ("from", #Blob(fromBlob)),
        ("to", #Blob(toBlob)),
        ("amount", #Nat(42)),
        ("created_at", #Nat(1699218263)),
        ("memo", #Nat(0))
    ]);
    
    let expected = fromHex("c56ece650e1de4269c5bdeff7875949e3e2033f85b2d193c2ff4f7f78bdcfc75");
    let result = Blob.fromArray(ReIndy.hash_val(val));
    Test.expect.blob(result).equal(expected);
});

Test.test("Response Verification: Arrays", func() {
    // ["a"]
    let val1 : ReIndy.Value = #Array([#Text("a")]);
    let expected1 = fromHex("bf5d3affb73efd2ec6c36ad3112dd933efed63c4e1cbffcfa88e2759c144f2d8");
    let result1 = Blob.fromArray(ReIndy.hash_val(val1));
    Test.expect.blob(result1).equal(expected1);

    // ["a", "b"]
    let val2 : ReIndy.Value = #Array([#Text("a"), #Text("b")]);
    let expected2 = fromHex("e5a01fee14e0ed5c48714f22180f25ad8365b53f9779f79dc4a3d7e93963f94a");
    let result2 = Blob.fromArray(ReIndy.hash_val(val2));
    Test.expect.blob(result2).equal(expected2);

    // [["a"]]
    let val3 : ReIndy.Value = #Array([#Array([#Text("a")])]);
    let expected3 = fromHex("eb48bdfa15fc43dbea3aabb1ee847b6e69232c0f0d9705935e50d60cce77877f");
    let result3 = Blob.fromArray(ReIndy.hash_val(val3));
    Test.expect.blob(result3).equal(expected3);

    // [["a", "b"]]  (hash_array_reference_5)
    let val4 : ReIndy.Value = #Array([#Array([#Text("a"), #Text("b")])]);
    let expected4 = fromHex("029fd80ca2dd66e7c527428fc148e812a9d99a5e41483f28892ef9013eee4a19");
    let result4 = Blob.fromArray(ReIndy.hash_val(val4));
    Test.expect.blob(result4).equal(expected4);
});

Test.test("Response Verification: Mixed Array (Blob vs Text)", func() {
    // [Blob "a", "b"] vs ["a", "b"]
    let valMixed : ReIndy.Value = #Array([
        #Blob(Blob.fromArray([97])), // "a"
        #Text("b")
    ]);
    let expected = fromHex("e5a01fee14e0ed5c48714f22180f25ad8365b53f9779f79dc4a3d7e93963f94a"); // Same as ["a", "b"]
    let result = Blob.fromArray(ReIndy.hash_val(valMixed));
    Test.expect.blob(result).equal(expected);
});

Test.test("Response Verification: Hash Bytes", func() {
    // map with bytes key
    let val : ReIndy.Value = #Map([
        ("bytes", #Blob(Blob.fromArray([1, 2, 3, 4])))
    ]);
    let expected = fromHex("546729666d96a712bd94f902a0388e33f9a19a335c35bc3d95b0221a4a574455");
    let result = Blob.fromArray(ReIndy.hash_val(val));
    Test.expect.blob(result).equal(expected);
});

Test.test("Response Verification: Complex Nested Map", func() {
    /* 
    [
        ("key_bytes", Blob rep of [1; 10]),   // 10 bytes of 0x01
        ("key_string", "test_string"),
        ("key_u64", 42),
        ("key_inner", [
            ("key_string_2", "test_string_2")
        ]),
        ("key_array", [
             [("key_string_0", "test_string_0")],
             [("key_string_1", "test_string_1")]
        ])
    ]
    */
    let bytes10 = fromHex("01010101010101010101");

    let val : ReIndy.Value = #Map([
        ("key_bytes", #Blob(bytes10)),
        ("key_string", #Text("test_string")),
        ("key_u64", #Nat(42)),
        ("key_inner", #Map([
            ("key_string_2", #Text("test_string_2"))
        ])),
        ("key_array", #Array([
            #Map([("key_string_0", #Text("test_string_0"))]),
            #Map([("key_string_1", #Text("test_string_1"))])
        ]))
    ]);
    
    let expected = fromHex("ace3c6e84b170c6235faff2ee1152d831c332a7e3c932fb7d129f973d6913ff2");
    let result = Blob.fromArray(ReIndy.hash_val(val));
    Test.expect.blob(result).equal(expected);
});


