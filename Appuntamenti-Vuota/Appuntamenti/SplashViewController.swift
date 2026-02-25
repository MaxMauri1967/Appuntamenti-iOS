import UIKit

class SplashViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 99/255, green: 102/255, blue: 241/255, alpha: 1) // #6366F1

        // Logo
        let logoImageView = UIImageView(image: UIImage(named: "AppIcon"))
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.layer.cornerRadius = 22
        logoImageView.clipsToBounds = true
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logoImageView)

        // App name label
        let titleLabel = UILabel()
        titleLabel.text = "Appuntamenti"
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Subtitle
        let subtitleLabel = UILabel()
        subtitleLabel.text = "I miei Appuntamenti"
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.7)
        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        // Spinner
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)

        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -60),
            logoImageView.widthAnchor.constraint(equalToConstant: 120),
            logoImageView.heightAnchor.constraint(equalToConstant: 120),

            titleLabel.topAnchor.constraint(equalTo: logoImageView.bottomAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            spinner.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 30),
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])

        // Try auto-login after 1.5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.tryAutoLogin()
        }
    }

    private func tryAutoLogin() {
        guard APIService.shared.isConfigured else {
            showSetup()
            return
        }

        APIService.shared.autoLogin { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.showMain()
                } else {
                    self?.showSetup()
                }
            }
        }
    }

    private func showMain() {
        let mainVC = MainViewController()
        let nav = UINavigationController(rootViewController: mainVC)

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            window.rootViewController = nav
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
        }
    }

    private func showSetup() {
        let mainVC = MainViewController()
        let setupVC = SetupViewController()
        setupVC.delegate = mainVC

        let nav = UINavigationController(rootViewController: setupVC)

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            window.rootViewController = nav
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: nil)
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
}
