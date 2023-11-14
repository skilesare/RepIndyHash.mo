import ReIndy "../src";
import Blob "mo:base/Blob";
import D "mo:base/Debug";
import Array "mo:base/Array";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Hex "mo:encoding/Hex";



//works with simple object
D.print(debug_show(ReIndy.hash_val(#Map([
    ("name", #Text("foo")),
    ("message", #Text("Hello World!")),
    ("answer", #Nat(42))
  ]))));

let #ok(hello_world_foo) = Hex.decode("b0c6f9191e37dceafdfc47fbfc7e9cc95f21c7b985c2f7ba5855015c2a8f13ac");

assert Blob.fromArray(ReIndy.hash_val(#Map([
    ("name", #Text("foo")),
    ("message", #Text("Hello World!")),
    ("answer", #Nat(42))
  ]))) == Blob.fromArray(hello_world_foo);

  //works with double key
let #ok(double_name) = Hex.decode("435f77c9bdeca5dba4a4b8a34e4f732b4311f1fc252ec6d4e8ee475234b170f9");

assert Blob.fromArray(ReIndy.hash_val(#Map([
    ("name", #Text("foo")),
    ("name", #Text("bar")),
    ("message", #Text("Hello World!"))
  ]))) == Blob.fromArray(double_name);


  //independent of order
assert Blob.fromArray(ReIndy.hash_val(#Map([
    ("name", #Text("foo")),
    ("name", #Text("bar")),
    ("message", #Text("Hello World!"))
  ]))) == Blob.fromArray(ReIndy.hash_val(#Map([
    ("name", #Text("foo")),
    
    ("message", #Text("Hello World!")),
    ("name", #Text("bar")),
  ])));

   //works with blobs
   let #ok(blob) = Hex.decode("546729666d96a712bd94f902a0388e33f9a19a335c35bc3d95b0221a4a574455");

   D.print(debug_show(ReIndy.hash_val(#Map([
    ("bytes", #Blob(Blob.fromArray([1,2,3,4])))
  ]))));

   D.print(debug_show(blob));
assert Blob.fromArray(ReIndy.hash_val(#Map([
    ("bytes", #Blob(Blob.fromArray([1,2,3,4])))
  ]))) == Blob.fromArray(blob);

  let #ok(test_nat) = Hex.decode("684888c0ebb17f374298b65ee2807526c066094c701bcc7ebbe1c1095f494fc1");

  assert Blob.fromArray(ReIndy.hash_val(#Nat(42))) == Blob.fromArray(test_nat);

  let #ok(test_int) = Hex.decode("de5a6f78116eca62d7fc5ce159d23ae6b889b365a1739ad2cf36f925a140d0cc");

  D.print(debug_show(test_int, ReIndy.hash_val(#Int(-42))));

  assert Blob.fromArray(ReIndy.hash_val(#Int(-42))) == Blob.fromArray(test_int);

  let #ok(test_text) = Hex.decode("dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f");

  assert Blob.fromArray(ReIndy.hash_val(#Text("Hello, World!"))) == Blob.fromArray(test_text);

  let #ok(test_blob) = Hex.decode("9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a");

  assert Blob.fromArray(ReIndy.hash_val(#Blob(Blob.fromArray([1,2,3,4])))) == Blob.fromArray(test_blob);

  //let #ok(test_array) = Hex.decode("9f64a747e1b97f131fabb6b447296c9b6f0201e79fb3c5356e6c77e89b6a806a");

  //assert Blob.fromArray(ReIndy.hash_val(#Text("Hello, World!"))) == Blob.fromArray(test_text);

  let #ok(test_Map) = Hex.decode("c56ece650e1de4269c5bdeff7875949e3e2033f85b2d193c2ff4f7f78bdcfc75");

  D.print(debug_show(test_Map, ReIndy.hash_val(#Map([
    ("from", #Blob(Blob.fromArray([0,171,205,239,0,18,52,0,86,120,154,0,188,222,240,0,1,35,69,103,137,0,171,205,239,1]))),
    ("to",   #Blob(Blob.fromArray([0,171, 13,239,0,18,52,0,86,120,154,0,188,222,240,0,1,35,69,103,137,0,171,205,239,1]))),
    ("amount", #Nat(42)),
    ("created_at", #Nat(1699218263)),
    ("memo", #Nat(0))

  ]))));

  assert Blob.fromArray(ReIndy.hash_val(#Map([
    ("from", #Blob(Blob.fromArray([0,171,205,239,0,18,52,0,86,120,154,0,188,222,240,0,1,35,69,103,137,0,171,205,239,1]))),
    ("to",   #Blob(Blob.fromArray([0,171, 13,239,0,18,52,0,86,120,154,0,188,222,240,0,1,35,69,103,137,0,171,205,239,1]))),
    ("amount", #Nat(42)),
    ("created_at", #Nat(1699218263)),
    ("memo", #Nat(0))

  ]))) == Blob.fromArray(test_Map);

  

  /* input: Map([("from", Blob(b'\x00\xab\xcd\xef\x00\x12\x34\x00\x56\x78\x9a\x00\xbc\xde\xf0\x00\x01\x23\x45\x67\x89\x00\xab\xcd\xef\x01')),
            ("to",        Blob(b'\x00\xab\x0d\xef\x00\x12\x34\x00\x56\x78\x9a\x00\xbc\xde\xf0\x00\x01\x23\x45\x67\x89\x00\xab\xcd\xef\x01')),
            ("amount", Nat(42)),
            ("created_at", Nat(1699218263)),
            ("memo", Nat(0))
    ]) */


