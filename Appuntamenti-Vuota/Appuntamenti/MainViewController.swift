import UIKit
import WebKit
import UserNotifications

class MainViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {

    private var webView: WKWebView!
    private var loadingOverlay: UIView!
    private var isAutoLoggingIn = false

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.247, green: 0.318, blue: 0.710, alpha: 1)
        setupWebView()
        setupLoadingOverlay()

        let mode = UserDefaults.standard.string(forKey: "appMode") ?? "offline"
        if mode == "online" {
            // Check if we have saved credentials — if so, hide the WebView during auto-login
            let savedUser = UserDefaults.standard.string(forKey: "savedUsername") ?? ""
            let savedPass = UserDefaults.standard.string(forKey: "savedPassword") ?? ""
            if !savedUser.isEmpty && !savedPass.isEmpty {
                isAutoLoggingIn = true
                showLoadingOverlay()
            }
            loadOnlinePage()
        } else {
            loadLocalPage()
        }
    }

    // MARK: - Setup

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true

        // Enable IndexedDB persistence
        let dataStore = WKWebsiteDataStore.default()
        config.websiteDataStore = dataStore

        // Add JavaScript bridge for notifications and credentials
        let contentController = WKUserContentController()
        contentController.add(self, name: "scheduleNotification")
        contentController.add(self, name: "cancelNotification")
        contentController.add(self, name: "cancelAllNotifications")
        contentController.add(self, name: "saveCredentials")

        // Inject mobile-friendly CSS overrides to fix server CSS on narrow screens
        let mobileCSS = WKUserScript(
            source: """
            (function() {
                var style = document.createElement('style');
                style.textContent = `
                    /* === Base: prevent horizontal overflow === */
                    html, body {
                        overflow-x: hidden !important;
                        width: 100% !important;
                        max-width: 100vw !important;
                        -webkit-text-size-adjust: 100% !important;
                    }
                    body {
                        padding: 0.75rem !important;
                        box-sizing: border-box !important;
                    }
                    .container {
                        max-width: 100% !important;
                        overflow-x: hidden !important;
                        padding: 0 !important;
                    }

                    /* === Header: compact for mobile === */
                    header {
                        flex-wrap: wrap !important;
                        gap: 0.5rem !important;
                        margin-bottom: 1rem !important;
                    }
                    h1 {
                        font-size: 1.25rem !important;
                        width: 100% !important;
                    }

                    /* === Filter buttons: wrap and fit === */
                    .status-filter-container {
                        flex-wrap: wrap !important;
                        gap: 0.5rem !important;
                        margin-bottom: 1rem !important;
                    }
                    .status-filter-group {
                        flex-wrap: wrap !important;
                        gap: 0.4rem !important;
                    }
                    .status-btn {
                        padding: 0.4rem 0.75rem !important;
                        font-size: 0.75rem !important;
                    }

                    /* === Date rows: stack vertically === */
                    .date-row {
                        flex-direction: column !important;
                        padding: 1rem !important;
                        gap: 0.75rem !important;
                        max-width: 100% !important;
                        overflow: hidden !important;
                    }

                    /* === Date sidebar: horizontal compact bar === */
                    .date-sidebar {
                        min-width: 0 !important;
                        flex-direction: row !important;
                        align-items: baseline !important;
                        gap: 0.5rem !important;
                        padding-right: 0 !important;
                        padding-bottom: 0.5rem !important;
                        border-right: none !important;
                        border-bottom: 2px solid #f1f5f9 !important;
                    }
                    .date-day-name {
                        font-size: 0.7rem !important;
                        margin-top: 0 !important;
                        order: 1 !important;
                    }
                    .date-day-num {
                        font-size: 1.5rem !important;
                        order: 2 !important;
                    }
                    .date-month {
                        font-size: 0.8rem !important;
                        order: 3 !important;
                    }

                    /* === Cards: full width, proper sizing === */
                    .day-content {
                        flex-direction: column !important;
                        width: 100% !important;
                        min-width: 0 !important;
                        gap: 0.75rem !important;
                    }
                    .appointment-card {
                        min-width: 0 !important;
                        max-width: 100% !important;
                        width: 100% !important;
                        flex: 1 1 100% !important;
                        padding: 0.75rem 1rem !important;
                        box-sizing: border-box !important;
                    }

                    /* === Card content: readable === */
                    .card-title {
                        font-size: 0.95rem !important;
                        word-break: break-word !important;
                        overflow-wrap: break-word !important;
                    }
                    .card-time {
                        font-size: 0.8rem !important;
                        margin-bottom: 0.5rem !important;
                    }
                    .card-desc {
                        font-size: 0.8rem !important;
                        margin-bottom: 0.75rem !important;
                    }

                    /* === Card action buttons: horizontal, readable === */
                    .card-actions {
                        display: flex !important;
                        flex-wrap: wrap !important;
                        gap: 0.5rem !important;
                        justify-content: flex-start !important;
                    }
                    .card-actions .badge,
                    .card-actions .btn,
                    .card-actions button,
                    .card-actions a {
                        white-space: nowrap !important;
                        font-size: 0.7rem !important;
                        padding: 0.25rem 0.5rem !important;
                        writing-mode: horizontal-tb !important;
                        text-orientation: mixed !important;
                        display: inline-flex !important;
                        align-items: center !important;
                    }

                    /* === Badges: compact === */
                    .badge {
                        white-space: nowrap !important;
                        font-size: 0.65rem !important;
                        padding: 0.2rem 0.5rem !important;
                    }

                    /* === Modal: mobile friendly === */
                    .modal-content {
                        width: 95% !important;
                        max-width: 95% !important;
                        padding: 1.25rem !important;
                        margin: 0 auto !important;
                        max-height: 90vh !important;
                        overflow-y: auto !important;
                    }

                    /* === Buttons: general === */
                    .btn {
                        padding: 0.5rem 0.75rem !important;
                        font-size: 0.8rem !important;
                    }

                    /* === Add button: always visible === */
                    #addBtn, .btn-primary {
                        display: inline-flex !important;
                        visibility: visible !important;
                        opacity: 1 !important;
                        white-space: nowrap !important;
                    }

                    /* === Header actions: wrap properly === */
                    .header-actions {
                        display: flex !important;
                        flex-wrap: wrap !important;
                        gap: 0.5rem !important;
                        width: 100% !important;
                        align-items: center !important;
                    }
                    .search-box {
                        min-width: 0 !important;
                        flex: 1 1 100% !important;
                    }
                    .filter-select {
                        flex: 0 0 auto !important;
                    }

                    /* === Settings panel: mobile friendly === */
                    .settings-panel {
                        width: 100% !important;
                    }
                    .settings-content {
                        padding: 0.75rem !important;
                    }
                    .settings-row {
                        flex-wrap: wrap !important;
                        gap: 0.5rem !important;
                    }
                    .settings-row select {
                        width: 100% !important;
                    }

                    /* === Appointments grid === */
                    .appointments-grid {
                        gap: 1rem !important;
                    }
                `;
                document.head.appendChild(style);
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        contentController.addUserScript(mobileCSS)

        config.userContentController = contentController

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.bounces = true
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Loading Overlay (hides login flash)

    private func setupLoadingOverlay() {
        loadingOverlay = UIView()
        loadingOverlay.backgroundColor = UIColor(red: 0.247, green: 0.318, blue: 0.710, alpha: 1)
        loadingOverlay.translatesAutoresizingMaskIntoConstraints = false
        loadingOverlay.isHidden = true

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "Caricamento..."
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false

        loadingOverlay.addSubview(spinner)
        loadingOverlay.addSubview(label)
        view.addSubview(loadingOverlay)

        NSLayoutConstraint.activate([
            loadingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            spinner.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: loadingOverlay.centerYAnchor, constant: -20),

            label.centerXAnchor.constraint(equalTo: loadingOverlay.centerXAnchor),
            label.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 16),
        ])
    }

    private func showLoadingOverlay() {
        loadingOverlay.isHidden = false
        view.bringSubviewToFront(loadingOverlay)
    }

    private func hideLoadingOverlay() {
        UIView.animate(withDuration: 0.3) {
            self.loadingOverlay.alpha = 0
        } completion: { _ in
            self.loadingOverlay.isHidden = true
            self.loadingOverlay.alpha = 1
        }
    }

    // MARK: - Load Local Page

    private func loadLocalPage() {
        guard let htmlPath = Bundle.main.path(forResource: "index", ofType: "html", inDirectory: "WebAssets") else {
            print("Appuntamenti: index.html not found in WebAssets")
            return
        }
        let htmlURL = URL(fileURLWithPath: htmlPath)
        let baseURL = htmlURL.deletingLastPathComponent()
        webView.loadFileURL(htmlURL, allowingReadAccessTo: baseURL)
    }

    // MARK: - Load Online Page

    private func loadOnlinePage() {
        guard let url = URL(string: "https://www.gondolaoffice.eu/appuntamenti/") else {
            print("Appuntamenti: Invalid online URL")
            return
        }
        webView.load(URLRequest(url: url))
    }

    // MARK: - WKScriptMessageHandler (JavaScript Bridge)

    func userContentController(_ userContentController: WKUserContentController,
                                didReceive message: WKScriptMessage) {
        switch message.name {
        case "scheduleNotification":
            handleScheduleNotification(message.body)
        case "cancelNotification":
            handleCancelNotification(message.body)
        case "cancelAllNotifications":
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            print("Appuntamenti: All notifications cancelled")
        case "saveCredentials":
            handleSaveCredentials(message.body)
        default:
            break
        }
    }

    // MARK: - Credential Management

    private func handleSaveCredentials(_ body: Any) {
        guard let dict = body as? [String: Any],
              let username = dict["username"] as? String,
              let password = dict["password"] as? String else {
            print("Appuntamenti: Invalid credentials data")
            return
        }
        UserDefaults.standard.set(username, forKey: "savedUsername")
        UserDefaults.standard.set(password, forKey: "savedPassword")
        print("Appuntamenti: Credentials saved")
    }

    private func autoFillLoginIfNeeded() {
        let mode = UserDefaults.standard.string(forKey: "appMode") ?? "offline"
        guard mode == "online" else { return }

        guard let savedUser = UserDefaults.standard.string(forKey: "savedUsername"),
              let savedPass = UserDefaults.standard.string(forKey: "savedPassword"),
              !savedUser.isEmpty, !savedPass.isEmpty else {
            // No saved credentials — show the login page
            hideLoadingOverlay()
            isAutoLoggingIn = false
            return
        }

        let escapedUser = savedUser.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let escapedPass = savedPass.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")

        let autoLoginScript = """
        (function() {
            var uField = document.getElementById('username');
            var pField = document.getElementById('password');
            if (uField && pField) {
                uField.value = '\(escapedUser)';
                pField.value = '\(escapedPass)';
                var form = uField.closest('form');
                if (form) { form.submit(); }
            }
        })();
        """
        webView.evaluateJavaScript(autoLoginScript, completionHandler: nil)
        print("Appuntamenti: Auto-login attempted")
    }

    private func injectCredentialInterceptor() {
        let interceptScript = """
        (function() {
            var form = document.querySelector('form');
            var uField = document.getElementById('username');
            var pField = document.getElementById('password');
            if (form && uField && pField) {
                form.addEventListener('submit', function() {
                    window.webkit.messageHandlers.saveCredentials.postMessage({
                        username: uField.value,
                        password: pField.value
                    });
                });
            }
        })();
        """
        webView.evaluateJavaScript(interceptScript, completionHandler: nil)
    }

    private func handleScheduleNotification(_ body: Any) {
        guard let dict = body as? [String: Any],
              let id = dict["id"] as? String,
              let title = dict["title"] as? String,
              let bodyText = dict["body"] as? String,
              let timestamp = dict["timestamp"] as? Double else {
            print("Appuntamenti: Invalid notification data")
            return
        }

        let fireDate = Date(timeIntervalSince1970: timestamp / 1000.0)

        // Don't schedule notifications in the past
        guard fireDate > Date() else {
            print("Appuntamenti: Skipping past notification: \(title)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = bodyText
        content.sound = .default
        content.badge = 1

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Appuntamenti: Error scheduling notification: \(error)")
            } else {
                print("Appuntamenti: Notification scheduled: \(title) at \(fireDate)")
            }
        }
    }

    private func handleCancelNotification(_ body: Any) {
        guard let dict = body as? [String: Any],
              let id = dict["id"] as? String else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        print("Appuntamenti: Notification cancelled: \(id)")
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Inject the iOS notification bridge into the page
        let bridgeScript = """
        if (!window.AndroidBridge) {
            window.AndroidBridge = {
                scheduleNotification: function(id, title, body, timestamp) {
                    window.webkit.messageHandlers.scheduleNotification.postMessage({
                        id: String(id), title: title, body: body, timestamp: timestamp
                    });
                },
                cancelNotification: function(id) {
                    window.webkit.messageHandlers.cancelNotification.postMessage({id: String(id)});
                },
                cancelAllNotifications: function() {
                    window.webkit.messageHandlers.cancelAllNotifications.postMessage({});
                }
            };
        }
        """
        webView.evaluateJavaScript(bridgeScript, completionHandler: nil)

        // Online mode: handle login page
        let mode = UserDefaults.standard.string(forKey: "appMode") ?? "offline"
        if mode == "online" {
            if let url = webView.url?.absoluteString, url.contains("login.php") || url.contains("auth.php") {
                // On login page: try auto-fill, or intercept manual login
                autoFillLoginIfNeeded()
                injectCredentialInterceptor()
            } else {
                // We navigated away from login (auto-login succeeded or user is already logged in)
                if isAutoLoggingIn {
                    isAutoLoggingIn = false
                    hideLoadingOverlay()
                }
                // Schedule notifications after a short delay to let JS render appointments
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    self?.scheduleNotificationsFromPage()
                }
            }
        }
    }

    // MARK: - WKUIDelegate

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    // MARK: - Intercept Settings Link

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url,
           url.absoluteString.contains("settings.php") {
            // Intercept settings link — show native settings instead
            decisionHandler(.cancel)
            showNotificationSettings()
            return
        }
        decisionHandler(.allow)
    }

    // MARK: - Native Notification Settings

    private func showNotificationSettings() {
        let reminder1Key = "phoneReminder1"
        let reminder2Key = "phoneReminder2"
        let currentR1 = UserDefaults.standard.integer(forKey: reminder1Key)
        let currentR2 = UserDefaults.standard.integer(forKey: reminder2Key)
        let r1Value = currentR1 > 0 ? currentR1 : 1440   // default 24h
        let r2Value = currentR2 > 0 ? currentR2 : 60     // default 1h

        let r1Options: [(String, Int)] = [
            ("6 ore prima", 360),
            ("12 ore prima", 720),
            ("24 ore prima (1 giorno)", 1440),
            ("48 ore prima (2 giorni)", 2880)
        ]

        let r2Options: [(String, Int)] = [
            ("1 ora prima", 60),
            ("1 ora e 30 min prima", 90),
            ("2 ore prima", 120),
            ("2 ore e 30 min prima", 150),
            ("3 ore prima", 180),
            ("4 ore prima", 240),
            ("5 ore prima", 300),
            ("6 ore prima", 360)
        ]

        // Build display strings
        let r1Current = r1Options.first(where: { $0.1 == r1Value })?.0 ?? "24 ore prima"
        let r2Current = r2Options.first(where: { $0.1 == r2Value })?.0 ?? "1 ora prima"

        let alert = UIAlertController(
            title: "⚙️ Impostazioni Notifiche",
            message: "1° Promemoria: \(r1Current)\n2° Promemoria: \(r2Current)\n\nSeleziona quale promemoria modificare:",
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(title: "1° Promemoria", style: .default) { [weak self] _ in
            self?.showReminderPicker(title: "1° Promemoria", options: r1Options, key: reminder1Key)
        })

        alert.addAction(UIAlertAction(title: "2° Promemoria", style: .default) { [weak self] _ in
            self?.showReminderPicker(title: "2° Promemoria", options: r2Options, key: reminder2Key)
        })

        alert.addAction(UIAlertAction(title: "Torna alla pagina", style: .cancel, handler: nil))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        present(alert, animated: true)
    }

    private func showReminderPicker(title: String, options: [(String, Int)], key: String) {
        let current = UserDefaults.standard.integer(forKey: key)

        let alert = UIAlertController(
            title: "🔔 \(title)",
            message: "Scegli quando ricevere la notifica:",
            preferredStyle: .actionSheet
        )

        for (label, value) in options {
            let isSelected = (value == current)
            let prefix = isSelected ? "✅ " : ""
            alert.addAction(UIAlertAction(title: "\(prefix)\(label)", style: .default) { [weak self] _ in
                UserDefaults.standard.set(value, forKey: key)
                print("Appuntamenti: \(title) set to \(value) minutes")
                // Reschedule notifications with new settings
                self?.scheduleNotificationsFromPage()
            })
        }

        alert.addAction(UIAlertAction(title: "Annulla", style: .cancel, handler: nil))

        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        present(alert, animated: true)
    }

    // MARK: - Schedule Notifications from Page Appointments

    private func scheduleNotificationsFromPage() {
        let r1Min = UserDefaults.standard.integer(forKey: "phoneReminder1")
        let r2Min = UserDefaults.standard.integer(forKey: "phoneReminder2")
        let reminder1 = r1Min > 0 ? r1Min : 1440  // default 24h
        let reminder2 = r2Min > 0 ? r2Min : 60    // default 1h

        // Cancel all existing reminders first
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        // Inject JS to read appointments from the page and send to bridge
        let script = """
        (function() {
            var cards = document.querySelectorAll('.appointment-card');
            var appointments = [];
            cards.forEach(function(card) {
                var titleEl = card.querySelector('.card-title');
                var timeEl = card.querySelector('.card-time');
                var dateRow = card.closest('.date-row');
                var dayNum = dateRow ? dateRow.querySelector('.date-day-num') : null;
                var month = dateRow ? dateRow.querySelector('.date-month') : null;

                if (titleEl && timeEl && dayNum && month) {
                    var title = titleEl.textContent.trim();
                    var time = timeEl.textContent.trim();
                    var day = dayNum.textContent.trim();
                    var monthText = month.textContent.trim();
                    appointments.push({title: title, time: time, day: day, month: monthText, id: card.dataset.id || ''});
                }
            });

            // Send each appointment for notification scheduling
            appointments.forEach(function(app) {
                window.webkit.messageHandlers.scheduleNotification.postMessage({
                    action: 'scheduleFromPage',
                    title: app.title,
                    time: app.time,
                    day: app.day,
                    month: app.month,
                    appointmentId: app.id,
                    reminder1: \(reminder1),
                    reminder2: \(reminder2)
                });
            });
        })();
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}
