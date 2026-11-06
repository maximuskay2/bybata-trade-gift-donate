# BYBATA Database Backup Information

## Backup Details

**Date:** December 2, 2025 12:23 AM  
**Database:** bybata  
**Format:** PostgreSQL plain SQL dump (compressed)  
**File:** `bybata_backup_20251202_122333.sql.gz`  
**Size:** 18 KB (compressed) / 116 KB (uncompressed)  
**Location:** `/Users/akingbadekayode/StudioProjects/BYBATAPHP/bybata/apps/api/`

---

## Restore Instructions

### Quick Restore
```bash
cd /Users/akingbadekayode/StudioProjects/BYBATAPHP/bybata/apps/api

# Decompress and restore in one command
gunzip -c bybata_backup_20251202_122333.sql.gz | \
  PGPASSWORD=changeme psql -h localhost -p 5433 -U postgres -d bybata
```

### Step-by-Step Restore

1. **Decompress the backup:**
   ```bash
   gunzip bybata_backup_20251202_122333.sql.gz
   ```

2. **Drop existing database (CAUTION - this deletes all data):**
   ```bash
   PGPASSWORD=changeme dropdb -h localhost -p 5433 -U postgres bybata
   ```

3. **Create fresh database:**
   ```bash
   PGPASSWORD=changeme createdb -h localhost -p 5433 -U postgres bybata
   ```

4. **Restore from backup:**
   ```bash
   PGPASSWORD=changeme psql -h localhost -p 5433 -U postgres -d bybata < bybata_backup_20251202_122333.sql
   ```

---

## Automated Backup Script

A backup script has been created at: `backup-database.sh`

### Usage:
```bash
cd /Users/akingbadekayode/StudioProjects/BYBATAPHP/bybata/apps/api
./backup-database.sh
```

This script will:
- Create a timestamped backup file
- Compress it automatically
- Store in `./database-backups/` directory
- Show file size and restore command

### Schedule Regular Backups (Optional)

Add to crontab for daily backups at 2 AM:
```bash
0 2 * * * cd /Users/akingbadekayode/StudioProjects/BYBATAPHP/bybata/apps/api && ./backup-database.sh
```

---

## What's Backed Up

This backup contains the complete database including:

### Core Tables
- User accounts and profiles
- Authentication sessions and tokens
- Email and phone verification

### Features
- **Trades:** All trade listings, offers, negotiations
- **Gifts:** Gift posts, claims, comments, likes
- **Campaigns:** Donation campaigns, updates, reward tiers
- **Communities:** Communities, members, posts, likes, comments, events
- **Chat:** Conversations, messages, reactions, reports
- **Wallet:** Transactions, transfers, funding intents
- **Karma:** Karma accounts, events, achievements

### System Data
- Settings and configurations
- Audit logs
- Webhook events
- Notifications

---

## Database Schema Version

**Prisma Schema:** Current as of December 2, 2025  
**Last Migration:** Latest applied migrations included in backup

---

## Important Notes

⚠️ **Before Restoring:**
- Stop the API server to avoid conflicts
- Ensure PostgreSQL is running on port 5433
- Backup current data if needed

✅ **After Restoring:**
- Restart the API server
- Verify data integrity
- Check application functionality

🔒 **Security:**
- Keep backup files secure
- Do not commit to version control
- Store in encrypted storage for production backups

---

## Backup Verification

To verify backup integrity:
```bash
# Check file is not corrupted
gunzip -t bybata_backup_20251202_122333.sql.gz

# Count tables in backup
gunzip -c bybata_backup_20251202_122333.sql.gz | grep "CREATE TABLE" | wc -l
```

Expected table count: 50+ tables

---

## Next Steps Before Making Schema Changes

✅ **Backup created successfully**  
⬜ Review roadmap document  
⬜ Plan Phase 1 schema changes  
⬜ Create migration files  
⬜ Test on development database  
⬜ Apply to production with rollback plan
