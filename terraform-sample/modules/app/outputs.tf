output "ecs_cluster_name" {
  value = aws_ecs_cluster.app_cluster.name
}

output "ecs_service_name" {
  value = aws_ecs_service.app_service.name
}

output "ecs_task_family" {
  value = aws_ecs_task_definition.app_task_definition.family
}

output "ecs_task_revision" {
  value = aws_ecs_task_definition.app_task_definition.revision
}


output "esc_task_definition_arn" {
  value = aws_ecs_task_definition.app_task_definition.arn
}

output "tg_1" {
  value = aws_lb_target_group.app_tg_1
}

output "tg_2" {
  value = aws_lb_target_group.app_tg_2
}

output "listener_green" {
  # countを利用したリソースはlistになるので、インデックスを指定する
  value = length(var.certificate_arn) > 0  ? aws_lb_listener.app_listener_green_https.0 : aws_lb_listener.app_listener_green_http.0
}

output "listener_blue" {
  value = aws_lb_listener.app_listener_blue
}