

output "Filesystem-Mount-Details" {
value = <<END

derived_storage_server_shape=${local.derived_storage_server_shape}

END
}


output "SSH-login" {
value = <<END

        CHANGEME: ${var.ssh_private_key_path}

        Bastion: ssh -i ${var.ssh_private_key_path} ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)}

        Storage Server-1: ssh -i ${var.ssh_private_key_path}  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i ${var.ssh_private_key_path} -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)} -W %h:%p %r" ${var.ssh_user}@${element(concat(oci_core_instance.storage_server.*.private_ip, [""]), 0)}

        Compute-1: ssh -i ${var.ssh_private_key_path}  -o BatchMode=yes -o StrictHostkeyChecking=no  -o ProxyCommand="ssh -i ${var.ssh_private_key_path} -o BatchMode=yes -o StrictHostkeyChecking=no ${var.ssh_user}@${element(concat(oci_core_instance.bastion.*.public_ip, [""]), 0)} -W %h:%p %r" ${var.ssh_user}@${element(concat(oci_core_instance.compute.*.private_ip, [""]), 0)}

END
}



