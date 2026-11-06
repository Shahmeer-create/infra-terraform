# ---------------------------------------------------------------------------
# CloudWatch Alarms and Dashboard (all under count = enable_alarms ? 1 : 0)
# ---------------------------------------------------------------------------

# SNS Topic for alarm notifications
resource "aws_sns_topic" "alarms" {
  count = var.enable_alarms ? 1 : 0

  name = "${local.name_prefix}-alarms"

  tags = {
    Name = "${local.name_prefix}-alarms"
  }
}

# Email subscription (only when alarm_email is set)
resource "aws_sns_topic_subscription" "email" {
  count = var.enable_alarms && var.alarm_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alarms[0].arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ---------------------------------------------------------------------------
# ECS Alarms
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS CPU utilization > 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.backend.name
  }

  alarm_actions = var.enable_alarms && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
  ok_actions    = var.enable_alarms && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = { Name = "${local.name_prefix}-ecs-cpu-high" }
}

resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-ecs-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "ECS Memory utilization > 85%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.backend.name
  }

  alarm_actions = var.enable_alarms && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
  ok_actions    = var.enable_alarms && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = { Name = "${local.name_prefix}-ecs-memory-high" }
}

resource "aws_cloudwatch_metric_alarm" "ecs_task_count_low" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-ecs-task-count-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RunningTaskCount"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = var.desired_count
  alarm_description   = "ECS running task count below desired"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = aws_ecs_cluster.main.name
    ServiceName = aws_ecs_service.backend.name
  }

  alarm_actions = var.enable_alarms && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
  ok_actions    = var.enable_alarms && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = { Name = "${local.name_prefix}-ecs-task-count-low" }
}

# ---------------------------------------------------------------------------
# ALB Alarms
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "alb_5xx_rate" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-alb-5xx-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  threshold           = 5
  alarm_description   = "ALB 5XX error rate > 5%"
  treat_missing_data  = "notBreaching"

  metric_query {
    id          = "error_rate"
    expression  = "(m1/m2)*100"
    label       = "5XX Rate"
    return_data = true
  }

  metric_query {
    id = "m1"
    metric {
      metric_name = "HTTPCode_ELB_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"
      dimensions = {
        LoadBalancer = aws_lb.main.arn_suffix
      }
    }
  }

  metric_query {
    id = "m2"
    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = 300
      stat        = "Sum"
      dimensions = {
        LoadBalancer = aws_lb.main.arn_suffix
      }
    }
  }

  alarm_actions = var.enable_alarms && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
  ok_actions    = var.enable_alarms && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = { Name = "${local.name_prefix}-alb-5xx-rate" }
}

resource "aws_cloudwatch_metric_alarm" "alb_response_time" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-alb-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 2
  alarm_description   = "ALB average response time > 2s"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  alarm_actions = var.enable_alarms && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
  ok_actions    = var.enable_alarms && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = { Name = "${local.name_prefix}-alb-response-time" }
}

resource "aws_cloudwatch_metric_alarm" "alb_rejected_connections" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-alb-rejected-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "RejectedConnectionCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "ALB rejected connections > 0"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  alarm_actions = var.enable_alarms && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
  ok_actions    = var.enable_alarms && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = { Name = "${local.name_prefix}-alb-rejected-connections" }
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  count = var.enable_alarms ? 1 : 0

  alarm_name          = "${local.name_prefix}-alb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0
  alarm_description   = "ALB unhealthy host count > 0"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
    TargetGroup  = aws_lb_target_group.backend.arn_suffix
  }

  alarm_actions = var.enable_alarms && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []
  ok_actions    = var.enable_alarms && var.alarm_email != "" ? [aws_sns_topic.alarms[0].arn] : []

  tags = { Name = "${local.name_prefix}-alb-unhealthy-hosts" }
}

# ---------------------------------------------------------------------------
# CloudWatch Dashboard
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_dashboard" "main" {
  count = var.enable_alarms ? 1 : 0

  dashboard_name = "${local.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ECS CPU & Memory Utilization"
          region = var.aws_region
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.backend.name],
            ["AWS/ECS", "MemoryUtilization", "ClusterName", aws_ecs_cluster.main.name, "ServiceName", aws_ecs_service.backend.name],
          ]
          view   = "timeSeries"
          stat   = "Average"
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title  = "ALB Request Count & Response Time"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix],
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.main.arn_suffix],
          ]
          view   = "timeSeries"
          stat   = "Sum"
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ALB 5XX Errors"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", aws_lb.main.arn_suffix],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", aws_lb.main.arn_suffix],
          ]
          view   = "timeSeries"
          stat   = "Sum"
          period = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          title  = "ALB Healthy/Unhealthy Host Count"
          region = var.aws_region
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", aws_lb.main.arn_suffix, "TargetGroup", aws_lb_target_group.backend.arn_suffix],
            ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", aws_lb.main.arn_suffix, "TargetGroup", aws_lb_target_group.backend.arn_suffix],
          ]
          view   = "timeSeries"
          stat   = "Average"
          period = 60
        }
      }
    ]
  })
}
