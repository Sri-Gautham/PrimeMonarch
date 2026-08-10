import Foundation
import SwiftData

// MARK: - Body Measurement

@Model
final class BodyMeasurement {
    @Attribute(.unique) var id: UUID
    var loggedAt: Date
    var siteRawValue: String
    var customSiteName: String?
    var valueCentimeters: Double
    var notes: String?

    init(site: MeasurementSite, valueCentimeters: Double, loggedAt: Date = Date()) {
        self.id = UUID()
        self.loggedAt = loggedAt
        self.siteRawValue = site.rawValue
        self.valueCentimeters = valueCentimeters
    }

    var site: MeasurementSite {
        get { MeasurementSite(rawValue: siteRawValue) ?? .custom }
        set { siteRawValue = newValue.rawValue }
    }

    var displayName: String {
        site == .custom ? (customSiteName ?? "Custom") : site.displayName
    }
}

// MARK: - Progress Photo

@Model
final class ProgressPhoto {
    @Attribute(.unique) var id: UUID
    var takenAt: Date
    var angleRawValue: String
    var customAngleLabel: String?
    var localFileIdentifier: String   // filename within protected storage
    var notes: String?
    var isHidden: Bool               // hidden from gallery if sensitive

    init(angleRawValue: String, localFileIdentifier: String, takenAt: Date = Date()) {
        self.id = UUID()
        self.takenAt = takenAt
        self.angleRawValue = angleRawValue
        self.localFileIdentifier = localFileIdentifier
        self.isHidden = false
    }

    var angle: PhotoAngle {
        get { PhotoAngle(rawValue: angleRawValue) ?? .custom }
        set { angleRawValue = newValue.rawValue }
    }

    var displayLabel: String {
        angle == .custom ? (customAngleLabel ?? "Photo") : angle.displayName
    }
}
