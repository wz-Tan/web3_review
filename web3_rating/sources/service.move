module web3_rating::service;

use std::string::String;
use std::vector::index_of;
use sui::balance::{Self, Balance};
use sui::clock::Clock;
use sui::coin::{Self, Coin};
use sui::dynamic_field as df;
use sui::object_table::{Self, ObjectTable};
use sui::sui::SUI;
use sui::transfer::{Self, public_share_object, public_transfer};
use web3_rating::moderator::Moderator;
use web3_rating::review::{Self, Review, new_review};
use sui::coin::from_balance;

const EInvalidPermission: u64 = 1;
const ENotEnoughBalance: u64 = 2;
const ENotExists: u64 = 3;

const MAX_REVIEWERS_TO_REWARD: u64 = 10;

//Admins can control services
public struct AdminCap has key, store {
    id: UID,
    service_id: ID,
}

//Represents a service (Maybe like a freelancing site)
public struct Service has key, store {
    id: UID,
    reward_pool: Balance<SUI>,
    reward: u64,
    top_reviews: vector<ID>,
    reviews: ObjectTable<ID, Review>,
    overall_rate: u64,
    name: String,
}

//Proof of Experience (This person has written other stuff before)
public struct ProofOfExperience has key {
    id: UID,
    service_id: UID,
}

//Review Record (Review Details)
public struct ReviewRecord has drop, store {
    owner: address,
    overall_rate: u8,
    time_issued: u64,
}

#[allow(lint(self_transfer))]
public fun create_service(name: String, ctx: &mut TxContext): ID {
    let id = object::new(ctx);
    //Convert UID into ID
    let service_id = id.to_inner();
    let service = Service {
        id,
        reward_pool: balance::zero(),
        reward: 1000000,
        top_reviews: vector[],
        reviews: object_table::new(ctx),
        overall_rate: 0,
        name,
    };

    //Create Admin Capabilities For This Service
    let adminCap = AdminCap {
        id: object::new(ctx),
        service_id,
    };

    //Share the service to everyone (mutable)
    transfer::share_object(service);
    //Transfer an item from other modules (adminCap belongs to another module)
    transfer::public_transfer(adminCap, tx_context::sender(ctx));

    service_id
}

public fun write_new_review(
    service: &mut Service,
    owner: address,
    content: String,
    overall_rate: u8,
    clock: &Clock,
    poe: ProofOfExperience,
    ctx: &mut TxContext,
) {
    //ensure has experience on this service (i have used this before)
    assert!(poe.service_id==service.id.to_inner(), EInvalidPermission);

    //One person can only write one review (delete once used)
    let ProofOfExperience { id, service_id: _ } = poe;
    object::delete(id);

    let review = review::new_review(
        owner,
        service.id.to_inner(),
        content,
        true,
        overall_rate,
        clock,
        ctx,
    );
    service.add_review(review, owner, overall_rate)
}

public fun write_new_review_without_poe(
    service: &mut Service,
    owner: address,
    content: String,
    overall_rate: u8,
    clock: &Clock,
    ctx: &mut TxContext,
) {
    let review = review::new_review(
        owner,
        service.id.to_inner(),
        content,
        false,
        overall_rate,
        clock,
        ctx,
    );
    service.add_review(review, owner, overall_rate)
}

fun add_review(service: &mut Service, review: &mut Review, owner: address, overall_rate: u8) {
    let id = review.get_id();
    let total_score = review.get_total_score();
    let time_issued = reveiw.get_time_issued();
    //Add review and update the top reviews
    service.reviews.add(id, review);
    service.update_top_reviews(id, total_score);
    //Add the review record of the id into the service
    df::add(&mut service.id, id, ReviewRecord { owner, overall_rate, time_issued });

    //Improve overall rating of the service
    let overall_rate = (overall_rate as u64);
    service.overall_rate = service.overall_rate+overall_rate
}

//Condition to Update The Top Reviews
fun should_update_top_reviews(service: &mut Service, total_score: u64): bool {
    let length = service.top_reviews.length();
    length <MAX_REVIEWERS_TO_REWARD || review.get_total_score(service.top_reviews[length-1]) < total_score
}

//Delete Extra Reviews
fun prune_top_reviews(service: &mut Service) {
    while (service.top_reviews.length() > MAX_REVIEWERS_TO_REWARD) {
        service.top_reviews.pop_back();
    }
}

public fun upvote(service: &mut Service, review_id: ID) {
    let rev = &mut service.reviews[review_id];
    review::upvote(rev);
    reorder(service, review_id, review::get_total_score(rev));
}

// Reorders Reviews after Adding A New One (Add into top review if in top 10 or else just reorder)
fun reorder(service: &mut Service, review_id: ID, total_score: u64) {
    //If not in array, add into array.
    //If already in array, remove and reinsert
    let (contains, idx) = service.top_reviews.index_of(&review_id);
    if (!contains) {
        service.update_top_reviews(review_id, total_score)
    } else {
        service.top_reviews.remove(idx);
        let idx = service.find_idx(total_score);
        service.top_reviews.insert(review_id, idx);
    }
}

fun update_top_reviews(service: &mut Service, review_id: ID, total_score: u64) {
    if (service.should_update_top_reviews(total_score)) {
        let idx = service.find_idx(total_score);
        service.top_reviews.insert(review_id, idx);
        service.prune_top_reviews();
    }
}

//Find Index To Slot In the New Review
fun find_idx(service: &mut Service, total_score: u64): u64 {
    let mut i = service.top_reviews.length()-1;
    //Iterate through list items
    while (0<i) {
        let review_id = service.top_reviews[i];
        if (review::get_total_score(borrow_mut(service.reviews, &review_id))>total_score) {
            break
        };
        i = i-1;
    };
    i = i+1;
    i
}

//Get Total Score of A Review
fun get_total_score(service: &mut Service, review_id: ID) :u64{
    service.reviews[review_id].total_score
}

//Distribute Rewards 
fun distribute_rewards(cap: &mut AdminCap, service: &mut Service, ctx: &mut TxContext){
    //Check If the User Has The Capabilities 
    assert!(cap.service_id==service.id.to_inner(), EInvalidPermission);
    let mut len=service.top_reviews.length();
    if (len> MAX_REVIEWERS_TO_REWARD) {len= MAX_REVIEWERS_TO_REWARD};
    //check balance
    assert!(service.reward_pool>=service.reward*len, ENotEnoughBalance);
    let mut i = 0;
    //Break down the desired amount of coins
    while (i <len){
       let sub_balance=service.reward_pool.split(service.reward); 
       //Make the balance into  a coin
       let reward=coin::from_balance(balance, ctx);
       let review_id= &service.top_reviews[i];
    };
    
}