# Gets a list of Availability Domains
data "oci_identity_availability_domains" "availability_domains" {
  compartment_id = "${var.compartment_ocid}"
}

data "oci_core_images" "InstanceImageOCID" {
    compartment_id            = var.compartment_ocid
    operating_system          = var.instance_os
    operating_system_version  = var.linux_os_version


    # To remove ampere Arm images.
    # Oracle-Linux-7.9-aarch64-2021.04.13-0 for Ampere Arm images.
    # Oracle-Linux-7.9-2021.04.09-0
    # Oracle-Linux-8.3-2021.05.12-0
    filter {
      name   = "display_name"
      values = ["^([a-zA-z]+)-([a-zA-z]+)-([\\.0-9]+)-([\\.0-9-]+)$"]
      regex  = true
  }


}
