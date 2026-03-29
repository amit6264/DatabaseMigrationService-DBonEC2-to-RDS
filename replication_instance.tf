resource "aws_dms_replication_instance" "this" {
  replication_instance_id       = var.replication_instance_id
  replication_instance_class    = var.replication_instance_class
  allocated_storage             = 50
  publicly_accessible           = true
  apply_immediately             = true

  tags = {
    Name = "dms-replication-instance"
  }
}
