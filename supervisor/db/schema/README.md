# Supervisor Database Schema

This directory contains the database schema definition for the HomeForge Supervisor component.

## Overview

The Supervisor maintains local state for device identity, user management, access control, and audit logging. The database is designed to be:

- **Local-first**: All data stored locally on the device
- **Privacy-focused**: No cloud dependency for core functionality  
- **Audit-ready**: Comprehensive audit logging for security events
- **Idempotent**: Unique constraints prevent duplicate entries

## Database Technology

**SQLite** - Chosen for:
- Zero configuration required
- Serverless (embedded in application)
- ACID compliant
- Cross-platform compatibility
- Perfect for local-first architecture

## Schema Components

### Core Entities

1. **Device** - Physical device identity and claim status
2. **User** - Local user accounts for authentication
3. **Role** - RBAC role definitions
4. **RoleBinding** - User-to-Role-to-Scope mappings
5. **Session** - Active user sessions
6. **RefreshToken** - Long-lived tokens for session renewal
7. **RecoveryCode** - Hashed backup recovery codes
8. **AuditEvent** - Append-only security audit log
9. **SecretMetadata** - References to encrypted secrets

### Key Design Principles

- **Idempotency**: Unique constraints on device_id, recovery codes, etc.
- **Audit Trail**: All security-relevant events logged to AuditEvent table
- **Soft Deletes**: Critical tables use soft deletes (is_deleted flag) for audit purposes
- **Timestamps**: All tables include created_at, updated_at for tracking
- **Foreign Keys**: Enabled with ON DELETE CASCADE where appropriate
- **Indexes**: Strategic indexes on frequently queried columns

## Migrations

Database migrations are located in `../migrations/` and follow a sequential numbering scheme:

- `001_initial_schema.sql` - Creates all core tables
- Future migrations will follow: `002_description.sql`, etc.

### Running Migrations

Migrations should be applied in sequential order. The migration system tracks which migrations have been applied to prevent duplicate execution.

## ERD

See `../../docs/erd.md` for the Entity Relationship Diagram showing all tables and their relationships.

## Security Considerations

- **Password Hashing**: User passwords stored using Argon2id
- **Recovery Codes**: Hashed using SHA-256 before storage
- **Public Keys**: Stored in PEM format
- **Secrets**: Not stored in database, only metadata/references
- **Audit Events**: Append-only, no updates or deletes allowed
- **Sessions**: Include device fingerprint for security

## References

- [Onboarding and Trust Architecture](../../../docs/architecture/onboarding-and-trust.md)
- [HOM-6: Create domain model + database schema](https://linear.app/homeforge/issue/HOM-6/)
