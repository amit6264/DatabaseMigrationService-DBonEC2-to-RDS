resource "aws_dms_replication_task" "full_load" {
  replication_task_id          = "full-load-task"
  migration_type               = "full-load"
  replication_instance_arn     = aws_dms_replication_instance.this.replication_instance_arn
  source_endpoint_arn          = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn          = aws_dms_endpoint.target.endpoint_arn

  table_mappings = <<EOF
{
  "rules": [
    {
      "rule-type": "selection",
      "rule-id": "1",
      "rule-name": "1",
      "object-locator": {
        "schema-name": "employee_db",     #give your DB name 
        "table-name": "%"                # give your table name
      },
      "rule-action": "include"
    }
  ]
}
EOF

  replication_task_settings = <<EOF
{
  "TargetTablePrepMode": "DROP_AND_CREATE",
  "FullLoadSettings": {
    "CommitRate": 10000
  }
}
EOF
}
