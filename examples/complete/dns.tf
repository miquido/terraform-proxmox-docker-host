# The Route53 zone of the domain. The module creates no DNS records: the example points the apex and the wildcard
# at the VM (a private address is fine, the DNS-01 challenge only needs the zone to be delegated).
resource "aws_route53_zone" "main" {
  name = var.domain
}

resource "aws_route53_record" "apex" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain
  type    = "A"
  ttl     = 300
  records = [module.docker_host.ip]
}

resource "aws_route53_record" "wildcard" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "*.${var.domain}"
  type    = "A"
  ttl     = 300
  records = [module.docker_host.ip]
}
