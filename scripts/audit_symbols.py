#!/usr/bin/env python3
import os
import re
import json
from collections import defaultdict

APPLE_FRAMEWORKS = {
    "SwiftUI": "UI declarative framework",
    "SwiftData": "Persistence and data modeling framework",
    "Foundation": "Fundamental data types, networking, formatting, and date manipulation",
    "AppKit": "macOS user interface framework",
    "UIKit": "iOS user interface framework (cross-platform / preview shims)",
    "EventKit": "Calendar and reminder database access",
    "CoreLocation": "Geographic location and geocoding services",
    "MapKit": "Map display and local search services",
    "UniformTypeIdentifiers": "Uniform Type Identifiers for document types and drag/drop/export",
    "PDFKit": "PDF document rendering and generation",
    "Combine": "Reactive streams and asynchronous event handling",
    "AppIntents": "Siri, Shortcuts, and system actions integration",
    "Observation": "Swift observation macro and tracking engine",
    "os": "Unified logging system (os.Logger, OSLog)",
    "OSLog": "Unified logging system",
    "CryptoKit": "Cryptographic operations and hashing",
    "CloudKit": "CloudKit sync and records",
    "CoreGraphics": "2D vector graphics and coordinate types (CGFloat, CGPoint, CGRect)",
    "CoreData": "Legacy object graph management (used for CloudKit sync monitor notifications)",
    "Testing": "Swift Testing framework (@Test, #expect, #require, @Suite)",
    "Accessibility": "Accessibility primitives and system accessibility APIs",
    "Security": "Security and keychain services",
    "CommonCrypto": "C-based cryptographic hashing",
    "SQLite3": "Direct SQLite access",
    "PackageDescription": "Swift Package Manager manifest definitions"
}

DEPRECATION_RULES = [
    {
        "id": "SWIFTUI_FOREGROUND_COLOR",
        "name": ".foregroundColor(_:) is deprecated",
        "framework": "SwiftUI",
        "pattern": r"\.foregroundColor\(",
        "replacement": ".foregroundStyle(_:)",
        "doc_ref": "https://developer.apple.com/documentation/swiftui/view/foregroundcolor(_:)",
        "severity": "Warning",
        "details": "Apple deprecated .foregroundColor in macOS 12 / iOS 15 in favor of .foregroundStyle, which supports hierarchical styles, gradients, and semantic materials."
    },
    {
        "id": "SWIFTUI_CORNER_RADIUS",
        "name": ".cornerRadius(_:) is deprecated",
        "framework": "SwiftUI",
        "pattern": r"\.cornerRadius\(",
        "replacement": ".clipShape(RoundedRectangle(cornerRadius:...)) or .clipShape(.rect(cornerRadius:...))",
        "doc_ref": "https://developer.apple.com/documentation/swiftui/view/corner_radius(_:antialiased:)",
        "severity": "Warning",
        "details": "Apple deprecated .cornerRadius in macOS 13 / iOS 16 in favor of .clipShape(RoundedRectangle(cornerRadius:)) or .clipShape(.rect(cornerRadius:))."
    },
    {
        "id": "SWIFTUI_ON_CHANGE_DEPRECATED",
        "name": "onChange(of:perform:) is deprecated",
        "framework": "SwiftUI",
        "pattern": r"\.onChange\(\s*of:\s*[^,]+,\s*perform:\s*",
        "replacement": ".onChange(of:) { [oldValue, newValue] in ... } or .onChange(of:initial:_:) in iOS 17 / macOS 14+",
        "doc_ref": "https://developer.apple.com/documentation/swiftui/view/onchange(of:perform:)",
        "severity": "Warning",
        "details": "Apple deprecated the 2-parameter .onChange(of:perform:) in macOS 14 / iOS 17 in favor of closure taking zero, one, or two arguments (oldValue, newValue)."
    },
    {
        "id": "SWIFTUI_ACCENT_COLOR",
        "name": ".accentColor(_:) is deprecated",
        "framework": "SwiftUI",
        "pattern": r"\.accentColor\(",
        "replacement": ".tint(_:)",
        "doc_ref": "https://developer.apple.com/documentation/swiftui/view/accentcolor(_:)",
        "severity": "Warning",
        "details": "Apple deprecated .accentColor in macOS 13 / iOS 16 in favor of .tint(_:)."
    },
    {
        "id": "SWIFTUI_NAVIGATION_VIEW",
        "name": "NavigationView is deprecated",
        "framework": "SwiftUI",
        "pattern": r"\bNavigationView\b",
        "replacement": "NavigationStack or NavigationSplitView",
        "doc_ref": "https://developer.apple.com/documentation/swiftui/navigationview",
        "severity": "Warning",
        "details": "Apple deprecated NavigationView in macOS 13 / iOS 16 in favor of NavigationStack (stack-based) or NavigationSplitView (multi-column)."
    },
    {
        "id": "SWIFTUI_NAVIGATION_BAR_TITLE",
        "name": ".navigationBarTitle(_:) is deprecated",
        "framework": "SwiftUI",
        "pattern": r"\.navigationBarTitle\(",
        "replacement": ".navigationTitle(_:)",
        "doc_ref": "https://developer.apple.com/documentation/swiftui/view/navigationbartitle(_:)",
        "severity": "Warning",
        "details": "Apple deprecated .navigationBarTitle in iOS 14 / macOS 11 in favor of .navigationTitle(_:)."
    },
    {
        "id": "TASK_SLEEP_NANOSECONDS",
        "name": "Task.sleep(nanoseconds:) is deprecated",
        "framework": "Foundation / Swift Concurrency",
        "pattern": r"Task\.sleep\(\s*nanoseconds:",
        "replacement": "Task.sleep(for: .seconds(...) / .milliseconds(...))",
        "doc_ref": "https://developer.apple.com/documentation/swift/task/sleep(nanoseconds:)",
        "severity": "Warning",
        "details": "Apple deprecated nanosecond-based Task.sleep in macOS 13 / iOS 16 in favor of duration-based Task.sleep(for:)."
    },
    {
        "id": "EVENTKIT_REQUEST_ACCESS",
        "name": "EKEventStore.requestAccess(to:completion:) is deprecated",
        "framework": "EventKit",
        "pattern": r"\.requestAccess\(\s*to:",
        "replacement": "requestFullAccessToEvents() or requestWriteOnlyAccessToEvents()",
        "doc_ref": "https://developer.apple.com/documentation/eventkit/ekeventstore/requestaccess(to:completion:)",
        "severity": "Warning",
        "details": "Apple deprecated requestAccess(to:completion:) in macOS 14 / iOS 17 in favor of granular modern async methods requestFullAccessToEvents() or requestWriteOnlyAccessToEvents()."
    },
    {
        "id": "OBSERVABLE_OBJECT_LEGACY",
        "name": "ObservableObject / @Published / @StateObject legacy pattern",
        "framework": "Combine / SwiftUI",
        "pattern": r"(:|\bclass\s+\w+\s*:.*?\b)ObservableObject\b|@Published\s+var|@StateObject\s+var",
        "replacement": "@Observable macro (Observation framework) with @State / @Bindable",
        "doc_ref": "https://developer.apple.com/documentation/observation",
        "severity": "Info",
        "details": "In iOS 17 / macOS 14+, Apple introduced the @Observable macro which provides property-level dependency tracking, removing the overhead of ObservableObject, @Published, and @StateObject."
    }
]

# Patterns for symbol discovery
SYMBOL_PATTERNS = {
    # SwiftData
    "SwiftData.@Model": r"@Model\b",
    "SwiftData.@Query": r"@Query\b",
    "SwiftData.@Relationship": r"@Relationship\b",
    "SwiftData.@Attribute": r"@Attribute\b",
    "SwiftData.ModelContext": r"\bModelContext\b",
    "SwiftData.ModelContainer": r"\bModelContainer\b",
    "SwiftData.ModelConfiguration": r"\bModelConfiguration\b",
    "SwiftData.FetchDescriptor": r"\bFetchDescriptor\b",
    "SwiftData.Predicate": r"\bPredicate\b|#Predicate\b",
    "SwiftData.SortDescriptor": r"\bSortDescriptor\b",
    "SwiftData.ModelActor": r"\bModelActor\b",
    "SwiftData.Schema": r"\bSchema\b",
    "SwiftData.PersistentIdentifier": r"\bPersistentIdentifier\b",
    "SwiftData.DefaultSerialModelExecutor": r"\bDefaultSerialModelExecutor\b",

    # SwiftUI Views & Controls
    "SwiftUI.View": r"\bView\b",
    "SwiftUI.Text": r"\bText\(",
    "SwiftUI.Button": r"\bButton\(",
    "SwiftUI.TextField": r"\bTextField\(",
    "SwiftUI.SecureField": r"\bSecureField\(",
    "SwiftUI.TextEditor": r"\bTextEditor\(",
    "SwiftUI.Toggle": r"\bToggle\(",
    "SwiftUI.Picker": r"\bPicker\(",
    "SwiftUI.DatePicker": r"\bDatePicker\(",
    "SwiftUI.ProgressView": r"\bProgressView\(",
    "SwiftUI.Menu": r"\bMenu\(",
    "SwiftUI.Link": r"\bLink\(",
    "SwiftUI.Label": r"\bLabel\(",
    "SwiftUI.Image": r"\bImage\(",
    "SwiftUI.VStack": r"\bVStack\b",
    "SwiftUI.HStack": r"\bHStack\b",
    "SwiftUI.ZStack": r"\bZStack\b",
    "SwiftUI.Grid": r"\bGrid\b",
    "SwiftUI.GridRow": r"\bGridRow\b",
    "SwiftUI.LazyVStack": r"\bLazyVStack\b",
    "SwiftUI.LazyHStack": r"\bLazyHStack\b",
    "SwiftUI.ScrollView": r"\bScrollView\b",
    "SwiftUI.Table": r"\bTable\b",
    "SwiftUI.TableColumn": r"\bTableColumn\b",
    "SwiftUI.List": r"\bList\b",
    "SwiftUI.Section": r"\bSection\b",
    "SwiftUI.Form": r"\bForm\b",
    "SwiftUI.Group": r"\bGroup\b",
    "SwiftUI.GroupBox": r"\bGroupBox\b",
    "SwiftUI.GeometryReader": r"\bGeometryReader\b",
    "SwiftUI.NavigationStack": r"\bNavigationStack\b",
    "SwiftUI.NavigationSplitView": r"\bNavigationSplitView\b",
    "SwiftUI.NavigationPath": r"\bNavigationPath\b",
    "SwiftUI.NavigationLink": r"\bNavigationLink\b",
    "SwiftUI.Divider": r"\bDivider\b",
    "SwiftUI.Spacer": r"\bSpacer\b",
    "SwiftUI.Canvas": r"\bCanvas\b",
    "SwiftUI.Color": r"\bColor\b",
    "SwiftUI.LinearGradient": r"\bLinearGradient\b",
    "SwiftUI.RadialGradient": r"\bRadialGradient\b",
    "SwiftUI.AngularGradient": r"\bAngularGradient\b",
    "SwiftUI.RoundedRectangle": r"\bRoundedRectangle\b",
    "SwiftUI.UnevenRoundedRectangle": r"\bUnevenRoundedRectangle\b",
    "SwiftUI.Circle": r"\bCircle\b",
    "SwiftUI.Rectangle": r"\bRectangle\b",
    "SwiftUI.Capsule": r"\bCapsule\b",
    "SwiftUI.WindowGroup": r"\bWindowGroup\b",
    "SwiftUI.Settings": r"\bSettings\b",
    "SwiftUI.MenuBarExtra": r"\bMenuBarExtra\b",

    # SwiftUI Property Wrappers
    "SwiftUI.@State": r"@State\b",
    "SwiftUI.@Binding": r"@Binding\b",
    "SwiftUI.@Bindable": r"@Bindable\b",
    "SwiftUI.@Environment": r"@Environment\b",
    "SwiftUI.@FocusState": r"@FocusState\b",
    "SwiftUI.@AppStorage": r"@AppStorage\b",
    "SwiftUI.@SceneStorage": r"@SceneStorage\b",
    "SwiftUI.@Namespace": r"@Namespace\b",
    "SwiftUI.@StateObject": r"@StateObject\b",
    "SwiftUI.@ObservedObject": r"@ObservedObject\b",
    "SwiftUI.@EnvironmentObject": r"@EnvironmentObject\b",

    # SwiftUI Modifiers
    "SwiftUI..padding": r"\.padding\(",
    "SwiftUI..frame": r"\.frame\(",
    "SwiftUI..background": r"\.background\(",
    "SwiftUI..foregroundStyle": r"\.foregroundStyle\(",
    "SwiftUI..foregroundColor": r"\.foregroundColor\(",
    "SwiftUI..clipShape": r"\.clipShape\(",
    "SwiftUI..cornerRadius": r"\.cornerRadius\(",
    "SwiftUI..sheet": r"\.sheet\(",
    "SwiftUI..fullScreenCover": r"\.fullScreenCover\(",
    "SwiftUI..popover": r"\.popover\(",
    "SwiftUI..alert": r"\.alert\(",
    "SwiftUI..confirmationDialog": r"\.confirmationDialog\(",
    "SwiftUI..navigationTitle": r"\.navigationTitle\(",
    "SwiftUI..toolbar": r"\.toolbar\b",
    "SwiftUI..searchable": r"\.searchable\(",
    "SwiftUI..focused": r"\.focused\(",
    "SwiftUI..onSubmit": r"\.onSubmit\(",
    "SwiftUI..help": r"\.help\(",
    "SwiftUI..keyboardShortcut": r"\.keyboardShortcut\(",
    "SwiftUI..disabled": r"\.disabled\(",
    "SwiftUI..tag": r"\.tag\(",
    "SwiftUI..task": r"\.task\b",
    "SwiftUI..onChange": r"\.onChange\(",
    "SwiftUI..onAppear": r"\.onAppear\(",
    "SwiftUI..onDisappear": r"\.onDisappear\(",
    "SwiftUI..modelContainer": r"\.modelContainer\(",
    "SwiftUI..modelContext": r"\.modelContext\(",
    "SwiftUI..tint": r"\.tint\(",
    "SwiftUI..accentColor": r"\.accentColor\(",
    "SwiftUI..accessibilityElement": r"\.accessibilityElement\(",
    "SwiftUI..accessibilityLabel": r"\.accessibilityLabel\(",
    "SwiftUI..accessibilityValue": r"\.accessibilityValue\(",
    "SwiftUI..accessibilityHint": r"\.accessibilityHint\(",
    "SwiftUI..accessibilityAction": r"\.accessibilityAction\(",
    "SwiftUI..accessibilityAddTraits": r"\.accessibilityAddTraits\(",
    "SwiftUI..accessibilityRemoveTraits": r"\.accessibilityRemoveTraits\(",
    "SwiftUI..accessibilityHeading": r"\.accessibilityHeading\(",
    "SwiftUI..animation": r"\.animation\(",
    "SwiftUI..transition": r"\.transition\(",
    "SwiftUI..matchedGeometryEffect": r"\.matchedGeometryEffect\(",
    "SwiftUI..font": r"\.font\(",
    "SwiftUI..lineLimit": r"\.lineLimit\(",
    "SwiftUI..multilineTextAlignment": r"\.multilineTextAlignment\(",
    "SwiftUI..textSelection": r"\.textSelection\(",
    "SwiftUI..labelsHidden": r"\.labelsHidden\(",
    "SwiftUI..fixedSize": r"\.fixedSize\(",
    "SwiftUI..layoutPriority": r"\.layoutPriority\(",

    # Observation
    "Observation.@Observable": r"@Observable\b",
    "Observation.ObservationTracking": r"\bObservationTracking\b",
    "Observation.withObservationTracking": r"\bwithObservationTracking\b",

    # EventKit
    "EventKit.EKEventStore": r"\bEKEventStore\b",
    "EventKit.EKEvent": r"\bEKEvent\b",
    "EventKit.EKCalendar": r"\bEKCalendar\b",
    "EventKit.EKEntityType": r"\bEKEntityType\b",
    "EventKit.EKAuthorizationStatus": r"\bEKAuthorizationStatus\b",
    "EventKit.requestFullAccessToEvents": r"\brequestFullAccessToEvents\(",
    "EventKit.requestWriteOnlyAccessToEvents": r"\brequestWriteOnlyAccessToEvents\(",
    "EventKit.requestAccess": r"\brequestAccess\(",

    # AppKit
    "AppKit.NSApplication": r"\bNSApplication\b",
    "AppKit.NSWindow": r"\bNSWindow\b",
    "AppKit.NSWorkspace": r"\bNSWorkspace\b",
    "AppKit.NSPasteboard": r"\bNSPasteboard\b",
    "AppKit.NSColor": r"\bNSColor\b",
    "AppKit.NSFont": r"\bNSFont\b",
    "AppKit.NSImage": r"\bNSImage\b",
    "AppKit.NSOpenPanel": r"\bNSOpenPanel\b",
    "AppKit.NSSavePanel": r"\bNSSavePanel\b",
    "AppKit.NSViewRepresentable": r"\bNSViewRepresentable\b",
    "AppKit.NSViewControllerRepresentable": r"\bNSViewControllerRepresentable\b",
    "AppKit.NSHostingController": r"\bNSHostingController\b",
    "AppKit.NSEvent": r"\bNSEvent\b",
    "AppKit.NSMenuItem": r"\bNSMenuItem\b",
    "AppKit.NSAlert": r"\bNSAlert\b",
    "AppKit.NSButton": r"\bNSButton\b",

    # CoreLocation & MapKit
    "CoreLocation.CLLocationManager": r"\bCLLocationManager\b",
    "CoreLocation.CLLocation": r"\bCLLocation\b",
    "CoreLocation.CLLocationCoordinate2D": r"\bCLLocationCoordinate2D\b",
    "CoreLocation.CLGeocoder": r"\bCLGeocoder\b",
    "CoreLocation.CLPlacemark": r"\bCLPlacemark\b",
    "CoreLocation.CLAuthorizationStatus": r"\bCLAuthorizationStatus\b",
    "MapKit.MKLocalSearch": r"\bMKLocalSearch\b",
    "MapKit.MKLocalSearchCompleter": r"\bMKLocalSearchCompleter\b",
    "MapKit.MKLocalSearchCompletion": r"\bMKLocalSearchCompletion\b",
    "MapKit.MKCoordinateRegion": r"\bMKCoordinateRegion\b",
    "MapKit.MKCoordinateSpan": r"\bMKCoordinateSpan\b",
    "MapKit.MKMapItem": r"\bMKMapItem\b",
    "MapKit.MKPlacemark": r"\bMKPlacemark\b",
    "MapKit.Map": r"\bMap\(",
    "MapKit.MapCameraPosition": r"\bMapCameraPosition\b",
    "MapKit.Marker": r"\bMarker\(",
    "MapKit.Annotation": r"\bAnnotation\(",

    # UniformTypeIdentifiers
    "UniformTypeIdentifiers.UTType": r"\bUTType\b",

    # AppIntents
    "AppIntents.AppIntent": r"\bAppIntent\b",
    "AppIntents.AppShortcutsProvider": r"\bAppShortcutsProvider\b",
    "AppIntents.AppShortcut": r"\bAppShortcut\b",
    "AppIntents.IntentParameter": r"@Parameter\b",
    "AppIntents.IntentResult": r"\bIntentResult\b",
    "AppIntents.OpenIntent": r"\bOpenIntent\b",

    # PDFKit
    "PDFKit.PDFDocument": r"\bPDFDocument\b",
    "PDFKit.PDFPage": r"\bPDFPage\b",
    "PDFKit.PDFView": r"\bPDFView\b",

    # Combine
    "Combine.AnyCancellable": r"\bAnyCancellable\b",
    "Combine.PassthroughSubject": r"\bPassthroughSubject\b",
    "Combine.CurrentValueSubject": r"\bCurrentValueSubject\b",
    "Combine.Publisher": r"\bPublisher\b",
    "Combine.Publishers": r"\bPublishers\b",

    # os & OSLog
    "os.Logger": r"\bLogger\(|\bLogger\b",
    "os.OSLog": r"\bOSLog\b",
    "os.os_log": r"\bos_log\(",

    # CryptoKit
    "CryptoKit.SHA256": r"\bSHA256\b",
    "CryptoKit.SymmetricKey": r"\bSymmetricKey\b",
    "CryptoKit.AES": r"\bAES\b",

    # CloudKit & CoreData
    "CloudKit.CKRecordZone": r"\bCKRecordZone\b",
    "CloudKit.CKSubscription": r"\bCKSubscription\b",
    "CoreData.NSPersistentCloudKitContainer": r"\bNSPersistentCloudKitContainer\b",

    # Testing
    "Testing.@Test": r"@Test\b",
    "Testing.@Suite": r"@Suite\b",
    "Testing.#expect": r"#expect\(",
    "Testing.#require": r"#require\(",

    # Foundation
    "Foundation.Date": r"\bDate\b",
    "Foundation.Data": r"\bData\b",
    "Foundation.UUID": r"\bUUID\b",
    "Foundation.URL": r"\bURL\b",
    "Foundation.URLRequest": r"\bURLRequest\b",
    "Foundation.URLSession": r"\bURLSession\b",
    "Foundation.Calendar": r"\bCalendar\b",
    "Foundation.TimeZone": r"\bTimeZone\b",
    "Foundation.Locale": r"\bLocale\b",
    "Foundation.Decimal": r"\bDecimal\b",
    "Foundation.NumberFormatter": r"\bNumberFormatter\b",
    "Foundation.DateFormatter": r"\bDateFormatter\b",
    "Foundation.ISO8601DateFormatter": r"\bISO8601DateFormatter\b",
    "Foundation.DateInterval": r"\bDateInterval\b",
    "Foundation.Measurement": r"\bMeasurement\b",
    "Foundation.UnitDuration": r"\bUnitDuration\b",
    "Foundation.UnitLength": r"\bUnitLength\b",
    "Foundation.JSONEncoder": r"\bJSONEncoder\b",
    "Foundation.JSONDecoder": r"\bJSONDecoder\b",
    "Foundation.PropertyListEncoder": r"\bPropertyListEncoder\b",
    "Foundation.PropertyListDecoder": r"\bPropertyListDecoder\b",
    "Foundation.JSONSerialization": r"\bJSONSerialization\b",
    "Foundation.UserDefaults": r"\bUserDefaults\b",
    "Foundation.FileManager": r"\bFileManager\b",
    "Foundation.FileHandle": r"\bFileHandle\b",
    "Foundation.AttributedString": r"\bAttributedString\b",
    "Foundation.NotificationCenter": r"\bNotificationCenter\b",
    "Foundation.Task": r"\bTask\b|\bTask\.detached\b",
    "Foundation.MainActor": r"@MainActor\b",
    "Foundation.Sendable": r"\bSendable\b",
}

def scan_codebase(root_dir="."):
    source_files = []
    for r, dirs, files in os.walk(root_dir):
        if any(p in r for p in ["/.build", "/build", "/BuildData", "/artifacts", "/.git"]):
            continue
        for f in files:
            if f.endswith(".swift"):
                source_files.append(os.path.normpath(os.path.join(r, f)))

    source_files.sort()
    print(f"Total Swift files to audit: {len(source_files)}")

    # Results collections
    module_files = defaultdict(list)
    framework_usage = defaultdict(lambda: defaultdict(list))
    symbol_usage = defaultdict(lambda: defaultdict(list))
    deprecations_found = []
    file_audits = {}

    import_re = re.compile(r"^\s*import\s+(?:(?:struct|class|enum|protocol|var|let|func)\s+)?([A-Za-z0-9_]+)", re.MULTILINE)

    for path in source_files:
        # Determine module/package
        parts = path.split(os.sep)
        if parts[0] == "InvoicingApplication":
            module_name = "InvoicingApplication (App)"
        elif parts[0] == "InvoicingApplicationTests":
            module_name = "InvoicingApplicationTests"
        elif parts[0] == "Packages" and len(parts) > 1:
            module_name = f"Packages/{parts[1]}"
        else:
            module_name = parts[0]

        module_files[module_name].append(path)

        with open(path, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()

        # Extract imports
        imports = import_re.findall(content)
        apple_imports = [imp for imp in imports if imp in APPLE_FRAMEWORKS]
        for imp in apple_imports:
            framework_usage[imp][module_name].append(path)

        # Check deprecations line by line
        lines = content.splitlines()
        file_deprecations = []
        for line_num, line in enumerate(lines, start=1):
            # Skip pure comments
            stripped = line.strip()
            if stripped.startswith("//") or stripped.startswith("/*") or stripped.startswith("*"):
                continue

            for rule in DEPRECATION_RULES:
                if re.search(rule["pattern"], line):
                    # Special filters to avoid false positives
                    if rule["id"] == "OBSERVABLE_OBJECT_LEGACY":
                        # only flag if actually defining or using ObservableObject
                        pass
                    dep_record = {
                        "file": path,
                        "line": line_num,
                        "line_content": line.strip(),
                        "rule_id": rule["id"],
                        "rule_name": rule["name"],
                        "framework": rule["framework"],
                        "replacement": rule["replacement"],
                        "doc_ref": rule["doc_ref"],
                        "severity": rule["severity"],
                        "details": rule["details"],
                        "module": module_name
                    }
                    deprecations_found.append(dep_record)
                    file_deprecations.append(dep_record)

        # Detect symbol usages
        detected_symbols = []
        for sym_id, pattern in SYMBOL_PATTERNS.items():
            matches = list(re.finditer(pattern, content))
            if matches:
                fw, sym_name = sym_id.split(".", 1)
                symbol_usage[sym_id][module_name].append({
                    "file": path,
                    "count": len(matches)
                })
                detected_symbols.append({
                    "symbol": sym_name,
                    "framework": fw,
                    "count": len(matches)
                })

        file_audits[path] = {
            "module": module_name,
            "apple_imports": apple_imports,
            "all_imports": imports,
            "deprecations": file_deprecations,
            "symbols_count": len(detected_symbols),
            "detected_symbols": detected_symbols
        }

    return {
        "source_files": source_files,
        "module_files": module_files,
        "framework_usage": framework_usage,
        "symbol_usage": symbol_usage,
        "deprecations_found": deprecations_found,
        "file_audits": file_audits
    }

if __name__ == "__main__":
    results = scan_codebase(".")
    print("\n=== AUDIT SUMMARY ===")
    print(f"Modules Audited: {len(results['module_files'])}")
    for mod, flist in sorted(results["module_files"].items()):
        print(f"  {mod:35}: {len(flist):3} files")

    print("\n=== APPLE FRAMEWORK USAGE ===")
    for fw, mod_dict in sorted(results["framework_usage"].items(), key=lambda x: -sum(len(v) for v in x[1].values())):
        total_files = sum(len(v) for v in mod_dict.values())
        print(f"  {fw:25}: {total_files:3} files across {len(mod_dict)} modules")

    print("\n=== DEPRECATIONS / MODERNIZATION FINDINGS ===")
    print(f"Total Deprecation / Modernization occurrences found: {len(results['deprecations_found'])}")
    by_rule = defaultdict(list)
    for d in results["deprecations_found"]:
        by_rule[d["rule_id"]].append(d)

    for rule_id, occurrences in sorted(by_rule.items(), key=lambda x: -len(x[1])):
        sample = occurrences[0]
        print(f"\n[{rule_id}] ({sample['severity']}) - {sample['rule_name']}: {len(occurrences)} matches")
        print(f"  Framework: {sample['framework']}")
        print(f"  Apple Doc: {sample['doc_ref']}")
        print(f"  Modern Alternative: {sample['replacement']}")
        print("  Sample Occurrences:")
        for occ in occurrences[:5]:
            print(f"    - {occ['file']}:{occ['line']}: {occ['line_content']}")
        if len(occurrences) > 5:
            print(f"    ... and {len(occurrences) - 5} more")

    # Save full structured json
    with open("artifacts/apple_symbol_audit_raw.json", "w", encoding="utf-8") as f:
        json.dump({
            "total_files": len(results["source_files"]),
            "modules": {k: len(v) for k, v in results["module_files"].items()},
            "deprecations": results["deprecations_found"],
            "symbol_summary": {k: sum(item["count"] for m in v.values() for item in m) for k, v in results["symbol_usage"].items()}
        }, f, indent=2)
    print("\nWrote artifacts/apple_symbol_audit_raw.json")
