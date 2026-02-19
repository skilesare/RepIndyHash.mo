import lib ".";

persistent actor{

  let x = 1;

  public shared func test() : async [Nat8]{

    lib.hash_val(#Text("test"));
  };


};