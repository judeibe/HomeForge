# HomeForge Architecture Documentation

This directory contains architectural documentation for the HomeForge smart home platform.

## Documents

### [Onboarding and Trust Architecture (LAN vs Tunnel)](./onboarding-and-trust.md)

**Issue:** HOM-5  
**Status:** Draft  
**Last Updated:** 2026-02-12

Comprehensive design document covering:

- Device onboarding and trust establishment
- Local-first authentication architecture
- Optional cloud connectivity via secure tunnels
- Threat model and security considerations
- MVP scope and non-goals
- Upgrade and rollout strategy

**Quick Overview:**

- **Local-First:** All device control works without internet
- **Optional Cloud:** Secure tunnels for remote access (opt-in)
- **Zero-Knowledge:** Cloud cannot access user data or control devices
- **End-to-End Encrypted:** Tunnel traffic encrypted with session keys

## Architecture Principles

1. **Privacy First:** User data stays local by default
2. **Local Control:** No cloud dependency for core functionality
3. **Security by Design:** Defense in depth with multiple security layers
4. **Progressive Trust:** Devices earn trust through cryptographic proof
5. **Cryptographic Agility:** Support for algorithm upgrades without breaking changes

## Contributing

When adding new architecture documents:

1. Use the same structure and format as existing documents
2. Include diagrams for complex flows
3. Document security implications
4. Define clear non-goals to manage scope
5. Consider upgrade and migration paths

## Related Documentation

- [Project README](../../README.md)
- Issue Tracker: <https://linear.app/homeforge/>

---

*For questions about architecture decisions, please open an issue or discussion.*
