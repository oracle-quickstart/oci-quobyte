[bastion]
${bastion_name} ansible_host=${bastion_ip} ansible_user=opc role=bastion
[cluster]
%{ for host, ip in cluster ~}
${host} ansible_host=${ip} ansible_user=opc role=cluster
%{ endfor ~}
[compute]
%{ for host, ip in compute ~}
${host} ansible_host=${ip} ansible_user=opc role=compute
%{ endfor ~}
[all:children]
bastion
cluster
compute
[all:vars]
ansible_connection=ssh
ansible_user=opc
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
rdma_network=192.168.168.0
rdma_netmask=255.255.252.0
fs_name=${fs_name}
fs_type=${fs_type}
vcn_domain_name=${vcn_domain_name}
public_subnet=${public_subnet}
private_storage_subnet_cidr_block=${private_storage_subnet_cidr_block}
private_fs_subnet_cidr_block=${private_fs_subnet_cidr_block}
private_storage_subnet_dns_label=${private_storage_subnet_dns_label}
private_fs_subnet_dns_label=${private_fs_subnet_dns_label}
filesystem_subnet_domain_name=${filesystem_subnet_domain_name}
storage_subnet_domain_name=${storage_subnet_domain_name}
storage_server_filesystem_vnic_hostname_prefix=${storage_server_filesystem_vnic_hostname_prefix}
storage_server_node_count=${storage_server_node_count}
storage_tier_1_disk_perf_tier=${storage_tier_1_disk_perf_tier}
stripe_size=${stripe_size}
mount_point=${mount_point}
storage_secondary_vnic_private_ips=${storage_secondary_vnic_private_ips}
repo_id=${repo_id}
