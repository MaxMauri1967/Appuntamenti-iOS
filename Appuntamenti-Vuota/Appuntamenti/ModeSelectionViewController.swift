import UIKit

class ModeSelectionViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.247, green: 0.318, blue: 0.710, alpha: 1)
        setupUI()
    }

    private func setupUI() {
        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Benvenuto!"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Come vuoi usare l'app?"
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        subtitleLabel.font = UIFont.systemFont(ofSize: 18, weight: .regular)
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        // Offline Card
        let offlineCard = createModeCard(
            icon: "📴",
            title: "Offline",
            description: "Salva gli appuntamenti sul dispositivo. Nessuna connessione necessaria.",
            action: #selector(offlineTapped)
        )
        view.addSubview(offlineCard)

        // Online Card
        let onlineCard = createModeCard(
            icon: "🌐",
            title: "Online",
            description: "Connettiti al database remoto per accedere ai tuoi appuntamenti da ovunque.",
            action: #selector(onlineTapped)
        )
        view.addSubview(onlineCard)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),

            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),

            offlineCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            offlineCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            offlineCard.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 50),
            offlineCard.heightAnchor.constraint(equalToConstant: 140),

            onlineCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            onlineCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            onlineCard.topAnchor.constraint(equalTo: offlineCard.bottomAnchor, constant: 20),
            onlineCard.heightAnchor.constraint(equalToConstant: 140),
        ])
    }

    private func createModeCard(icon: String, title: String, description: String, action: Selector) -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false

        let iconLabel = UILabel()
        iconLabel.text = icon
        iconLabel.font = UIFont.systemFont(ofSize: 40)
        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(iconLabel)

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.textColor = .white
        titleLbl.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLbl)

        let descLbl = UILabel()
        descLbl.text = description
        descLbl.textColor = UIColor.white.withAlphaComponent(0.7)
        descLbl.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        descLbl.numberOfLines = 0
        descLbl.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(descLbl)

        NSLayoutConstraint.activate([
            iconLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            iconLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            titleLbl.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 16),
            titleLbl.topAnchor.constraint(equalTo: card.topAnchor, constant: 25),
            titleLbl.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            descLbl.leadingAnchor.constraint(equalTo: titleLbl.leadingAnchor),
            descLbl.topAnchor.constraint(equalTo: titleLbl.bottomAnchor, constant: 6),
            descLbl.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
        ])

        let tap = UITapGestureRecognizer(target: self, action: action)
        card.addGestureRecognizer(tap)
        card.isUserInteractionEnabled = true

        return card
    }

    @objc private func offlineTapped() {
        UserDefaults.standard.set("offline", forKey: "appMode")
        transitionToMain()
    }

    @objc private func onlineTapped() {
        UserDefaults.standard.set("online", forKey: "appMode")
        transitionToMain()
    }

    private func transitionToMain() {
        let mainVC = MainViewController()
        mainVC.modalTransitionStyle = .crossDissolve
        mainVC.modalPresentationStyle = .fullScreen

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            window.rootViewController = mainVC
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}
