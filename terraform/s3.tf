resource "aws_s3_bucket" "library" {
  bucket = var.library_bucket_name
  tags   = { Name = var.library_bucket_name }
}

resource "aws_s3_bucket" "setup" {
  bucket = var.setup_bucket_name
  tags   = { Name = var.setup_bucket_name }
}

# Upload Caddyfile rendered
resource "aws_s3_object" "caddy" {
  bucket = aws_s3_bucket.setup.id
  key    = "Caddyfile"
  content = templatefile("${var.setup_path}/Caddyfile.tpl", {
    admin_email = var.admin_email
    domain_name = var.domain_name
  })
}

# Upload remaining files
resource "aws_s3_object" "files" {
  for_each = { for f in fileset(var.setup_path, "**/*") : f => f if !endswith(f, ".tpl") }

  bucket = aws_s3_bucket.setup.id
  key    = each.value
  source = "${var.setup_path}/${each.value}"

  etag   = filemd5("${var.setup_path}/${each.value}")
}