# Database Import Troubleshooting Guide

## Common Issue: MySQL Access Denied Error

### Symptom
```
ERROR 1045 (28000): Access denied for user 'root'@'<IP>' (using password: YES)
```

### Root Causes

1. **Missing Root Password in Secret Manager**
   - The MySQL root password is not stored in Google Secret Manager
   - The script tries multiple secret name patterns but cannot find it

2. **MySQL Root User Not Allowed Remote Connections**
   - MySQL root user by default only allows connections from localhost
   - Connections from the NFS VM IP are rejected

3. **Wrong Password**
   - The password stored in Secret Manager doesn't match the actual MySQL root password

### Solutions

#### Option 1: Store Root Password in Secret Manager (Recommended)

Store the MySQL root password in Google Secret Manager with one of these names:
- `<instance-name>-root-password`
- `<instance-name>_root_password`
- `db-root-password`
- `mysql-root-password`
- `sql-root-password`

Example:
```bash
# Get your MySQL instance name
INSTANCE_NAME=$(gcloud sql instances list --filter="databaseVersion:MYSQL*" --format="value(name)" --limit=1)

# Store the root password
echo -n "YOUR_ROOT_PASSWORD" | gcloud secrets create ${INSTANCE_NAME}-root-password \
  --data-file=- \
  --replication-policy="automatic"
```

#### Option 2: Grant Root User Remote Access

Connect to your MySQL instance and run:
```sql
-- Option A: Allow from any IP (less secure)
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'your_password';

-- Option B: Allow from specific IP (more secure)
GRANT ALL PRIVILEGES ON *.* TO 'root'@'<NFS_VM_IP>' IDENTIFIED BY 'your_password';

FLUSH PRIVILEGES;
```

Replace `<NFS_VM_IP>` with the IP of your NFS VM (e.g., 10.142.192.2).

#### Option 3: Use Cloud SQL Proxy (Automatic Fallback)

The updated import script now automatically attempts to use Cloud SQL Proxy if direct connection fails. This requires:
- Cloud SQL Proxy installed on the NFS VM
- Proper IAM permissions for Cloud SQL Client

### Verification Steps

After applying one of the solutions above:

1. **Verify Secret Exists**
```bash
gcloud secrets list --filter="name:root-password"
```

2. **Test MySQL Connection from NFS VM**
```bash
# SSH to NFS VM
gcloud compute ssh <NFS_VM_NAME> --zone=<ZONE>

# Test connection
mysql -h <DB_IP> -u root -p
```

3. **Run Terraform Apply**
```bash
cd modules/OpenEMR
terraform apply
```

### Prevention

To avoid this issue in future deployments:
1. Always store MySQL root passwords in Secret Manager during instance creation
2. Configure MySQL to allow connections from VPC private network
3. Use Cloud SQL Proxy for secure connections
4. Document your secret naming conventions

### Getting More Help

If the issue persists:
1. Check the detailed error output from the import script
2. Verify network connectivity between NFS VM and MySQL instance
3. Check Cloud SQL authorized networks configuration
4. Review IAM permissions for the service account
