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
