locals {
  talos_schematic_id = var.talos_schematic_id != null ? var.talos_schematic_id : talos_image_factory_schematic.this[0].id

  # Content identity of the boot image. The image factory builds deterministically
  # from (schematic, version, platform, architecture), so this digest changes
  # exactly when the OVA bytes are meant to change — and, unlike a catalog item
  # name, nobody can edit it in the VCD UI.
  talos_image_identity = sha256(join("|", [
    local.talos_schematic_id,
    var.talos_version,
    "vmware",
    "amd64",
  ]))
  talos_image_fingerprint = substr(local.talos_image_identity, 0, 12)

  # The fingerprint is part of the catalog item name on purpose. vcd_catalog_item
  # exposes `name` as Required but not ForceNew, and the provider's Update only
  # pushes the new name onto the vApp template that is already there, so a bare
  # "talos-<version>" lets a hand-renamed item pass for a fresh upload.
  talos_catalog_id = "talos-${var.talos_version}-${local.talos_image_fingerprint}"

  talos_installer_image_url = data.talos_image_factory_urls.amd64.urls.installer
  talos_amd64_image_url     = data.talos_image_factory_urls.amd64.urls.disk_image

  # ...and part of the local filename, for the same reason: the factory serves
  # every version as "vmware-amd64.ova", so a constant download path lets a stale
  # file from an earlier version be handed to ova_path, which is ForceNew but
  # never diffs because the string does not change.
  talos_ova_filename = "talos-${var.talos_version}-${local.talos_image_fingerprint}-${element(split("/", local.talos_amd64_image_url), -1)}"
  talos_ova_path     = "${path.root}/${local.talos_ova_filename}"

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
  # Keyed on the image identity, not only on the URL: the URL is what changes on
  # a version bump, but the identity is what the catalog item has to follow.
  # expected_sha256 is a separate key so that pinning or repinning the checksum
  # forces a fresh download and upload, without churning the catalog item name
  # for an image whose content did not change.
  triggers_replace = {
    image_identity  = local.talos_image_identity
    image_url       = local.talos_amd64_image_url
    expected_sha256 = var.talos_ova_sha256 == null ? "" : var.talos_ova_sha256
  }

  input = local.talos_image_identity

  provisioner "local-exec" {
    interpreter = ["/bin/sh", "-eu", "-c"]

    environment = {
      OVA_PATH   = local.talos_ova_path
      OVA_NAME   = local.talos_ova_filename
      OVA_URL    = local.talos_amd64_image_url
      OVA_SHA256 = var.talos_ova_sha256 == null ? "" : var.talos_ova_sha256
    }

    # -fSL, not bare -s. The image factory answers the disk_image URL with a 302
    # to a signed asset host, so a download without --location silently writes a
    # ~500-byte HTML redirect page and exits 0 — and without --fail any HTTP
    # error does the same. Caught on zeta 2026-08-12: the file on disk was an
    # HTML document. Nothing broke then, only because vcd_catalog_item had been
    # renamed in place on every version bump since the catalog was first
    # populated, so the bad file was never uploaded.
    #
    # Everything after curl exists because a clean exit code is not evidence
    # that the bytes are an OVA. Fail the apply here rather than let a redirect
    # page become the vApp template that every node boots from.
    command = <<-EOT
      set -eu

      curl -fSL --retry 3 --retry-delay 5 -o "$OVA_PATH" "$OVA_URL"

      bytes=$(wc -c < "$OVA_PATH" | tr -d ' ')
      if [ "$bytes" -lt 33554432 ]; then
        echo "ERROR: $OVA_PATH is $bytes bytes, far too small for a Talos OVA." >&2
        echo "First 200 bytes follow. An HTML document here means the download" >&2
        echo "followed no redirect, or hit an error page." >&2
        head -c 200 "$OVA_PATH" >&2 || true
        echo >&2
        rm -f "$OVA_PATH"
        exit 1
      fi

      # An OVA is an uncompressed tar whose first member is the OVF descriptor.
      first_member=$(tar -tf "$OVA_PATH" 2>/dev/null | head -n 1 || true)
      case "$first_member" in
        *.ovf) : ;;
        *)
          echo "ERROR: $OVA_PATH is not an OVA. Its first tar member is" >&2
          echo "'$first_member' instead of an .ovf descriptor." >&2
          rm -f "$OVA_PATH"
          exit 1
          ;;
      esac

      if command -v sha256sum >/dev/null 2>&1; then
        actual=$(sha256sum "$OVA_PATH" | cut -d' ' -f1)
      elif command -v shasum >/dev/null 2>&1; then
        actual=$(shasum -a 256 "$OVA_PATH" | cut -d' ' -f1)
      else
        echo "ERROR: neither sha256sum nor shasum is available." >&2
        exit 1
      fi

      # Durable record of the bytes that this apply is about to upload.
      printf '%s  %s\n' "$actual" "$OVA_NAME" > "$OVA_PATH.sha256"

      if [ -n "$OVA_SHA256" ] && [ "$actual" != "$OVA_SHA256" ]; then
        echo "ERROR: checksum mismatch for $OVA_PATH" >&2
        echo "  talos_ova_sha256 = $OVA_SHA256" >&2
        echo "  downloaded       = $actual" >&2
        rm -f "$OVA_PATH"
        exit 1
      fi

      echo "Talos OVA verified: $bytes bytes, sha256 $actual"
    EOT
  }
}

data "vcd_catalog" "faino" {
  name = "Faino"
}

resource "vcd_catalog_item" "talos-boot-image" {
  org     = data.vcd_org.this.name
  catalog = "Faino"

  name     = local.talos_catalog_id
  ova_path = local.talos_ova_path

  # depends_on gives ordering only. The provider's Update for this resource
  # touches nothing but the vApp template's name and description, so without an
  # explicit replacement trigger a version bump renames the image that is
  # already in the catalog and terraform plan stays clean. Measured on zeta: the
  # item called "talos-v1.13.8" still held the April 2025 build, every new node
  # rejected its machine config on grubUseUKICmdline, and both node replacement
  # and disaster recovery were broken while plan reported no changes.
  lifecycle {
    replace_triggered_by = [terraform_data.talos-ova]
  }

  depends_on = [terraform_data.talos-ova]
}

data "vcd_catalog_vapp_template" "talos-boot-image" {
  name       = local.talos_catalog_id
  catalog_id = data.vcd_catalog.faino.id
  depends_on = [vcd_catalog_item.talos-boot-image]
}
