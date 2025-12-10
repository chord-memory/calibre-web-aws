# -----------------------------
# IAM Profile for calibre-server
# -----------------------------
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "calibre-server-profile"
  role = aws_iam_role.ec2_role.name
}


# -----------------------------
# AssumeRole policy for calibre-server
# -----------------------------
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}


# -----------------------------
# IAM Role for calibre-server
# -----------------------------
resource "aws_iam_role" "ec2_role" {
  name               = "calibre-server-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}


# -----------------------------
# SSM policy for calibre-server
# -----------------------------
resource "aws_iam_role_policy_attachment" "ec2_ssm_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


# --------------------------------------
# S3 Read-Only policy for calibre-server
# --------------------------------------
data "aws_iam_policy_document" "s3_readonly_for_ec2" {
  statement {
    sid = "AllowReadLibraryBucket"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.library.arn,
      "${aws_s3_bucket.library.arn}/*",
      aws_s3_bucket.setup.arn,
      "${aws_s3_bucket.setup.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "s3_readonly_for_ec2" {
  name   = "ec2-s3-readonly"
  policy = data.aws_iam_policy_document.s3_readonly_for_ec2.json
}

resource "aws_iam_role_policy_attachment" "ec2_s3_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_readonly_for_ec2.arn
}