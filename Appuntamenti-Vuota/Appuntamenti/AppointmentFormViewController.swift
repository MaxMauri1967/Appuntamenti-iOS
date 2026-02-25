import UIKit

protocol AppointmentFormDelegate: AnyObject {
    func didSaveAppointment()
}

class AppointmentFormViewController: UIViewController {

    weak var delegate: AppointmentFormDelegate?
    var appointment: Appointment?  // nil = create, non-nil = edit

    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleField = UITextField()
    private let datePicker = UIDatePicker()
    private let timePicker = UIDatePicker()
    private let descriptionView = UITextView()
    private let statusSegment = UISegmentedControl(items: ["In attesa", "Completato", "Annullato"])
    private let saveButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)

    private let primaryColor = UIColor(red: 99/255, green: 102/255, blue: 241/255, alpha: 1)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        title = appointment == nil ? "Nuovo Appuntamento" : "Modifica Appuntamento"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Annulla", style: .plain, target: self, action: #selector(cancelTapped))

        setupUI()
        populateForm()
    }

    // MARK: - UI

    private func setupUI() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
        ])

        var lastAnchor = contentView.topAnchor

        // Titolo
        lastAnchor = addLabel("Titolo", below: lastAnchor, topSpacing: 24)
        titleField.placeholder = "Es: Visita medica"
        titleField.font = .systemFont(ofSize: 16)
        titleField.borderStyle = .none
        titleField.backgroundColor = UIColor(red: 248/255, green: 250/255, blue: 252/255, alpha: 1)
        titleField.layer.cornerRadius = 10
        titleField.layer.borderWidth = 1
        titleField.layer.borderColor = UIColor(red: 203/255, green: 213/255, blue: 225/255, alpha: 1).cgColor
        titleField.translatesAutoresizingMaskIntoConstraints = false
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 44))
        titleField.leftView = paddingView
        titleField.leftViewMode = .always
        contentView.addSubview(titleField)
        NSLayoutConstraint.activate([
            titleField.topAnchor.constraint(equalTo: lastAnchor, constant: 8),
            titleField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            titleField.heightAnchor.constraint(equalToConstant: 44),
        ])
        lastAnchor = titleField.bottomAnchor

        // Data
        lastAnchor = addLabel("Data", below: lastAnchor, topSpacing: 20)
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .compact
        datePicker.locale = Locale(identifier: "it_IT")
        datePicker.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(datePicker)
        NSLayoutConstraint.activate([
            datePicker.topAnchor.constraint(equalTo: lastAnchor, constant: 8),
            datePicker.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
        ])
        lastAnchor = datePicker.bottomAnchor

        // Ora
        lastAnchor = addLabel("Ora", below: lastAnchor, topSpacing: 20)
        timePicker.datePickerMode = .time
        timePicker.preferredDatePickerStyle = .compact
        timePicker.locale = Locale(identifier: "it_IT")
        timePicker.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(timePicker)
        NSLayoutConstraint.activate([
            timePicker.topAnchor.constraint(equalTo: lastAnchor, constant: 8),
            timePicker.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
        ])
        lastAnchor = timePicker.bottomAnchor

        // Descrizione
        lastAnchor = addLabel("Descrizione", below: lastAnchor, topSpacing: 20)
        descriptionView.font = .systemFont(ofSize: 16)
        descriptionView.backgroundColor = UIColor(red: 248/255, green: 250/255, blue: 252/255, alpha: 1)
        descriptionView.layer.cornerRadius = 10
        descriptionView.layer.borderWidth = 1
        descriptionView.layer.borderColor = UIColor(red: 203/255, green: 213/255, blue: 225/255, alpha: 1).cgColor
        descriptionView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        descriptionView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(descriptionView)
        NSLayoutConstraint.activate([
            descriptionView.topAnchor.constraint(equalTo: lastAnchor, constant: 8),
            descriptionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            descriptionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            descriptionView.heightAnchor.constraint(equalToConstant: 100),
        ])
        lastAnchor = descriptionView.bottomAnchor

        // Stato
        lastAnchor = addLabel("Stato", below: lastAnchor, topSpacing: 20)
        statusSegment.selectedSegmentIndex = 0
        statusSegment.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusSegment)
        NSLayoutConstraint.activate([
            statusSegment.topAnchor.constraint(equalTo: lastAnchor, constant: 8),
            statusSegment.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statusSegment.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])
        lastAnchor = statusSegment.bottomAnchor

        // Save button
        saveButton.setTitle("Salva", for: .normal)
        saveButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = primaryColor
        saveButton.layer.cornerRadius = 12
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        contentView.addSubview(saveButton)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        saveButton.addSubview(spinner)

        NSLayoutConstraint.activate([
            saveButton.topAnchor.constraint(equalTo: lastAnchor, constant: 32),
            saveButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            saveButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            saveButton.heightAnchor.constraint(equalToConstant: 50),
            saveButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40),

            spinner.centerYAnchor.constraint(equalTo: saveButton.centerYAnchor),
            spinner.trailingAnchor.constraint(equalTo: saveButton.trailingAnchor, constant: -16),
        ])

        // Tap to dismiss
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @discardableResult
    private func addLabel(_ text: String, below anchor: NSLayoutYAxisAnchor, topSpacing: CGFloat) -> NSLayoutYAxisAnchor {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(red: 30/255, green: 41/255, blue: 59/255, alpha: 1)
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: anchor, constant: topSpacing),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
        ])
        return label.bottomAnchor
    }

    private func populateForm() {
        guard let app = appointment else { return }

        titleField.text = app.title
        descriptionView.text = app.description

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        if let date = dateFormatter.date(from: app.appointmentDate) {
            datePicker.date = date
        }

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        if let time = timeFormatter.date(from: app.appointmentTime) {
            timePicker.date = time
        } else {
            timeFormatter.dateFormat = "HH:mm"
            if let time = timeFormatter.date(from: app.appointmentTime) {
                timePicker.date = time
            }
        }

        switch app.status {
        case "pending": statusSegment.selectedSegmentIndex = 0
        case "completed": statusSegment.selectedSegmentIndex = 1
        case "cancelled": statusSegment.selectedSegmentIndex = 2
        default: statusSegment.selectedSegmentIndex = 0
        }
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func saveTapped() {
        guard let title = titleField.text, !title.isEmpty else {
            showAlert("Inserisci un titolo")
            return
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: datePicker.date)

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let timeStr = timeFormatter.string(from: timePicker.date)

        let desc = descriptionView.text ?? ""
        let statuses = ["pending", "completed", "cancelled"]
        let status = statuses[statusSegment.selectedSegmentIndex]

        setLoading(true)

        if let existing = appointment {
            // Update
            APIService.shared.updateAppointment(id: existing.id, title: title, date: dateStr, time: timeStr, description: desc, status: status) { [weak self] result in
                DispatchQueue.main.async {
                    self?.setLoading(false)
                    switch result {
                    case .success:
                        self?.delegate?.didSaveAppointment()
                        self?.dismiss(animated: true)
                    case .failure(let error):
                        self?.showAlert("Errore: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            // Create
            APIService.shared.createAppointment(title: title, date: dateStr, time: timeStr, description: desc, status: status) { [weak self] result in
                DispatchQueue.main.async {
                    self?.setLoading(false)
                    switch result {
                    case .success:
                        self?.delegate?.didSaveAppointment()
                        self?.dismiss(animated: true)
                    case .failure(let error):
                        self?.showAlert("Errore: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    private func setLoading(_ loading: Bool) {
        saveButton.isEnabled = !loading
        saveButton.alpha = loading ? 0.6 : 1.0
        if loading { spinner.startAnimating() } else { spinner.stopAnimating() }
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
