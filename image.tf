locals {
  talos_schematic_id = coalesce(var.talos_schematic_id, talos_image_factory_schematic.this[0].id)

  talos_catalog_id = "talos-${var.talos_version}"

  talos_installer_image_url = data.talos_image_factory_urls.amd64.urls.installer
  talos_amd64_image_url     = data.talos_image_factory_urls.amd64.urls.disk_image

  image_label_selector = join(",",
    [
      "os=talos",
      "cluster=${var.cluster_name}",
      "talos_version=${var.talos_version}",
      "talos_schematic_id=${substr(local.talos_schematic_id, 0, 32)}"
    ]
  )

  talos_image_extensions = distinct(
    concat(
      ["siderolabs/vmtoolsd-guest-agent"],
      var.talos_image_extensions,

      # longhorn requirements
      [
        "siderolabs/iscsi-tools",
        "siderolabs/util-linux-tools",
      ]
    )
  )
}

data "talos_image_factory_extensions_versions" "this" {
  count = var.talos_schematic_id == null ? 1 : 0

  talos_version = var.talos_version
  filters = {
    names = local.talos_image_extensions
  }
}

resource "talos_image_factory_schematic" "this" {
  count = var.talos_schematic_id == null ? 1 : 0

  schematic = yamlencode(
    {
      customization = {
        extraKernelArgs = var.talos_extra_kernel_args
        systemExtensions = {
          officialExtensions = (
            length(local.talos_image_extensions) > 0 ?
            data.talos_image_factory_extensions_versions.this[0].extensions_info.*.name :
            []
          )
        }
      }
    }
  )
}

data "talos_image_factory_urls" "amd64" {
  talos_version = var.talos_version
  schematic_id  = local.talos_schematic_id
  platform      = "vmware"
  architecture  = "amd64"
}


resource "terraform_data" "talos-ova" {
  triggers_replace = [data.talos_image_factory_urls.amd64.urls.disk_image]

  provisioner "local-exec" {
    command = "curl -s -o ${path.root}/${element(split("/", data.talos_image_factory_urls.amd64.urls.disk_image), -1)} ${data.talos_image_factory_urls.amd64.urls.disk_image}"
  }
}

data "vcd_catalog" "faino" {
  name = "Faino"
}

resource "vcd_catalog_item" "talos-boot-image" {
  org     = data.vcd_org.this.name
  catalog = "Faino"

  name     = local.talos_catalog_id
  ova_path = "${path.root}/${element(split("/", data.talos_image_factory_urls.amd64.urls.disk_image), -1)}"

  depends_on = [terraform_data.talos-ova]
}

data "vcd_catalog_vapp_template" "talos-boot-image" {
  name       = local.talos_catalog_id
  catalog_id = data.vcd_catalog.faino.id
  depends_on = [vcd_catalog_item.talos-boot-image]
}
