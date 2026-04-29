# IAM Role for EventBridge Scheduler
resource "aws_iam_role" "eventbridge_scheduler" {
  name = "${var.project_name}-${var.environment}-eventbridge-scheduler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-${var.environment}-eventbridge-scheduler-role"
  }
}

# IAM Policy for EventBridge Scheduler to manage Aurora
resource "aws_iam_role_policy" "eventbridge_scheduler_aurora" {
  name = "${var.project_name}-${var.environment}-eventbridge-scheduler-aurora-policy"
  role = aws_iam_role.eventbridge_scheduler.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds:StartDBCluster",
          "rds:StopDBCluster"
        ]
        Resource = aws_rds_cluster.knowledge_base.arn
      }
    ]
  })
}

# EventBridge Scheduler: Aurora Start (9:00 JST / 00:00 UTC)
resource "aws_scheduler_schedule" "aurora_start" {
  name       = "${var.project_name}-${var.environment}-aurora-start"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = var.aurora_start_cron

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:rds:startDBCluster"
    role_arn = aws_iam_role.eventbridge_scheduler.arn

    input = jsonencode({
      DbClusterIdentifier = aws_rds_cluster.knowledge_base.cluster_identifier
    })
  }

  state = "ENABLED"
}

# EventBridge Scheduler: Aurora Stop (19:00 JST / 10:00 UTC)
resource "aws_scheduler_schedule" "aurora_stop" {
  name       = "${var.project_name}-${var.environment}-aurora-stop"
  group_name = "default"

  flexible_time_window {
    mode = "OFF"
  }

  schedule_expression = var.aurora_stop_cron

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:rds:stopDBCluster"
    role_arn = aws_iam_role.eventbridge_scheduler.arn

    input = jsonencode({
      DbClusterIdentifier = aws_rds_cluster.knowledge_base.cluster_identifier
    })
  }

  state = "ENABLED"
}
