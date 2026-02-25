import UIKit

protocol SetupViewControllerDelegate: AnyObject {
    func setupDidComplete()
}

class SetupViewController: UIViewController {

    weak var delegate: SetupViewControllerDelegate?

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let logoLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let serverField = UITextField()
    private let usernameField = UITextField()
    private let passwordField = UITextField()
    private let connectButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)

    // MARK: - Colors

    private let primaryColor = UIColor(red: 99/255, green: 102/255, blue: 241/255, alpha: 1)
    private let bgColor = UIColor(red: 248/255, green: 250/255, blue: 252/255, alpha: 1)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = bgColor
        setupUI()
        loadSavedValues()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    // MARK: - UI Setup

    private func setupUI() {
        // Scroll view
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        // Logo
        logoLabel.text = "📅"
        logoLabel.font = .systemFont(ofSize: 60)
        logoLabel.textAlignment = .center
        logoLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(logoLabel)

        // Title
        titleLabel.text = "Appuntamenti"
        titleLabel.font = .systemFont(ofSize: 28, weight: .bold)
        titleLabel.textColor = UIColor(red: 30/255, green: 41/255, blue: 59/255, alpha: 1)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        // Subtitle
        subtitleLabel.text = "Configura la connessione al server"
        subtitleLabel.font = .systemFont(ofSize: 15, weight: .regular)
        subtitleLabel.textColor = UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1)
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)

        // Fields
        setupField(serverField, placeholder: "URL Server (es. gondolaoffice.eu/appuntamenti)", icon: "🌐", keyboardType: .URL)
        setupField(usernameField, placeholder: "Username", icon: "👤", keyboardType: .default)
        setupField(passwordField, placeholder: "Password", icon: "🔒", keyboardType: .default, isSecure: true)

        // Connect button
        connectButton.setTitle("  Connetti", for: .normal)
        connectButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        connectButton.setTitleColor(.white, for: .normal)
        connectButton.backgroundColor = primaryColor
        connectButton.layer.cornerRadius = 12
        connectButton.translatesAutoresizingMaskIntoConstraints = false
        connectButton.addTarget(self, action: #selector(connectTapped), for: .touchUpInside)
        contentView.addSubview(connectButton)

        // Status
        statusLabel.text = ""
        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusLabel)

        // Spinner
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        contentView.addSubview(spinner)

        // Layout
        NSLayoutConstraint.activate([
            logoLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 80),
            logoLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            titleLabel.topAnchor.constraint(equalTo: logoLabel.bottomAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 32),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -32),

            serverField.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            serverField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            serverField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            serverField.heightAnchor.constraint(equalToConstant: 50),

            usernameField.topAnchor.constraint(equalTo: serverField.bottomAnchor, constant: 16),
            usernameField.leadingAnchor.constraint(equalTo: serverField.leadingAnchor),
            usernameField.trailingAnchor.constraint(equalTo: serverField.trailingAnchor),
            usernameField.heightAnchor.constraint(equalToConstant: 50),

            passwordField.topAnchor.constraint(equalTo: usernameField.bottomAnchor, constant: 16),
            passwordField.leadingAnchor.constraint(equalTo: serverField.leadingAnchor),
            passwordField.trailingAnchor.constraint(equalTo: serverField.trailingAnchor),
            passwordField.heightAnchor.constraint(equalToConstant: 50),

            connectButton.topAnchor.constraint(equalTo: passwordField.bottomAnchor, constant: 32),
            connectButton.leadingAnchor.constraint(equalTo: serverField.leadingAnchor),
            connectButton.trailingAnchor.constraint(equalTo: serverField.trailingAnchor),
            connectButton.heightAnchor.constraint(equalToConstant: 50),

            spinner.topAnchor.constraint(equalTo: connectButton.bottomAnchor, constant: 20),
            spinner.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            statusLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: serverField.leadingAnchor),
            statusLabel.trailingAnchor.constraint(equalTo: serverField.trailingAnchor),
            statusLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),
        ])

        // Tap to dismiss keyboard
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
    }

    private func setupField(_ field: UITextField, placeholder: String, icon: String, keyboardType: UIKeyboardType, isSecure: Bool = false) {
        field.placeholder = placeholder
        field.font = .systemFont(ofSize: 16)
        field.backgroundColor = .white
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1
        field.layer.borderColor = UIColor(red: 203/255, green: 213/255, blue: 225/255, alpha: 1).cgColor
        field.keyboardType = keyboardType
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.isSecureTextEntry = isSecure
        field.translatesAutoresizingMaskIntoConstraints = false
        field.returnKeyType = .next

        // Icon label as left view
        let iconView = UILabel()
        iconView.text = "  \(icon) "
        iconView.font = .systemFont(ofSize: 18)
        iconView.sizeToFit()
        field.leftView = iconView
        field.leftViewMode = .always

        contentView.addSubview(field)
    }

    private func loadSavedValues() {
        serverField.text = UserDefaults.standard.string(forKey: "serverURL") ?? ""
        usernameField.text = UserDefaults.standard.string(forKey: "savedUsername") ?? ""
        passwordField.text = UserDefaults.standard.string(forKey: "savedPassword") ?? ""
    }

    // MARK: - Actions

    @objc private func connectTapped() {
        dismissKeyboard()

        guard let url = serverField.text, !url.isEmpty else {
            showStatus("Inserisci l'URL del server", isError: true)
            return
        }
        guard let username = usernameField.text, !username.isEmpty else {
            showStatus("Inserisci lo username", isError: true)
            return
        }
        guard let password = passwordField.text, !password.isEmpty else {
            showStatus("Inserisci la password", isError: true)
            return
        }

        setLoading(true)
        showStatus("Connessione in corso...", isError: false)

        APIService.shared.login(url: url, username: username, password: password) { [weak self] result in
            DispatchQueue.main.async {
                self?.setLoading(false)
                switch result {
                case .success(let displayName):
                    self?.showStatus("✅ Connesso come \(displayName)", isError: false)
                    // Request notification permission
                    NotificationManager.shared.requestPermission { _ in }
                    // Transition to main screen after short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.transitionToMain()
                    }
                case .failure(let error):
                    self?.showStatus("❌ \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func setLoading(_ loading: Bool) {
        connectButton.isEnabled = !loading
        connectButton.alpha = loading ? 0.6 : 1.0
        if loading {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
    }

    private func showStatus(_ text: String, isError: Bool) {
        statusLabel.text = text
        statusLabel.textColor = isError
            ? UIColor(red: 153/255, green: 27/255, blue: 27/255, alpha: 1)
            : UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1)
    }

    private func transitionToMain() {
        let mainVC = MainViewController()
        let nav = UINavigationController(rootViewController: mainVC)

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            window.rootViewController = nav
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }
}
