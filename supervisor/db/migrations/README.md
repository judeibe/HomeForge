# Database Migrations

This directory contains SQL migration scripts for the HomeForge Supervisor database.

## Migration Files

- `001_initial_schema.sql` - Creates initial database schema with all core tables
- `001_initial_schema_rollback.sql` - Rollback script for initial schema

## Migration Numbering

Migrations are numbered sequentially starting from 001. Each migration should include:

1. **Forward migration**: `NNN_description.sql`
2. **Rollback migration**: `NNN_description_rollback.sql`
3. **Version number in filename**: Zero-padded 3-digit number (001, 002, etc.)

## Running Migrations

### Prerequisites

- SQLite 3.x installed
- Database file location: `supervisor.db` (or as configured)

### Apply Migration

```bash
# Apply migration manually
sqlite3 supervisor.db < migrations/001_initial_schema.sql

# Or using a migration tool (recommended for production)
# Example with golang-migrate:
migrate -path migrations -database sqlite3://supervisor.db up
```

### Rollback Migration

```bash
# Rollback manually
sqlite3 supervisor.db < migrations/001_initial_schema_rollback.sql

# Or using a migration tool
migrate -path migrations -database sqlite3://supervisor.db down 1
```

## Migration Best Practices

### DO:
- ✅ Test migrations on a copy of production data
- ✅ Include both forward and rollback migrations
- ✅ Use `IF NOT EXISTS` for tables and indexes
- ✅ Include CHECK constraints for data validation
- ✅ Add descriptive comments explaining complex logic
- ✅ Use transactions for multi-statement migrations
- ✅ Test rollback migrations before deploying
- ✅ Include migration metadata in AuditEvent table

### DON'T:
- ❌ Drop columns (use soft deletes instead)
- ❌ Remove constraints without understanding impact
- ❌ Modify existing migrations after they've been deployed
- ❌ Skip version numbers
- ❌ Forget to update the schema documentation

## Migration Checklist

Before deploying a migration:

- [ ] Migration tested on development database
- [ ] Migration tested on copy of production data
- [ ] Rollback migration tested
- [ ] Schema documentation updated (ERD, README)
- [ ] Performance impact assessed (for large tables)
- [ ] Indexes added for new queries
- [ ] Foreign key constraints validated
- [ ] Default values provided for new columns
- [ ] Audit event logged for migration
- [ ] Code changes coordinated with migration

## Schema Validation

After applying a migration, validate the schema:

```bash
# Check all tables exist
sqlite3 supervisor.db ".tables"

# Check schema for specific table
sqlite3 supervisor.db ".schema Device"

# Verify foreign keys are enabled
sqlite3 supervisor.db "PRAGMA foreign_keys;"

# Check integrity
sqlite3 supervisor.db "PRAGMA integrity_check;"

# List all indexes
sqlite3 supervisor.db ".indexes"
```

## Migration Tracking

The database does not currently have an automatic migration tracking table. Consider implementing one for production:

```sql
CREATE TABLE schema_migrations (
    version INTEGER PRIMARY KEY,
    applied_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    description TEXT NOT NULL
);
```

## Troubleshooting

### Foreign Key Violations

If you encounter foreign key violations during migration:

```bash
# Temporarily disable foreign keys
PRAGMA foreign_keys = OFF;
# Run migration
# Re-enable foreign keys
PRAGMA foreign_keys = ON;
```

### Migration Conflicts

If migration fails mid-way:

1. Check SQLite error message for details
2. Restore from backup if needed
3. Fix the migration script
4. Re-test on development database
5. Re-apply to production

### Rollback Failures

If rollback fails:

1. Check for dependent objects (views, triggers)
2. Drop dependent objects first
3. Retry rollback
4. Restore from backup if necessary

## Future Migrations

When creating new migrations:

1. Increment version number (002, 003, etc.)
2. Follow naming convention: `NNN_description.sql`
3. Create corresponding rollback script
4. Update schema documentation
5. Test thoroughly before committing

## References

- [SQLite Documentation](https://www.sqlite.org/docs.html)
- [SQL Migrations Best Practices](https://www.prisma.io/dataguide/types/relational/migration-strategies)
- [Schema Design README](../schema/README.md)
- [ERD Documentation](../../docs/erd.md)

---

*Part of issue HOM-6: Create domain model + database schema for identity and device state*
