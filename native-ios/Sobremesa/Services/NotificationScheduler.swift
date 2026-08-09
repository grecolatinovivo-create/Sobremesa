//
//  NotificationScheduler.swift
//  Sobremesa
//
//  I richiami locali della brace: un avviso quando la brace entra in avviso
//  (giorno 4) e uno quando il posto si libera (giorno 7). Nessun server:
//  tutto è schedulato sul dispositivo e ricalcolato a ogni attività reale.
//  Persuasione etica: si avvisa PRIMA della perdita, non dopo.
//

import Foundation
import UserNotifications

@MainActor
struct NotificationScheduler {

    let rules: ProductRules

    /// Chiede il permesso solo la prima volta e solo in un momento sensato
    /// (quando l'utente inizia ad abitare un circolo), mai al primo avvio.
    func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    private let ritualIdentifier = "sobremesa.rituale"

    /// Riprogramma tutti i richiami in base alle membership correnti.
    /// Chiamata dopo ogni attività: le date sono sempre quelle vere.
    func reschedule(memberships: [(circleName: String, lastActivity: Date, suspended: Bool, animatedByMe: Bool)]) {
        let center = UNUserNotificationCenter.current()
        // Il campanile della sera (identifier fisso) NON va cancellato qui.
        center.getPendingNotificationRequests { requests in
            let daCancellare = requests.map(\.identifier).filter { $0 != ritualIdentifier }
            center.removePendingNotificationRequests(withIdentifiers: daCancellare)
        }
        let now = Date.now
        for membership in memberships where !membership.suspended {
            // Giorno dell'avviso: la brace si sta spegnendo, si può ancora rimediare.
            schedule(center: center,
                     fireDate: membership.lastActivity.addingTimeInterval(
                        Double(rules.emberWarningAfterDays) * 86_400),
                     now: now,
                     title: String(localized: "notif.avviso.title", bundle: L10n.bundle),
                     body: String(format: String(localized: "notif.avviso.body", bundle: L10n.bundle),
                                  rules.emberWarningAfterDays, membership.circleName))
            // Giorno dell'epilogo: il posto si è liberato.
            // L'animatore non viene mai espulso: a lui questa non si manda.
            guard !membership.animatedByMe else { continue }
            schedule(center: center,
                     fireDate: membership.lastActivity.addingTimeInterval(
                        Double(rules.emberExpulsionAfterDays) * 86_400),
                     now: now,
                     title: String(localized: "notif.espulsione.title", bundle: L10n.bundle),
                     body: String(format: String(localized: "notif.espulsione.body", bundle: L10n.bundle),
                                  rules.emberExpulsionAfterDays, membership.circleName))
        }
    }

    /// Il rituale della sera: UNA notifica al giorno, all'ora scelta
    /// dall'utente, solo se ha tavoli. Un campanile, non una slot machine.
    func scheduleRitual(enabled: Bool, minutesFromMidnight: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [ritualIdentifier])
        guard enabled else { return }
        var components = DateComponents()
        components.hour = minutesFromMidnight / 60
        components.minute = minutesFromMidnight % 60
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notif.rituale.title", bundle: L10n.bundle)
        content.body = String(localized: "notif.rituale.body", bundle: L10n.bundle)
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: ritualIdentifier,
                                         content: content, trigger: trigger))
    }

    private func schedule(center: UNUserNotificationCenter,
                          fireDate: Date, now: Date,
                          title: String, body: String) {
        let interval = fireDate.timeIntervalSince(now)
        guard interval > 60 else { return } // eventi già passati: se ne occupa evaluateEmbers
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: UUID().uuidString,
                                         content: content, trigger: trigger))
    }
}
