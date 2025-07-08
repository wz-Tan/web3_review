module web3_rating::dashboard;

//Collection of Services
public struct Dashboard has key,store{
    id:UID,
    service_type: String
}

//Create Dashboard
public fun create_dashboard(service_type:String, ctx: &mut TxContext){
    let db=Dashboard{
        id:object::new(ctx),
        service_type
    };
    transfer::share_object(db)
}

//Register new service to the dashboard (Add via dynamic field)
public fun register_service(db: &mut Dashboard, service_id:ID){
    //Add service id under the name of service id into database
    df::add(&mut db.id, service_id, service_id)
}

