data "aws_ami" "ubuntu" {
  most_recent = true
  owners = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  user_data_path = "${path.module}/user_data.sh.tpl"
}

resource "terraform_data" "user_data_hash" {
  input = filemd5(local.user_data_path)
}

resource "aws_instance" "ec2" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name

  root_block_device {
    volume_type = "gp3"
  }

  lifecycle {
    replace_triggered_by = [
      terraform_data.user_data_hash
    ]
  }
  user_data = templatefile(local.user_data_path, {
    domain_name       = var.domain_name
    admin_user        = var.admin_user
    admin_pass        = var.admin_pass
    lib_vol_nodash    = replace(aws_ebs_volume.library.id, "-", "")
    config_vol_nodash = replace(aws_ebs_volume.config.id, "-", "")
    library_bucket    = aws_s3_bucket.library.bucket
    setup_bucket      = aws_s3_bucket.setup.bucket
  })

  tags = { Name = "calibre-server" }
}

resource "aws_eip" "ec2_eip" {
  instance = aws_instance.ec2.id
  domain   = "vpc"
  tags     = { Name = "calibre-eip" }
}

resource "aws_route53_record" "cweb" {
  zone_id = var.hosted_zone_id
  name    = "${var.domain_name}."
  type    = "A"
  ttl     = 3600
  records = [aws_eip.ec2_eip.public_ip]
}