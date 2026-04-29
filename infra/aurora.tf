# Aurora Subnet Group
resource "aws_db_subnet_group" "aurora" {
  name       = "${var.project_name}-${var.environment}-aurora-subnet"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.project_name}-${var.environment}-aurora-subnet"
  }
}

# Aurora Security Group
resource "aws_security_group" "aurora" {
  name        = "${var.project_name}-${var.environment}-aurora-sg"
  description = "Security group for Aurora PostgreSQL"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from Lambda"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-aurora-sg"
  }
}

# Aurora Cluster Parameter Group
resource "aws_rds_cluster_parameter_group" "aurora" {
  name        = "${var.project_name}-${var.environment}-aurora-cluster-pg"
  family      = "aurora-postgresql16"
  description = "Aurora PostgreSQL 16 cluster parameter group"

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements,pgvector"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-aurora-cluster-pg"
  }
}

# Aurora DB Parameter Group
resource "aws_db_parameter_group" "aurora" {
  name        = "${var.project_name}-${var.environment}-aurora-db-pg"
  family      = "aurora-postgresql16"
  description = "Aurora PostgreSQL 16 DB parameter group"

  tags = {
    Name = "${var.project_name}-${var.environment}-aurora-db-pg"
  }
}

# Generate random password for Aurora master user
resource "random_password" "aurora_master" {
  length  = 32
  special = true
}

# Store Aurora master password in Secrets Manager
resource "aws_secretsmanager_secret" "aurora_master" {
  name                    = "${var.project_name}-${var.environment}-aurora-master-password"
  description             = "Aurora master user password"
  recovery_window_in_days = 7

  tags = {
    Name = "${var.project_name}-${var.environment}-aurora-master-password"
  }
}

resource "aws_secretsmanager_secret_version" "aurora_master" {
  secret_id = aws_secretsmanager_secret.aurora_master.id
  secret_string = jsonencode({
    username = var.aurora_master_username
    password = random_password.aurora_master.result
  })
}

# Aurora Cluster
resource "aws_rds_cluster" "knowledge_base" {
  cluster_identifier              = "${var.project_name}-${var.environment}-kb"
  engine                          = "aurora-postgresql"
  engine_mode                     = "provisioned"
  engine_version                  = "16.2"
  database_name                   = "knowledge_base"
  master_username                 = var.aurora_master_username
  master_password                 = random_password.aurora_master.result
  db_subnet_group_name            = aws_db_subnet_group.aurora.name
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora.name
  vpc_security_group_ids          = [aws_security_group.aurora.id]
  skip_final_snapshot             = true
  enabled_cloudwatch_logs_exports = ["postgresql"]
  backup_retention_period         = 7

  serverlessv2_scaling_configuration {
    min_capacity = var.aurora_min_capacity
    max_capacity = var.aurora_max_capacity
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-kb"
  }
}

# Aurora Cluster Instance
resource "aws_rds_cluster_instance" "knowledge_base" {
  identifier              = "${var.project_name}-${var.environment}-kb-instance-1"
  cluster_identifier      = aws_rds_cluster.knowledge_base.id
  instance_class          = "db.serverless"
  engine                  = aws_rds_cluster.knowledge_base.engine
  engine_version          = aws_rds_cluster.knowledge_base.engine_version
  db_parameter_group_name = aws_db_parameter_group.aurora.name
  publicly_accessible     = false

  tags = {
    Name = "${var.project_name}-${var.environment}-kb-instance-1"
  }
}
