module web3_rating::service;

use std::string::String;
use sui::balance::Balance;
use sui::object_table::ObjectTable;
use sui::sui::SUI;
use web3_rating::review::Review;

const MAX_REVIEWERS_TO_REWARD: u64 = 10;

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

public fun upvote(service: &mut Service, review_id: ID) {
    let review = &mut service.reviews[review_id];
    review.upvote();
    service.reorder(service, review_id, review.get_total_score());
}

// Reorders Reviews after Adding A New One (Add into top review if in top 10 or else just reorder)
fun reorder(service: &mut Service, review_id: ID, total_score: u64) {
    //If not in array, add into array.
    //If already in array, remove and reinsert
    let (contains, idx) = service.top_reviews.index_of(review_id);
    if (!contains) {
        service.update_top_reviews(review_id, total_score)
    } else {
        service.top_reviews.remove(idx);
        let idx = service.find_idx(total_score);
        service.top_reviews.insert(review_id, idx);
    }
}

fun update_top_reviews(service: &mut Service, review_id: ID, total_score: u64) {
    let idx = service.find_idx(total_score);
    service.top_reviews.insert(review_id, idx);
    service.prune_top_reviews();
}

//Find Index To Slot In the New Review
fun find_idx(service: &mut Service, total_score: u64): u64 {
    let mut i = service.top_reviews.length()-1;
    //Iterate through list items
    while (0<i) {
        let review_id = service.top_reviews[i];
        if (service.get_total_score(review_id)>total_score) {
            break
        };
        i = i-1;
    };
    i=i+1;
    i
}

fun prune_top_reviews(service: &mut Service) {
    let len = service.top_reviews.length();
    if (len > MAX_REVIEWERS_TO_REWARD) {
        service.top_reviews.pop_back();
    };
}
