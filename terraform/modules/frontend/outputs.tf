output "bucket_name" {
  value = aws_s3_bucket.frontend.bucket
}

output "distribution_id" {
  value = aws_cloudfront_distribution.frontend.id
}

output "distribution_arn" {
  value = aws_cloudfront_distribution.frontend.arn
}

output "bucket_arn" {
  value = aws_s3_bucket.frontend.arn
}

output "url" {
  value = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}
