import Foundation

class APIService {

    static let shared = APIService()

    private let session: URLSession
    private var csrfToken: String?

    var baseURL: String {
        get { UserDefaults.standard.string(forKey: "serverURL") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "serverURL") }
    }

    var isConfigured: Bool {
        !baseURL.isEmpty
    }

    private init() {
        let config = URLSessionConfiguration.default
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.timeoutIntervalForRequest = 15
        session = URLSession(configuration: config)
    }

    // MARK: - Helpers

    private func apiURL(action: String, params: [String: String] = [:]) -> URL? {
        var urlString = baseURL.hasSuffix("/") ? baseURL : baseURL + "/"
        urlString += "api.php?action=\(action)"
        for (key, value) in params {
            urlString += "&\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
        }
        return URL(string: urlString)
    }

    // MARK: - Login

    func login(url: String, username: String, password: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Normalize and save base URL
        var normalizedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedURL.hasPrefix("http") {
            normalizedURL = "https://" + normalizedURL
        }
        if normalizedURL.hasSuffix("/") {
            normalizedURL = String(normalizedURL.dropLast())
        }

        guard let loginURL = URL(string: "\(normalizedURL)/api.php?action=login") else {
            completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL non valido"])))
            return
        }

        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["username": username, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        session.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Nessuna risposta dal server"])))
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMsg = json["error"] as? String {
                    completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                } else {
                    completion(.failure(NSError(domain: "APIService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Errore \(httpResponse.statusCode)"])))
                }
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = json["success"] as? Bool, success {
                    self?.csrfToken = json["csrf_token"] as? String
                    self?.baseURL = normalizedURL

                    // Save credentials
                    UserDefaults.standard.set(username, forKey: "savedUsername")
                    UserDefaults.standard.set(password, forKey: "savedPassword")

                    let displayName = (json["username"] as? String) ?? username
                    completion(.success(displayName))
                } else {
                    completion(.failure(NSError(domain: "APIService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Risposta non valida"])))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    func autoLogin(completion: @escaping (Bool) -> Void) {
        guard isConfigured,
              let username = UserDefaults.standard.string(forKey: "savedUsername"),
              let password = UserDefaults.standard.string(forKey: "savedPassword"),
              !username.isEmpty, !password.isEmpty else {
            completion(false)
            return
        }

        login(url: baseURL, username: username, password: password) { result in
            switch result {
            case .success:
                completion(true)
            case .failure:
                completion(false)
            }
        }
    }

    func logout() {
        UserDefaults.standard.removeObject(forKey: "savedUsername")
        UserDefaults.standard.removeObject(forKey: "savedPassword")
        UserDefaults.standard.removeObject(forKey: "serverURL")
        csrfToken = nil

        // Clear cookies
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
    }

    // MARK: - Fetch Appointments

    func fetchAppointments(sheet: String? = nil, status: String? = nil, completion: @escaping (Result<[Appointment], Error>) -> Void) {
        var params: [String: String] = [:]
        if let sheet = sheet { params["sheet"] = sheet }
        if let status = status { params["status"] = status }

        guard let url = apiURL(action: "list", params: params) else {
            completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL non valido"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Nessun dato"])))
                return
            }

            // Check for auth error
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                completion(.failure(NSError(domain: "APIService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Sessione scaduta"])))
                return
            }

            do {
                let decoder = JSONDecoder()
                let appointments = try decoder.decode([Appointment].self, from: data)
                completion(.success(appointments))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Fetch Sheets (Years)

    func fetchSheets(completion: @escaping (Result<[String], Error>) -> Void) {
        guard let url = apiURL(action: "sheets") else {
            completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL non valido"])))
            return
        }

        session.dataTask(with: URLRequest(url: url)) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.success([]))
                return
            }
            do {
                let sheets = try JSONDecoder().decode([String].self, from: data)
                completion(.success(sheets))
            } catch {
                completion(.success([]))
            }
        }.resume()
    }

    // MARK: - Create Appointment

    func createAppointment(title: String, date: String, time: String, description: String, status: String, completion: @escaping (Result<Int, Error>) -> Void) {
        guard let url = apiURL(action: "create") else {
            completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL non valido"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        if let csrf = csrfToken {
            request.setValue(csrf, forHTTPHeaderField: "X-CSRF-TOKEN")
        }

        let body = "title=\(title.urlEncoded)&date=\(date.urlEncoded)&time=\(time.urlEncoded)&description=\(description.urlEncoded)&status=\(status.urlEncoded)"
        request.httpBody = body.data(using: .utf8)

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(NSError(domain: "APIService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Nessun dato"])))
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let id = json["id"] as? Int {
                    completion(.success(id))
                } else if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let errorMsg = json["error"] as? String {
                    completion(.failure(NSError(domain: "APIService", code: -3, userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                } else {
                    completion(.success(0))
                }
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }

    // MARK: - Update Appointment

    func updateAppointment(id: Int, title: String, date: String, time: String, description: String, status: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = apiURL(action: "update", params: ["id": "\(id)"]) else {
            completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL non valido"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        if let csrf = csrfToken {
            request.setValue(csrf, forHTTPHeaderField: "X-CSRF-TOKEN")
        }

        let body = "title=\(title.urlEncoded)&date=\(date.urlEncoded)&time=\(time.urlEncoded)&description=\(description.urlEncoded)&status=\(status.urlEncoded)"
        request.httpBody = body.data(using: .utf8)

        session.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            completion(.success(()))
        }.resume()
    }

    // MARK: - Delete Appointment

    func deleteAppointment(id: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let url = apiURL(action: "delete", params: ["id": "\(id)"]) else {
            completion(.failure(NSError(domain: "APIService", code: -1, userInfo: [NSLocalizedDescriptionKey: "URL non valido"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        if let csrf = csrfToken {
            request.setValue(csrf, forHTTPHeaderField: "X-CSRF-TOKEN")
        }
        request.httpBody = "delete=1".data(using: .utf8)

        session.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            completion(.success(()))
        }.resume()
    }
}

// MARK: - String URL Encoding Extension

extension String {
    var urlEncoded: String {
        self.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self
    }
}
