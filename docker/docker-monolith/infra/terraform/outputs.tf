# выводить публичный ip каждого инстанса
output "external_ip_app" {
  value = yandex_compute_instance.vm-app.*.network_interface.0.nat_ip_address
}
