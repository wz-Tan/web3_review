module web3_rating::review;

//The review for an item
use std::string::String;
use sui::math::min;

public struct Review has key, store{
    id:UID,
    owner: address,
    service_id: ID,
    content:String,
    //Length of comment
    len:u64,
    //Extrinsic score
    votes:u64,
    time_issued:u64,
    //proof of experience
    has_poe:bool,
    total_score:u64,
    overall_rate:u8
}

fun calculate_total_score(rev:&mut Review):u64{
    //let makes the variables into val, mut makes them var
    let mut intrinsic_score:u64=rev.len;
    intrinsic_score=min(intrinsic_score,150);

    let extrinsic_score=10*rev.votes;
    let vm=if (rev.has_poe) {2} else {1};
    (intrinsic_score+extrinsic_score)*vm
}

fun get_total_score(rev: &mut Review) : u64{
    update_total_score(rev);
    rev.total_score
}

fun update_total_score(rev:&mut Review){
    rev.total_score=calculate_total_score(rev);
}

fun upvote(rev:&mut Review){
    rev.votes=rev.votes+1;
}
