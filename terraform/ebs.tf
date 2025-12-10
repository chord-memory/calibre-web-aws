resource "aws_ebs_volume" "config" {
  availability_zone = aws_subnet.public.availability_zone
  size              = var.config_volume_size_gb
  type              = "gp3"

  lifecycle {
    prevent_destroy = true 
  }
  tags = { Name = "calibre-config" }
}

resource "aws_volume_attachment" "config_attach" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.config.id
  instance_id = aws_instance.ec2.id
}

resource "aws_ebs_volume" "library" {
  availability_zone = aws_subnet.public.availability_zone
  size              = var.library_volume_size_gb
  type              = "gp3"

  lifecycle {
    prevent_destroy = true 
  }
  tags = { Name = "calibre-library" }
}

resource "aws_volume_attachment" "library_attach" {
  device_name = "/dev/sdg"
  volume_id   = aws_ebs_volume.library.id
  instance_id = aws_instance.ec2.id
}