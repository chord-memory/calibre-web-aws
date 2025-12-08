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

data "template_file" "userdata" {
  template = file("${path.module}/user_data.sh.tpl")
  vars = {
    domain_name    = var.domain_name
    admin_user     = var.admin_user
    admin_pass     = var.admin_pass
    config_volume  = var.config_volume_device_mnt
    library_volume = var.library_volume_device_mnt
    library_bucket = aws_s3_bucket.library.bucket
    setup_bucket   = aws_s3_bucket.setup.bucket
  }
}

resource "aws_instance" "ec2" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]

  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }
  user_data = data.template_file.userdata.rendered

  tags = { Name = "calibre-server" }
}

resource "aws_eip" "ec2_eip" {
  instance = aws_instance.ec2.id
  vpc      = true
  tags     = { Name = "calibre-eip" }
}