#!/bin/bash

# BYBATA Database Backup Script
# Creates a full database dump with timestamp

# Database connection details
DB_NAME="bybata"
DB_USER="postgres"
DB_HOST="localhost"
DB_PORT="5433"

# Backup directory
BACKUP_DIR="./database-backups"
mkdir -p "$BACKUP_DIR"

# Timestamp for backup file
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/bybata_backup_$TIMESTAMP.sql"

echo "==========================================="
echo "BYBATA Database Backup"
echo "==========================================="
echo "Database: $DB_NAME"
echo "Host: $DB_HOST:$DB_PORT"
echo "Backup file: $BACKUP_FILE"
echo ""

# Create the backup
echo "Creating backup..."
PGPASSWORD=changeme pg_dump \
  -h $DB_HOST \
  -p $DB_PORT \
  -U $DB_USER \
  -d $DB_NAME \
  --verbose \
  --format=plain \
  --file="$BACKUP_FILE"

# Check if backup was successful
if [ $? -eq 0 ]; then
  # Compress the backup
  echo ""
  echo "Compressing backup..."
  gzip "$BACKUP_FILE"
  COMPRESSED_FILE="${BACKUP_FILE}.gz"
  
  # Get file size
  FILE_SIZE=$(du -h "$COMPRESSED_FILE" | cut -f1)
  
  echo ""
  echo "==========================================="
  echo "✅ Backup completed successfully!"
  echo "==========================================="
  echo "Backup file: $COMPRESSED_FILE"
  echo "File size: $FILE_SIZE"
  echo ""
  echo "To restore this backup, run:"
  echo "  gunzip -c $COMPRESSED_FILE | PGPASSWORD=changeme psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME"
  echo ""
else
  echo ""
  echo "❌ Backup failed!"
  exit 1
fi

# List recent backups
echo "Recent backups:"
ls -lh "$BACKUP_DIR" | tail -n 5
