# -----------------
# Providers
# -----------------
provider "aws" {
  region = "us-east-1"
}

provider "azurerm" {
  features {}
}

# -----------------
# AWS PART
# -----------------

# 1) actual bucket
resource "aws_s3_bucket" "weather_app" {
  bucket = "weather-tracker-bucket-34538222" # must be globally unique
}

# 2) website config (new-style)
resource "aws_s3_bucket_website_configuration" "weather_site" {
  bucket = aws_s3_bucket.weather_app.id

  index_document { suffix = "index.html" }
  error_document { key = "error.html" }
}

# 3) public access block (allow public policy if you choose to add one)
resource "aws_s3_bucket_public_access_block" "public_access" {
  bucket                  = aws_s3_bucket.weather_app.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# 4) upload files
resource "aws_s3_object" "website_index" {
  bucket       = aws_s3_bucket.weather_app.id
  key          = "index.html"
  source       = "website/index.html"
  content_type = "text/html"
}

resource "aws_s3_object" "website_style" {
  bucket       = aws_s3_bucket.weather_app.id
  key          = "styles.css"
  source       = "website/styles.css"
  content_type = "text/css"
}

resource "aws_s3_object" "website_script" {
  bucket       = aws_s3_bucket.weather_app.id
  key          = "script.js"
  source       = "website/script.js"
  content_type = "application/javascript"
}

resource "aws_s3_object" "website_assets" {
  for_each = fileset("website/assets", "*")
  bucket   = aws_s3_bucket.weather_app.id
  key      = "assets/${each.value}"
  source   = "website/assets/${each.value}"
}

# -----------------
# AZURE PART
# -----------------

resource "azurerm_resource_group" "rg" {
  name     = "rg-static-website"
  location = "East US"
}

resource "azurerm_storage_account" "storage" {
  name                     = "sladeazureproj345382" # 3-24 chars, lowercase/numbers only
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
}

resource "azurerm_storage_account_static_website" "static" {
  storage_account_id = azurerm_storage_account.storage.id
  index_document     = "index.html"
  error_404_document = "error.html"
}

# Uploads to $web
resource "azurerm_storage_blob" "index_html" {
  name                   = "index.html"
  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = "text/html"
  source                 = "website/index.html"
  depends_on             = [azurerm_storage_account_static_website.static]
}

resource "azurerm_storage_blob" "styles_css" {
  name                   = "styles.css"
  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = "text/css"
  source                 = "website/styles.css"
  depends_on             = [azurerm_storage_account_static_website.static]
}

resource "azurerm_storage_blob" "script_js" {
  name                   = "script.js"
  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type           = "application/javascript"
  source                 = "website/script.js"
  depends_on             = [azurerm_storage_account_static_website.static]
}

resource "azurerm_storage_blob" "assets" {
  for_each               = fileset("website/assets", "**/*")
  name                   = "assets/${each.value}"
  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = "$web"
  type                   = "Block"
  content_type = lookup(
    {
      png  = "image/png"
      jpg  = "image/jpeg"
      jpeg = "image/jpeg"
      gif  = "image/gif"
      svg  = "image/svg+xml"
      webp = "image/webp"
    },
    split(".", each.value)[length(split(".", each.value)) - 1],
    "application/octet-stream"
  )
  source     = "website/assets/${each.value}"
  depends_on = [azurerm_storage_account_static_website.static]
}

# -----------------
# ROUTE 53 / DNS
# -----------------

# Hosted zone for sladesanctuary.com
resource "aws_route53_zone" "main" {
  name = "sladesanctuary.com"
}

# Health checks (hostnames only)
resource "aws_route53_health_check" "aws_health_check" {
  type              = "HTTPS"
  fqdn              = "d2x0zifluqede0.cloudfront.net"
  port              = 443
  request_interval  = 30
  failure_threshold = 3
}

resource "aws_route53_health_check" "azure_health_check" {
  type              = "HTTPS"
  fqdn              = "sladeazureproj345382.z13.web.core.windows.net"
  port              = 443
  request_interval  = 30
  failure_threshold = 3
}

# Apex -> CloudFront (no CNAME at apex; A-alias only)
resource "aws_route53_record" "apex_primary" {
  zone_id         = aws_route53_zone.main.zone_id
  name            = "sladesanctuary.com"
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = "d2x0zifluqede0.cloudfront.net"
    zone_id                = "Z2FDTNDATAQYW2" # CloudFront hosted zone ID (global & fixed)
    evaluate_target_health = true
  }
}

# www PRIMARY -> CloudFront (failover primary)
resource "aws_route53_record" "www_primary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.sladesanctuary.com"
  type    = "CNAME"
  records = ["d2x0zifluqede0.cloudfront.net"]
  ttl     = 300

  set_identifier = "www-primary"
  failover_routing_policy { type = "PRIMARY" }
  health_check_id = aws_route53_health_check.aws_health_check.id
}

# www SECONDARY -> Azure static site (failover secondary)
resource "aws_route53_record" "www_secondary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.sladesanctuary.com"
  type    = "CNAME"
  records = ["sladeazureproj345382.z13.web.core.windows.net"] # no https://
  ttl     = 300

  set_identifier = "www-secondary"
  failover_routing_policy { type = "SECONDARY" }
  health_check_id = aws_route53_health_check.azure_health_check.id
}

