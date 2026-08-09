#!/bin/zsh
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

for forbidden_path in \
  "InvoicingApplication/Resources/Data/AllData-Export-2025-07-21-174716.json" \
  "InvoicingApplication/Resources/Data/clients.json" \
  "InvoicingApplication/Resources/Data/payees.json" \
  "InvoicingApplication/Resources/Data/invoices.json" \
  "InvoicingApplication/Resources/Data/services.json"; do
  [[ ! -e "$forbidden_path" ]] || { print -u2 "Forbidden bundled data: $forbidden_path"; exit 1; }
done

! rg -n "PersistentStoreSanitizer|NSAllowsArbitraryLoads|com\\.example\\.|Fruit Identifier|Fruit Property Identifier" \
  Packages InvoicingApplication --glob '*.{swift,plist,pbxproj}'

! rg -n "NSPersistentCloudKitContainerEventChangedNotification|userInfo\?\[\"event\"\]|Mirror\(reflecting: event\)" \
  Packages/Data/Sources/Data/Services/CloudKitSyncMonitor.swift

! rg -n "NSCloudKitMirroringDelegateWillResetSyncNotification|AppSchemaV[123]" \
  Packages/Data/Sources/Data --glob '*.swift'

! rg -n "func importAllData\(\)" Packages InvoicingApplication --glob '*.swift'

# Swift 6 concurrency escape hatches are prohibited in production sources.
! rg -n "@unchecked Sendable|@preconcurrency[[:space:]]+import|nonisolated\\(unsafe\\)|Task\\.detached" \
  Packages InvoicingApplication --glob '*.swift'

# A cancelled delay must not be converted into successful workflow progress.
! rg -n "try\\?[[:space:]]+await[[:space:]]+Task\\.sleep" \
  Packages InvoicingApplication --glob '*.swift'

print "Apple audit static checks passed"
