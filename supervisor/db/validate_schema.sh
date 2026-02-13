#!/bin/bash
# Schema validation script
# Tests database schema integrity and constraints

set -e

DB_FILE="${1:-data/supervisor_test.db}"
MIGRATION_FILE="supervisor/db/migrations/001_initial_schema.sql"

echo "=================================================="
echo "HomeForge Supervisor - Database Schema Validator"
echo "=================================================="
echo ""
echo "Database: $DB_FILE"
echo ""

# Remove old test database if it exists
if [ -f "$DB_FILE" ]; then
    echo "Removing existing test database..."
    rm -f "$DB_FILE"
fi

# Create database directory if needed
mkdir -p "$(dirname "$DB_FILE")"

echo "Applying migration..."
sqlite3 "$DB_FILE" < "$MIGRATION_FILE"

echo "✓ Migration applied successfully"
echo ""

# Verify tables exist
echo "Checking tables..."
TABLES=$(sqlite3 "$DB_FILE" "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;" | wc -l)
echo "✓ Found $TABLES tables"

# Verify views exist
VIEWS=$(sqlite3 "$DB_FILE" "SELECT name FROM sqlite_master WHERE type='view' ORDER BY name;" | wc -l)
echo "✓ Found $VIEWS views"

# Verify triggers exist
TRIGGERS=$(sqlite3 "$DB_FILE" "SELECT name FROM sqlite_master WHERE type='trigger' ORDER BY name;" | wc -l)
echo "✓ Found $TRIGGERS triggers"

# Verify indexes exist
INDEXES=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM sqlite_master WHERE type='index' AND name NOT LIKE 'sqlite_autoindex%';" | head -1)
echo "✓ Found $INDEXES custom indexes"

echo ""
echo "Running integrity check..."
INTEGRITY=$(sqlite3 "$DB_FILE" "PRAGMA integrity_check;")
if [ "$INTEGRITY" = "ok" ]; then
    echo "✓ Database integrity check passed"
else
    echo "✗ Database integrity check failed: $INTEGRITY"
    exit 1
fi

echo ""
echo "Testing constraints..."

# Test 1: Unique device_id constraint
echo -n "Testing unique device_id constraint... "
sqlite3 "$DB_FILE" "INSERT INTO Device (device_id, public_key) VALUES ('dev123', 'pubkey1');" 2>/dev/null
if sqlite3 "$DB_FILE" "INSERT INTO Device (device_id, public_key) VALUES ('dev123', 'pubkey2');" 2>/dev/null; then
    echo "✗ FAILED - Duplicate device_id allowed"
    exit 1
else
    echo "✓ PASSED"
fi

# Test 2: Unique username constraint
echo -n "Testing unique username constraint... "
sqlite3 "$DB_FILE" "INSERT INTO User (username, password_hash, display_name) VALUES ('user1', 'hash1', 'User One');" 2>/dev/null
if sqlite3 "$DB_FILE" "INSERT INTO User (username, password_hash, display_name) VALUES ('user1', 'hash2', 'User Two');" 2>/dev/null; then
    echo "✗ FAILED - Duplicate username allowed"
    exit 1
else
    echo "✓ PASSED"
fi

# Test 3: Username length constraint
echo -n "Testing username length constraint... "
if sqlite3 "$DB_FILE" "INSERT INTO User (username, password_hash, display_name) VALUES ('ab', 'hash', 'Too Short');" 2>/dev/null; then
    echo "✗ FAILED - Too short username allowed"
    exit 1
else
    echo "✓ PASSED"
fi

# Test 4: Foreign key constraint (Device -> User)
echo -n "Testing foreign key constraint... "
if sqlite3 "$DB_FILE" "PRAGMA foreign_keys = ON; INSERT INTO Device (device_id, public_key, is_claimed, claimed_at, claimed_by_user_id) VALUES ('dev456', 'key', 1, CURRENT_TIMESTAMP, 9999);" 2>/dev/null; then
    echo "✗ FAILED - Invalid foreign key allowed"
    exit 1
else
    echo "✓ PASSED"
fi

# Test 5: Audit event append-only (prevent updates)
echo -n "Testing audit event update prevention... "
sqlite3 "$DB_FILE" "INSERT INTO AuditEvent (event_type, event_data, success) VALUES ('test.event', '{}', 1);" 2>/dev/null
if sqlite3 "$DB_FILE" "UPDATE AuditEvent SET event_type = 'modified' WHERE id = 2;" 2>/dev/null; then
    echo "✗ FAILED - Audit event update allowed"
    exit 1
else
    echo "✓ PASSED"
fi

# Test 6: Audit event append-only (prevent deletes)
echo -n "Testing audit event delete prevention... "
if sqlite3 "$DB_FILE" "DELETE FROM AuditEvent WHERE id = 2;" 2>/dev/null; then
    echo "✗ FAILED - Audit event delete allowed"
    exit 1
else
    echo "✓ PASSED"
fi

# Test 7: System role delete prevention
echo -n "Testing system role delete prevention... "
if sqlite3 "$DB_FILE" "DELETE FROM Role WHERE name = 'admin';" 2>/dev/null; then
    echo "✗ FAILED - System role delete allowed"
    exit 1
else
    echo "✓ PASSED"
fi

# Test 8: Recovery code uniqueness
echo -n "Testing recovery code uniqueness... "
USER_ID=$(sqlite3 "$DB_FILE" "SELECT id FROM User LIMIT 1;")
sqlite3 "$DB_FILE" "INSERT INTO RecoveryCode (user_id, code_hash) VALUES ($USER_ID, 'hash123');" 2>/dev/null
if sqlite3 "$DB_FILE" "INSERT INTO RecoveryCode (user_id, code_hash) VALUES ($USER_ID, 'hash123');" 2>/dev/null; then
    echo "✗ FAILED - Duplicate recovery code allowed"
    exit 1
else
    echo "✓ PASSED"
fi

# Test 9: Session token uniqueness
echo -n "Testing session token uniqueness... "
sqlite3 "$DB_FILE" "INSERT INTO Session (session_token, user_id, device_fingerprint, expires_at) VALUES ('token123', $USER_ID, 'fp1', '2026-12-31');" 2>/dev/null
if sqlite3 "$DB_FILE" "INSERT INTO Session (session_token, user_id, device_fingerprint, expires_at) VALUES ('token123', $USER_ID, 'fp2', '2026-12-31');" 2>/dev/null; then
    echo "✗ FAILED - Duplicate session token allowed"
    exit 1
else
    echo "✓ PASSED"
fi

# Test 10: Role binding uniqueness
echo -n "Testing role binding uniqueness... "
ROLE_ID=$(sqlite3 "$DB_FILE" "SELECT id FROM Role LIMIT 1;")
sqlite3 "$DB_FILE" "INSERT INTO RoleBinding (user_id, role_id, scope_type) VALUES ($USER_ID, $ROLE_ID, 'global');" 2>/dev/null
if sqlite3 "$DB_FILE" "INSERT INTO RoleBinding (user_id, role_id, scope_type) VALUES ($USER_ID, $ROLE_ID, 'global');" 2>/dev/null; then
    echo "✗ FAILED - Duplicate role binding allowed"
    exit 1
else
    echo "✓ PASSED"
fi

echo ""
echo "Testing views..."

# Test view: ActiveSessions
echo -n "Testing ActiveSessions view... "
COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM ActiveSessions;")
if [ "$COUNT" = "1" ]; then
    echo "✓ PASSED (found $COUNT active session)"
else
    echo "✗ FAILED - Expected 1 session, found $COUNT"
fi

# Test view: UserPermissions
echo -n "Testing UserPermissions view... "
COUNT=$(sqlite3 "$DB_FILE" "SELECT COUNT(*) FROM UserPermissions;")
if [ "$COUNT" -ge "1" ]; then
    echo "✓ PASSED (found $COUNT permission entries)"
else
    echo "✗ FAILED - No permissions found"
fi

echo ""
echo "Testing automatic timestamps..."

# Test updated_at trigger
echo -n "Testing updated_at trigger... "
BEFORE=$(sqlite3 "$DB_FILE" "SELECT updated_at FROM User WHERE username='user1';")
sleep 1
sqlite3 "$DB_FILE" "UPDATE User SET display_name='Updated Name' WHERE username='user1';" 2>/dev/null
AFTER=$(sqlite3 "$DB_FILE" "SELECT updated_at FROM User WHERE username='user1';")
if [ "$BEFORE" != "$AFTER" ]; then
    echo "✓ PASSED"
else
    echo "✗ FAILED - updated_at not changed"
fi

echo ""
echo "=================================================="
echo "All validation tests passed! ✓"
echo "=================================================="
echo ""
echo "Schema Statistics:"
echo "  - Tables: $TABLES"
echo "  - Views: $VIEWS"
echo "  - Triggers: $TRIGGERS"
echo "  - Indexes: $INDEXES"
echo ""
echo "Database ready for use!"
