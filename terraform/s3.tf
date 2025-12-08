resource "aws_s3_bucket" "library" {
  bucket = var.library_bucket_name
  tags   = { Name = var.library_bucket_name }
}

resource "aws_s3_bucket" "setup" {
  bucket = var.setup_bucket_name
  tags   = { Name = var.setup_bucket_name }
}

data "template_file" "caddy" {
  template = file("${var.setup_path}/Caddyfile.tpl")
  vars = {
    admin_email = var.admin_email
    domain_name = var.domain_name
  }
}

resource "aws_s3_object" "files" {
  for_each = fileset(var.setup_path, "**/*")

  bucket = aws_s3_bucket.setup.id
  key    = each.value
  source = "${var.setup_path}/${each.value}"

  etag = filemd5("${var.setup_path}/${each.value}")
}