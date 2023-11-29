output "queue_url" {
  value = aws_sqs_queue.pipe_source.url
}

output "queue_arn" {
  value = aws_sqs_queue.pipe_source.arn
}
