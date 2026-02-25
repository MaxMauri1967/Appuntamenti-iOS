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
        loadLocalPage()
    }

    // MARK: - Setup

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true

        // Enable IndexedDB persistence
        let dataStore = WKWebsiteDataStore.default()
        config.websiteDataStore = dataStore

        // Add JavaScript bridge for notifications
        let contentController = WKUserContentController()
        contentController.add(self, name: "scheduleNotification")
        contentController.add(self, name: "cancelNotification")
        contentController.add(self, name: "cancelAllNotifications")
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
        default:
            break
        }
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
