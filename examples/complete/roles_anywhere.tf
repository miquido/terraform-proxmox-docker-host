# Credentials for the DNS-01 challenge: Traefik on the VM authenticates to AWS with a client certificate (IAM Roles
# Anywhere) and gets short-lived credentials of a role that can change records only in the zone of the domain.
# The CA below is a throwaway one for machine identity only; in real setups use your own CA or a shared identity.
resource "tls_private_key" "ca" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "ca" {
  private_key_pem       = tls_private_key.ca.private_key_pem
  is_ca_certificate     = true
  validity_period_hours = 87600 # 10 years

  subject {
    common_name  = "${var.name}-ca"
    organization = "Miquido"
  }

  allowed_uses = ["cert_signing", "crl_signing", "digital_signature"]
}

resource "tls_private_key" "client" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "client" {
  private_key_pem = tls_private_key.client.private_key_pem

  subject {
    common_name  = "${var.name}-traefik-client"
    organization = "Miquido"
  }
}

# Valid for a year. After that the provider issues a new one, which changes the cloud-init and replaces the VM.
resource "tls_locally_signed_cert" "client" {
  cert_request_pem   = tls_cert_request.client.cert_request_pem
  ca_private_key_pem = tls_private_key.ca.private_key_pem
  ca_cert_pem        = tls_self_signed_cert.ca.cert_pem

  validity_period_hours = 8760
  allowed_uses          = ["client_auth", "digital_signature", "key_encipherment"]
}

resource "aws_rolesanywhere_trust_anchor" "main" {
  name    = var.name
  enabled = true

  source {
    source_type = "CERTIFICATE_BUNDLE"
    source_data {
      x509_certificate_data = tls_self_signed_cert.ca.cert_pem
    }
  }
}

resource "aws_rolesanywhere_profile" "main" {
  name      = var.name
  role_arns = [aws_iam_role.dns_challenge.arn]
  enabled   = true
}

resource "aws_iam_role" "dns_challenge" {
  name = "${var.name}-dns-challenge"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "rolesanywhere.amazonaws.com" }
        Action    = ["sts:AssumeRole", "sts:TagSession", "sts:SetSourceIdentity"]
        Condition = {
          ArnEquals = { "aws:SourceArn" = aws_rolesanywhere_trust_anchor.main.arn }
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "dns_challenge" {
  name = "route53-acme"
  role = aws_iam_role.dns_challenge.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "route53:GetChange",
          "route53:ChangeResourceRecordSets",
        ]
        Resource = [
          aws_route53_zone.main.arn,
          "arn:aws:route53:::change/*",
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["route53:ListHostedZones", "route53:ListHostedZonesByName", "route53:ListResourceRecordSets"]
        Resource = "*"
      },
    ]
  })
}
