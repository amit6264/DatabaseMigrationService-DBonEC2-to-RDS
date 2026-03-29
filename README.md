README.md – End-to-End AWS DMS Migration (EC2 → RDS) using Terraform

This guide explains how to migrate a MySQL/MariaDB database running on an EC2 instance to Amazon RDS MySQL using AWS DMS, fully automated with Terraform.

It covers:

EC2 MySQL setup (installation, users, permissions)
Enabling binary logging (needed for CDC)
Creating RDS MySQL instance
Creating DMS Replication Instance
Creating Source & Target Endpoints
Creating Migration Tasks (Full Load + CDC)
Testing the replication
1. Prerequisites
Tools Required
AWS Account on Amazon Web Services
Terraform installed (>=1.0)
AWS CLI configured (aws configure)
Key Pair for EC2 login
Security Groups allowing:
DMS → EC2 MySQL (3306)
DMS → RDS MySQL (3306)
Your IP → EC2 SSH (22)
Your IP → RDS MySQL (3306 optional)
2. Step 1 — Create EC2 Instance & Install MySQL/MariaDB

SSH into EC2:

ssh -i mykey.pem ec2-user@<EC2-PUBLIC-IP>
Install MariaDB (or MySQL)
sudo yum install mariadb-server -y
sudo systemctl enable mariadb
sudo systemctl start mariadb
Secure DB
sudo mysql_secure_installation
Login to MySQL
sudo mysql -u root
3. Step 2 — Create Database & User

Inside MySQL CLI:

CREATE DATABASE employee_db;

USE employee_db;

CREATE TABLE employees (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50),
    salary INT
);

Create user for DMS:

CREATE USER 'dms_user'@'%' IDENTIFIED BY 'DmsUser@123';
GRANT ALL PRIVILEGES ON *.* TO 'dms_user'@'%';
FLUSH PRIVILEGES;
4. Step 3 — Enable Binary Logging (Required for CDC)

Edit server configuration:

sudo nano /etc/my.cnf.d/server.cnf

Add inside [mysqld] section:

log_bin=mysqld-bin
binlog_format=ROW
binlog_checksum=NONE
gtid_mode=ON
enforce_gtid_consistency=ON

Restart DB:

sudo systemctl restart mariadb

Verify:

SHOW VARIABLES LIKE 'log_bin';
5. Step 4 — Create RDS MySQL Instance

You can create manually OR via Terraform.

Example Terraform resource:

resource "aws_db_instance" "my_rds" {
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  db_name              = "employee_db"
  username             = "admin"
  password             = "Admin12345!"
  publicly_accessible  = true
  skip_final_snapshot  = true
}
6. Step 5 — Terraform for DMS Migration

Create the following Terraform resources:

6.1 DMS Replication Instance
resource "aws_dms_replication_instance" "dms" {
  replication_instance_id = "my-dms-repl"
  replication_instance_class = "dms.t3.medium"
  allocated_storage = 50
}
6.2 Source Endpoint (EC2 MySQL)
resource "aws_dms_endpoint" "source" {
  endpoint_id   = "source-mysql"
  endpoint_type = "source"
  engine_name   = "mysql"

  username = "dms_user"
  password = "DmsUser@123"
  server_name = aws_instance.ec2_instance.private_ip
  port = 3306
  database_name = "employee_db"
}
6.3 Target Endpoint (RDS MySQL)
resource "aws_dms_endpoint" "target" {
  endpoint_id   = "target-rds"
  endpoint_type = "target"
  engine_name   = "mysql"

  username = aws_db_instance.my_rds.username
  password = aws_db_instance.my_rds.password
  server_name = aws_db_instance.my_rds.address
  port = 3306
  database_name = "employee_db"
}
6.4 DMS Migration Task (Full Load + CDC)
resource "aws_dms_replication_task" "migration" {
  replication_task_id          = "ec2-to-rds-task"
  migration_type               = "cdc"
  replication_instance_arn     = aws_dms_replication_instance.dms.arn
  source_endpoint_arn          = aws_dms_endpoint.source.arn
  target_endpoint_arn          = aws_dms_endpoint.target.arn

  table_mappings = <<EOF
{
  "rules": [
    {
      "rule-type": "selection",
      "rule-id": "1",
      "rule-name": "1",
      "object-locator": {
        "schema-name": "employee_db",
        "table-name": "%"
      },
      "rule-action": "include"
    }
  ]
}
EOF
}
7. Deploy All Terraform Code
terraform init
terraform plan
terraform apply -auto-approve
8. Step 6 — Validate Migration
Insert Data in EC2 MySQL
INSERT INTO employees (name, salary) VALUES
('Test User', 40000),
('Amit Patidar', 55000),
('Riya Sharma', 50000);
Check RDS MySQL
select * from employees;

You must see all rows replicated.

9. Step 7 — Continuous Sync (CDC)

Because:

log_bin=ON
binlog_format=ROW

Any new inserts on EC2 MySQL should automatically appear in RDS without restarting task.

10. Troubleshooting
Issue	Cause	Fix
No CDC	Binary logging not enabled	Enable log_bin & restart MariaDB
DMS cannot connect	SG rules missing	Allow DMS → EC2 and DMS → RDS on 3306
Tables not copied	Wrong table mapping	Use % wildcard
RDS not updating	Restarted task incorrectly	Use CDC mode, not Migrate once
11. Project Structure
dms-migration/
│
├── main.tf
├── ec2.tf
├── rds.tf
├── dms.tf
├── variables.tf
├── outputs.tf
└── README.md
