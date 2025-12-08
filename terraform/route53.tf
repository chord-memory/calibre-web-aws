data "aws_route53_zone" "zone" {
  id = var.hosted_zone_id
}

resource "aws_route53_record" "cweb" {
  zone_id = data.aws_route53_zone.zone.id
  name    = var.domain_name
  type    = "A"
  ttl     = 300
  records = [aws_eip.ec2_eip.public_ip]
}