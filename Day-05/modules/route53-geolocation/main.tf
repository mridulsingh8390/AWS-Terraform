resource "aws_route53_health_check" "regional" {
  fqdn              = var.alb_dns_name
  port              = 443
  type              = "HTTPS"
  resource_path     = var.health_check_path
  failure_threshold = 3
  request_interval  = 30

  tags = merge(var.tags, { Name = "${var.set_identifier}-health-check" })
}

resource "aws_route53_record" "regional" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  set_identifier  = var.set_identifier
  health_check_id = aws_route53_health_check.regional.id

  geolocation_routing_policy {
    continent   = var.continent
    country     = var.country
    subdivision = var.subdivision
  }

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}
