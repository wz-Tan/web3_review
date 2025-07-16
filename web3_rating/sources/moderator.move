module web3_rating::moderator;

use sui::test_scenario::sender;
use sui::transfer;
use sui::transfer::transfer;

//Separate moderator and capabilities to shortlist people, and actually give power to some of them (VIP)
//Moderator for the entire platform, admin for services
/// Represents a moderator that can be used to delete reviews
public struct Moderator has key {
    id: UID,
}

/// A capability that can be used to perform admin operations on a service
public struct ModCap has key, store {
    id: UID,
}

//When first deployed, give yourself the moderator capabilities
fun init(ctx: &mut TxContext) {
    let mod_cap = ModCap {
        id: object_new(ctx),
    };
    transfer::transfer(mod_cap, sender(ctx))
}

//Add Moderator to Somebody 
public fun add_moderator(_:&ModCap,recipient:address,tx:&mut TxContext){
    let mod=Moderator{
        id: object_new(ctx)
    };
    transfer::transfer(mod, recipient)
}

//Delete moderator
public fun delete_moderator(mod:Moderator){
    let Moderator{
        id
    } = mod;
    object_delete(id);
}
