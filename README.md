# AWS DMS Migration: EC2 → RDS (Terraform)

End-to-end guide to migrate a MySQL/MariaDB database from an EC2 instance to Amazon RDS using AWS Database Migration Service (DMS), fully automated with Terraform.

---

## Architecture Overview

```
EC2 (MySQL/MariaDB)
        │
        ▼ (port 3306)
AWS DMS Replication Instance
        │
        ▼ (port 3306)
Amazon RDS (MySQL 8.0)
```

**Migration Modes:**
- **Full Load** – copies all existing data
- **CDC (Change Data Capture)** – continuously syncs new changes in real-time

---

## Prerequisites

| Requirement | Details |
|---|---|
| AWS Account | With sufficient IAM permissions |
| Terraform | >= 1.0 |
| AWS CLI | Configured via `aws configure` |
| EC2 Key Pair | For SSH access |

**Security Group Rules Required:**

| Source | Destination | Port |
|---|---|---|
| DMS Replication Instance | EC2 MySQL | 3306 |
| DMS Replication Instance | RDS MySQL | 3306 |
| Your IP | EC2 (SSH) | 22 |

---

## Project Structure

```
dms-migration/
│
├── main.tf
├── ec2.tf
├── rds.tf
├── dms.tf
├── variables.tf
├── outputs.tf
└── README.md
```

---

## Step 1 — EC2 Setup: Install MySQL/MariaDB

SSH into your EC2 instance:

```bash
ssh -i mykey.pem ec2-user@<EC2-PUBLIC-IP>
```

Install and start MariaDB:

```bash
sudo yum install mariadb-server -y
sudo systemctl enable mariadb
sudo systemctl start mariadb
```

Secure the installation:

```bash
sudo mysql_secure_installation
```

Login to MySQL:

```bash
sudo mysql -u root
```

---

## Step 2 — Create Database, Table & DMS User

Inside the MySQL CLI, run:

```sql
CREATE DATABASE employee_db;

USE employee_db;

CREATE TABLE employees (
    id     INT AUTO_INCREMENT PRIMARY KEY,
    name   VARCHAR(50),
    salary INT
);
```

Create a dedicated user for DMS:

```sql
CREATE USER 'dms_user'@'%' IDENTIFIED BY 'DmsUser@123';
GRANT ALL PRIVILEGES ON *.* TO 'dms_user'@'%';
FLUSH PRIVILEGES;
```

---

## Step 3 — Enable Binary Logging (Required for CDC)

Open the MariaDB config file:

```bash
sudo nano /etc/my.cnf.d/server.cnf
```

Add the following inside the `[mysqld]` section:

```ini
log_bin=mysqld-bin
binlog_format=ROW
binlog_checksum=NONE
gtid_mode=ON
enforce_gtid_consistency=ON
```

Restart MariaDB and verify:

```bash
sudo systemctl restart mariadb
```

```sql
SHOW VARIABLES LIKE 'log_bin';
```

> **Note:** Binary logging is mandatory for CDC. Without it, real-time replication will not work.

---

## Step 4 — Create RDS MySQL Instance

**`rds.tf`**

```hcl
resource "aws_db_instance" "my_rds" {
  engine              = "mysql"
  engine_version      = "8.0"
  instance_class      = "db.t3.micro"
  allocated_storage   = 20
  db_name             = "employee_db"
  username            = "admin"
  password            = "Admin12345!"
  publicly_accessible = true
  skip_final_snapshot = true
}
```

---

## Step 5 — DMS Replication Instance & Endpoints

**`dms.tf` — Replication Instance**

```hcl
resource "aws_dms_replication_instance" "dms" {
  replication_instance_id    = "my-dms-repl"
  replication_instance_class = "dms.t3.medium"
  allocated_storage          = 50
}
```

**Source Endpoint (EC2 MySQL)**

```hcl
resource "aws_dms_endpoint" "source" {
  endpoint_id   = "source-mysql"
  endpoint_type = "source"
  engine_name   = "mysql"

  username      = "dms_user"
  password      = "DmsUser@123"
  server_name   = aws_instance.ec2_instance.private_ip
  port          = 3306
  database_name = "employee_db"
}
```

**Target Endpoint (RDS MySQL)**

```hcl
resource "aws_dms_endpoint" "target" {
  endpoint_id   = "target-rds"
  endpoint_type = "target"
  engine_name   = "mysql"

  username      = aws_db_instance.my_rds.username
  password      = aws_db_instance.my_rds.password
  server_name   = aws_db_instance.my_rds.address
  port          = 3306
  database_name = "employee_db"
}
```

---

## Step 6 — DMS Migration Task (Full Load + CDC)

```hcl
resource "aws_dms_replication_task" "migration" {
  replication_task_id      = "ec2-to-rds-task"
  migration_type           = "cdc"
  replication_instance_arn = aws_dms_replication_instance.dms.arn
  source_endpoint_arn      = aws_dms_endpoint.source.arn
  target_endpoint_arn      = aws_dms_endpoint.target.arn

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
```

> **Note:** The `%` wildcard in `table-name` automatically includes all tables under `employee_db`.

---

## Step 7 — Deploy with Terraform

Run the following commands in your project directory:

```bash
terraform init
terraform plan
terraform apply -auto-approve
```

---

## Step 8 — Validate the Migration

Insert test data on EC2 MySQL:

```sql
INSERT INTO employees (name, salary) VALUES
('Test User',    40000),
('Amit Patidar', 55000),
('Riya Sharma',  50000);
```

Verify on RDS MySQL:

```sql
SELECT * FROM employees;
```

All 3 rows should appear. Any new inserts on EC2 will automatically sync to RDS in real-time — no task restart needed.

---

## Troubleshooting

| Issue | Cause | Fix |
|---|---|---|
| No CDC / replication not working | Binary logging not enabled | Enable `log_bin` and restart MariaDB (Step 3) |
| DMS cannot connect to source or target | Security group rules missing | Allow DMS → EC2 and DMS → RDS on port 3306 |
| Tables not copied | Wrong table mapping config | Use `%` wildcard in `table_mappings` |
| RDS not updating after inserts | Task mode is wrong | Use CDC mode, not "Migrate once" |

---

## References

- [AWS DMS Documentation](https://docs.aws.amazon.com/dms/latest/userguide/Welcome.html)
- [Terraform AWS DMS Resources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dms_replication_instance)
- [AWS RDS MySQL](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_MySQL.html)
