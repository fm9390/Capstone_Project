output "db_host" {
  value = aws_db_instance.discogs_db.address
}

output "website_url" {
  value = "http://${aws_s3_bucket.wordpress.bucket}.s3-website.${var.region}.amazonaws.com"
}
