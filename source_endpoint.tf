resource "aws_dms_endpoint" "source" {
  endpoint_id   = "ec2-mariadb-source"
  endpoint_type = "source"
  engine_name   = "mariadb"

  username = var.source_db_user
  password = var.source_db_password
  database_name = "employee_db"

  server_name = var.ec2_db_ip
  port        = 3306

  ssl_mode = "none"
}
