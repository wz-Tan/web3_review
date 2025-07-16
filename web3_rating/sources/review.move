module web3_rating::review;

use std::string::String;
use sui::clock::Clock;
use sui::math;
use sui::object::delete;

//Invalid Content Length Error Code
const EInvalidContentLen: u64 = 1;

const MIN_REVIEW_CONTENT_LEN: u64 = 5;
const MAX_REVIEW_CONTENT_LEN: u64 = 1000;

public struct Review has key, store {
    id: UID,
    owner: address,
    service_id: ID,
    content: String,
    //Length of comment
    len: u64,
    //Extrinsic score
    votes: u64,
    time_issued: u64,
    //proof of experience
    has_poe: bool,
    total_score: u64,
    overall_rate: u8,
}

//Only reusable within same package
public(package) fun new_review(
    owner: address,
    service_id: ID,
    content: String,
    has_poe: bool,
    overall_rate: u8,
    clock: &Clock,
    ctx: &mut TxContext,
): Review {
    let len = content.length();
    assert!(length>=MIN_REVIEW_CONTENT_LEN && length<=MAX_REVIEW_CONTENT_LEN, EInvalidContentLen);
    let mut new_review = Review {
        id: object::new(ctx),
        owner,
        service_id,
        content,
        len,
        votes: 0,
        time_issued: clock.timestamp_ms(),
        has_poe,
        total_score: 0,
        overall_rate,
    };
    new_review.total_score=new_review.calculate_total_score();
    new_review
}

//Delete Review
public(package) fun delete_review(rev:Review){
    //Break Down Review
    let Review{
        id,
        owner: _,
        service_id: _,
        content: _,
        len: _,
        votes: _,
        time_issued: _,
        has_poe: _,
        total_score: _,
        overall_rate: _,
    } = rev;
    object::delete(id)
}


fun calculate_total_score(rev: &mut Review): u64 {
    //let makes the variables into val, mut makes them var
    let mut intrinsic_score: u64 = rev.len;
    intrinsic_score = min(intrinsic_score, 150);

    let extrinsic_score = 10*rev.votes;
    let vm = if (rev.has_poe) { 2 } else { 1 };
    (intrinsic_score+extrinsic_score)*vm
}

//For getters we can just use an & symbol to show this is read only
public fun get_total_score(rev: &Review): u64 {
    rev.total_score
}

fun update_total_score(rev: &mut Review) {
    rev.total_score = rev.calculate_total_score(rev);
}

public fun upvote(rev: &mut Review) {
    rev.votes = rev.votes+1;
    rev.update_total_score();
}

public fun get_id(rev:&Review) :ID{
    rev.id.to_inner()
}

public fun get_time_issued(rev:&Review):u64{
    rev.time_issued
}