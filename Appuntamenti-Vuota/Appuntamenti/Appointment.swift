import Foundation

struct Appointment: Codable {
    let id: Int
    var title: String
    var appointmentDate: String
    var appointmentTime: String
    var description: String?
    var status: String
    var sourceSheet: String?
    var reminderSent: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case appointmentDate = "appointment_date"
        case appointmentTime = "appointment_time"
        case description
        case status
        case sourceSheet = "source_sheet"
        case reminderSent = "reminder_sent"
    }

    var displayTime: String {
        let parts = appointmentTime.split(separator: ":")
        if parts.count >= 2 {
            return "\(parts[0]):\(parts[1])"
        }
        return appointmentTime
    }

    var dateObject: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = formatter.date(from: "\(appointmentDate) \(appointmentTime)") {
            return date
        }
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: "\(appointmentDate) \(appointmentTime)")
    }

    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: appointmentDate) else { return appointmentDate }
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "EEEE d MMMM yyyy"
        return formatter.string(from: date).capitalized
    }

    var statusDisplayName: String {
        switch status {
        case "pending": return "In attesa"
        case "completed": return "Completato"
        case "cancelled": return "Annullato"
        default: return status
        }
    }
}
