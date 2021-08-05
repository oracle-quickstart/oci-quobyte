
resource "tls_private_key" "ssh" {
  algorithm   = "RSA"
}


locals {
  bastion_subnet_id = var.use_existing_vcn ? var.bastion_subnet_id : element(concat(oci_core_subnet.public.*.id, [""]), 0)
  image_id          = (var.use_marketplace_image ? var.mp_listing_resource_id : var.images[var.region])
  compute_subnet_id  = var.use_existing_vcn ? var.fs_subnet_id : element(concat(oci_core_subnet.fs.*.id, [""]), 0)
}

data "template_file" "bastion_config" {
  template = file("config.bastion")
  vars = {
    key = tls_private_key.ssh.private_key_pem
  }
}

resource "oci_core_instance" "bastion" {
  depends_on          = [ oci_core_instance.storage_server, oci_core_subnet.public,
   ]
  count               = var.bastion_node_count
  availability_domain = local.ad
#fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = var.compartment_ocid
  shape               = var.bastion_shape
  display_name        = "${var.bastion_hostname_prefix}${format("%01d", count.index+1)}"
  hostname_label      = "${var.bastion_hostname_prefix}${format("%01d", count.index+1)}"
  metadata = {
    ssh_authorized_keys = "${var.ssh_public_key}\n${tls_private_key.ssh.public_key_openssh}"
    user_data           = base64encode(data.template_file.bastion_config.rendered)
  }
  source_details {
    source_id   = local.image_id
    source_type = "image"
  }
  create_vnic_details {
    subnet_id = local.bastion_subnet_id
  }
  launch_options {
    network_type = "VFIO"
  }

  agent_config {
    is_management_disabled = true
  }

  provisioner "file" {
    source        = "playbooks"
    destination   = "/home/opc/"
    connection {
      host        = oci_core_instance.bastion[0].public_ip
      type        = "ssh"
      user        = "opc"
      private_key = tls_private_key.ssh.private_key_pem
    }
  }

  provisioner "file" {
    content        = templatefile("${path.module}/inventory.tpl", {  
      bastion_name = oci_core_instance.bastion[0].display_name,
      bastion_ip = oci_core_instance.bastion[0].private_ip,
      storage = zipmap(data.oci_core_instance.storage_server.*.display_name, data.oci_core_instance.storage_server.*.private_ip),
      cluster = zipmap(data.oci_core_vnic.storage_secondary_vnic.*.display_name, data.oci_core_vnic.storage_secondary_vnic.*.private_ip_address),
      compute = zipmap(data.oci_core_instance.compute.*.display_name, data.oci_core_instance.compute.*.private_ip),
      fs_name = var.fs_name,
      fs_type = var.fs_type,
      vcn_domain_name = local.vcn_domain_name,
      public_subnet = data.oci_core_subnet.public_subnet.cidr_block,
      private_storage_subnet_cidr_block = data.oci_core_subnet.private_storage_subnet.cidr_block,
      private_fs_subnet_cidr_block = data.oci_core_subnet.private_fs_subnet.cidr_block,
      private_storage_subnet_dns_label = data.oci_core_subnet.private_storage_subnet.dns_label,
      private_fs_subnet_dns_label = data.oci_core_subnet.private_fs_subnet.dns_label,
      filesystem_subnet_domain_name = local.filesystem_subnet_domain_name,
      storage_subnet_domain_name = local.storage_subnet_domain_name,
      storage_server_node_count = var.storage_server_node_count,
      storage_tier_1_disk_perf_tier = var.storage_tier_1_disk_perf_tier,
      stripe_size = var.stripe_size,
      mount_point = var.mount_point,
      storage_server_filesystem_vnic_hostname_prefix = local.storage_server_filesystem_vnic_hostname_prefix,
      storage_secondary_vnic_private_ips = join(",", data.oci_core_vnic.storage_secondary_vnic.*.private_ip_address),
      repo_id = var.repo_id,
    })

    destination   = "/home/opc/playbooks/inventory"
    connection {
      host        = oci_core_instance.bastion[0].public_ip
      type        = "ssh"
      user        = "opc"
      private_key = tls_private_key.ssh.private_key_pem
    }
  }


  provisioner "file" {
    content     = tls_private_key.ssh.private_key_pem
    destination = "/home/opc/.ssh/cluster.key"
    connection {
      host        = oci_core_instance.bastion[0].public_ip
      type        = "ssh"
      user        = "opc"
      private_key = tls_private_key.ssh.private_key_pem
    }
  }

  provisioner "file" {
    content     = tls_private_key.ssh.private_key_pem
    destination = "/home/opc/.ssh/id_rsa"
    connection {
      host        = oci_core_instance.bastion[0].public_ip
      type        = "ssh"
      user        = "opc"
      private_key = tls_private_key.ssh.private_key_pem
    }
  }

  provisioner "file" {
    content     = join("\n", data.oci_core_instance.storage_server.*.private_ip, data.oci_core_instance.compute.*.private_ip)
    destination = "/tmp/hosts"
    connection {
      host        = oci_core_instance.bastion[0].public_ip
      type        = "ssh"
      user        = "opc"
      private_key = tls_private_key.ssh.private_key_pem
    }
  }


  provisioner "file" {
    source      = "configure.sh"
    destination = "/tmp/configure.sh"
    connection {
      host        = oci_core_instance.bastion[0].public_ip
      type        = "ssh"
      user        = "opc"
      private_key = tls_private_key.ssh.private_key_pem
    }
  }


}

resource "null_resource" "run_configure_sh" {
  depends_on = [ oci_core_instance.bastion, null_resource.notify_storage_server_nodes_block_attach_complete ]
  count      = var.bastion_node_count


  provisioner "file" {
    source      = "configure.sh"
    destination = "/tmp/configure.sh"
    connection {
      host        = oci_core_instance.bastion[0].public_ip
      type        = "ssh"
      user        = "opc"
      private_key = tls_private_key.ssh.private_key_pem
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/opc/.ssh/cluster.key",
      "chmod 600 /home/opc/.ssh/id_rsa",
      "chmod a+x /tmp/configure.sh",
      "chmod a+x /tmp/*.sh",
      "/tmp/configure.sh"
    ]
    connection {
      host        = oci_core_instance.bastion[0].public_ip
      type        = "ssh"
      user        = "opc"
      private_key = tls_private_key.ssh.private_key_pem
    }
  }
}




locals {
  storage_subnet_id = var.use_existing_vcn ? var.storage_subnet_id : element(concat(oci_core_subnet.storage.*.id, [""]), 0)
  fs_subnet_id = var.use_existing_vcn ? var.fs_subnet_id : element(concat(oci_core_subnet.fs.*.id, [""]), 0)
  derived_storage_server_shape = (length(regexall("^Scratch", var.fs_type)) > 0 ? var.scratch_storage_server_shape : var.persistent_storage_server_shape)
  derived_storage_server_disk_count = (var.storage_tier_1_disk_count)
## derived_storage_server_disk_count = (length(regexall("DenseIO",local.derived_storage_server_shape)) > 0 ? 0 : var.storage_tier_1_disk_count)
}


resource "oci_core_instance" "storage_server" {
  count               = var.storage_server_node_count
  availability_domain = local.ad

  #fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = var.compartment_ocid
  display_name        = "${var.storage_server_hostname_prefix}${format("%01d", count.index+1)}"
  hostname_label      = "${var.storage_server_hostname_prefix}${format("%01d", count.index+1)}"
  shape               = local.derived_storage_server_shape
  subnet_id           = local.storage_subnet_id

  source_details {
    source_type = "image"
    source_id   = local.image_id
  }

  launch_options {
    network_type = "VFIO"
  }

  agent_config {
    is_management_disabled = true
  }
  
  metadata = {
    ssh_authorized_keys = join(
      "\n",
      [
        var.ssh_public_key,
        tls_private_key.ssh.public_key_openssh
      ]
    )
    user_data = "${base64encode(join("\n", list(
        "#!/usr/bin/env bash",
        "set -x",
      )))}"
    }

  timeouts {
    create = "120m"
  }

}





resource "oci_core_instance" "compute" {
  count               = var.compute_node_count
  availability_domain = local.ad
  #fault_domain        = "FAULT-DOMAIN-${(count.index%3)+1}"
  compartment_id      = var.compartment_ocid
  display_name        = "${var.compute_node_hostname_prefix}${format("%01d", count.index+1)}"
  hostname_label      = "${var.compute_node_hostname_prefix}${format("%01d", count.index+1)}"
  shape               = var.compute_node_shape
  subnet_id           = local.compute_subnet_id

  source_details {
    source_type = "image"
    source_id   = local.image_id
  }

  launch_options {
    network_type = "VFIO"
  }

  agent_config {
    is_management_disabled = true
  }

  metadata = {
    ssh_authorized_keys = join(
      "\n",
      [
        var.ssh_public_key,
        tls_private_key.ssh.public_key_openssh
      ]
    )
    user_data = "${base64encode(join("\n", list(
        "#!/usr/bin/env bash",
        "set -x",
      )))}"
    }

  timeouts {
    create = "120m"
  }

}


