# Apple Audit Remediation Ledger

| Finding | Status | Evidence |
| --- | --- | --- |
| 1. Raw store sanitizer | Fixed | `PersistentStoreSanitizer` removed; container opens only configured SwiftData store. |
| 2. Bundled customer data | Fixed in current tree | Five customer-derived JSON resources removed. Git-history purge remains separate destructive operation. |
| 3. Historical schema migration | Blocked | Requires redacted shipped stores and matching builds/source revisions. No historical schema may be fabricated. |
| 4. Secure randomness | Fixed | Encryption fails when `SecRandomCopyBytes` returns non-success. |
| 5–7. Release sandbox, ATS, CloudKit events | In progress | Entitlements split, ATS removed, typed CloudKit event observation added. Release archive still required. |
| 8–9. Travel cancellation and isolation | In progress | Directions cancellation added. Full service extraction into model actor remains required before release. |
| 10–15. Accessibility and view structure | In progress | Reduce Motion support and baseline semantic typography added. Screen-by-screen remediation remains required. |
| 16. Deployment target | Fixed | Info plist uses `$(MACOSX_DEPLOYMENT_TARGET)`. |
| 17–18. Test isolation and App Intents | In progress | `OpenClientIntent` now resolves registered dependencies. Isolated direct tests remain required. |
| 19. UTI ownership | Fixed | Obsolete declarations removed; active identifiers use owned reverse-DNS prefix. |
| 20–21. Unsafe singleton/import | Fixed | Delivery center unsafe annotation removed; SwiftData import added. |

## Privacy incident record

Affected current-tree paths: five JSON resources listed in `scripts/verify_audit_remediation.sh`.

History purge owner: release manager. Required evidence: encrypted recovery mirror, exact `git filter-repo --invert-paths` command log, rewritten-ref verification, binary invalidation, collaborator re-clone notice, and approved retention/destruction record. Never record customer values here.
