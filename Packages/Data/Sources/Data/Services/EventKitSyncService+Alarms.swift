import Foundation
import EventKit
import CoreLocation

extension EventKitSyncService {

    // MARK: - Alarm Serialization

    private struct SerializedAlarm: Codable {
        let relativeOffset: TimeInterval?
        let absoluteDate: Date?
        let proximityRaw: Int?
        let structuredTitle: String?
        let latitude: Double?
        let longitude: Double?
    }

    func serializeAlarms(_ alarms: [EKAlarm]?) -> Data? {
        guard let alarms, !alarms.isEmpty else { return nil }
        let payload = alarms.map { alarm in
            let coordinate = alarm.structuredLocation?.geoLocation?.coordinate
            return SerializedAlarm(
                relativeOffset: alarm.absoluteDate == nil ? alarm.relativeOffset : nil,
                absoluteDate:   alarm.absoluteDate,
                proximityRaw:   alarm.proximity.rawValue,
                structuredTitle: alarm.structuredLocation?.title,
                latitude:  coordinate?.latitude,
                longitude: coordinate?.longitude
            )
        }
        return try? JSONEncoder().encode(payload)
    }

    // periphery:ignore
    func deserializeAlarms(_ data: Data?) -> [EKAlarm]? {
        guard let data else { return nil }

        if let payload = try? JSONDecoder().decode([SerializedAlarm].self, from: data) {
            return payload.compactMap { item in
                let alarm: EKAlarm
                if let absoluteDate = item.absoluteDate {
                    alarm = EKAlarm(absoluteDate: absoluteDate)
                } else if let relativeOffset = item.relativeOffset {
                    alarm = EKAlarm(relativeOffset: relativeOffset)
                } else {
                    return nil
                }
                if let proximityRaw = item.proximityRaw,
                   let proximity = EKAlarmProximity(rawValue: proximityRaw) {
                    alarm.proximity = proximity
                }
                if item.structuredTitle != nil || (item.latitude != nil && item.longitude != nil) {
                    let structuredLocation = EKStructuredLocation(title: item.structuredTitle ?? "Reminder")
                    if let lat = item.latitude, let lon = item.longitude {
                        structuredLocation.geoLocation = CLLocation(latitude: lat, longitude: lon)
                    }
                    alarm.structuredLocation = structuredLocation
                }
                return alarm
            }
        }

        if let legacyAlarms = try? NSKeyedUnarchiver.unarchivedObject(
            ofClasses: [NSArray.self, EKAlarm.self],
            from: data
        ) as? [EKAlarm] {
            return legacyAlarms
        }

        return nil
    }
}
