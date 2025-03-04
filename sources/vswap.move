
/// Module: v_swap
module vcetus::v_swap;

use sui::{
    coin::{Coin, CoinMetadata},
    clock::{Clock},
};
use vcetus::{
    city::{Self, CITY, CoinCityRegistry},
    village::{Self, VILLAGE, CoinVillageRegistry},
};
use cetus_clmm::{
    pool_creator::{Self},
    config::GlobalConfig,
    factory::Pools as CetusPools,
    position::{Position},
};

const VILLAGE_DEX_ALLOCATION: u64 = 150_000_000_000_000;
const CITY_DEX_ALLOCATION: u64 = 100_000_000_000_000; 

public struct PositionHolder<phantom T> has key {
    id: UID,
    position: Position
}

#[allow(lint(self_transfer))]
public fun create_cetus_pool_v_s(
    config: &GlobalConfig,
    cetus_pools: &mut CetusPools,
    coin_city: &mut CoinCityRegistry,
    coin_village: &mut CoinVillageRegistry,
    metadata_city: &CoinMetadata<CITY>,
    metadata_village: &CoinMetadata<VILLAGE>,
    clock: &Clock,
    ctx: &mut TxContext,
){

    // village coin allocation and city coin allocation 

    let village_coin = village::mint(coin_village, VILLAGE_DEX_ALLOCATION, ctx); 
    let city_coin = city::mint(coin_city, CITY_DEX_ALLOCATION, ctx); 

    let tick_spacing = 60; 
    let (tick_lower, tick_upper) = pool_creator::full_range_tick_range(tick_spacing);

    let city_amount =  (city_coin.value() as u128); 
    let village_amount = (VILLAGE_DEX_ALLOCATION as u128); 

    // calculate price with higher precision
    // price = (village_amount * (1u128 << 64)) / city_amount; 

    let initial_price = (city_amount * (1u128 << 64)) / village_amount; 

    let (position, remaining_coin_v, remaining_coin_c) = pool_creator::create_pool_v2<VILLAGE, CITY>(
        config, 
        cetus_pools, 
        tick_spacing,
        initial_price, 
        std::string::utf8(b"VILLAGE/SUI Pool"),
        tick_lower, 
        tick_upper,
        village_coin, 
        city_coin,
        metadata_village, // village
        metadata_city, // city
        true, 
        clock, 
        ctx
    );

    transfer::public_transfer(remaining_coin_v, tx_context::sender(ctx));
    transfer::public_transfer(remaining_coin_c, tx_context::sender(ctx));
    let position_holder = PositionHolder<CITY> {
        id: object::new(ctx),
        position, 
    };
    transfer::share_object(position_holder);
}


#[allow(lint(self_transfer))]
public fun create_cetus_pool_ab<CoinTypeA, CoinTypeB>(
    config: &GlobalConfig,
    cetus_pools: &mut CetusPools,
    coin_a: Coin<CoinTypeA>,
    coin_b: Coin<CoinTypeB>,
    metadata_a: &CoinMetadata<CoinTypeA>,
    metadata_b: &CoinMetadata<CoinTypeB>,
    fix_amount: bool,
    initial_price: u128,
    tick_spacing: u32,
    lower_tick_idx: u32,
    upper_tick_idx: u32,
    clock: &Clock,
    ctx: &mut TxContext,
){
    let (position, remaining_coin_v, remaining_coin_c) = pool_creator::create_pool_v2(
        config, 
        cetus_pools, 
        tick_spacing,
        initial_price, 
        std::string::utf8(b""),
        lower_tick_idx,
        upper_tick_idx,
        coin_a, 
        coin_b, 
        metadata_a,
        metadata_b,
        fix_amount, 
        clock, 
        ctx
    );
    transfer::public_transfer(remaining_coin_v, tx_context::sender(ctx));
    transfer::public_transfer(remaining_coin_c, tx_context::sender(ctx));
    let position_holder = PositionHolder<CoinTypeA> {
        id: object::new(ctx),
        position, 
    };
    transfer::share_object(position_holder);
}