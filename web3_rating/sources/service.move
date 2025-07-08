module web3_rating::service;

const MAX_REVIEWERS_TO_REWARD:u64=10;

//Represents a service (Maybe like a freelancing site)
public struct Service has key, store{
    id:UID,
    reward_pool: Balance<SUI>,
    reward: u64,
    top_reviews: vector<ID>,
    reviews: ObjectTable<ID,Review>,
    overall_rate: u64,
    name:String,
}

public fun upvote(service: &mut Service,review_id:ID){
    let review=&mut service.reviews[review_id];
    review.upvote()
}