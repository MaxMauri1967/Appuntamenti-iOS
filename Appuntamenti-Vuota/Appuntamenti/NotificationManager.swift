import Foundation
import UserNotifications

class NotificationManager {

    static let shared = NotificationManager()

    private init() {}

    // MARK: - Permission

    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    // MARK: - Settings

    var reminder1Minutes: Int {
        let val = UserDefaults.standard.integer(forKey: "phoneReminder1")
        return val > 0 ? val : 1440  // default 24h
    }

    var reminder2Minutes: Int {
        let val = UserDefaults.standard.integer(forKey: "phoneReminder2")
        return val > 0 ? val : 60    // default 1h
    }

    static let reminder1Options: [(String, Int)] = [
        ("6 ore prima", 360),
        ("12 ore prima", 720),
        ("24 ore prima (1 giorno)", 1440),
        ("48 ore prima (2 giorni)", 2880)
    ]

    static let reminder2Options: [(String, Int)] = [
        ("1 ora prima", 60),
        ("1 ora e 30 min prima", 90),
        ("2 ore prima", 120),
        ("2 ore e 30 min prima", 150),
        ("3 ore prima", 180),
        ("4 ore prima", 240),
        ("5 ore prima", 300),
        ("6 ore prima", 360)
    ]

    var reminder1Label: String {
        Self.reminder1Options.first(where: { $0.1 == reminder1Minutes })?.0 ?? "24 ore prima"
    }

    var reminder2Label: String {
        Self.reminder2Options.first(where: { $0.1 == reminder2Minutes })?.0 ?? "1 ora prima"
    }

    // MARK: - Schedule Notifications

    func scheduleNotifications(for appointments: [Appointment]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let r1Seconds = TimeInterval(reminder1Minutes * 60)
        let r2Seconds = TimeInterval(reminder2Minutes * 60)

        for appointment in appointments {
            guard appointment.status == "pending",
                  let appDate = appointment.dateObject else { continue }

            let now = Date()

            // 1st reminder
            let fire1 = appDate.addingTimeInterval(-r1Seconds)
            if fire1 > now {
                let content = UNMutableNotificationContent()
                content.title = "⏰ Promemoria"
                content.body = "\(appointment.title) — \(appointment.displayTime)"
                content.sound = .default

                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire1)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request = UNNotificationRequest(identifier: "r1_\(appointment.id)", content: content, trigger: trigger)
                center.add(request)
            }

            // 2nd reminder
            let fire2 = appDate.addingTimeInterval(-r2Seconds)
            if fire2 > now {
                let content = UNMutableNotificationContent()
                content.title = "🔔 Fra poco"
                content.body = "\(appointment.title) — \(appointment.displayTime)"
                content.sound = .default

                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire2)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request = UNNotificationRequest(identifier: "r2_\(appointment.id)", content: content, trigger: trigger)
                center.add(request)
            }
        }

        print("Appuntamenti: Scheduled notifications for \(appointments.filter { $0.status == "pending" }.count) pending appointments")
    }
}
