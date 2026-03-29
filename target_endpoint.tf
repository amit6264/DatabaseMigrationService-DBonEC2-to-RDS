resource "aws_dms_endpoint" "target" {
  endpoint_id   = "rds-mysql-target"
  endpoint_type = "target"
  engine_name   = "mysql"

  username = var.target_db_user
  password = var.target_db_password
  database_name = "employee_db"

  server_name = var.rds_endpoint
  port        = 3306

  ssl_mode = "none"
}
