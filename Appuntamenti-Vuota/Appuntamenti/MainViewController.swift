import UIKit

class MainViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, AppointmentFormDelegate {

    // MARK: - Data

    private var allAppointments: [Appointment] = []
    private var groupedAppointments: [(date: String, displayDate: String, appointments: [Appointment])] = []
    private var sheets: [String] = []
    private var currentSheet: String?
    private var currentStatus: String? = "pending"

    // MARK: - UI

    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let refreshControl = UIRefreshControl()
    private let yearButton = UIButton(type: .system)
    private let statusSegment = UISegmentedControl(items: ["Tutti", "In attesa", "Completati"])
    private let emptyLabel = UILabel()
    private let loadingSpinner = UIActivityIndicatorView(style: .large)

    // MARK: - Colors

    private let primaryColor = UIColor(red: 99/255, green: 102/255, blue: 241/255, alpha: 1)
    private let bgColor = UIColor(red: 248/255, green: 250/255, blue: 252/255, alpha: 1)
    private let textMain = UIColor(red: 30/255, green: 41/255, blue: 59/255, alpha: 1)
    private let textMuted = UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = bgColor

        setupNavigation()
        setupYearSelector()
        setupStatusFilter()
        setupTableView()
        setupEmptyState()
        setupLoadingSpinner()

        // Default filter to "In attesa"
        statusSegment.selectedSegmentIndex = 1

        // Default to current year
        let currentYear = String(Calendar.current.component(.year, from: Date()))
        currentSheet = currentYear
        updateYearButtonTitle(currentYear)

        loadSheets()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - Navigation Bar

    private func setupNavigation() {
        title = "Appuntamenti"
        navigationController?.navigationBar.prefersLargeTitles = true

        // Settings button (left)
        let settingsBtn = UIBarButtonItem(image: UIImage(systemName: "gearshape"), style: .plain, target: self, action: #selector(settingsTapped))
        settingsBtn.tintColor = primaryColor
        navigationItem.leftBarButtonItem = settingsBtn

        // Add button (right)
        let addBtn = UIBarButtonItem(image: UIImage(systemName: "plus.circle.fill"), style: .plain, target: self, action: #selector(addTapped))
        addBtn.tintColor = primaryColor
        navigationItem.rightBarButtonItem = addBtn
    }

    // MARK: - Year Selector

    private func setupYearSelector() {
        yearButton.setTitle("📅 2026 ▾", for: .normal)
        yearButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        yearButton.setTitleColor(primaryColor, for: .normal)
        yearButton.backgroundColor = primaryColor.withAlphaComponent(0.1)
        yearButton.layer.cornerRadius = 16
        yearButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16)
        yearButton.translatesAutoresizingMaskIntoConstraints = false
        yearButton.addTarget(self, action: #selector(yearTapped), for: .touchUpInside)
        view.addSubview(yearButton)

        NSLayoutConstraint.activate([
            yearButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            yearButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            yearButton.heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    private func updateYearButtonTitle(_ year: String) {
        yearButton.setTitle("📅 \(year) ▾", for: .normal)
    }

    private func loadSheets() {
        APIService.shared.fetchSheets { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let years):
                    self?.sheets = years.sorted()
                    // Add current year if not present
                    let currentYear = String(Calendar.current.component(.year, from: Date()))
                    if !years.contains(currentYear) {
                        self?.sheets.append(currentYear)
                        self?.sheets.sort()
                    }
                case .failure:
                    break
                }
            }
        }
    }

    // MARK: - Status Filter

    private func setupStatusFilter() {
        statusSegment.selectedSegmentTintColor = primaryColor
        statusSegment.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: UIFont.systemFont(ofSize: 13, weight: .semibold)], for: .selected)
        statusSegment.setTitleTextAttributes([.foregroundColor: textMuted, .font: UIFont.systemFont(ofSize: 13, weight: .medium)], for: .normal)
        statusSegment.translatesAutoresizingMaskIntoConstraints = false
        statusSegment.addTarget(self, action: #selector(statusChanged), for: .valueChanged)
        view.addSubview(statusSegment)

        NSLayoutConstraint.activate([
            statusSegment.topAnchor.constraint(equalTo: yearButton.bottomAnchor, constant: 10),
            statusSegment.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusSegment.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    // MARK: - Table View

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.register(AppointmentCell.self, forCellReuseIdentifier: "AppointmentCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(pullToRefresh), for: .valueChanged)
        refreshControl.tintColor = primaryColor
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: statusSegment.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Empty State

    private func setupEmptyState() {
        emptyLabel.text = "Nessun appuntamento trovato"
        emptyLabel.font = .systemFont(ofSize: 16, weight: .medium)
        emptyLabel.textColor = textMuted
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    // MARK: - Loading

    private func setupLoadingSpinner() {
        loadingSpinner.color = primaryColor
        loadingSpinner.hidesWhenStopped = true
        loadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(loadingSpinner)
        NSLayoutConstraint.activate([
            loadingSpinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingSpinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    // MARK: - Data Loading

    private func loadData() {
        loadingSpinner.startAnimating()
        emptyLabel.isHidden = true

        let statusFilter: String?
        switch statusSegment.selectedSegmentIndex {
        case 1: statusFilter = "pending"
        case 2: statusFilter = "completed"
        default: statusFilter = nil
        }
        currentStatus = statusFilter

        APIService.shared.fetchAppointments(sheet: currentSheet, status: statusFilter) { [weak self] result in
            DispatchQueue.main.async {
                self?.loadingSpinner.stopAnimating()
                self?.refreshControl.endRefreshing()
                switch result {
                case .success(let appointments):
                    self?.allAppointments = appointments
                    self?.groupAppointments()
                    self?.tableView.reloadData()
                    self?.emptyLabel.isHidden = !(self?.groupedAppointments.isEmpty ?? true)

                    // Schedule notifications for pending
                    if statusFilter == nil || statusFilter == "pending" {
                        NotificationManager.shared.scheduleNotifications(for: appointments)
                    }
                case .failure(let error):
                    self?.showErrorAlert(error.localizedDescription)
                }
            }
        }
    }

    private func groupAppointments() {
        var dict: [String: [Appointment]] = [:]
        for app in allAppointments {
            dict[app.appointmentDate, default: []].append(app)
        }
        groupedAppointments = dict.map { (date: $0.key, displayDate: formatDateHeader($0.key), appointments: $0.value) }
            .sorted { $0.date < $1.date }
    }

    private func formatDateHeader(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: date).capitalized
    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return groupedAppointments.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groupedAppointments[section].appointments.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AppointmentCell", for: indexPath) as! AppointmentCell
        let appointment = groupedAppointments[indexPath.section].appointments[indexPath.row]
        cell.configure(with: appointment, primaryColor: primaryColor)
        return cell
    }

    // MARK: - Section Headers

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let header = UIView()
        header.backgroundColor = bgColor

        let label = UILabel()
        label.text = groupedAppointments[section].displayDate
        label.font = .systemFont(ofSize: 15, weight: .bold)
        label.textColor = primaryColor
        label.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20),
            label.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -4),
        ])
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 40
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let appointment = groupedAppointments[indexPath.section].appointments[indexPath.row]
        showEditForm(for: appointment)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let appointment = groupedAppointments[indexPath.section].appointments[indexPath.row]

        // Delete
        let deleteAction = UIContextualAction(style: .destructive, title: "Elimina") { [weak self] _, _, completion in
            self?.confirmDelete(appointment: appointment)
            completion(true)
        }
        deleteAction.image = UIImage(systemName: "trash")

        // Toggle status
        let isCompleted = appointment.status == "completed"
        let toggleAction = UIContextualAction(style: .normal, title: isCompleted ? "Riapri" : "Completa") { [weak self] _, _, completion in
            self?.toggleStatus(appointment: appointment)
            completion(true)
        }
        toggleAction.backgroundColor = isCompleted ? .systemOrange : .systemGreen
        toggleAction.image = UIImage(systemName: isCompleted ? "arrow.uturn.backward" : "checkmark.circle")

        return UISwipeActionsConfiguration(actions: [deleteAction, toggleAction])
    }

    // MARK: - Actions

    @objc private func addTapped() {
        let formVC = AppointmentFormViewController()
        formVC.delegate = self
        let nav = UINavigationController(rootViewController: formVC)
        present(nav, animated: true)
    }

    @objc private func yearTapped() {
        let alert = UIAlertController(title: "Seleziona Anno", message: nil, preferredStyle: .actionSheet)

        for year in sheets {
            let action = UIAlertAction(title: year, style: .default) { [weak self] _ in
                self?.currentSheet = year
                self?.updateYearButtonTitle(year)
                self?.loadData()
            }
            // Highlight current selection
            if year == currentSheet {
                action.setValue(true, forKey: "checked")
            }
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Annulla", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func settingsTapped() {
        let alert = UIAlertController(title: "Impostazioni", message: nil, preferredStyle: .actionSheet)

        // Notification settings
        alert.addAction(UIAlertAction(title: "🔔 Notifiche", style: .default) { [weak self] _ in
            self?.showNotificationSettings()
        })

        // Logout
        alert.addAction(UIAlertAction(title: "🚪 Disconnetti", style: .destructive) { [weak self] _ in
            self?.confirmLogout()
        })

        alert.addAction(UIAlertAction(title: "Annulla", style: .cancel))

        present(alert, animated: true)
    }

    @objc private func statusChanged() {
        loadData()
    }

    @objc private func pullToRefresh() {
        loadData()
    }

    // MARK: - Edit Form

    private func showEditForm(for appointment: Appointment) {
        let formVC = AppointmentFormViewController()
        formVC.appointment = appointment
        formVC.delegate = self
        let nav = UINavigationController(rootViewController: formVC)
        present(nav, animated: true)
    }

    // MARK: - Toggle Status

    private func toggleStatus(appointment: Appointment) {
        let newStatus = appointment.status == "completed" ? "pending" : "completed"
        APIService.shared.updateAppointment(
            id: appointment.id,
            title: appointment.title,
            date: appointment.appointmentDate,
            time: appointment.appointmentTime,
            description: appointment.description ?? "",
            status: newStatus
        ) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.loadData()
                case .failure(let error):
                    self?.showErrorAlert(error.localizedDescription)
                }
            }
        }
    }

    // MARK: - Delete

    private func confirmDelete(appointment: Appointment) {
        let alert = UIAlertController(
            title: "Eliminare?",
            message: "Vuoi eliminare \"\(appointment.title)\"?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Annulla", style: .cancel))
        alert.addAction(UIAlertAction(title: "Elimina", style: .destructive) { [weak self] _ in
            APIService.shared.deleteAppointment(id: appointment.id) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.loadData()
                    case .failure(let error):
                        self?.showErrorAlert(error.localizedDescription)
                    }
                }
            }
        })
        present(alert, animated: true)
    }

    // MARK: - Notification Settings

    private func showNotificationSettings() {
        let alert = UIAlertController(
            title: "🔔 Impostazioni Notifiche",
            message: "1° Promemoria: \(NotificationManager.shared.reminder1Label)\n2° Promemoria: \(NotificationManager.shared.reminder2Label)",
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(title: "Cambia 1° Promemoria", style: .default) { [weak self] _ in
            self?.showReminderPicker(isFirst: true)
        })

        alert.addAction(UIAlertAction(title: "Cambia 2° Promemoria", style: .default) { [weak self] _ in
            self?.showReminderPicker(isFirst: false)
        })

        alert.addAction(UIAlertAction(title: "Annulla", style: .cancel))
        present(alert, animated: true)
    }

    private func showReminderPicker(isFirst: Bool) {
        let options = isFirst ? NotificationManager.reminder1Options : NotificationManager.reminder2Options
        let key = isFirst ? "phoneReminder1" : "phoneReminder2"

        let alert = UIAlertController(title: isFirst ? "1° Promemoria" : "2° Promemoria", message: nil, preferredStyle: .actionSheet)
        for option in options {
            alert.addAction(UIAlertAction(title: option.0, style: .default) { [weak self] _ in
                UserDefaults.standard.set(option.1, forKey: key)
                // Reschedule notifications
                NotificationManager.shared.scheduleNotifications(for: self?.allAppointments ?? [])
            })
        }
        alert.addAction(UIAlertAction(title: "Annulla", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - Logout

    private func confirmLogout() {
        let alert = UIAlertController(
            title: "Disconnetti",
            message: "Vuoi disconnetterti? Dovrai reinserire le credenziali.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Annulla", style: .cancel))
        alert.addAction(UIAlertAction(title: "Disconnetti", style: .destructive) { [weak self] _ in
            APIService.shared.logout()
            // Switch to setup screen
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = scene.windows.first {
                let setupVC = SetupViewController()
                setupVC.delegate = self
                let nav = UINavigationController(rootViewController: setupVC)
                window.rootViewController = nav
                window.makeKeyAndVisible()
            }
        })
        present(alert, animated: true)
    }

    // MARK: - AppointmentFormDelegate

    func didSaveAppointment() {
        loadData()
    }

    // MARK: - Error

    private func showErrorAlert(_ message: String) {
        let alert = UIAlertController(title: "Errore", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }
}

// MARK: - SetupViewControllerDelegate
extension MainViewController: SetupViewControllerDelegate {
    func setupDidComplete() {
        // Re-login happened, reload data
        loadData()
        // Switch root to this
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            let nav = UINavigationController(rootViewController: self)
            window.rootViewController = nav
            window.makeKeyAndVisible()
        }
    }
}

// MARK: - Custom Cell

class AppointmentCell: UITableViewCell {

    private let cardView = UIView()
    private let accentBar = UIView()
    private let titleLabel = UILabel()
    private let timeLabel = UILabel()
    private let descLabel = UILabel()
    private let badgeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        setupCell()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupCell() {
        // Card background
        cardView.backgroundColor = .white
        cardView.layer.cornerRadius = 12
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.06
        cardView.layer.shadowOffset = CGSize(width: 0, height: 2)
        cardView.layer.shadowRadius = 8
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)

        // Accent bar
        accentBar.layer.cornerRadius = 1.5
        accentBar.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(accentBar)

        // Title
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = UIColor(red: 30/255, green: 41/255, blue: 59/255, alpha: 1)
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)

        // Time
        timeLabel.font = .systemFont(ofSize: 13, weight: .medium)
        timeLabel.textColor = UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1)
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(timeLabel)

        // Description
        descLabel.font = .systemFont(ofSize: 13, weight: .regular)
        descLabel.textColor = UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1)
        descLabel.numberOfLines = 2
        descLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(descLabel)

        // Badge
        badgeLabel.font = .systemFont(ofSize: 11, weight: .bold)
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 10
        badgeLabel.clipsToBounds = true
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            accentBar.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 8),
            accentBar.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            accentBar.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -8),
            accentBar.widthAnchor.constraint(equalToConstant: 3),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: badgeLabel.leadingAnchor, constant: -8),

            timeLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            timeLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            descLabel.topAnchor.constraint(equalTo: timeLabel.bottomAnchor, constant: 6),
            descLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            descLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            descLabel.bottomAnchor.constraint(lessThanOrEqualTo: cardView.bottomAnchor, constant: -12),

            badgeLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            badgeLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 65),
            badgeLabel.heightAnchor.constraint(equalToConstant: 22),
        ])
    }

    func configure(with appointment: Appointment, primaryColor: UIColor) {
        titleLabel.text = appointment.title
        timeLabel.text = "🕐 \(appointment.displayTime)"
        descLabel.text = appointment.description
        descLabel.isHidden = (appointment.description ?? "").isEmpty
        accentBar.backgroundColor = primaryColor

        // Badge
        badgeLabel.text = " \(appointment.statusDisplayName) "
        switch appointment.status {
        case "pending":
            badgeLabel.backgroundColor = UIColor(red: 254/255, green: 243/255, blue: 199/255, alpha: 1)
            badgeLabel.textColor = UIColor(red: 146/255, green: 64/255, blue: 14/255, alpha: 1)
        case "completed":
            badgeLabel.backgroundColor = UIColor(red: 209/255, green: 250/255, blue: 229/255, alpha: 1)
            badgeLabel.textColor = UIColor(red: 6/255, green: 95/255, blue: 70/255, alpha: 1)
        case "cancelled":
            badgeLabel.backgroundColor = UIColor(red: 254/255, green: 226/255, blue: 226/255, alpha: 1)
            badgeLabel.textColor = UIColor(red: 153/255, green: 27/255, blue: 27/255, alpha: 1)
        default:
            badgeLabel.backgroundColor = .systemGray5
            badgeLabel.textColor = .systemGray
        }
    }
}
