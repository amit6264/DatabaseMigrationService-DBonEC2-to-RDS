variable "region" {
  default = "eu-north-1"
}

variable "replication_instance_class" {
  default = "dms.t3.micro"
}

variable "replication_instance_id" {
  default = "ec2-rds-replication-instance"
}

variable "source_db_user" {
  default = "root"
}

variable "source_db_password" {
  default = "amit123"
}

variable "target_db_user" {
  default = "admin"
}

variable "target_db_password" {
  default = "cloud123"
}

variable "rds_endpoint" {
  description = "RDS endpoint hostname only"
}

variable "ec2_db_ip" {
  description = "EC2 private IP running MariaDB"
}
