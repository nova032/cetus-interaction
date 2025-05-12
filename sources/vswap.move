
/// Module: v_swap
module vcetus::v_swap;

use sui::{
    coin::{Self, Coin, CoinMetadata},
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
    partner::{Partner},
    pool::{Self, Pool, FlashSwapReceipt},
    tick_math,
};

use std::type_name::{Self, TypeName};
use sui::balance;
use sui::event::emit;

const VILLAGE_DEX_ALLOCATION: u64 = 1_000_000_000_000_000;
const CITY_DEX_ALLOCATION: u64 = 30_000_000_000_000; 

const DEFAULT_PARTNER_ID: address =
    @0x8e0b7668a79592f70fbfb1ae0aebaf9e2019a7049783b9a4b6fe7c6ae038b528;

public struct PositionHolder<phantom T> has key {
    id: UID,
    position: Position
}

public struct CetusSwapEvent has copy, store, drop {
    pool: ID,
    amount_in: u64,
    amount_out: u64,
    a2b: bool,
    by_amount_in: bool,
    partner_id: ID,
    coin_a: TypeName,
    coin_b: TypeName,
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

    let city_amount =  (CITY_DEX_ALLOCATION as u128); 
    let village_amount = (VILLAGE_DEX_ALLOCATION as u128); 

    // calculate price with higher precision
    // price = (village_amount * (1u128 << 64)) / city_amount; 

  //  let initial_price = (city_amount * (1u128 << 64)) / village_amount; 


    let (position, remaining_coin_v, remaining_coin_c) = pool_creator::create_pool_v2<VILLAGE, CITY>(
        config, 
        cetus_pools, 
        tick_spacing,
        3195071000000000000, 
       // 3197336011907818496,
        std::string::utf8(b"VILLAGE/SUI Pool"),
        tick_lower, 
        tick_upper,
        village_coin, 
        city_coin,
        metadata_village, // village
        metadata_city, // city
        false, 
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

public fun swap_a2b<CoinTypeA, CoinTypeB>(
    config: &GlobalConfig,
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    partner: &mut Partner,
    coin_a: Coin<CoinTypeA>,
    clock: &Clock,
    ctx: &mut TxContext,
): Coin<CoinTypeB> {
    let amount_in = coin::value(&coin_a);
    let (receive_a, receive_b, flash_receipt, pay_amount) = flash_swap<CoinTypeA, CoinTypeB>(
        config,
        pool,
        partner,
        amount_in,
        true,
        true,
        tick_math::min_sqrt_price(),
        clock,
        ctx,
    );

    assert!(pay_amount == amount_in, 0);
    let remainer_a = repay_flash_swap_a2b<CoinTypeA, CoinTypeB>(
        config,
        pool,
        partner,
        coin_a,
        flash_receipt,
        ctx,
    );
    transfer_or_destroy_coin(remainer_a, ctx);
    coin::destroy_zero(receive_a);
    receive_b
}

public fun swap_b2a<CoinTypeA, CoinTypeB>(
    config: &GlobalConfig,
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    partner: &mut Partner,
    coin_b: Coin<CoinTypeB>,
    clock: &Clock,
    ctx: &mut TxContext,
): Coin<CoinTypeA> {
    let amount_in = coin::value(&coin_b);
    let (receive_a, receive_b, flash_receipt, pay_amount) = flash_swap<CoinTypeA, CoinTypeB>(
        config,
        pool,
        partner,
        amount_in,
        false,
        true,
        tick_math::max_sqrt_price(),
        clock,
        ctx,
    );

    assert!(pay_amount == amount_in, 0);
    coin::destroy_zero(receive_b);

    let remainer_b = repay_flash_swap_b2a<CoinTypeA, CoinTypeB>(
        config,
        pool,
        partner,
        coin_b,
        flash_receipt,
        ctx,
    );
    transfer_or_destroy_coin(remainer_b, ctx);
    receive_a
}

public fun repay_flash_swap_a2b<CoinTypeA, CoinTypeB>(
    config: &GlobalConfig,
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    partner: &mut Partner,
    coin_a: Coin<CoinTypeA>,
    receipt: FlashSwapReceipt<CoinTypeA, CoinTypeB>,
    ctx: &mut TxContext,
): Coin<CoinTypeA> {
    let coin_b = coin::zero<CoinTypeB>(ctx);
    let (repaid_coin_a, repaid_coin_b) = repay_flash_swap<CoinTypeA, CoinTypeB>(
        config,
        pool,
        partner,
        true,
        coin_a,
        coin_b,
        receipt,
        ctx,
    );
    transfer_or_destroy_coin<CoinTypeB>(repaid_coin_b, ctx);
    (repaid_coin_a)
}

public fun repay_flash_swap_b2a<CoinTypeA, CoinTypeB>(
    config: &GlobalConfig,
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    partner: &mut Partner,
    coin_b: Coin<CoinTypeB>,
    receipt: FlashSwapReceipt<CoinTypeA, CoinTypeB>,
    ctx: &mut TxContext,
): Coin<CoinTypeB> {
    let coin_a = coin::zero<CoinTypeA>(ctx);
    let (repaid_coin_a, repaid_coin_b) = repay_flash_swap<CoinTypeA, CoinTypeB>(
        config,
        pool,
        partner,
        false,
        coin_a,
        coin_b,
        receipt,
        ctx,
    );

    transfer_or_destroy_coin<CoinTypeA>(repaid_coin_a, ctx);
    (repaid_coin_b)
}


fun flash_swap<CoinTypeA, CoinTypeB>(
    config: &GlobalConfig,
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    partner: &Partner,
    amount: u64,
    a2b: bool,
    by_amount_in: bool,
    sqrt_price_limit: u128,
    clock: &Clock,
    ctx: &mut TxContext,
): (Coin<CoinTypeA>, Coin<CoinTypeB>, FlashSwapReceipt<CoinTypeA, CoinTypeB>, u64) {
    let (receive_a, receive_b, flash_receipt) = if (
        object::id_address(partner) == DEFAULT_PARTNER_ID
    ) {
        pool::flash_swap<CoinTypeA, CoinTypeB>(
            config,
            pool,
            a2b,
            by_amount_in,
            amount,
            sqrt_price_limit,
            clock,
        )
    } else {
        pool::flash_swap_with_partner<CoinTypeA, CoinTypeB>(
            config,
            pool,
            partner,
            a2b,
            by_amount_in,
            amount,
            sqrt_price_limit,
            clock,
        )
    };

    let receive_a_amount = balance::value(&receive_a);
    let receive_b_amount = balance::value(&receive_b);
    let repay_amount = pool::swap_pay_amount(&flash_receipt);

    let amount_in = if (by_amount_in) {
        amount
    } else {
        repay_amount
    };
    let amount_out = receive_a_amount + receive_b_amount;

    emit(CetusSwapEvent {
        pool: object::id(pool),
        amount_in,
        amount_out,
        a2b,
        by_amount_in,
        partner_id: object::id(partner),
        coin_a: type_name::get<CoinTypeA>(),
        coin_b: type_name::get<CoinTypeB>(),
    });

    let coin_a = coin::from_balance(receive_a, ctx);
    let coin_b = coin::from_balance(receive_b, ctx);

    (coin_a, coin_b, flash_receipt, repay_amount)
}

fun repay_flash_swap<CoinTypeA, CoinTypeB>(
    config: &GlobalConfig,
    pool: &mut Pool<CoinTypeA, CoinTypeB>,
    partner: &mut Partner,
    a2b: bool,
    coin_a: Coin<CoinTypeA>,
    coin_b: Coin<CoinTypeB>,
    receipt: FlashSwapReceipt<CoinTypeA, CoinTypeB>,
    ctx: &mut TxContext,
): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
    let repay_amount = pool::swap_pay_amount(&receipt);

    let mut coin_a = coin_a;
    let mut coin_b = coin_b;
    let (pay_coin_a, pay_coin_b) = if (a2b) {
        (coin_a.split(repay_amount, ctx).into_balance(), balance::zero<CoinTypeB>())
    } else {
        (balance::zero<CoinTypeA>(), coin_b.split(repay_amount, ctx).into_balance())
    };

    if (object::id_address(partner) == DEFAULT_PARTNER_ID) {
        pool::repay_flash_swap<CoinTypeA, CoinTypeB>(
            config,
            pool,
            pay_coin_a,
            pay_coin_b,
            receipt,
        );
    } else {
        pool::repay_flash_swap_with_partner<CoinTypeA, CoinTypeB>(
            config,
            pool,
            partner,
            pay_coin_a,
            pay_coin_b,
            receipt,
        );
    };
    (coin_a, coin_b)
}


  #[allow(lint(self_transfer))]
    public fun transfer_or_destroy_coin<CoinType>(
        coin: Coin<CoinType>,
        ctx: &TxContext
    ) {
        if (coin::value(&coin) > 0) {
            transfer::public_transfer(coin, tx_context::sender(ctx))
        } else {
            coin::destroy_zero(coin)
        }
    }
