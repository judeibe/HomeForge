-- Migration Rollback: 001_initial_schema
-- Description: Rollback initial database schema
-- Date: 2026-02-13
-- Issue: HOM-6

-- Disable foreign key constraints temporarily
PRAGMA foreign_keys = OFF;

-- ============================================================================
-- DROP VIEWS
-- ============================================================================

DROP VIEW IF EXISTS UnusedRecoveryCodes;
DROP VIEW IF EXISTS ClaimedDevices;
DROP VIEW IF EXISTS UserPermissions;
DROP VIEW IF EXISTS ActiveSessions;

-- ============================================================================
-- DROP TRIGGERS
-- ============================================================================

-- Audit event protection triggers
DROP TRIGGER IF EXISTS prevent_auditevent_delete;
DROP TRIGGER IF EXISTS prevent_auditevent_update;

-- System role protection trigger
DROP TRIGGER IF EXISTS prevent_system_role_delete;

-- Updated_at triggers
DROP TRIGGER IF EXISTS update_secretmetadata_timestamp;
DROP TRIGGER IF EXISTS update_refreshtoken_timestamp;
DROP TRIGGER IF EXISTS update_session_timestamp;
DROP TRIGGER IF EXISTS update_rolebinding_timestamp;
DROP TRIGGER IF EXISTS update_role_timestamp;
DROP TRIGGER IF EXISTS update_user_timestamp;
DROP TRIGGER IF EXISTS update_device_timestamp;

-- ============================================================================
-- DROP INDEXES
-- ============================================================================

-- SecretMetadata indexes
DROP INDEX IF EXISTS idx_secretmetadata_rotated_at;
DROP INDEX IF EXISTS idx_secretmetadata_secret_type;
DROP INDEX IF EXISTS idx_secretmetadata_secret_id;

-- AuditEvent indexes
DROP INDEX IF EXISTS idx_auditevent_success;
DROP INDEX IF EXISTS idx_auditevent_created_at;
DROP INDEX IF EXISTS idx_auditevent_event_type;
DROP INDEX IF EXISTS idx_auditevent_user_id;

-- RecoveryCode indexes
DROP INDEX IF EXISTS idx_recoverycode_is_used;
DROP INDEX IF EXISTS idx_recoverycode_user_id;
DROP INDEX IF EXISTS idx_recoverycode_code_hash;

-- RefreshToken indexes
DROP INDEX IF EXISTS idx_refreshtoken_is_revoked;
DROP INDEX IF EXISTS idx_refreshtoken_expires_at;
DROP INDEX IF EXISTS idx_refreshtoken_user_id;
DROP INDEX IF EXISTS idx_refreshtoken_token_hash;

-- Session indexes
DROP INDEX IF EXISTS idx_session_device_fingerprint;
DROP INDEX IF EXISTS idx_session_expires_at;
DROP INDEX IF EXISTS idx_session_user_id;
DROP INDEX IF EXISTS idx_session_token;

-- RoleBinding indexes
DROP INDEX IF EXISTS idx_rolebinding_scope;
DROP INDEX IF EXISTS idx_rolebinding_role_id;
DROP INDEX IF EXISTS idx_rolebinding_user_id;

-- Role indexes
DROP INDEX IF EXISTS idx_role_is_system;
DROP INDEX IF EXISTS idx_role_name;

-- User indexes
DROP INDEX IF EXISTS idx_user_is_admin;
DROP INDEX IF EXISTS idx_user_is_deleted;
DROP INDEX IF EXISTS idx_user_username;

-- Device indexes
DROP INDEX IF EXISTS idx_device_claimed_by_user_id;
DROP INDEX IF EXISTS idx_device_is_claimed;
DROP INDEX IF EXISTS idx_device_device_id;

-- ============================================================================
-- DROP TABLES
-- ============================================================================

DROP TABLE IF EXISTS SecretMetadata;
DROP TABLE IF EXISTS AuditEvent;
DROP TABLE IF EXISTS RecoveryCode;
DROP TABLE IF EXISTS RefreshToken;
DROP TABLE IF EXISTS Session;
DROP TABLE IF EXISTS RoleBinding;
DROP TABLE IF EXISTS Role;
DROP TABLE IF EXISTS User;
DROP TABLE IF EXISTS Device;

-- ============================================================================
-- Re-enable foreign key constraints
-- ============================================================================

PRAGMA foreign_keys = ON;

-- ============================================================================
-- Rollback Complete
-- ============================================================================
