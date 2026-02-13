# HomeForge Supervisor

The Supervisor is the core controller component of the HomeForge platform, responsible for device management, user authentication, and local state management.

## Overview

The Supervisor runs on the HomeForge hub device (e.g., Raspberry Pi) and provides:

- **Device Management**: Onboarding, claiming, and controlling smart home devices
- **User Authentication**: Local-first user accounts with password-based auth
- **Access Control**: Role-based access control (RBAC) with scoped permissions
- **Session Management**: Secure session and refresh token handling
- **Audit Logging**: Comprehensive security event logging
- **Secret Management**: Metadata tracking for encrypted secrets

## Architecture

### Local-First Design

The Supervisor is designed to work completely offline without any cloud dependency:

- All user data stored locally in SQLite database
- Authentication happens locally using password hashing
- No external API calls required for core functionality
- Optional cloud connectivity for remote access via secure tunnels

### Security Model

Based on the [Onboarding and Trust Architecture](../docs/architecture/onboarding-and-trust.md):

1. **Device States**: Unclaimed → Claimed via cryptographic proof
2. **Authentication**: Argon2id password hashing + session tokens
3. **Authorization**: RBAC with role bindings and scoped permissions
4. **Audit Trail**: Append-only audit log for all security events
5. **Recovery**: Hashed recovery codes for account access

## Directory Structure

```
supervisor/
├── db/
│   ├── migrations/           # SQL migration scripts
│   │   ├── 001_initial_schema.sql
│   │   ├── 001_initial_schema_rollback.sql
│   │   └── README.md
│   └── schema/
│       └── README.md         # Schema documentation
├── docs/
│   └── erd.md               # Entity Relationship Diagram
└── README.md                # This file
```

## Database Schema

The Supervisor uses **SQLite** for local data storage with the following core entities:

### Core Tables

1. **Device** - Physical device identity and claim status
   - Unique device_id for each device
   - Public key for cryptographic operations
   - Claim status and ownership tracking

2. **User** - Local user accounts
   - Username/password authentication (Argon2id)
   - Admin flag for privileged access
   - Soft delete for audit trail

3. **Role** - RBAC role definitions
   - System and custom roles
   - JSON permissions array
   - Protection against deleting system roles

4. **RoleBinding** - User-to-Role-to-Scope mappings
   - Assigns roles to users
   - Optional scope restrictions (global, device, room, zone)
   - Unique constraint prevents duplicate bindings

5. **Session** - Active user sessions
   - Short-lived session tokens
   - Device fingerprint tracking
   - Automatic expiration

6. **RefreshToken** - Long-lived tokens for renewal
   - 90-day expiration by default
   - Device fingerprint for security
   - Revocation support

7. **RecoveryCode** - Backup account recovery
   - Single-use recovery codes
   - SHA-256 hashed before storage
   - Typically 8-10 codes per user

8. **AuditEvent** - Security audit log
   - Append-only (no updates/deletes)
   - Tracks all security-relevant events
   - JSON event data for flexibility

9. **SecretMetadata** - Secret references
   - Metadata only, no actual secrets stored
   - Secret rotation tracking
   - Key derivation information

### Database Design Features

- **Idempotency**: Unique constraints on device_id, usernames, recovery codes
- **Referential Integrity**: Foreign keys with CASCADE/SET NULL
- **Audit Trail**: Triggers prevent modifying/deleting audit events
- **Timestamps**: Automatic created_at/updated_at tracking
- **Indexes**: Strategic indexes on frequently queried columns
- **Views**: Pre-built views for common queries

See [ERD Documentation](docs/erd.md) for detailed schema diagram and table descriptions.

## Getting Started

### Prerequisites

- SQLite 3.x
- Go 1.21+ (when implementation is added)

### Database Setup

1. Create database directory:
   ```bash
   mkdir -p data
   ```

2. Run initial migration:
   ```bash
   sqlite3 data/supervisor.db < db/migrations/001_initial_schema.sql
   ```

3. Verify schema:
   ```bash
   sqlite3 data/supervisor.db ".tables"
   sqlite3 data/supervisor.db "PRAGMA integrity_check;"
   ```

### Sample Data

For development/testing, you can insert sample data:

```sql
-- Create admin user (password: changeme - CHANGE IN PRODUCTION!)
-- Note: Use proper Argon2id hashing in production
INSERT INTO User (username, password_hash, display_name, is_admin)
VALUES ('admin', '$argon2id$...', 'Administrator', 1);

-- Assign admin role
INSERT INTO RoleBinding (user_id, role_id, scope_type)
VALUES (1, 1, 'global');

-- Add unclaimed device
INSERT INTO Device (device_id, public_key, is_claimed)
VALUES ('dev_abc123', '-----BEGIN PUBLIC KEY-----...', 0);
```

## Default Roles

The system includes four default roles:

| Role | Description | Permissions |
|------|-------------|-------------|
| `admin` | Full system access | `["*"]` |
| `user` | Standard user | `["devices.read", "devices.control", "profile.read", "profile.update"]` |
| `device_manager` | Device management | `["devices.read", "devices.write", "devices.delete"]` |
| `readonly` | Read-only access | `["devices.read", "profile.read"]` |

## Security Considerations

### Password Security

- **Hashing**: Use Argon2id with appropriate parameters
  - Memory: 64 MB
  - Iterations: 3
  - Parallelism: 4
  - Salt: 16 bytes (random)
- **Never** store plain text passwords
- **Never** log passwords or recovery codes

### Session Security

- **Session Tokens**: Cryptographically random (32+ bytes)
- **Expiration**: Short-lived (default 1 hour)
- **Refresh Tokens**: Long-lived (default 90 days)
- **Device Fingerprint**: Track device for anomaly detection
- **IP Tracking**: Log IP addresses for audit trail

### Recovery Codes

- **Generation**: 8-10 random codes per user
- **Format**: 24 characters, base32 encoded (e.g., `XXXX-XXXX-XXXX-XXXX-XXXX-XXXX`)
- **Hashing**: SHA-256 before storage
- **Single Use**: Codes invalidated after use
- **Secure Display**: Show once to user, then never again

### Audit Events

All security-relevant events must be logged:

- User login/logout (success and failure)
- Device claim/unclaim
- Session creation/expiration
- Role assignment/removal
- Permission denied events
- Recovery code usage
- Account modifications

## API Design (Future)

The Supervisor will expose REST/gRPC APIs for:

- Device onboarding and management
- User authentication and session management
- Role and permission management
- Audit event querying

API design will follow principles from the [Onboarding and Trust Architecture](../docs/architecture/onboarding-and-trust.md).

## Testing

### Database Tests

Test migrations:
```bash
# Apply migration
sqlite3 test.db < db/migrations/001_initial_schema.sql

# Run queries to verify
sqlite3 test.db "SELECT * FROM Role;"

# Test rollback
sqlite3 test.db < db/migrations/001_initial_schema_rollback.sql
```

### Schema Validation

Validate constraints:
```sql
-- Test unique constraints
INSERT INTO User (username, password_hash, display_name) 
VALUES ('test', 'hash', 'Test User');

-- This should fail (duplicate username)
INSERT INTO User (username, password_hash, display_name) 
VALUES ('test', 'hash2', 'Test User 2');

-- Test foreign keys
-- This should fail (invalid user_id)
INSERT INTO Session (session_token, user_id, device_fingerprint, expires_at)
VALUES ('token', 9999, 'fingerprint', '2026-12-31');

-- Test check constraints
-- This should fail (username too short)
INSERT INTO User (username, password_hash, display_name)
VALUES ('ab', 'hash', 'User');
```

## Performance Considerations

### Query Optimization

- All foreign keys are indexed
- Frequently queried columns have indexes
- Use prepared statements to prevent SQL injection
- Use views for complex queries

### Maintenance

Periodic cleanup tasks:

```sql
-- Clean up expired sessions (run daily)
DELETE FROM Session WHERE expires_at < CURRENT_TIMESTAMP;

-- Clean up expired refresh tokens (run daily)
DELETE FROM RefreshToken WHERE expires_at < CURRENT_TIMESTAMP AND is_revoked = 1;

-- Archive old audit events (run monthly)
-- Consider moving old events to archive table
```

### Scaling

For deployments with many audit events:

- Consider partitioning AuditEvent table by date
- Implement audit log rotation/archival
- Use separate database for audit logs
- Add pagination for audit queries

## Development Roadmap

- [ ] Implement application code (Go/Rust/other)
- [ ] Add API layer (REST/gRPC)
- [ ] Implement authentication handlers
- [ ] Add device onboarding flows
- [ ] Implement RBAC enforcement
- [ ] Add audit logging middleware
- [ ] Create management CLI tools
- [ ] Add comprehensive test suite
- [ ] Performance testing and optimization
- [ ] Security audit

## References

- [Database Schema Documentation](db/schema/README.md)
- [Migration Guide](db/migrations/README.md)
- [Entity Relationship Diagram](docs/erd.md)
- [Onboarding and Trust Architecture](../docs/architecture/onboarding-and-trust.md)
- [Issue HOM-6](https://linear.app/homeforge/issue/HOM-6/)

## Contributing

When making changes to the database schema:

1. Create a new migration file with incremented version number
2. Update ERD diagram to reflect changes
3. Update this README if adding new tables or major changes
4. Test migration and rollback thoroughly
5. Update any affected documentation

## License

TBD

---

*This component is part of the HomeForge smart home platform.*
*For more information, see the [main README](../README.md).*
