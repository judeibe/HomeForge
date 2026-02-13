# Sample SQL Queries

This document provides example SQL queries for common operations with the HomeForge Supervisor database.

## Table of Contents

1. [User Management](#user-management)
2. [Device Management](#device-management)
3. [Role and Permission Management](#role-and-permission-management)
4. [Session Management](#session-management)
5. [Audit and Security](#audit-and-security)
6. [Recovery Codes](#recovery-codes)
7. [Advanced Queries](#advanced-queries)

---

## User Management

### Create a New User

```sql
-- Create a new user (password should be Argon2id hashed)
INSERT INTO User (username, password_hash, display_name, is_admin)
VALUES ('alice', '$argon2id$v=19$m=65536,t=3,p=4$...', 'Alice Smith', 0);
```

### Get User by Username

```sql
SELECT id, username, display_name, is_admin, created_at
FROM User
WHERE username = 'alice' AND is_deleted = 0;
```

### Update User Display Name

```sql
UPDATE User
SET display_name = 'Alice Johnson'
WHERE username = 'alice';
```

### Soft Delete User

```sql
UPDATE User
SET is_deleted = 1
WHERE username = 'alice';
```

### List All Active Users

```sql
SELECT id, username, display_name, is_admin, created_at
FROM User
WHERE is_deleted = 0
ORDER BY username;
```

### Get User with Roles

```sql
SELECT 
    u.id,
    u.username,
    u.display_name,
    GROUP_CONCAT(r.name, ', ') as roles
FROM User u
LEFT JOIN RoleBinding rb ON u.id = rb.user_id
LEFT JOIN Role r ON rb.role_id = r.id
WHERE u.is_deleted = 0
GROUP BY u.id, u.username, u.display_name
ORDER BY u.username;
```

---

## Device Management

### Register New Unclaimed Device

```sql
INSERT INTO Device (device_id, public_key)
VALUES ('dev_abc123', '-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...
-----END PUBLIC KEY-----');
```

### Claim Device for User

```sql
UPDATE Device
SET is_claimed = 1,
    claimed_at = CURRENT_TIMESTAMP,
    claimed_by_user_id = (SELECT id FROM User WHERE username = 'alice')
WHERE device_id = 'dev_abc123';

-- Also log the claim event
INSERT INTO AuditEvent (user_id, event_type, event_data, success)
VALUES (
    (SELECT id FROM User WHERE username = 'alice'),
    'device.claimed',
    json_object('device_id', 'dev_abc123'),
    1
);
```

### Unclaim Device

```sql
UPDATE Device
SET is_claimed = 0,
    claimed_at = NULL,
    claimed_by_user_id = NULL
WHERE device_id = 'dev_abc123';
```

### List All Claimed Devices

```sql
SELECT 
    d.device_id,
    d.claimed_at,
    u.username as claimed_by,
    u.display_name
FROM Device d
JOIN User u ON d.claimed_by_user_id = u.id
WHERE d.is_claimed = 1
ORDER BY d.claimed_at DESC;
```

### Get Devices Claimed by User

```sql
SELECT 
    d.device_id,
    d.claimed_at,
    d.created_at
FROM Device d
WHERE d.is_claimed = 1
  AND d.claimed_by_user_id = (SELECT id FROM User WHERE username = 'alice')
ORDER BY d.claimed_at DESC;
```

---

## Role and Permission Management

### Assign Role to User (Global Scope)

```sql
INSERT INTO RoleBinding (user_id, role_id, scope_type, scope_id)
VALUES (
    (SELECT id FROM User WHERE username = 'alice'),
    (SELECT id FROM Role WHERE name = 'user'),
    'global',
    ''
);
```

### Assign Role to User (Device Scope)

```sql
INSERT INTO RoleBinding (user_id, role_id, scope_type, scope_id)
VALUES (
    (SELECT id FROM User WHERE username = 'alice'),
    (SELECT id FROM Role WHERE name = 'device_manager'),
    'device',
    'dev_abc123'
);
```

### Remove Role from User

```sql
DELETE FROM RoleBinding
WHERE user_id = (SELECT id FROM User WHERE username = 'alice')
  AND role_id = (SELECT id FROM Role WHERE name = 'user')
  AND scope_type = 'global';
```

### List User's Roles and Permissions

```sql
SELECT 
    r.name as role_name,
    r.permissions,
    rb.scope_type,
    rb.scope_id
FROM RoleBinding rb
JOIN Role r ON rb.role_id = r.id
WHERE rb.user_id = (SELECT id FROM User WHERE username = 'alice')
ORDER BY rb.scope_type, r.name;
```

### Check if User Has Permission

```sql
-- Check if user has admin role (which has all permissions)
SELECT COUNT(*) > 0 as has_permission
FROM User u
WHERE u.username = 'alice'
  AND u.is_admin = 1
  AND u.is_deleted = 0;

-- Check if user has specific role
SELECT COUNT(*) > 0 as has_permission
FROM RoleBinding rb
JOIN Role r ON rb.role_id = r.id
WHERE rb.user_id = (SELECT id FROM User WHERE username = 'alice')
  AND r.name = 'device_manager';
```

### Create Custom Role

```sql
INSERT INTO Role (name, description, permissions, is_system)
VALUES (
    'guest',
    'Guest access with limited permissions',
    '["devices.read"]',
    0
);
```

---

## Session Management

### Create New Session

```sql
INSERT INTO Session (
    session_token,
    user_id,
    device_fingerprint,
    ip_address,
    user_agent,
    expires_at
)
VALUES (
    'sess_' || hex(randomblob(16)),  -- Generate random session token
    (SELECT id FROM User WHERE username = 'alice'),
    'fingerprint_xyz',
    '192.168.1.100',
    'Mozilla/5.0 ...',
    datetime('now', '+1 hour')
);
```

### Validate Session

```sql
SELECT 
    s.id,
    s.user_id,
    u.username,
    u.is_admin
FROM Session s
JOIN User u ON s.user_id = u.id
WHERE s.session_token = 'sess_...'
  AND s.expires_at > CURRENT_TIMESTAMP
  AND u.is_deleted = 0;
```

### Invalidate Session

```sql
DELETE FROM Session
WHERE session_token = 'sess_...';
```

### Invalidate All User Sessions

```sql
DELETE FROM Session
WHERE user_id = (SELECT id FROM User WHERE username = 'alice');
```

### Clean Up Expired Sessions

```sql
DELETE FROM Session
WHERE expires_at < CURRENT_TIMESTAMP;
```

### List Active Sessions for User

```sql
SELECT 
    session_token,
    device_fingerprint,
    ip_address,
    created_at,
    expires_at
FROM Session
WHERE user_id = (SELECT id FROM User WHERE username = 'alice')
  AND expires_at > CURRENT_TIMESTAMP
ORDER BY created_at DESC;
```

### Create Refresh Token

```sql
INSERT INTO RefreshToken (
    token_hash,
    user_id,
    device_fingerprint,
    expires_at
)
VALUES (
    hex(randomblob(32)),  -- SHA-256 hash of actual token
    (SELECT id FROM User WHERE username = 'alice'),
    'fingerprint_xyz',
    datetime('now', '+90 days')
);
```

### Revoke Refresh Token

```sql
UPDATE RefreshToken
SET is_revoked = 1
WHERE token_hash = '...';
```

---

## Audit and Security

### Log User Login

```sql
INSERT INTO AuditEvent (
    user_id,
    event_type,
    event_data,
    ip_address,
    user_agent,
    success
)
VALUES (
    (SELECT id FROM User WHERE username = 'alice'),
    'user.login.success',
    json_object('method', 'password'),
    '192.168.1.100',
    'Mozilla/5.0 ...',
    1
);
```

### Log Failed Login Attempt

```sql
INSERT INTO AuditEvent (
    user_id,
    event_type,
    event_data,
    ip_address,
    success
)
VALUES (
    NULL,  -- User ID unknown for failed login
    'user.login.failed',
    json_object('username', 'alice', 'reason', 'invalid_password'),
    '192.168.1.100',
    0
);
```

### Get Recent Audit Events

```sql
SELECT 
    id,
    event_type,
    event_data,
    ip_address,
    success,
    created_at
FROM AuditEvent
ORDER BY created_at DESC
LIMIT 100;
```

### Get User Activity History

```sql
SELECT 
    event_type,
    event_data,
    ip_address,
    success,
    created_at
FROM AuditEvent
WHERE user_id = (SELECT id FROM User WHERE username = 'alice')
ORDER BY created_at DESC
LIMIT 50;
```

### Get Failed Login Attempts

```sql
SELECT 
    event_data,
    ip_address,
    created_at
FROM AuditEvent
WHERE event_type = 'user.login.failed'
  AND created_at > datetime('now', '-24 hours')
ORDER BY created_at DESC;
```

### Get Security Events by Type

```sql
SELECT 
    user_id,
    event_data,
    ip_address,
    created_at
FROM AuditEvent
WHERE event_type LIKE 'device.%'
  AND created_at > datetime('now', '-7 days')
ORDER BY created_at DESC;
```

---

## Recovery Codes

### Generate Recovery Codes for User

```sql
-- Generate 10 recovery codes (in practice, hash these with SHA-256)
INSERT INTO RecoveryCode (user_id, code_hash)
SELECT 
    (SELECT id FROM User WHERE username = 'alice'),
    hex(randomblob(16))
FROM (
    SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5
    UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9 UNION SELECT 10
);
```

### Check Recovery Code

```sql
SELECT id, user_id, is_used
FROM RecoveryCode
WHERE code_hash = 'hash_of_submitted_code'
  AND is_used = 0;
```

### Mark Recovery Code as Used

```sql
UPDATE RecoveryCode
SET is_used = 1,
    used_at = CURRENT_TIMESTAMP
WHERE id = ?;

-- Also log the usage
INSERT INTO AuditEvent (user_id, event_type, event_data, success)
VALUES (
    (SELECT user_id FROM RecoveryCode WHERE id = ?),
    'recovery_code.used',
    json_object('recovery_code_id', ?),
    1
);
```

### Count Unused Recovery Codes

```sql
SELECT COUNT(*) as unused_codes
FROM RecoveryCode
WHERE user_id = (SELECT id FROM User WHERE username = 'alice')
  AND is_used = 0;
```

### Invalidate All Recovery Codes

```sql
DELETE FROM RecoveryCode
WHERE user_id = (SELECT id FROM User WHERE username = 'alice');
```

---

## Advanced Queries

### User Dashboard Stats

```sql
SELECT 
    (SELECT COUNT(*) FROM Device WHERE claimed_by_user_id = u.id) as devices_claimed,
    (SELECT COUNT(*) FROM Session WHERE user_id = u.id AND expires_at > CURRENT_TIMESTAMP) as active_sessions,
    (SELECT COUNT(*) FROM RecoveryCode WHERE user_id = u.id AND is_used = 0) as unused_recovery_codes,
    u.created_at as member_since
FROM User u
WHERE u.username = 'alice';
```

### System Health Check

```sql
SELECT 
    'users' as metric,
    COUNT(*) as count
FROM User WHERE is_deleted = 0
UNION ALL
SELECT 'devices', COUNT(*) FROM Device WHERE is_claimed = 1
UNION ALL
SELECT 'active_sessions', COUNT(*) FROM Session WHERE expires_at > CURRENT_TIMESTAMP
UNION ALL
SELECT 'audit_events_today', COUNT(*) FROM AuditEvent WHERE created_at > date('now')
UNION ALL
SELECT 'roles', COUNT(*) FROM Role;
```

### Find Suspicious Login Activity

```sql
-- Multiple failed login attempts from same IP
SELECT 
    ip_address,
    COUNT(*) as failed_attempts,
    MAX(created_at) as last_attempt
FROM AuditEvent
WHERE event_type = 'user.login.failed'
  AND created_at > datetime('now', '-1 hour')
GROUP BY ip_address
HAVING COUNT(*) > 5
ORDER BY failed_attempts DESC;
```

### Devices Claimed in Last 7 Days

```sql
SELECT 
    d.device_id,
    u.username,
    d.claimed_at
FROM Device d
JOIN User u ON d.claimed_by_user_id = u.id
WHERE d.claimed_at > datetime('now', '-7 days')
ORDER BY d.claimed_at DESC;
```

### Users with No Active Sessions

```sql
SELECT 
    u.username,
    u.display_name,
    MAX(s.created_at) as last_session
FROM User u
LEFT JOIN Session s ON u.id = s.user_id
WHERE u.is_deleted = 0
GROUP BY u.id, u.username, u.display_name
HAVING MAX(s.expires_at) IS NULL OR MAX(s.expires_at) < CURRENT_TIMESTAMP
ORDER BY u.username;
```

### Secret Rotation Status

```sql
SELECT 
    secret_type,
    COUNT(*) as count,
    MIN(rotated_at) as oldest_rotation,
    MAX(rotated_at) as latest_rotation
FROM SecretMetadata
GROUP BY secret_type
ORDER BY oldest_rotation;
```

### Permissions Report

```sql
SELECT 
    u.username,
    GROUP_CONCAT(DISTINCT r.name) as roles,
    COUNT(DISTINCT rb.id) as role_bindings
FROM User u
LEFT JOIN RoleBinding rb ON u.id = rb.user_id
LEFT JOIN Role r ON rb.role_id = r.id
WHERE u.is_deleted = 0
GROUP BY u.id, u.username
ORDER BY u.username;
```

---

## Performance Tips

1. **Use Prepared Statements**: Always use parameterized queries to prevent SQL injection
   ```sql
   -- Good
   SELECT * FROM User WHERE username = ?
   
   -- Bad (vulnerable to SQL injection)
   SELECT * FROM User WHERE username = 'user_input'
   ```

2. **Leverage Indexes**: The schema includes indexes on frequently queried columns
   ```sql
   -- Fast (uses idx_device_device_id)
   SELECT * FROM Device WHERE device_id = 'dev_123';
   
   -- Slow (no index on public_key)
   SELECT * FROM Device WHERE public_key LIKE '%abc%';
   ```

3. **Use Views for Complex Queries**: Pre-defined views are optimized
   ```sql
   -- Use view
   SELECT * FROM ActiveSessions WHERE username = 'alice';
   
   -- Instead of joining manually
   SELECT s.* FROM Session s JOIN User u ON s.user_id = u.id 
   WHERE u.username = 'alice' AND s.expires_at > CURRENT_TIMESTAMP;
   ```

4. **Batch Operations**: Use transactions for multiple related operations
   ```sql
   BEGIN TRANSACTION;
   INSERT INTO User (...) VALUES (...);
   INSERT INTO RoleBinding (...) VALUES (...);
   INSERT INTO RecoveryCode (...) VALUES (...);
   COMMIT;
   ```

5. **Regular Cleanup**: Periodically clean expired data
   ```sql
   -- Run daily
   DELETE FROM Session WHERE expires_at < datetime('now', '-7 days');
   DELETE FROM RefreshToken WHERE expires_at < CURRENT_TIMESTAMP AND is_revoked = 1;
   ```

---

*For more information, see the [ERD documentation](erd.md) and [schema README](../db/schema/README.md).*
