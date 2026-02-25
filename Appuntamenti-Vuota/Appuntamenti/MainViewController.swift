import UIKit
import WebKit
import UserNotifications

class MainViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {

    private var webView: WKWebView!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.247, green: 0.318, blue: 0.710, alpha: 1)
        setupWebView()

        let mode = UserDefaults.standard.string(forKey: "appMode") ?? "offline"
        if mode == "online" {
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
        config.userContentController = contentController

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
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
              !savedUser.isEmpty, !savedPass.isEmpty else { return }

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
            if let url = webView.url?.absoluteString, url.contains("login.php") {
                // On login page: try auto-fill, or intercept manual login
                autoFillLoginIfNeeded()
                injectCredentialInterceptor()
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

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}
