import lib ".";

persistent actor {


  public shared func test() : async [Nat8]{

    lib.hash_val(#Text("test"));
  };


};