terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.67.0"
    }
  }
}

provider "aws" {
  region = var.region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  token      = var.aws_session_token
}

# Create a Web ACL
resource "aws_wafv2_web_acl" "web_acl" {
  name        = "OWASP-JuiceShop-WAF"
  description = "WAF for OWASP Juice Shop application"
  scope       = "REGIONAL" # Use REGIONAL for ALB; CLOUDFRONT for CloudFront

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "OWASP-JuiceShop-WAF"
    sampled_requests_enabled   = true
  }

  # Custom Rule: Allow requests from France only
  rule {
    name     = "BlockNonFrenchIPs"
    priority = 0
    action {
      block {}
    }

  statement {
    not_statement {
      statement {
        geo_match_statement {
          country_codes = ["FR"]
        }
      }
    }
  }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "BlockNonFrenchIPs"
      sampled_requests_enabled   = true
    }
  }

  # Managed Rule Group: Anonymous IP List
  rule {
    name     = "AWSManagedRulesAnonymousIpList"
    priority = 1
    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAnonymousIpList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AnonymousIpList"
      sampled_requests_enabled   = true
    }
  }

  # Managed Rule Group: Common Rule Set
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 2
    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Managed Rule Group: Known Bad Inputs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3
    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Managed Rule Group: SQL Injection
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 4
    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "SQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }
}

# Associate WAF Web ACL with ALB
resource "aws_wafv2_web_acl_association" "alb_association" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.web_acl.arn
}