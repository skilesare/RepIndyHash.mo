
import Sha256 "mo:sha2/Sha256";
import Text "mo:core/Text";
import Array "mo:core/Array";
import Nat8 "mo:core/Nat8";
import Blob "mo:core/Blob";
import Int "mo:core/Int";
import Iter "mo:core/Iter";
import List "mo:core/List";
import Leb128 "mo:leb128";

module {
  /// The Type used to express ICRC3 values
  public type Value = { 
    #Blob : Blob; 
    #Text : Text; 
    #Nat : Nat;
    #Int : Int;
    #Array : [Value]; 
    #Map : [(Text, Value)]; 
  };

  // Also see https://github.com/dfinity/ic-hs/blob/master/src/IC/HTTP/RequestId.hs

  ///Creates the represntatinally independent hash of a Value
  public func hash_val(v : Value) : [Nat8] {
    encode_val(v) |> Sha256.fromArray(#sha256, _) |> Blob.toArray _
  };

  func encode_val(v : Value) : [Nat8] {
    switch (v) {
      case (#Blob(b))   { Blob.toArray(b) };
      case (#Text(t)) { Blob.toArray(Text.encodeUtf8(t)) };
      case (#Nat(n))    { leb128(n) };
      case (#Int(i))    { sleb128(i) };
      case (#Array(a))  { arrayConcat(Iter.map(a.vals(), hash_val)); };
      case (#Map(m))    {
        let entries = List.empty<Blob>();
        for((k, val) in m.vals()) {
            List.add(entries, Blob.fromArray(arrayConcat([ hash_val(#Text(k)), hash_val(val) ].vals())));
        };
        List.sortInPlace(entries, Blob.compare); 
        arrayConcat(Iter.map(List.toArray(entries).vals(), Blob.toArray));
      }
    }
  };

  func leb128(nat : Nat) : [Nat8] {
    Leb128.toUnsignedBytes(nat)
  };

  func sleb128(i : Int) : [Nat8] {
    Leb128.toSignedBytes(i)
  };

  func h(b1 : Blob) : Blob {
    Sha256.fromBlob(#sha256, b1);
  };

  // Array concat
  func arrayConcat<X>(as : Iter.Iter<[X]>) : [X] {
    let buf = List.empty<X>();
    for(thisItem in as){
      List.addAll(buf, thisItem.vals());
    };
    List.toArray(buf);
  };
};
