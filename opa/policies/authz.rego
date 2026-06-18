package topic10.authz

default allow = false

roles[role] {
    role := input.roles[_]
}

allow {
    input.action == "admin_maintenance"
    input.subject_type == "service"
    input.client_id == "admin-service-client"
    roles["admin-maintenance"]
}

allow {
    input.action == "order_verify_ownership"
    input.subject_type == "service"
    input.client_id == "billing-service-client"
    roles["order-ownership-read"]
    input.order_id != ""
    input.order_owner != ""
    input.requested_username != ""
    input.order_owner == input.requested_username
}

allow {
    input.action == "billing_checkout"
    input.subject_type == "human"
    input.username != ""
    input.ownership_confirmed == true
    input.ownership_confirmation_source == "order-service"
}
