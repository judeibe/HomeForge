-- Migration: 001_initial_schema
-- Description: Create initial database schema for HomeForge Supervisor
-- Date: 2026-02-13
-- Issue: HOM-6

-- Enable foreign key constraints
PRAGMA foreign_keys = ON;

-- ============================================================================
-- TABLE: Device
-- Description: Physical devices in the HomeForge ecosystem
-- ============================================================================
CREATE TABLE IF NOT EXISTS Device (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL UNIQUE,
    public_key TEXT NOT NULL,
    is_claimed BOOLEAN NOT NULL DEFAULT 0,
    claimed_at TIMESTAMP NULL,
    claimed_by_user_id INTEGER NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (claimed_by_user_id) REFERENCES User(id) ON DELETE CASCADE,
    
    CHECK (is_claimed IN (0, 1)),
    CHECK (is_claimed = 0 OR (claimed_at IS NOT NULL AND claimed_by_user_id IS NOT NULL))
);

CREATE INDEX idx_device_device_id ON Device(device_id);
CREATE INDEX idx_device_is_claimed ON Device(is_claimed);
CREATE INDEX idx_device_claimed_by_user_id ON Device(claimed_by_user_id);

-- ============================================================================
-- TABLE: User
-- Description: Local user accounts for authentication and authorization
-- ============================================================================
CREATE TABLE IF NOT EXISTS User (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    display_name TEXT NOT NULL,
    is_admin BOOLEAN NOT NULL DEFAULT 0,
    is_deleted BOOLEAN NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CHECK (is_admin IN (0, 1)),
    CHECK (is_deleted IN (0, 1)),
    CHECK (length(username) >= 3 AND length(username) <= 64),
    CHECK (length(display_name) >= 1 AND length(display_name) <= 128)
);

CREATE INDEX idx_user_username ON User(username);
CREATE INDEX idx_user_is_deleted ON User(is_deleted);
CREATE INDEX idx_user_is_admin ON User(is_admin);

-- ============================================================================
-- TABLE: Role
-- Description: RBAC role definitions with associated permissions
-- ============================================================================
CREATE TABLE IF NOT EXISTS Role (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL,
    permissions TEXT NOT NULL, -- JSON array of permission strings
    is_system BOOLEAN NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    CHECK (is_system IN (0, 1)),
    CHECK (length(name) >= 1 AND length(name) <= 64)
);

CREATE INDEX idx_role_name ON Role(name);
CREATE INDEX idx_role_is_system ON Role(is_system);

-- Insert default system roles
INSERT INTO Role (name, description, permissions, is_system) VALUES
    ('admin', 'Full system administrator access', '["*"]', 1),
    ('user', 'Standard user access', '["devices.read", "devices.control", "profile.read", "profile.update"]', 1),
    ('device_manager', 'Device management only', '["devices.read", "devices.write", "devices.delete"]', 1),
    ('readonly', 'Read-only access', '["devices.read", "profile.read"]', 1);

-- ============================================================================
-- TABLE: RoleBinding
-- Description: Maps users to roles with optional scope restrictions
-- ============================================================================
CREATE TABLE IF NOT EXISTS RoleBinding (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    role_id INTEGER NOT NULL,
    scope_type TEXT NOT NULL DEFAULT 'global', -- 'global', 'device', 'room', etc.
    scope_id TEXT NULL, -- NULL for global scope
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES User(id) ON DELETE CASCADE,
    FOREIGN KEY (role_id) REFERENCES Role(id) ON DELETE CASCADE,
    
    UNIQUE (user_id, role_id, scope_type, scope_id),
    CHECK (scope_type IN ('global', 'device', 'room', 'zone')),
    CHECK (scope_type = 'global' OR scope_id IS NOT NULL)
);

CREATE INDEX idx_rolebinding_user_id ON RoleBinding(user_id);
CREATE INDEX idx_rolebinding_role_id ON RoleBinding(role_id);
CREATE INDEX idx_rolebinding_scope ON RoleBinding(scope_type, scope_id);

-- ============================================================================
-- TABLE: Session
-- Description: Active user sessions with associated metadata
-- ============================================================================
CREATE TABLE IF NOT EXISTS Session (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_token TEXT NOT NULL UNIQUE,
    user_id INTEGER NOT NULL,
    device_fingerprint TEXT NOT NULL,
    ip_address TEXT NULL,
    user_agent TEXT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES User(id) ON DELETE CASCADE,
    
    CHECK (expires_at > created_at)
);

CREATE INDEX idx_session_token ON Session(session_token);
CREATE INDEX idx_session_user_id ON Session(user_id);
CREATE INDEX idx_session_expires_at ON Session(expires_at);
CREATE INDEX idx_session_device_fingerprint ON Session(device_fingerprint);

-- ============================================================================
-- TABLE: RefreshToken
-- Description: Long-lived tokens for session renewal
-- ============================================================================
CREATE TABLE IF NOT EXISTS RefreshToken (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    token_hash TEXT NOT NULL UNIQUE,
    user_id INTEGER NOT NULL,
    device_fingerprint TEXT NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    is_revoked BOOLEAN NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES User(id) ON DELETE CASCADE,
    
    CHECK (is_revoked IN (0, 1)),
    CHECK (expires_at > created_at)
);

CREATE INDEX idx_refreshtoken_token_hash ON RefreshToken(token_hash);
CREATE INDEX idx_refreshtoken_user_id ON RefreshToken(user_id);
CREATE INDEX idx_refreshtoken_expires_at ON RefreshToken(expires_at);
CREATE INDEX idx_refreshtoken_is_revoked ON RefreshToken(is_revoked);

-- ============================================================================
-- TABLE: RecoveryCode
-- Description: Hashed backup recovery codes for account access
-- ============================================================================
CREATE TABLE IF NOT EXISTS RecoveryCode (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    code_hash TEXT NOT NULL UNIQUE,
    is_used BOOLEAN NOT NULL DEFAULT 0,
    used_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES User(id) ON DELETE CASCADE,
    
    CHECK (is_used IN (0, 1)),
    CHECK (is_used = 0 OR used_at IS NOT NULL)
);

CREATE INDEX idx_recoverycode_code_hash ON RecoveryCode(code_hash);
CREATE INDEX idx_recoverycode_user_id ON RecoveryCode(user_id);
CREATE INDEX idx_recoverycode_is_used ON RecoveryCode(is_used);

-- ============================================================================
-- TABLE: AuditEvent
-- Description: Append-only audit log for security events
-- ============================================================================
CREATE TABLE IF NOT EXISTS AuditEvent (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NULL,
    event_type TEXT NOT NULL,
    event_data TEXT NOT NULL, -- JSON event details
    ip_address TEXT NULL,
    user_agent TEXT NULL,
    success BOOLEAN NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (user_id) REFERENCES User(id) ON DELETE SET NULL,
    
    CHECK (success IN (0, 1)),
    CHECK (length(event_type) >= 1 AND length(event_type) <= 128)
);

CREATE INDEX idx_auditevent_user_id ON AuditEvent(user_id);
CREATE INDEX idx_auditevent_event_type ON AuditEvent(event_type);
CREATE INDEX idx_auditevent_created_at ON AuditEvent(created_at);
CREATE INDEX idx_auditevent_success ON AuditEvent(success);

-- ============================================================================
-- TABLE: SecretMetadata
-- Description: Metadata and references for encrypted secrets
-- Note: Actual secrets are NOT stored in the database
-- ============================================================================
CREATE TABLE IF NOT EXISTS SecretMetadata (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    secret_id TEXT NOT NULL UNIQUE,
    secret_type TEXT NOT NULL,
    description TEXT NOT NULL,
    key_derivation_info TEXT NULL, -- JSON with key derivation parameters
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    rotated_at TIMESTAMP NULL,
    
    CHECK (secret_type IN ('api_key', 'certificate', 'signing_key', 'encryption_key', 'private_key', 'symmetric_key')),
    CHECK (length(secret_id) >= 1 AND length(secret_id) <= 128)
);

CREATE INDEX idx_secretmetadata_secret_id ON SecretMetadata(secret_id);
CREATE INDEX idx_secretmetadata_secret_type ON SecretMetadata(secret_type);
CREATE INDEX idx_secretmetadata_rotated_at ON SecretMetadata(rotated_at);

-- ============================================================================
-- TRIGGERS: Updated_at timestamp automation
-- ============================================================================

-- Trigger for Device table
CREATE TRIGGER update_device_timestamp 
AFTER UPDATE ON Device
FOR EACH ROW
BEGIN
    UPDATE Device SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Trigger for User table
CREATE TRIGGER update_user_timestamp 
AFTER UPDATE ON User
FOR EACH ROW
BEGIN
    UPDATE User SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Trigger for Role table
CREATE TRIGGER update_role_timestamp 
AFTER UPDATE ON Role
FOR EACH ROW
BEGIN
    UPDATE Role SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Trigger for RoleBinding table
CREATE TRIGGER update_rolebinding_timestamp 
AFTER UPDATE ON RoleBinding
FOR EACH ROW
BEGIN
    UPDATE RoleBinding SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Trigger for Session table
CREATE TRIGGER update_session_timestamp 
AFTER UPDATE ON Session
FOR EACH ROW
BEGIN
    UPDATE Session SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Trigger for RefreshToken table
CREATE TRIGGER update_refreshtoken_timestamp 
AFTER UPDATE ON RefreshToken
FOR EACH ROW
BEGIN
    UPDATE RefreshToken SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Trigger for SecretMetadata table
CREATE TRIGGER update_secretmetadata_timestamp 
AFTER UPDATE ON SecretMetadata
FOR EACH ROW
BEGIN
    UPDATE SecretMetadata SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- ============================================================================
-- TRIGGERS: Audit event protection (prevent updates/deletes)
-- ============================================================================

CREATE TRIGGER prevent_auditevent_update
BEFORE UPDATE ON AuditEvent
FOR EACH ROW
BEGIN
    SELECT RAISE(ABORT, 'AuditEvent records cannot be updated');
END;

CREATE TRIGGER prevent_auditevent_delete
BEFORE DELETE ON AuditEvent
FOR EACH ROW
BEGIN
    SELECT RAISE(ABORT, 'AuditEvent records cannot be deleted');
END;

-- ============================================================================
-- TRIGGERS: System role protection (prevent deletion)
-- ============================================================================

CREATE TRIGGER prevent_system_role_delete
BEFORE DELETE ON Role
FOR EACH ROW
WHEN OLD.is_system = 1
BEGIN
    SELECT RAISE(ABORT, 'System roles cannot be deleted');
END;

-- ============================================================================
-- VIEWS: Commonly used queries
-- ============================================================================

-- View: Active Sessions
CREATE VIEW IF NOT EXISTS ActiveSessions AS
SELECT 
    s.id,
    s.session_token,
    s.user_id,
    u.username,
    u.display_name,
    s.device_fingerprint,
    s.ip_address,
    s.expires_at,
    s.created_at
FROM Session s
JOIN User u ON s.user_id = u.id
WHERE s.expires_at > CURRENT_TIMESTAMP
  AND u.is_deleted = 0;

-- View: User Permissions
CREATE VIEW IF NOT EXISTS UserPermissions AS
SELECT 
    u.id as user_id,
    u.username,
    u.is_admin,
    r.name as role_name,
    r.permissions,
    rb.scope_type,
    rb.scope_id
FROM User u
LEFT JOIN RoleBinding rb ON u.id = rb.user_id
LEFT JOIN Role r ON rb.role_id = r.id
WHERE u.is_deleted = 0;

-- View: Claimed Devices
CREATE VIEW IF NOT EXISTS ClaimedDevices AS
SELECT 
    d.id,
    d.device_id,
    d.is_claimed,
    d.claimed_at,
    d.claimed_by_user_id,
    u.username as claimed_by_username,
    u.display_name as claimed_by_display_name,
    d.created_at
FROM Device d
LEFT JOIN User u ON d.claimed_by_user_id = u.id
WHERE d.is_claimed = 1;

-- View: Unused Recovery Codes
CREATE VIEW IF NOT EXISTS UnusedRecoveryCodes AS
SELECT 
    rc.id,
    rc.user_id,
    u.username,
    rc.created_at
FROM RecoveryCode rc
JOIN User u ON rc.user_id = u.id
WHERE rc.is_used = 0
  AND u.is_deleted = 0;

-- ============================================================================
-- Migration Complete
-- ============================================================================

-- Insert audit event for migration
INSERT INTO AuditEvent (user_id, event_type, event_data, success) VALUES
    (NULL, 'system.migration.completed', '{"migration": "001_initial_schema", "version": "1.0"}', 1);
