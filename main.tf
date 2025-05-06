variable "vcd_org_name" {
  type = string
}

data "vcd_org" "this" {
  name = var.vcd_org_name
}
