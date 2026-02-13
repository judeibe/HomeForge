# Entity Relationship Diagram (ERD)

## Database Schema for HomeForge Supervisor

This document provides a visual and textual representation of the database schema for the Supervisor component.

---

## Entity Relationship Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         HOMEFORGE SUPERVISOR DATABASE SCHEMA                     │
└─────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────┐         ┌──────────────────────┐         ┌──────────────────────┐
│      Device          │         │        User          │         │        Role          │
├──────────────────────┤         ├──────────────────────┤         ├──────────────────────┤
│ id (PK)              │         │ id (PK)              │◄────┐   │ id (PK)              │
│ device_id (UNIQUE)   │         │ username (UNIQUE)    │     │   │ name (UNIQUE)        │
│ public_key           │         │ password_hash        │     │   │ description          │
│ is_claimed           │         │ display_name         │     │   │ permissions (JSON)   │
│ claimed_at           │         │ is_admin             │     │   │ is_system            │
│ claimed_by_user_id   ├────┐    │ is_deleted           │     │   │ created_at           │
│ created_at           │    │    │ created_at           │     │   │ updated_at           │
│ updated_at           │    │    │ updated_at           │     │   └──────────────────────┘
└──────────────────────┘    │    └──────────────────────┘     │            │
                            │              │                  │            │
                            │              │                  │            │
                            │              │                  │            ▼
                            │              │                  │   ┌──────────────────────┐
                            │              │                  └───┤   RoleBinding        │
                            │              │                      ├──────────────────────┤
                            │              └─────────────────────►│ id (PK)              │
                            │                                     │ user_id (FK)         │
                            │                                     │ role_id (FK)         │
                            │                                     │ scope_type           │
                            │                                     │ scope_id             │
                            │                                     │ created_at           │
                            │                                     │ updated_at           │
                            │                                     └──────────────────────┘
                            │                                              │
                            │                                              │
┌───────────────────────────┼──────────────────────────────────────────────┘
│                           │
│                           │
▼                           │
┌──────────────────────┐    │              ┌──────────────────────┐
│     Session          │    │              │   RefreshToken       │
├──────────────────────┤    │              ├──────────────────────┤
│ id (PK)              │    │              │ id (PK)              │
│ session_token(UNIQUE)│    │              │ token_hash (UNIQUE)  │
│ user_id (FK)         ├────┤              │ user_id (FK)         ├────┐
│ device_fingerprint   │    │              │ device_fingerprint   │    │
│ ip_address           │    │              │ expires_at           │    │
│ user_agent           │    │              │ is_revoked           │    │
│ expires_at           │    │              │ created_at           │    │
│ created_at           │    │              │ updated_at           │    │
│ updated_at           │    │              └──────────────────────┘    │
└──────────────────────┘    │                                           │
                            │                                           │
                            │                                           │
                            │                                           │
                            │              ┌──────────────────────┐     │
                            │              │   RecoveryCode       │     │
                            │              ├──────────────────────┤     │
                            │              │ id (PK)              │     │
                            │              │ user_id (FK)         ├─────┘
                            │              │ code_hash (UNIQUE)   │
                            │              │ is_used              │
                            │              │ used_at              │
                            │              │ created_at           │
                            │              └──────────────────────┘
                            │
                            │              ┌──────────────────────┐
                            │              │    AuditEvent        │
                            │              ├──────────────────────┤
                            │              │ id (PK)              │
                            └─────────────►│ user_id (FK, NULL)   │
                                           │ event_type           │
                                           │ event_data (JSON)    │
                                           │ ip_address           │
                                           │ user_agent           │
                                           │ success              │
                                           │ created_at           │
                                           └──────────────────────┘
                                                     (Append-only)

                            ┌──────────────────────┐
                            │  SecretMetadata      │
                            ├──────────────────────┤
                            │ id (PK)              │
                            │ secret_id (UNIQUE)   │
                            │ secret_type          │
                            │ description          │
                            │ key_derivation_info  │
                            │ created_at           │
                            │ updated_at           │
                            │ rotated_at           │
                            └──────────────────────┘
                            (No actual secrets stored)
```

---

## Table Details

### 1. Device
Stores information about physical devices in the HomeForge ecosystem.

**Columns:**
- `id`: Primary key (INTEGER)
- `device_id`: Unique device identifier (TEXT, UNIQUE)
- `public_key`: Device's public key in PEM format (TEXT)
- `is_claimed`: Whether device is claimed by a user (BOOLEAN)
- `claimed_at`: Timestamp when device was claimed (TIMESTAMP)
- `claimed_by_user_id`: Foreign key to User table (INTEGER, nullable)
- `created_at`: Creation timestamp (TIMESTAMP)
- `updated_at`: Last update timestamp (TIMESTAMP)

**Indexes:**
- `idx_device_device_id` on `device_id`
- `idx_device_is_claimed` on `is_claimed`

**Constraints:**
- `device_id` must be unique
- `claimed_by_user_id` references `User(id)` with CASCADE delete

---

### 2. User
Local user accounts for authentication and authorization.

**Columns:**
- `id`: Primary key (INTEGER)
- `username`: Unique username (TEXT, UNIQUE)
- `password_hash`: Argon2id password hash (TEXT)
- `display_name`: User's display name (TEXT)
- `is_admin`: Administrator flag (BOOLEAN)
- `is_deleted`: Soft delete flag (BOOLEAN)
- `created_at`: Creation timestamp (TIMESTAMP)
- `updated_at`: Last update timestamp (TIMESTAMP)

**Indexes:**
- `idx_user_username` on `username`
- `idx_user_is_deleted` on `is_deleted`

**Constraints:**
- `username` must be unique

---

### 3. Role
RBAC role definitions with associated permissions.

**Columns:**
- `id`: Primary key (INTEGER)
- `name`: Unique role name (TEXT, UNIQUE)
- `description`: Role description (TEXT)
- `permissions`: JSON array of permission strings (TEXT)
- `is_system`: System-defined role flag (BOOLEAN)
- `created_at`: Creation timestamp (TIMESTAMP)
- `updated_at`: Last update timestamp (TIMESTAMP)

**Indexes:**
- `idx_role_name` on `name`

**Constraints:**
- `name` must be unique
- System roles cannot be deleted

**Default Roles:**
- `admin`: Full system access
- `user`: Standard user access
- `device_manager`: Device management only
- `readonly`: Read-only access

---

### 4. RoleBinding
Maps users to roles with optional scope restrictions.

**Columns:**
- `id`: Primary key (INTEGER)
- `user_id`: Foreign key to User table (INTEGER)
- `role_id`: Foreign key to Role table (INTEGER)
- `scope_type`: Scope type (TEXT): 'global', 'device', 'room', etc.
- `scope_id`: Scope identifier (TEXT, nullable)
- `created_at`: Creation timestamp (TIMESTAMP)
- `updated_at`: Last update timestamp (TIMESTAMP)

**Indexes:**
- `idx_rolebinding_user_id` on `user_id`
- `idx_rolebinding_role_id` on `role_id`
- `idx_rolebinding_scope` on `scope_type, scope_id`

**Constraints:**
- `user_id` references `User(id)` with CASCADE delete
- `role_id` references `Role(id)` with CASCADE delete
- Unique constraint on `(user_id, role_id, scope_type, scope_id)`

---

### 5. Session
Active user sessions with associated metadata.

**Columns:**
- `id`: Primary key (INTEGER)
- `session_token`: Unique session token (TEXT, UNIQUE)
- `user_id`: Foreign key to User table (INTEGER)
- `device_fingerprint`: Device identifier string (TEXT)
- `ip_address`: Client IP address (TEXT)
- `user_agent`: Client user agent (TEXT)
- `expires_at`: Session expiration timestamp (TIMESTAMP)
- `created_at`: Creation timestamp (TIMESTAMP)
- `updated_at`: Last update timestamp (TIMESTAMP)

**Indexes:**
- `idx_session_token` on `session_token`
- `idx_session_user_id` on `user_id`
- `idx_session_expires_at` on `expires_at`

**Constraints:**
- `session_token` must be unique
- `user_id` references `User(id)` with CASCADE delete

---

### 6. RefreshToken
Long-lived tokens for session renewal.

**Columns:**
- `id`: Primary key (INTEGER)
- `token_hash`: SHA-256 hash of refresh token (TEXT, UNIQUE)
- `user_id`: Foreign key to User table (INTEGER)
- `device_fingerprint`: Device identifier string (TEXT)
- `expires_at`: Token expiration timestamp (TIMESTAMP)
- `is_revoked`: Revocation flag (BOOLEAN)
- `created_at`: Creation timestamp (TIMESTAMP)
- `updated_at`: Last update timestamp (TIMESTAMP)

**Indexes:**
- `idx_refreshtoken_token_hash` on `token_hash`
- `idx_refreshtoken_user_id` on `user_id`
- `idx_refreshtoken_expires_at` on `expires_at`

**Constraints:**
- `token_hash` must be unique
- `user_id` references `User(id)` with CASCADE delete

---

### 7. RecoveryCode
Hashed backup recovery codes for account access.

**Columns:**
- `id`: Primary key (INTEGER)
- `user_id`: Foreign key to User table (INTEGER)
- `code_hash`: SHA-256 hash of recovery code (TEXT, UNIQUE)
- `is_used`: Usage flag (BOOLEAN)
- `used_at`: Timestamp when code was used (TIMESTAMP, nullable)
- `created_at`: Creation timestamp (TIMESTAMP)

**Indexes:**
- `idx_recoverycode_code_hash` on `code_hash`
- `idx_recoverycode_user_id` on `user_id`

**Constraints:**
- `code_hash` must be unique
- `user_id` references `User(id)` with CASCADE delete

**Notes:**
- Codes are single-use
- Typically 8-10 codes generated per user
- Used for account recovery when primary authentication fails

---

### 8. AuditEvent
Append-only audit log for security events.

**Columns:**
- `id`: Primary key (INTEGER)
- `user_id`: Foreign key to User table (INTEGER, nullable)
- `event_type`: Event type (TEXT): 'login', 'logout', 'device_claim', etc.
- `event_data`: JSON event details (TEXT)
- `ip_address`: Client IP address (TEXT, nullable)
- `user_agent`: Client user agent (TEXT, nullable)
- `success`: Event success flag (BOOLEAN)
- `created_at`: Creation timestamp (TIMESTAMP)

**Indexes:**
- `idx_auditevent_user_id` on `user_id`
- `idx_auditevent_event_type` on `event_type`
- `idx_auditevent_created_at` on `created_at`

**Constraints:**
- `user_id` references `User(id)` with SET NULL on delete
- No updates or deletes allowed (enforced at application level)

**Event Types:**
- `user.login.success` / `user.login.failed`
- `user.logout`
- `user.created` / `user.deleted`
- `device.claimed` / `device.unclaimed`
- `session.created` / `session.expired`
- `recovery_code.used`
- `role.assigned` / `role.removed`
- `permission.denied`

---

### 9. SecretMetadata
Metadata and references for encrypted secrets (actual secrets not stored).

**Columns:**
- `id`: Primary key (INTEGER)
- `secret_id`: Unique secret identifier (TEXT, UNIQUE)
- `secret_type`: Secret type (TEXT): 'api_key', 'certificate', 'signing_key', etc.
- `description`: Human-readable description (TEXT)
- `key_derivation_info`: JSON with key derivation parameters (TEXT, nullable)
- `created_at`: Creation timestamp (TIMESTAMP)
- `updated_at`: Last update timestamp (TIMESTAMP)
- `rotated_at`: Last rotation timestamp (TIMESTAMP, nullable)

**Indexes:**
- `idx_secretmetadata_secret_id` on `secret_id`
- `idx_secretmetadata_secret_type` on `secret_type`

**Constraints:**
- `secret_id` must be unique

**Notes:**
- Actual secret values are stored encrypted in separate secure storage
- This table only maintains metadata and references
- Used for secret lifecycle management and rotation tracking

---

## Relationships

1. **Device → User** (Many-to-One)
   - A device can be claimed by one user
   - A user can claim multiple devices

2. **User → RoleBinding** (One-to-Many)
   - A user can have multiple role bindings
   - Each role binding belongs to one user

3. **Role → RoleBinding** (One-to-Many)
   - A role can be assigned to multiple users
   - Each role binding references one role

4. **User → Session** (One-to-Many)
   - A user can have multiple active sessions
   - Each session belongs to one user

5. **User → RefreshToken** (One-to-Many)
   - A user can have multiple refresh tokens
   - Each refresh token belongs to one user

6. **User → RecoveryCode** (One-to-Many)
   - A user has multiple recovery codes
   - Each recovery code belongs to one user

7. **User → AuditEvent** (One-to-Many, Optional)
   - An audit event may reference a user
   - System events may not have a user

---

## Migration Strategy

### Initial Migration (001)
Creates all tables with indexes and constraints.

### Future Migrations
- Add new columns with DEFAULT values for backwards compatibility
- Create new tables as needed
- Never drop columns (use soft deletes)
- Add indexes to optimize query performance
- Update constraints carefully to avoid breaking existing data

### Rollback Support
Each migration should include:
1. Forward migration (UP)
2. Rollback migration (DOWN)
3. Verification queries to check migration success

---

## Query Patterns

### Common Queries

**Check if device is claimed:**
```sql
SELECT is_claimed, claimed_by_user_id 
FROM Device 
WHERE device_id = ?;
```

**Get user's roles and permissions:**
```sql
SELECT r.name, r.permissions, rb.scope_type, rb.scope_id
FROM RoleBinding rb
JOIN Role r ON rb.role_id = r.id
WHERE rb.user_id = ?;
```

**Validate session:**
```sql
SELECT s.id, s.user_id, u.username, u.is_admin
FROM Session s
JOIN User u ON s.user_id = u.id
WHERE s.session_token = ? 
  AND s.expires_at > CURRENT_TIMESTAMP
  AND u.is_deleted = 0;
```

**Get recent audit events for user:**
```sql
SELECT event_type, event_data, success, created_at
FROM AuditEvent
WHERE user_id = ?
ORDER BY created_at DESC
LIMIT 100;
```

**Check unused recovery codes:**
```sql
SELECT COUNT(*) 
FROM RecoveryCode
WHERE user_id = ? 
  AND is_used = 0;
```

---

## Performance Considerations

1. **Indexes**: All foreign keys and frequently queried columns are indexed
2. **Soft Deletes**: Allows audit trail while maintaining referential integrity
3. **JSON Columns**: Used for flexible schema (permissions, event_data)
4. **Partitioning**: AuditEvent table may need partitioning for large datasets
5. **Archival**: Old audit events and expired sessions should be archived periodically

---

## Security Considerations

1. **No Plain Text Secrets**: Passwords and recovery codes are hashed
2. **Token Hashing**: Refresh tokens stored as hashes
3. **Audit Trail**: All security events logged
4. **Soft Deletes**: Maintains history for forensics
5. **Foreign Keys**: Enforce referential integrity
6. **Append-Only Audit**: AuditEvent cannot be modified or deleted

---

*This ERD is part of issue HOM-6: Create domain model + database schema for identity and device state*
