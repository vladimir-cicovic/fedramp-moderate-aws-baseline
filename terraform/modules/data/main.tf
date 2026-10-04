# Aurora MySQL Serverless v2 (SC-8, SC-13, SC-28, SC-28(1), IA-2, IA-5, AU-2,
# CP-9, AC-3)

resource "aws_db_subnet_group" "this" {
  name        = "${var.name_prefix}-data"
  description = "Data-tier subnets, no internet route."
  subnet_ids  = var.subnet_ids
}

resource "aws_security_group" "db" {
  name        = "${var.name_prefix}-aurora"
  description = "MySQL from the private application subnets only."
  vpc_id      = var.vpc_id

  ingress {
    description = "MySQL from application subnets"
    protocol    = "tcp"
    from_port   = 3306
    to_port     = 3306
    cidr_blocks = var.allowed_cidrs
  }

  tags = { Name = "${var.name_prefix}-aurora" }
}

# Engine-level enforcement: no plaintext connections, audit log on.
resource "aws_rds_cluster_parameter_group" "this" {
  name        = "${var.name_prefix}-aurora-mysql8"
  family      = "aurora-mysql8.0"
  description = "TLS required, audit logging enabled."

  parameter {
    name  = "require_secure_transport"
    value = "ON"
  }

  parameter {
    name  = "server_audit_logging"
    value = "1"
  }

  parameter {
    name  = "server_audit_events"
    value = "CONNECT,QUERY_DCL,QUERY_DDL"
  }
}

# Pre-create the export log groups so they are encrypted and retained on our
# terms instead of RDS defaults.
resource "aws_cloudwatch_log_group" "exports" {
  for_each = toset(["audit", "error", "slowquery"])

  name              = "/aws/rds/cluster/${var.name_prefix}-aurora/${each.value}"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.logging_kms_key_arn
}

resource "aws_rds_cluster" "this" {
  #checkov:skip=CKV_AWS_326:Backtrack is not used; point-in-time recovery from automated backups covers CP-10 and costs nothing extra
  #checkov:skip=CKV_AWS_139:Deletion protection is a variable, off in the lab so terraform destroy works, on in production
  #checkov:skip=CKV2_AWS_8:Aurora automated backups cover the lab; AWS Backup plans with vault lock are a production item (CP-9, CP-6)
  cluster_identifier = "${var.name_prefix}-aurora"
  engine             = "aurora-mysql"
  engine_version     = var.engine_version
  database_name      = "app"

  master_username               = "dbadmin"
  manage_master_user_password   = true
  master_user_secret_kms_key_id = var.kms_key_arn

  db_subnet_group_name            = aws_db_subnet_group.this.name
  vpc_security_group_ids          = [aws_security_group.db.id]
  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name

  storage_encrypted                   = true
  kms_key_id                          = var.kms_key_arn
  iam_database_authentication_enabled = true
  enabled_cloudwatch_logs_exports     = ["audit", "error", "slowquery"]

  backup_retention_period      = var.backup_retention_days
  preferred_backup_window      = "03:00-04:00"
  preferred_maintenance_window = "sun:04:00-sun:05:00"
  copy_tags_to_snapshot        = true
  deletion_protection          = var.deletion_protection
  skip_final_snapshot          = var.skip_final_snapshot
  final_snapshot_identifier    = var.skip_final_snapshot ? null : "${var.name_prefix}-aurora-final"
  apply_immediately            = true

  serverlessv2_scaling_configuration {
    min_capacity             = var.min_capacity
    max_capacity             = var.max_capacity
    seconds_until_auto_pause = var.min_capacity == 0 ? 600 : null
  }

  depends_on = [aws_cloudwatch_log_group.exports]
}

resource "aws_rds_cluster_instance" "writer" {
  #checkov:skip=CKV_AWS_118:Enhanced monitoring adds an agent and cost for OS metrics the lab does not use; Performance Insights is on
  identifier         = "${var.name_prefix}-aurora-1"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  publicly_accessible        = false
  auto_minor_version_upgrade = true

  performance_insights_enabled    = true
  performance_insights_kms_key_id = var.kms_key_arn
}
