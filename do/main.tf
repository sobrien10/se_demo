data "terraform_remote_state" "aws_demo" {
  backend = "local"

  config = {
    path = "${path.module}/../terraform.tfstate"
  }
}

provider "bigip" {
  address = data.terraform_remote_state.aws_demo.outputs.f5_tmui
  username = data.terraform_remote_state.aws_demo.outputs.f5_user
  password = data.terraform_remote_state.aws_demo.outputs.f5_password
}

resource "bigip_do"  "do-example" {
    do_json = templatefile("do.tmpl", {
        hostname    = jsonencode("arch-bigip.f5demo.net"),
        external_ip = jsonencode("${data.terraform_remote_state.aws_demo.outputs.f5_pub_ip}/24"),
        external_gw = jsonencode(cidrhost(data.terraform_remote_state.aws_demo.outputs.f5_pub_cidr, 1)),
        dns         = jsonencode("8.8.8.8"),
        ntp         = jsonencode("time.google.com")
    })
    timeout = 120
}