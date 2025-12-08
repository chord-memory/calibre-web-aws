# -----------------------------
# SSM policy for calibre-server
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

resource "aws_iam_role" "ec2_role" {
  name               = "calibre-server-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

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
      aws_s3_bucket.library_bucket.arn,
      "${aws_s3_bucket.library_bucket.arn}/*"
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