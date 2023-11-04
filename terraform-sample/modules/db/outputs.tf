output "db_host" {
  value = aws_rds_cluster.aurora_serverless_mysql80.endpoint
}

output "db_port" {
  value = aws_rds_cluster.aurora_serverless_mysql80.port
}
