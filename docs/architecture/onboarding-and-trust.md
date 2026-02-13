# Onboarding and Trust Architecture (LAN vs Tunnel)

**Version:** 1.0  
**Date:** 2026-02-12  
**Status:** Draft  
**Issue:** [HOM-5](https://linear.app/homeforge/issue/HOM-5/define-onboarding-trust-architecture-lan-vs-tunnel)

## Executive Summary

This document defines the foundational design for device onboarding and trust establishment in HomeForge, a local-first smart home platform. The architecture prioritizes local control while providing optional cloud connectivity for remote access through secure tunnels.

**Key Principles:**

- Local-first: Devices work fully offline without cloud dependency
- Optional cloud: Remote access via secure tunnels when opted-in
- Zero-knowledge cloud: Cloud provider cannot access user data or control devices
- Progressive trust: Devices start unclaimed and gain trust through cryptographic proof

---

## Table of Contents

1. [Device States](#device-states)
2. [Local-First Authentication Requirements](#local-first-authentication-requirements)
3. [Cloud Account Relationship](#cloud-account-relationship)
4. [Secure Tunnel Enabling Flow](#secure-tunnel-enabling-flow)
5. [Threat Model](#threat-model)
6. [Non-Goals for MVP](#non-goals-for-mvp)
7. [Security Assumptions](#security-assumptions)
8. [Rollout and Upgrade Considerations](#rollout-and-upgrade-considerations)

---

## 1. Device States {#device-states}

### 1.1 Unclaimed Device State

An **unclaimed device** is a factory-fresh or factory-reset HomeForge device that has not been associated with any user account.

#### Characteristics

- **Identity:** Device has a unique device ID (UUID) and public/private key pair generated on first boot
- **Network:** Can connect to WiFi/Ethernet but has no authentication credentials
- **Access:** Broadcasts its presence on local network via mDNS/Bonjour for discovery
- **API:** Exposes a limited "onboarding API" accessible only from local network
- **Storage:** No user data, only factory firmware and device certificates
- **Trust:** Accepts commands only from devices on the same LAN segment during onboarding window

#### Security Posture

```text
┌─────────────────────────────────────┐
│     Unclaimed Device (LAN Only)     │
├─────────────────────────────────────┤
│ • mDNS advertisement                │
│ • Onboarding API (HTTP/HTTPS)       │
│ • Short-lived pairing mode (15 min) │
│ • Accept pairing from LAN only      │
│ • No user credentials stored        │
└─────────────────────────────────────┘
```

#### Onboarding Window

- Triggered by: Physical button press OR first power-on
- Duration: 15 minutes (configurable)
- Visual indicator: LED flashing pattern
- After timeout: Returns to secure mode, requires factory reset for new attempt

### 1.2 Claimed Device State

A **claimed device** has been successfully onboarded and is associated with a HomeForge home instance.

#### Characteristics

- **Identity:** Same device ID, plus enrolled in home's trust chain
- **Credentials:** Has home's root certificate and device-specific certificates
- **Access Control:** Enforces authentication for all API access
- **Storage:** Stores encrypted user data and home configuration
- **Trust:** Validates all requests using cryptographic signatures
- **Network Modes:**
  - **LAN mode:** Direct local communication with home controller
  - **Tunnel mode:** (Optional) Secure tunnel for remote access via cloud relay

#### Security Posture

```text
┌─────────────────────────────────────┐
│      Claimed Device (Secure)        │
├─────────────────────────────────────┤
│ • mTLS authentication required      │
│ • Home certificate validation       │
│ • Encrypted data at rest            │
│ • Signed firmware updates only      │
│ • Optional cloud tunnel (E2EE)      │
└─────────────────────────────────────┘
```

### 1.3 State Transition Diagram

```text
┌──────────────┐
│   Factory    │
│   Reset      │
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│  Unclaimed Device    │
│  - Generated key pair│
│  - mDNS broadcast    │
│  - Onboarding API    │
└──────┬───────────────┘
       │ Pairing request from
       │ authorized controller
       ▼
┌──────────────────────┐
│   Claimed Device     │
│  - Home certificate  │
│  - Authentication on │
│  - User data stored  │
└──────┬───────────────┘
       │ Factory reset
       │ command (authenticated)
       ▼
┌──────────────────────┐
│  Unclaimed Device    │
│  (Fresh key pair)    │
└──────────────────────┘
```

---

## 2. Local-First Authentication Requirement{#local-first-authentication-requirements}

### 2.1 Core Principle

**All device control must work without internet access.** The authentication system is designed to operate entirely on the local network with no dependency on cloud services.

### 2.2 Authentication Architecture

#### Home Certificate Authority (CA)

Each HomeForge installation acts as its own certificate authority:

```text
┌─────────────────────────────────────────┐
│         Home Root Certificate           │
│  • Self-signed during initial setup     │
│  • Long-lived (10 years)                │
│  • Stored encrypted on home controller  │
│  • Used to sign device certificates     │
└─────────────────────────────────────────┘
                    │
        ┌───────────┼───────────┐
        ▼           ▼           ▼
   ┌────────┐  ┌────────┐  ┌────────┐
   │Device 1│  │Device 2│  │Device 3│
   │  Cert  │  │  Cert  │  │  Cert  │
   └────────┘  └────────┘  └────────┘
```

#### Device Certificate Lifecycle

1. **Enrollment:** During onboarding, device submits CSR (Certificate Signing Request)
2. **Issuance:** Home controller signs CSR with home root CA
3. **Installation:** Device receives and stores signed certificate
4. **Validation:** All subsequent requests use mTLS with certificate validation
5. **Revocation:** Certificates can be revoked and blacklisted by home controller

### 2.3 User Authentication

#### Primary: Local Password/PIN

- **Setup:** User creates password during initial home setup
- **Storage:** Password hashed with Argon2id, stored on home controller
- **Verification:** All local authentication against this credential
- **Recovery:** Physical reset procedure with multi-step confirmation

#### Secondary: Device-Based Tokens

For user devices (phones, tablets):

- **Enrollment:** User authenticates with password, receives long-lived token
- **Token Format:** JWT signed by home root CA
- **Token Storage:** Secure enclave on device (iOS Keychain, Android KeyStore)
- **Rotation:** Tokens rotated every 90 days, old tokens remain valid for 30 days

#### Session Management

```text
User Device                 Home Controller
    │                              │
    │──── Login (password) ────────>│
    │                              │ Verify password hash
    │                              │ Generate session token
    │<─── Session token ────────────│
    │                              │
    │──── API request + token ─────>│
    │                              │ Validate token signature
    │                              │ Check expiration
    │<─── Response ─────────────────│
```

### 2.4 Cryptographic Specifications

- **Certificates:** ECDSA P-256 (secp256r1) for device certs
- **Key Exchange:** ECDHE for TLS connections
- **Password Hashing:** Argon2id (time=3, memory=64MB, parallelism=4)
- **Signatures:** Ed25519 for command signing
- **Encryption at Rest:** AES-256-GCM with device-unique keys

---

## 3. Cloud Account Relationship {#cloud-account-relationship}

### 3.1 Design Philosophy

**The cloud is optional and zero-knowledge.** Users can run HomeForge entirely locally, or opt-in to cloud services for remote access convenience.

### 3.2 Local vs Cloud Data Split

#### Data Stored ONLY Locally

- Device credentials and certificates
- User passwords/PINs
- Home automation rules and scenes
- Device state history
- Media files and recordings
- Encryption keys for user data
- Audit logs of all commands

#### Data Stored in Cloud (If Enabled)

- User account email (for login and recovery)
- Home ID (opaque UUID, no metadata)
- Device public keys (for tunnel routing)
- Tunnel connection metadata (IP, timestamps)
- Encrypted tunnel session keys (only endpoints can decrypt)

#### Data Never Stored Anywhere

- User activity patterns (analytics disabled by default)
- Plaintext device commands
- Unencrypted media or recordings

### 3.3 Cloud Account Relationship Model

```text
┌──────────────────────────────────────────────────┐
│              User (Optional)                     │
│        email: user@example.com                   │
│        cloud_user_id: uuid                       │
└────────────────┬─────────────────────────────────┘
                 │
                 │ owns (optional)
                 │
         ┌───────┴────────┐
         ▼                ▼
┌─────────────────┐  ┌─────────────────┐
│    Home A       │  │    Home B       │
│  home_id: uuid  │  │  home_id: uuid  │
│  (Local First)  │  │  (Local First)  │
└────────┬────────┘  └────────┬────────┘
         │                    │
         │ contains           │ contains
         │                    │
    ┌────┴─────┬──────┐      │
    ▼          ▼      ▼      ▼
┌────────┐ ┌────────┐ ...  ┌────────┐
│Device 1│ │Device 2│      │Device N│
└────────┘ └────────┘      └────────┘
```

### 3.4 Cloud Service Boundaries

The cloud service provides:

1. **Account Management:** User registration, email verification, password reset
2. **Tunnel Coordination:** NAT traversal, relay routing, connection brokering
3. **Discovery:** Find home public keys to establish secure tunnel
4. **Availability:** Relay ensures connectivity even behind restrictive NATs

The cloud service CANNOT:

- Read or modify device commands
- Access home automation rules
- Decrypt device state or media
- Issue commands to devices
- View user activity beyond connection metadata

---

## 4. Secure Tunnel Enabling Flow {#secure-tunnel-enabling-flow}

### 4.1 Overview

Secure tunnels enable remote access to HomeForge from outside the local network. The tunnel is end-to-end encrypted, with the cloud relay having zero knowledge of the traffic.

### 4.2 Prerequisites

Before enabling tunnel:

1. Home controller is claimed and operational locally
2. User has created a cloud account (optional step)
3. Home is linked to user's cloud account
4. Network allows outbound HTTPS (443) and WebSocket connections

### 4.3 Tunnel Architecture

```text
┌────────────────┐                           ┌────────────────┐
│  Mobile Device │                           │ Home Controller│
│   (Remote)     │                           │   (Behind NAT) │
└────────┬───────┘                           └────────┬───────┘
         │                                            │
         │ 1. Request tunnel                          │
         │    with home_id                            │
         ▼                                            │
┌─────────────────────────────────────────────────┐  │
│           Cloud Tunnel Service                  │  │
│  • Verifies user owns home_id                   │  │
│  • Returns tunnel endpoint                      │  │
└─────────────────┬───────────────────────────────┘  │
         │        │                                   │
         │        │ 2. Establish WebSocket            │
         │        │<──────────────────────────────────┘
         │        │    with home credentials
         │        │
         │        │ 3. Relay ready notification
         │<───────┘
         │
         │ 4. Connect to relay endpoint
         └────────>
         
┌────────────────────────────────────────────────────┐
│     E2E Encrypted Tunnel Established               │
│  Mobile <──[encrypted]──> Relay <──[encrypted]──>  │
│                          (zero knowledge)          │
└────────────────────────────────────────────────────┘
```

### 4.4 Detailed Sequence Diagram

```text
User Device          Cloud Service         Home Controller
    │                      │                      │
    │ 1. Cloud login       │                      │
    │─────────────────────>│                      │
    │   (email/password)   │                      │
    │                      │                      │
    │ 2. JWT token         │                      │
    │<─────────────────────│                      │
    │                      │                      │
    │ 3. Link home         │                      │
    │─────────────────────>│                      │
    │  (home_public_key,   │                      │
    │   home_id)           │                      │
    │                      │                      │
    │                      │ 4. Register home     │
    │                      │─────────────────────>│
    │                      │   (home_id,          │
    │                      │    public_key)       │
    │                      │                      │
    │                      │ 5. Confirm           │
    │                      │<─────────────────────│
    │                      │                      │
    │                      │ 6. WS connect        │
    │                      │<─────────────────────│
    │                      │   (persistent)       │
    │                      │                      │
    │ 7. Request tunnel    │                      │
    │─────────────────────>│                      │
    │   (home_id)          │                      │
    │                      │                      │
    │                      │ 8. Notify tunnel     │
    │                      │      request         │
    │                      │─────────────────────>│
    │                      │                      │
    │                      │ 9. Generate session  │
    │                      │    key pair          │
    │                      │<─────────────────────│
    │                      │  (pub_key_session)   │
    │                      │                      │
    │ 10. Session keys     │                      │
    │<─────────────────────│                      │
    │  (pub_key_home,      │                      │
    │   pub_key_user)      │                      │
    │                      │                      │
    │ 11. Derive shared    │                      │ 11. Derive shared
    │     secret (ECDH)    │                      │     secret (ECDH)
    │                      │                      │
    │ 12. Encrypted tunnel │                      │
    │<════════════════════════════════════════════>│
    │          Relay forwards encrypted packets    │
    │          but cannot decrypt them             │
```

### 4.5 Tunnel Security Properties

1. **End-to-End Encryption:**
   - Session keys derived using ECDH (Elliptic Curve Diffie-Hellman)
   - Symmetric encryption: ChaCha20-Poly1305
   - Forward secrecy: New session keys for each tunnel session

2. **Authentication:**
   - User proves ownership of cloud account
   - Home controller proves ownership of home_id
   - Mutual authentication before key exchange

3. **Integrity:**
   - All tunnel packets signed with session keys
   - Replay protection via nonce/sequence numbers
   - Tampering detected and connection terminated

4. **Privacy:**
   - Cloud relay cannot decrypt payload
   - Only sees encrypted bytes and routing metadata
   - No correlation between user identity and traffic patterns

### 4.6 Tunnel Lifecycle

```text
State: DISABLED
    │
    │ User enables remote access
    ▼
State: REGISTERING
    │ Home registers with cloud
    │ Establishes persistent WebSocket
    ▼
State: READY
    │ Waiting for tunnel requests
    │
    │ Remote user requests connection
    ▼
State: CONNECTING
    │ Key exchange
    │ Establish encrypted channel
    ▼
State: CONNECTED
    │ Tunnel active
    │ Passing encrypted traffic
    │
    │ User disconnects OR timeout
    ▼
State: READY
    │ Session cleaned up
    │ Waiting for next request
```

---

## 5. Threat Model {#threat-model}

### 5.1 Assets to Protect

1. **User Privacy:** Activity patterns, automation rules, device usage
2. **Device Control:** Unauthorized command execution
3. **Home Access:** Physical security via smart locks, cameras
4. **Data Integrity:** Configuration, logs, media
5. **Cryptographic Material:** Private keys, certificates, passwords

### 5.2 Trust Boundaries

```text
┌────────────────────────────────────────────────────┐
│                Trusted Zone                        │
│  ┌──────────────────────────────────────────┐     │
│  │  Local Network (LAN)                     │     │
│  │  • Home Controller                       │     │
│  │  • Claimed Devices                       │     │
│  │  • Authenticated User Devices            │     │
│  └──────────────────────────────────────────┘     │
│                                                    │
│  ┌──────────────────────────────────────────┐     │
│  │  E2E Encrypted Tunnel                    │     │
│  │  • Authenticated remote user             │     │
│  └──────────────────────────────────────────┘     │
└────────────────────────────────────────────────────┘
                      │
         Untrusted boundary
                      │
┌────────────────────────────────────────────────────┐
│             Untrusted Zone                         │
│  • Internet                                        │
│  • Cloud Relay (honest-but-curious)                │
│  • Other networks                                  │
│  • Unclaimed devices                               │
└────────────────────────────────────────────────────┘
```

### 5.3 Threat Scenarios

#### 5.3.1 LAN Attacker

**Scenario:** Attacker gains access to local network (guest WiFi, compromised device, nearby attacker)

**Attack Vectors:**

- Attempt to claim devices during onboarding window
- Intercept local traffic to capture credentials
- DoS attack on local services
- Attempt to brute force device credentials

**Mitigations:**

- Onboarding window time-limited and requires physical presence
- All LAN traffic uses TLS 1.3 with certificate pinning
- Rate limiting on authentication endpoints
- Strong credential requirements (min 12 chars, Argon2id)
- Device certificates rotated periodically
- Network segmentation recommendations in documentation

**Residual Risk:**

- LOW if best practices followed (strong passwords, firmware updated)
- MEDIUM if weak passwords or outdated firmware
- Attack requires sustained LAN access which is detectable

#### 5.3.2 Stolen Device

**Scenario:** Physical device theft (smart lock, camera, home controller)

**Attack Vectors:**

- Extract encryption keys from device storage
- Bypass authentication via hardware exploitation
- Access stored user data or credentials
- Use device as pivot point to attack home network

**Mitigations:**

- Encryption at rest using hardware-backed keys (TPM/Secure Enclave)
- Secure boot ensures only signed firmware runs
- Tamper detection (optional: secure element destroys keys if case opened)
- Remote device revocation via cloud (if enabled) or local command
- Certificates can be revoked and blacklisted
- Factory reset wipes all keys and user data

**Residual Risk:**

- LOW for data confidentiality (encryption at rest)
- MEDIUM for sophisticated hardware attacks (requires lab equipment)
- User notified of offline device (if monitoring enabled)
- Stolen device cannot rejoin network without valid certificate

#### 5.3.3 Leaked Recovery Codes

**Scenario:** User's password recovery codes are compromised (backup codes, email access)

**Attack Vectors:**

- Attacker uses recovery codes to reset password
- Gain full access to cloud account
- Establish rogue tunnel to home
- Issue commands via tunnel

**Mitigations:**

- Recovery codes are single-use and expire after 1 year
- Recovery process sends notification to all linked user devices
- Mandatory re-authentication for sensitive operations (add/remove devices)
- Recovery from cloud does NOT grant local access without existing device
- Local access requires physical presence for initial pairing
- Audit log tracks all authentication events

**Residual Risk:**

- MEDIUM if attacker has recovery codes + email access
- User notified of password reset and tunnel connections
- Attacker cannot claim new devices without local presence
- Local password can be changed from trusted device to lock out attacker

#### 5.3.4 Compromised Cloud Account

**Scenario:** Cloud service provider is breached or coerced to provide user data

**Attack Vectors:**

- Read stored user data from cloud database
- Attempt to decrypt tunnel traffic
- Correlate user activity across homes
- Redirect tunnel connections

**Mitigations:**

- Zero-knowledge architecture: Cloud cannot decrypt user data
- Tunnel traffic is end-to-end encrypted with session keys unknown to cloud
- Only metadata stored: email, home_id, public keys, connection times
- Home controller validates cloud-provided endpoints using pinned certificates
- Tunnel establishment requires mutual authentication
- User can self-host cloud service (future: federation support)

**Residual Risk:**

- LOW for data confidentiality (E2E encryption)
- LOW for command integrity (signed by home controller)
- Cloud can cause DoS by refusing tunnel connections
- Cloud sees connection metadata (IP addresses, times, frequency)
- Recommend VPN or Tor for metadata privacy (future work)

#### 5.3.5 Insider Threat (Cloud Employee)

**Scenario:** Malicious cloud service employee attempts to access user homes

**Attack Vectors:**

- Read database to find high-value targets
- Attempt MITM attack on tunnel establishment
- Modify cloud code to log decrypted traffic

**Mitigations:**

- Certificate pinning prevents MITM on tunnel
- Session keys derived using ECDH, not shared with cloud
- Encrypted payload cannot be decrypted even with code changes
- Audit logs of cloud employee database access
- Open source client/server allows independent verification

**Residual Risk:**

- LOW for data confidentiality
- Cloud can deny service but cannot decrypt traffic
- Recommendation: Self-host cloud relay for high-security environments

### 5.4 Non-Threat Scenarios (Out of Scope for MVP)

- **Nation-state adversary:** Quantum computing attacks on encryption
- **Supply chain attacks:** Compromised hardware or firmware at manufacture
- **Physical attacks:** Side-channel attacks, fault injection
- **Social engineering:** Phishing users for credentials (general security hygiene)

---

## 6. Non-Goals for MVP {#non-goals-for-mvp}

The following features and considerations are explicitly **not included** in the MVP to maintain focus and ship faster. They are candidates for future versions.

### 6.1 Advanced Features

❌ **Multi-user access control**

- MVP: Single owner, single password
- Future: Role-based access (admin, user, guest) with separate credentials

❌ **Fine-grained permissions**

- MVP: Full access for authenticated users
- Future: Per-device, per-room, per-action permissions

❌ **Federated identity**

- MVP: Password-based authentication only
- Future: OAuth, SAML, SSO integration

❌ **Biometric authentication**

- MVP: Password/PIN only
- Future: Fingerprint, face recognition on supported devices

### 6.2 Advanced Security

❌ **Hardware security modules (HSM)**

- MVP: Software-based key storage with encryption at rest
- Future: Integration with TPM 2.0, Secure Enclave, YubiKey

❌ **Certificate transparency**

- MVP: Self-signed CA, no public logging
- Future: Optional CT logs for audit

❌ **Post-quantum cryptography**

- MVP: ECDSA/ECDH (industry standard)
- Future: Hybrid classical/PQ when standards mature

❌ **Secure device attestation**

- MVP: Trust device on first claim
- Future: Remote attestation to verify genuine hardware/firmware

### 6.3 Operational Features

❌ **Automatic backup and recovery**

- MVP: Manual export/import of configuration
- Future: Encrypted cloud backup, automatic restore

❌ **High availability**

- MVP: Single home controller
- Future: Redundant controllers, failover

❌ **Over-the-air (OTA) updates**

- MVP: Manual firmware updates
- Future: Automatic, signed updates with rollback

❌ **Detailed audit logging and SIEM integration**

- MVP: Basic local logs
- Future: Comprehensive audit trail, export to external SIEM

### 6.4 Cloud Features

❌ **Multi-region cloud deployment**

- MVP: Single cloud region
- Future: Geo-distributed for lower latency

❌ **Cloud-side rules/automations**

- MVP: All rules run locally
- Future: Optional cloud rules for cross-home automation (NOT in MVP scope)

❌ **Usage analytics and insights**

- MVP: No telemetry
- Future: Opt-in anonymized analytics for energy savings, etc.

### 6.5 Interoperability

❌ **Third-party integrations**

- MVP: HomeForge devices only
- Future: Bridges to other ecosystems (HomeKit, Google Home, Alexa)

❌ **Open API for developers**

- MVP: Internal API only
- Future: Public API with OAuth scopes

---

## 7. Security Assumptions {#security-assumptions}

The security of this system depends on the following assumptions holding true:

### 7.1 Cryptographic Assumptions

1. **ECDSA and ECDH are secure:** P-256 curve resistant to known attacks
2. **AES-256-GCM is secure:** No practical break of AES with 256-bit keys
3. **Argon2id is secure:** Sufficient memory-hardness against brute force
4. **TLS 1.3 is secure:** No MITM when using certificate pinning
5. **Random number generation is secure:** Platform PRNG is cryptographically secure

### 7.2 System Assumptions

1. **Trusted execution environment:**
   - Home controller OS is not compromised
   - Kernel and system libraries are trusted
   - No malware on controller device

2. **Physical security:**
   - Home controller is in physically secure location
   - Devices cannot be easily tampered with
   - Onboarding requires physical presence

3. **Network assumptions:**
   - Local network is trusted or encrypted (WPA2/WPA3)
   - User can segment network or use dedicated WiFi for devices
   - Internet connection available for cloud features (optional)

### 7.3 User Behavior Assumptions

1. **Strong passwords:** Users choose passwords with sufficient entropy (min 12 chars)
2. **Secure storage:** Users store recovery codes securely (not in plain text)
3. **Software updates:** Users apply firmware updates in reasonable timeframe
4. **Email security:** User's email account is secured with strong password + 2FA
5. **Trusted devices:** User devices (phones, tablets) are not compromised

### 7.4 Cloud Service Assumptions

1. **Honest-but-curious model:** Cloud provides service correctly but may inspect data
2. **No protocol downgrades:** Cloud cannot force weaker encryption
3. **Certificate infrastructure:** Cloud certificate authorities are trustworthy
4. **Availability not guaranteed:** Cloud may experience outages (local control unaffected)

### 7.5 Failure Modes

If any assumption is violated:

- **Weak crypto:** Switch to stronger algorithms in next firmware version
- **Compromised controller:** Factory reset required, revoke all device certificates
- **Compromised cloud:** Disable cloud features, local control continues
- **Weak password:** Enforce stronger requirements, offer password strength meter
- **Lost recovery codes:** Require factory reset and re-onboarding

---

## 8. Rollout and Upgrade Considerations {#rollout-and-upgrade-considerations}

### 8.1 Initial Deployment

**Version 1.0 (MVP):**

- All homes start with local-only mode (no cloud)
- User opt-in required to enable cloud tunnel
- Firmware pre-installed on devices before shipping
- Initial onboarding flow includes security education

### 8.2 Upgrade Paths

#### 8.2.1 Backward Compatibility

**Rule:** Devices must support at least one prior major version protocol.

Example:

- v2.0 devices can communicate with v1.0 controller
- v1.0 devices can communicate with v2.0 controller
- v3.0 can drop support for v1.0 (but must support v2.0)

#### 8.2.2 Certificate Rotation

When home root CA needs rotation (e.g., crypto upgrade):

```text
1. Generate new root CA (v2) alongside old (v1)
2. Controller signs device certs with both CAs
3. Devices gradually re-enroll and get dual certs
4. Grace period: 90 days where both CA are valid
5. After grace period, revoke v1 CA
6. Devices with only v1 cert must re-enroll
```

#### 8.2.3 Protocol Versioning

All API requests include protocol version:

```json
{
  "protocol_version": "1.0",
  "device_id": "uuid",
  "command": "..."
}
```

Server responds with supported versions:

```json
{
  "supported_versions": ["1.0", "1.1", "2.0"],
  "response": "..."
}
```

Clients negotiate highest mutually supported version.

#### 8.2.4 Cryptographic Agility

Design allows algorithm changes without protocol redesign:

```text
Current: ECDSA P-256 + AES-256-GCM
Future:  P-384 or Ed448 + ChaCha20-Poly1305
```

Migration:

1. Firmware update adds support for new algorithms
2. Negotiation prefers new algorithms but falls back to old
3. After majority upgraded, deprecate old algorithms
4. Eventually remove support for old algorithms

### 8.3 Breaking Changes

**Avoid whenever possible.** If unavoidable:

1. **Announce:** Minimum 6 months notice before deprecation
2. **Grace period:** Run both protocols in parallel for 12 months
3. **Migration tool:** Automated upgrade path for users
4. **Support:** Clear documentation and troubleshooting guides
5. **Rollback:** Ability to revert to previous firmware version

### 8.4 Security Patch Process

**Critical vulnerabilities:**

- Hot-patch released within 24-48 hours
- Auto-update enabled by default (user can disable)
- Notification sent to all users via app + email

**Non-critical issues:**

- Included in regular monthly updates
- User can choose update schedule

### 8.5 Cloud Service Versioning

**API versioning:**

- Cloud API uses versioned endpoints: `/v1/tunnel`, `/v2/tunnel`
- Old versions supported for 24 months after new version release
- Sunset process announced 12 months in advance

**Database migrations:**

- Zero-downtime migrations using blue-green deployment
- Backward-compatible schema changes only
- Data export available before destructive changes

### 8.6 Device Lifecycle

```text
Year 0: Device released with firmware v1.0
Year 1-3: Regular updates to v1.x line
Year 4: v2.0 released, device upgraded (if compatible)
Year 5-7: Security updates only
Year 8+: End of life, no further updates
```

**End-of-life policy:**

- Minimum 8 years support from release date
- Local functionality continues indefinitely
- Cloud tunnel may require manual intervention after EOL

---

## Appendices

### Appendix A: Key Generation and Storage

**Home Controller:**

```bash
# Generate home root CA
openssl ecparam -name prime256v1 -genkey -noout -out home_ca_key.pem
openssl req -new -x509 -key home_ca_key.pem -out home_ca_cert.pem -days 3650

# Store encrypted with user's master password derived key
aes-256-gcm encrypt home_ca_key.pem > home_ca_key.enc
```

**Device:**

```bash
# Generate device key pair on first boot
openssl ecparam -name prime256v1 -genkey -noout -out device_key.pem
openssl req -new -key device_key.pem -out device_csr.pem

# Submit CSR to home controller during onboarding
# Receive signed certificate, store in secure storage
```

### Appendix B: Tunnel Packet Format

```text
┌────────────────────────────────────────────┐
│ Header (32 bytes)                          │
├────────────────────────────────────────────┤
│ Version: 1 byte (0x01)                     │
│ Flags: 1 byte                              │
│ Sequence: 8 bytes (uint64)                 │
│ Session ID: 16 bytes (UUID)                │
│ Payload Length: 4 bytes (uint32)           │
│ Reserved: 2 bytes                          │
├────────────────────────────────────────────┤
│ Encrypted Payload (variable)               │
│ • ChaCha20-Poly1305 encrypted              │
│ • Auth tag: 16 bytes                       │
├────────────────────────────────────────────┤
│ Signature (64 bytes)                       │
│ • ECDSA P-256 signature                    │
│ • Over header + encrypted payload          │
└────────────────────────────────────────────┘
```

### Appendix C: Example Configuration

**Home config (home_controller.yaml):**

```yaml
home_id: "550e8400-e29b-41d4-a716-446655440000"
home_name: "My Home"
created_at: "2026-02-12T00:00:00Z"

local_auth:
  password_hash: "$argon2id$v=19$m=65536,t=3,p=4$..."
  session_timeout_minutes: 60

cloud:
  enabled: true
  cloud_user_id: "user@example.com"
  tunnel_endpoint: "wss://tunnel.homeforge.io/v1"
  
devices:
  - device_id: "device-001"
    name: "Front Door Lock"
    certificate_serial: "1234567890"
    added_at: "2026-02-12T10:00:00Z"
```

### Appendix D: Recommended Reading

- [NIST Special Publication 800-63B](https://pages.nist.gov/800-63-3/sp800-63b.html): Digital Identity Guidelines (Authentication)
- [RFC 8446](https://datatracker.ietf.org/doc/html/rfc8446): Transport Layer Security (TLS) 1.3
- [RFC 6749](https://datatracker.ietf.org/doc/html/rfc6749): OAuth 2.0 Authorization Framework
- [OWASP IoT Security](https://owasp.org/www-project-internet-of-things/): IoT Security Best Practices
- [Zero Trust Architecture (NIST 800-207)](https://csrc.nist.gov/publications/detail/sp/800-207/final): Zero Trust principles

---

## Document History

| Version | Date       | Author      | Changes                     |
|---------|------------|-------------|-----------------------------|
| 1.0     | 2026-02-12 | HomeForge   | Initial draft for HOM-5     |

---

## Approval

This architecture document requires approval from:

- [ ] Security Team Lead
- [ ] Product Manager
- [ ] Engineering Lead
- [ ] CTO

**Status:** Draft - Awaiting Review

---
