
locals {
}

# derived_storage_server_disk_count

resource "oci_core_volume" "storage_tier_blockvolume" {
  count = local.derived_storage_server_disk_count * var.storage_server_node_count
  availability_domain = local.ad
  compartment_id      = var.compartment_ocid
  display_name        = "storage${count.index % var.storage_server_node_count + 1}-target${count.index % local.derived_storage_server_disk_count + 1}"

  size_in_gbs         = var.storage_tier_1_disk_size
  vpus_per_gb         = var.volume_type_vpus_per_gb_mapping[(var.storage_tier_1_disk_perf_tier)]
}


resource "oci_core_volume_attachment" "storage_tier_blockvolume_attach" {
  attachment_type = "iscsi"
  count = (var.storage_server_node_count * local.derived_storage_server_disk_count)
  instance_id = element(
    oci_core_instance.storage_server.*.id,
    count.index % var.storage_server_node_count,
  )
  volume_id = element(oci_core_volume.storage_tier_blockvolume.*.id, count.index)

  provisioner "remote-exec" {
    connection {
      agent   = false
      timeout = "30m"
      host = element(
        oci_core_instance.storage_server.*.private_ip,
        count.index % var.storage_server_node_count,
      )
      user                = var.ssh_user
      private_key         = tls_private_key.ssh.private_key_pem
      bastion_host        = oci_core_instance.bastion[0].public_ip
      bastion_port        = "22"
      bastion_user        = var.ssh_user
      bastion_private_key = tls_private_key.ssh.private_key_pem

    }

    inline = [
      "sudo -s bash -c 'set -x && iscsiadm -m node -o new -T ${self.iqn} -p ${self.ipv4}:${self.port}'",
      "sudo -s bash -c 'set -x && iscsiadm -m node -o update -T ${self.iqn} -n node.startup -v automatic '",
      "sudo -s bash -c 'set -x && iscsiadm -m node -T ${self.iqn} -p ${self.ipv4}:${self.port} -l '",
    ]
  }
}



resource "null_resource" "notify_storage_server_nodes_block_attach_complete" {
  depends_on = [ oci_core_volume_attachment.storage_tier_blockvolume_attach ]
  count = var.storage_server_node_count
  provisioner "remote-exec" {
    connection {
        agent               = false
        timeout             = "30m"
        host                = element(oci_core_instance.storage_server.*.private_ip, count.index)
        user                = var.ssh_user
        private_key         = tls_private_key.ssh.private_key_pem
        bastion_host        = oci_core_instance.bastion.*.public_ip[0]
        bastion_port        = "22"
        bastion_user        = var.ssh_user
        bastion_private_key = tls_private_key.ssh.private_key_pem
    }
    inline = [
      "set -x",
      "sudo touch /tmp/block-attach.complete",
    ]
  }
}
