output "job_queue_arn" {
  value = aws_batch_job_queue.job_queue.arn
}

output "error_handler" {
  value = module.error_handler.lambda_function
}

output "success_handler" {
  value = module.success_handler.lambda_function
}
