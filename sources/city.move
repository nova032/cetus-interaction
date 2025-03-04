/// Module: vendetta
module vcetus::city;

use std::{
    string::{Self, String},
};
use sui::{
    coin::{Self, Coin, TreasuryCap, CoinMetadata},
};

public struct CoinCityRegistry has key, store {
    id: UID,
    treasury: TreasuryCap<CITY>,
}

public struct CITY has drop {}

fun init(witness: CITY, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(
        witness, 
        9, 
        b"TEST A", 
        b"Token a", 
        b"token", 
        option::none(), 
        ctx
    );
    transfer::public_freeze_object(metadata);
    let coin_registry = CoinCityRegistry { id: object::new(ctx), treasury };
    transfer::public_share_object(coin_registry);
}

public fun mint( 
    coin_registry: &mut CoinCityRegistry,
    amount: u64,
    ctx: &mut TxContext
) : Coin<CITY> {
    let coin = coin::mint(&mut coin_registry.treasury, amount, ctx);
    coin
}

// === Metadata APIs ===

/// update metadata coin name
/// @AdminCap: admin capability 
/// @name: new coin coin name
/// @CoinRegistry: shared object that has treasury cap
/// @CoinMetadata: metadata of coin for update
// public fun update_name(
//     name: String,
//     coin_registry: &CoinRegistry,
//     metadata: &mut CoinMetadata<CITY>,
// ){
//     let cap = &coin_registry.treasury;
//     cap.update_name(metadata, name);
// }

/// update metadata description
/// @AdminCap: admin capability 
/// @description: new coin description
/// @CoinRegistry: shared object that has treasury cap
/// @CoinMetadata: metadata of coin for update
// public fun update_description(
//     description: String,
//     coin_registry: &CoinRegistry,
//     metadata: &mut CoinMetadata<CITY>,
// ){
//     let cap = &coin_registry.treasury;
//     cap.update_description(metadata, description);
// }

/// update metadata icon url
/// @AdminCap: admin capability 
/// @URL: new coin icon url
/// @CoinRegistry: shared object that has treasury cap
/// @CoinMetadata: metadata of coin for update

// public fun update_icon_url(
//     url: String,
//     coin_registry: &CoinRegistry,
//     metadata: &mut CoinMetadata<CITY>,
// ){
//     let cap = &coin_registry.treasury;
//     cap.update_icon_url(metadata, string::to_ascii(url));
// }

// // === Package functions
// public(package) fun borrow_treasury_cap(
//     coin_registry: &mut CoinRegistry
// ): &mut TreasuryCap<CITY>{
//     &mut coin_registry.treasury
// }

// === Public View Functions ===
public fun total_supply(
    self: &TreasuryCap<CITY>
): u64 {
    self.total_supply()
}


    
#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init( CITY{}, ctx);
}
