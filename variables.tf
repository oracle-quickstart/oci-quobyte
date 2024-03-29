###
## Variables.tf for Terraform
## Defines variables and local values
###

variable "vpc_cidr" { default = "10.0.0.0/16" }


variable "fs_name" { default = "quobyte" }
# Scratch or Persistent
variable "fs_type" { default = "Persistent" }
# Valid values:  Large Files, Small Files,  Mixed.  Select Mixed, if your workload generates a lot of Small files and Large files and you want to optimize filesystem cluster for both.  Small Files (Random IO),  Large Files (Sequential IO).
variable "fs_workload_type" { default = "Large Files" }


variable bastion_shape { default = "VM.Standard2.2" }
# Number of OCPU's for flex shape, otherwise ignore the variable
variable bastion_ocpus { default = "1" }
variable bastion_node_count { default = 1 }
variable bastion_hostname_prefix { default = "bastion-" }
# min 50GB, For Production, recommend sizing it based on what else u plan to run on the node.
variable bastion_boot_volume_size { default = "50" }



#  Storage Server nodes variables
variable persistent_storage_server_shape { default = "VM.DenseIO2.16" }
# Number of OCPU's for flex shape, otherwise ignore the variable
variable storage_server_ocpus { default = "2" }
variable storage_server_memory { default = 16 }
variable storage_server_custom_memory { default = false }
variable scratch_storage_server_shape { default = "VM.DenseIO2.16" }
#variable storage_server_shape { default = "" }
variable storage_server_node_count { default = 4 }
variable storage_server_hostname_prefix { default = "storage-server-" }
# Recommend using 200-300 GB in production to ensure there is enough space for logs.
variable storage_server_boot_volume_size { default = "300" }

# Compute nodes variables
variable compute_node_shape { default = "VM.Standard2.2" }
# Number of OCPU's for flex shape, otherwise ignore the variable
variable compute_node_ocpus { default = "1" }
variable compute_node_count { default = 2 }
variable compute_node_hostname_prefix { default = "compute-" }


# FS related variables
# Default file stripe size (aka chunk_size) used by clients to striping file data and send to desired number of storage targets (OSTs). Example: 1m, 512k, 2m, etc
variable stripe_size { default = "1m" }
variable mount_point { default = "/quobyte" }


# This is currently used for the deployment.  
variable "ad_number" {
  default = "-1"
}


variable "storage_tier_1_disk_perf_tier" {
  default = "Higher Performance"
  description = "Select block volume storage performance tier based on your performance needs. Valid values are Higher Performance, Balanced, Lower Cost"
}

variable "storage_tier_1_disk_count" {
  default = "4"
  description = "Number of block volume disk per file server. Each attached as JBOD (no RAID)."
}

variable "storage_tier_1_disk_size" {
  default = "50"
  description = "Select size in GB for each block volume/disk, min 50."
}


################################################################
## Variables which in most cases do not require change by user
################################################################

variable "scripts_directory" { default = "scripts" }

variable "tenancy_ocid" {}
variable "region" {}

variable "compartment_ocid" {
  description = "Compartment where infrastructure resources will be created"
}
variable "ssh_public_key" {
  description = "SSH Public Key"
}


variable "ssh_user" { default = "opc" }


locals {
  storage_server_dual_nics = (length(regexall("^BM", local.derived_storage_server_shape)) > 0 ? true : false)
  storage_server_hpc_shape = (length(regexall("HPC2", local.derived_storage_server_shape)) > 0 ? true : false)
  storage_subnet_domain_name="${data.oci_core_subnet.private_storage_subnet.dns_label}.${data.oci_core_vcn.quobyte.dns_label}.oraclevcn.com"
  filesystem_subnet_domain_name="${data.oci_core_subnet.private_fs_subnet.dns_label}.${data.oci_core_vcn.quobyte.dns_label}.oraclevcn.com"
  vcn_domain_name="${data.oci_core_vcn.quobyte.dns_label}.oraclevcn.com"
  storage_server_filesystem_vnic_hostname_prefix = "${var.storage_server_hostname_prefix}fs-vnic-"

  # If ad_number is non-negative use it for AD lookup, else use ad_name.
  # Allows for use of ad_number in TF deploys, and ad_name in ORM.
  # Use of max() prevents out of index lookup call.
  ad = "${var.ad_number >= 0 ? lookup(data.oci_identity_availability_domains.availability_domains.availability_domains[max(0,var.ad_number)],"name") : var.ad_name}"

  is_bastion_flex_shape = length(regexall(".*VM.*E[3-4].*Flex$", var.bastion_shape)) > 0 ? [var.bastion_ocpus]:[]
  is_storage_server_flex_shape = length(regexall(".*VM.*E[3-4].*Flex$", var.persistent_storage_server_shape)) > 0 ? [var.storage_server_ocpus]:[]
  # not used
  is_compute_node_flex_shape = length(regexall(".*VM.*E[3-4].*Flex$", var.compute_node_shape)) > 0 ? [var.compute_node_ocpus]:[]
  
  
  # https://docs.oracle.com/en-us/iaas/Content/Compute/Tasks/edit-launch-options.htm
  server_network_type = ( ( (length(regexall("VM.Standard.E2", local.derived_storage_server_shape)) > 0) || (length(regexall("VM.Standard.A1.Flex", local.derived_storage_server_shape)) > 0) ) ? "PARAVIRTUALIZED" : "VFIO")

  compute_network_type = ( ( (length(regexall("VM.Standard.E2", var.compute_node_shape)) > 0) || (length(regexall("VM.Standard.A1.Flex", var.compute_node_shape)) > 0) ) ? "PARAVIRTUALIZED" : "VFIO")
  
  # old logic to use static image
  #image_id          = (var.use_marketplace_image ? var.mp_listing_resource_id : var.images[var.region])

  image_id = (var.use_marketplace_image ? var.mp_listing_resource_id : data.oci_core_images.InstanceImageOCID.images.0.id)


}



# Oracle-Linux-8.3-2021.05.12-0
# https://docs.oracle.com/en-us/iaas/images/image/4672d9c5-9023-4b13-9021-cd3db35ea486/
# 5.4.17-2102.201.3.el8uek.x86_64 (UEK R6U2)
# imagesOL83_UEKR6U2
variable "images" {
  type = map(string)
  default = {
    us-ashburn-1   = "ocid1.image.oc1.iad.aaaaaaaa66sixgsmhurzb3g7jedimei4wzrsvuqxfteeeesgfsboyqwsb75q"
    us-phoenix-1   = "ocid1.image.oc1.phx.aaaaaaaa7tahbccrcjw5zrgg3dpjmti7ldaglfvvmk4hgmvp5jf54jwejpiq"
  }
}




variable "imagesCentos" {
  type = map(string)
  default = {
    // https://docs.cloud.oracle.com/iaas/images/image/96ad11d8-2a4f-4154-b128-4d4510756983/
    // See https://docs.us-phoenix-1.oraclecloud.com/images/ or https://docs.cloud.oracle.com/iaas/images/
    // Oracle-provided image "CentOS-7-2018.08.15-0"
    eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaavsw2452x5psvj7lzp7opjcpj3yx7or4swwzl5vrdydxtfv33sbmqa"
    us-ashburn-1   = "ocid1.image.oc1.iad.aaaaaaaahhgvnnprjhfmzynecw2lqkwhztgibz5tcs3x4d5rxmbqcmesyqta"
    uk-london-1    = "ocid1.image.oc1.uk-london-1.aaaaaaaa3iltzfhdk5m6f27wcuw4ttcfln54twkj66rsbn52yemg3gi5pkqa"
    us-phoenix-1   = "ocid1.image.oc1.phx.aaaaaaaaa2ph5vy4u7vktmf3c6zemhlncxkomvay2afrbw5vouptfbydwmtq"
  }
}

// See https://docs.cloud.oracle.com/en-us/iaas/images/image/0a72692a-bdbb-46fc-b17b-6e0a3fedeb23/
// Oracle-provided image "Oracle-Linux-7.7-2020.01.28-0"
// Kernel Version: 4.14.35-1902.10.4.el7uek.x86_64
variable "images1" {
  type = "map"
  default = {
    ap-melbourne-1 = "ocid1.image.oc1.ap-melbourne-1.aaaaaaaa3fvafraincszwi36zv2oeangeitnnj7svuqjbm2agz3zxhzozadq"
    ap-mumbai-1 = "ocid1.image.oc1.ap-mumbai-1.aaaaaaaabyd7swhvmsttpeejgksgx3faosizrfyeypdmqdghgn7wzed26l3q"
    ap-osaka-1 = "ocid1.image.oc1.ap-osaka-1.aaaaaaaa7eec33y25cvvanoy5kf5udu3qhheh3kxu3dywblwqerui3u72nua"
    ap-seoul-1 = "ocid1.image.oc1.ap-seoul-1.aaaaaaaai233ko3wxveyibsjf5oew4njzhmk34e42maetaynhbljbvkzyqqa"
    ap-sydney-1 = "ocid1.image.oc1.ap-sydney-1.aaaaaaaaeb3c3kmd3yfaqc3zu6ko2q6gmg6ncjvvc65rvm3aqqzi6xl7hluq"
    ap-tokyo-1 = "ocid1.image.oc1.ap-tokyo-1.aaaaaaaattpocc2scb7ece7xwpadvo4c5e7iuyg7p3mhbm554uurcgnwh5cq"
    ca-toronto-1 = "ocid1.image.oc1.ca-toronto-1.aaaaaaaa4u2x3aofmhogbw6xsckha6qdguiwqvh5ibnbuskfo2k6e3jhdtcq"
    eu-amsterdam-1 = "ocid1.image.oc1.eu-amsterdam-1.aaaaaaaan5tbzuvtyd5lwxj66zxc7vzmpvs5axpcxyhoicbr6yxgw2s7nqvq"
    eu-frankfurt-1 = "ocid1.image.oc1.eu-frankfurt-1.aaaaaaaa4xluwijh66fts4g42iw7gnixntcmns73ei3hwt2j7lihmswkrada"
    eu-zurich-1 = "ocid1.image.oc1.eu-zurich-1.aaaaaaaagj2saw4bisxyfe5joary52bpggvpdeopdocaeu2khpzte6whpksq"
    me-jeddah-1 = "ocid1.image.oc1.me-jeddah-1.aaaaaaaaczhhskrjad7l3vz2u3zyrqs4ys4r57nrbxgd2o7mvttzm4jryraa"
    sa-saopaulo-1 = "ocid1.image.oc1.sa-saopaulo-1.aaaaaaaabm464lilgh2nqw2vpshvc2cgoeuln5wgrfji5dafbiyi4kxtrmwa"
    uk-gov-london-1 = "ocid1.image.oc4.uk-gov-london-1.aaaaaaaa3badeua232q6br2srcdbjb4zyqmmzqgg3nbqwvp3ihjfac267glq"
    uk-london-1 = "ocid1.image.oc1.uk-london-1.aaaaaaaa2jxzt25jti6n64ks3hqbqbxlbkmvel6wew5dc2ms3hk3d3bdrdoa"
    us-ashburn-1 = "ocid1.image.oc1.iad.aaaaaaaamspvs3amw74gzpux4tmn6gx4okfbe3lbf5ukeheed6va67usq7qq"
    us-langley-1 = "ocid1.image.oc2.us-langley-1.aaaaaaaawzkqcffiqlingild6jqdnlacweni7ea2rm6kylar5tfc3cd74rcq"
    us-luke-1 = "ocid1.image.oc2.us-luke-1.aaaaaaaawo4qfu7ibanw2zwefm7q7hqpxsvzrmza4uwfqvtqg2quk6zghqia"
    us-phoenix-1 = "ocid1.image.oc1.phx.aaaaaaaamff6sipozlita6555ypo5uyqo2udhjqwtrml2trogi6vnpgvet5q"
  }
}



# Not used for normal terraform apply, added for ORM deployments.
variable "ad_name" {
  default = ""
}



variable "volume_attach_device_mapping" {
  type = map(string)
  default = {
    "0" = "/dev/oracleoci/oraclevdb"
    "1" = "/dev/oracleoci/oraclevdc"
    "2" = "/dev/oracleoci/oraclevdd"
    "3" = "/dev/oracleoci/oraclevde"
    "4" = "/dev/oracleoci/oraclevdf"
    "5" = "/dev/oracleoci/oraclevdg"
    "6" = "/dev/oracleoci/oraclevdh"
    "7" = "/dev/oracleoci/oraclevdi"
    "8" = "/dev/oracleoci/oraclevdj"
    "9" = "/dev/oracleoci/oraclevdk"
    "10" = "/dev/oracleoci/oraclevdl"
    "11" = "/dev/oracleoci/oraclevdm"
    "12" = "/dev/oracleoci/oraclevdn"
    "13" = "/dev/oracleoci/oraclevdo"
    "14" = "/dev/oracleoci/oraclevdp"
    "15" = "/dev/oracleoci/oraclevdq"
    "16" = "/dev/oracleoci/oraclevdr"
    "17" = "/dev/oracleoci/oraclevds"
    "18" = "/dev/oracleoci/oraclevdt"
    "19" = "/dev/oracleoci/oraclevdu"
    "20" = "/dev/oracleoci/oraclevdv"
    "21" = "/dev/oracleoci/oraclevdw"
    "22" = "/dev/oracleoci/oraclevdx"
    "23" = "/dev/oracleoci/oraclevdy"
    "24" = "/dev/oracleoci/oraclevdz"
    "25" = "/dev/oracleoci/oraclevdaa"
    "26" = "/dev/oracleoci/oraclevdab"
    "27" = "/dev/oracleoci/oraclevdac"
    "28" = "/dev/oracleoci/oraclevdad"
    "29" = "/dev/oracleoci/oraclevdae"
    "30" = "/dev/oracleoci/oraclevdaf"
    "31" = "/dev/oracleoci/oraclevdag"
  }
}

variable "volume_type_vpus_per_gb_mapping" {
  type = map(string)
  default = {
    "Higher Performance" = "20"
    "Balanced" = "10"
    "Lower Cost" = "0"
    "None" = "-1"
  }
}


#-------------------------------------------------------------------------------------------------------------
# Marketplace variables
# hpc-filesystem-BxxxFS-OL77_3.10.0-1062.9.1.el7.x86_64
# ------------------------------------------------------------------------------------------------------------

#variable "mp_listing_id" { default = "ocid1.appcataloglisting.oc1..aaaaaaaajmdokvtzailtlchqxk7nai45fxar6em7dfbdibxmspjsvs4uz3uq" }
#variable "mp_listing_resource_id" { default = "ocid1.image.oc1..aaaaaaaacnodhlnuidkvnlvu3dpu4n26knkqudjxzfpq3vexi7cobbclmbxa" }
#variable "mp_listing_resource_version" { default = "1.0" }

variable "use_marketplace_image" { default = true }

# ------------------------------------------------------------------------------------------------------------



variable "mp_listing_id" { default = "ocid1.appcataloglisting.oc1..aaaaaaaa2tsjrt6vdjvz6gz476fgq7cr2x5f2gskesjt4i2ocec56me4o65q" }
variable "mp_listing_resource_version" { default = "Oracle-Linux-8.1-2019.12.09-0" }

variable "mp_listing_resource_id" { default = "ocid1.image.oc1..aaaaaaaaoydld6bwi3l6ux4qxqwa6ue3q562tq5yxn4yi3yng3wvhnmhs6jq" }



variable "use_existing_vcn" {
  default = "false"
}

variable "vcn_id" {
  default = ""
}

variable "bastion_subnet_id" {
  default = ""
}

variable "storage_subnet_id" {
  default = ""
}

variable "fs_subnet_id" {
  default = ""
}

variable "create_compute_nodes" {
  default = "false"
}


variable instance_os {
    description = "Operating system for compute instances"
    default = "Oracle Linux"
}

# Using 7.9 works,  but 8.3 or 7.8 or 8.4 or 7 fails,  if only 8 is set, then it picks the latest 8.x.
# Only latest supported OS version works. if I use 7.7, it doesn't return an image ocid.
variable linux_os_version {
    description = "Operating system version for compute instances except NAT"
    #default = "8"
    default = "7.9"
}


#-------------------------------------------------------------------------------------------------------------
# Quobyte variables
# ------------------------------------------------------------------------------------------------------------
# Sign-up for Quobyte to get trial license or if you already have a license,  enter your repo_id here.
# https://www.quobyte.com/signup
variable repo_id { default = "FTSUx9VMUtNUTQJB7AGf0cjaDhrT27HH" }


