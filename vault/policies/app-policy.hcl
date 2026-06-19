# vault/policies/app-policy.hcl
#
# Vault policy for API services.
# Grants read-only access to the secret paths used by each service.

# Webhook secret – read by billing-service and webhook demo
path "secret/data/api/webhook" {
  capabilities = ["read"]
}

path "secret/metadata/api/webhook" {
  capabilities = ["read", "list"]
}

# Service client credentials – read by billing-service and admin-service
path "secret/data/api/service-clients" {
  capabilities = ["read"]
}

path "secret/metadata/api/service-clients" {
  capabilities = ["read", "list"]
}

# Order service config
path "secret/data/api/order-service" {
  capabilities = ["read"]
}

path "secret/metadata/api/order-service" {
  capabilities = ["read", "list"]
}

# User service config
path "secret/data/api/user-service" {
  capabilities = ["read"]
}

path "secret/metadata/api/user-service" {
  capabilities = ["read", "list"]
}
