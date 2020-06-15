

data "oci_core_instance" "storage_server" {
  count       = var.storage_server_node_count
  instance_id = element(concat(oci_core_instance.storage_server.*.id, [""]), count.index)
}

data "oci_core_instance" "compute" {
  count       = var.compute_node_count
  instance_id = element(concat(oci_core_instance.compute.*.id, [""]), count.index)
}


data "oci_core_subnet" "private_storage_subnet" {
  subnet_id = local.storage_subnet_id
}

data "oci_core_subnet" "private_fs_subnet" {
  subnet_id = local.fs_subnet_id
}


data "oci_core_subnet" "public_subnet" { 
  subnet_id = local.bastion_subnet_id
} 

data "oci_core_vcn" "quobyte" {
  vcn_id = var.use_existing_vcn ? var.vcn_id : oci_core_virtual_network.quobyte[0].id
}

output "bastion" {
  value = oci_core_instance.bastion[0].public_ip
}

output "storage_server_private_ips" {
  value = join(" ", oci_core_instance.storage_server.*.private_ip)
}

output "compute_private_ips" {
  value = join(" ", oci_core_instance.compute.*.private_ip)
}



data "oci_core_vnic" "storage_secondary_vnic" {
  count   = var.storage_server_node_count
  vnic_id = "${element(oci_core_vnic_attachment.storage_server_secondary_vnic_attachment.*.vnic_id, count.index)}"
}


/*
output "primary_ip_addresses" {
  value = ["${oci_core_instance.test_instance.public_ip}",
    "${oci_core_instance.test_instance.private_ip}",
  ]
}

output "secondary_public_ip_addresses" {
  value = ["${data.oci_core_vnic.storage_secondary_vnic.*.public_ip_address}"]
}
*/
output "secondary_private_ip_addresses" {
  value = ["${data.oci_core_vnic.storage_secondary_vnic.*.private_ip_address}"]
}

output "secondary_private_ip_addresses_1" {
  value = join(",", data.oci_core_vnic.storage_secondary_vnic.*.private_ip_address)
}
