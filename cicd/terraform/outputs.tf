output "app_instance_private_ip" {
  value = yandex_compute_instance.app.network_interface.0.ip_address
}

output "db_instance_private_ip" {
  value = yandex_compute_instance.db.network_interface.0.ip_address
}

output "storage_bucket_name" {
  value = yandex_storage_bucket.logs.bucket
}

output "storage_access_key" {
  value     = yandex_iam_service_account_static_access_key.storage_key.access_key
  sensitive = true
}

output "storage_secret_key" {
  value     = yandex_iam_service_account_static_access_key.storage_key.secret_key
  sensitive = true
}

output "network_id" {
  value = yandex_vpc_network.main.id
}

output "public_subnet_id" {
  value = yandex_vpc_subnet.public.id
}

output "private_app_subnet_id" {
  value = yandex_vpc_subnet.private_app.id
}

output "private_db_subnet_id" {
  value = yandex_vpc_subnet.private_db.id
}

output "nat_gateway_ip" {
  value = yandex_vpc_address.nat_ip.external_ipv4_address
}
