//
//  HiveAPI.swift
//  Hive-for-iOS
//
//  Created by Joseph Roque on 2020-01-14.
//  Copyright © 2020 Joseph Roque. All rights reserved.
//

import Foundation
import Combine
import Loaf

enum HiveAPIError: LocalizedError {
	case networkingError(Error)
	case invalidResponse
	case invalidHTTPResponse(Int)
	case invalidData
	case missingData
	case notImplemented
	case unauthorized

	var errorDescription: String? {
		switch self {
		case .networkingError:
			return "Network error"
		case .invalidResponse, .invalidData:
			return "Could not parse response"
		case .unauthorized:
			return "Unauthorized"
		case .invalidHTTPResponse(let code):
			if (500..<600).contains(code) {
				return "Server error (\(code))"
			} else {
				return "Unexpected HTTP error (\(code))"
			}
		case .missingData:
			return "Could not find data"
		case .notImplemented:
			return "The method has not been implemented"
		}
	}

	var loaf: LoafState {
		LoafState(self.errorDescription ?? "Unknown (API Error)", state: .error)
	}
}

typealias HiveAPIPromise<Success> = Future<Success, HiveAPIError>.Promise

class HiveAPI: ObservableObject {
	static let baseURL = URL(string: "https://hiveforios.josephroque.dev")!

	private var apiGroup: URL { HiveAPI.baseURL.appendingPathComponent("api") }
	private var userGroup: URL { apiGroup.appendingPathComponent("users") }
	private var matchGroup: URL { apiGroup.appendingPathComponent("matches") }

	private let session: NetworkSession
	private let apiQueue: DispatchQueue

	init(session: NetworkSession = URLSession.shared, queue: DispatchQueue = .global(qos: .userInitiated)) {
		self.session = session
		self.apiQueue = queue
	}

	func login(login: LoginData) -> AnyPublisher<AccessToken, HiveAPIError> {
		Future { promise in
			let url = self.userGroup.appendingPathComponent("login")

			let auth = String(format: "%@:%@", login.email, login.password)
			let authData = auth.data(using: String.Encoding.utf8)!
			let base64Auth = authData.base64EncodedString()

			var request = self.buildBaseRequest(to: url)
			request.httpMethod = "POST"
			request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")

			self.session.loadData(from: request) { [weak self] data, response, error in
				self?.handleResponse(data: data, response: response, error: error, promise: promise)
			}
		}
		.subscribe(on: apiQueue)
		.eraseToAnyPublisher()
	}

	func signup(signup: SignupData) -> AnyPublisher<UserSignup, HiveAPIError> {
		Future { promise in
			let url = self.userGroup.appendingPathComponent("signup")

			let encoder = JSONEncoder()
			guard let signupData = try? encoder.encode(signup) else {
				return promise(.failure(.invalidData))
			}

			var request = self.buildBaseRequest(to: url)
			request.httpMethod = "POST"
			request.httpBody = signupData

			self.session.loadData(from: request) { [weak self] data, response, error in
				self?.handleResponse(data: data, response: response, error: error, promise: promise)
			}
		}
		.subscribe(on: apiQueue)
		.eraseToAnyPublisher()
	}

	func checkToken(userId: User.ID, token: String) -> AnyPublisher<Bool, HiveAPIError> {
		Future<TokenValidation, HiveAPIError> { promise in
			let url = self.userGroup.appendingPathComponent("validate")

			var request = self.buildBaseRequest(to: url)
			request.httpMethod = "GET"
			Account.apply(auth: nil, to: &request, overridingTokenWith: token)

			self.session.loadData(from: request) { [weak self] data, response, error in
				self?.handleResponse(data: data, response: response, error: error, promise: promise)
			}
		}
		.subscribe(on: apiQueue)
		.map { result in userId == result.userId }
		.eraseToAnyPublisher()
	}

	func logout(fromAccount account: Account) -> AnyPublisher<Bool, HiveAPIError> {
		Future { promise in
			let url = self.userGroup.appendingPathComponent("logout")

			var request = self.buildBaseRequest(to: url, withAccount: account)
			request.httpMethod = "DELETE"

			self.session.loadData(from: request) { [weak self] data, response, error in
				self?.handleVoidResponse(data: data, response: response, error: error, promise: promise)
			}
		}
		.subscribe(on: apiQueue)
		.eraseToAnyPublisher()
	}

	// MARK: - Users

	func user(id: User.ID, withAccount account: Account?) -> AnyPublisher<User, HiveAPIError> {
		Future { promise in
			let url = self.userGroup
				.appendingPathComponent(id.uuidString)
				.appendingPathComponent("details")

			var request = self.buildBaseRequest(to: url, withAccount: account)
			request.httpMethod = "GET"

			self.session.loadData(from: request) { [weak self] data, response, error in
				self?.handleResponse(data: data, response: response, error: error, promise: promise)
			}
		}
		.subscribe(on: apiQueue)
		.eraseToAnyPublisher()
	}

	// MARK: - Matches

	func openMatches(withAccount account: Account?) -> AnyPublisher<[Match], HiveAPIError> {
		Future { promise in
			let url = self.matchGroup.appendingPathComponent("open")

			var request = self.buildBaseRequest(to: url, withAccount: account)
			request.httpMethod = "GET"

			self.session.loadData(from: request) { [weak self] data, response, error in
				self?.handleResponse(data: data, response: response, error: error, promise: promise)
			}
		}
		.subscribe(on: apiQueue)
		.eraseToAnyPublisher()
	}

	func matchDetails(id: Match.ID, withAccount account: Account?) -> AnyPublisher<Match, HiveAPIError> {
		Future { promise in
			let url = self.matchGroup.appendingPathComponent(id.uuidString)

			var request = self.buildBaseRequest(to: url, withAccount: account)
			request.httpMethod = "GET"

			self.session.loadData(from: request) { [weak self] data, response, error in
				self?.handleResponse(data: data, response: response, error: error, promise: promise)
			}
		}
		.subscribe(on: apiQueue)
		.eraseToAnyPublisher()
	}

	func joinMatch(id: Match.ID, withAccount account: Account?) -> AnyPublisher<JoinMatchResponse, HiveAPIError> {
		Future { promise in
			let url = self.matchGroup
				.appendingPathComponent(id.uuidString)
				.appendingPathComponent("join")

			var request = self.buildBaseRequest(to: url, withAccount: account)
			request.httpMethod = "POST"

			self.session.loadData(from: request) { [weak self] data, response, error in
				self?.handleResponse(data: data, response: response, error: error, promise: promise)
			}
		}
		.subscribe(on: apiQueue)
		.eraseToAnyPublisher()
	}

	func createMatch(withAccount account: Account?) -> AnyPublisher<CreateMatchResponse, HiveAPIError> {
		Future { promise in
			let url = self.matchGroup.appendingPathComponent("new")

			var request = self.buildBaseRequest(to: url, withAccount: account)
			request.httpMethod = "POST"

			self.session.loadData(from: request) { [weak self] data, response, error in
				self?.handleResponse(data: data, response: response, error: error, promise: promise)
			}
		}
		.subscribe(on: apiQueue)
		.eraseToAnyPublisher()
	}

	// MARK: - Common

	private func buildBaseRequest(to url: URL, withAccount account: Account? = nil) -> URLRequest {
		var request = URLRequest(url: url)
		request.addValue("application/json", forHTTPHeaderField: "Content-Type")
		request.addValue("application/json", forHTTPHeaderField: "Accept")
		account?.applyAuth(to: &request)
		return request
	}

	private func handleResponse<Result: Decodable>(
		data: Data?,
		response: URLResponse?,
		error: Error?,
		promise: HiveAPIPromise<Result>
	) {
		guard error == nil else {
			return promise(.failure(.networkingError(error!)))
		}

		guard let response = response as? HTTPURLResponse else {
			return promise(.failure(.invalidResponse))
		}

		guard (200..<400).contains(response.statusCode) else {
			if response.statusCode == 401 {
				reportUnauthorizedRequest()
				return promise(.failure(.unauthorized))
			}
			return promise(.failure(.invalidHTTPResponse(response.statusCode)))
		}

		let decoder = JSONDecoder()
		decoder.dateDecodingStrategy = .iso8601
		guard let data = data, let result = try? decoder.decode(Result.self, from: data) else {
			return promise(.failure(.invalidData))
		}

		promise(.success(result))
	}

	private func handleVoidResponse(
		data: Data?,
		response: URLResponse?,
		error: Error?,
		promise: HiveAPIPromise<Bool>
	) {
		guard error == nil else {
			return promise(.failure(.networkingError(error!)))
		}

		guard let response = response as? HTTPURLResponse else {
			return promise(.failure(.invalidResponse))
		}

		guard (200..<400).contains(response.statusCode) else {
			if response.statusCode == 401 {
				reportUnauthorizedRequest()
				return promise(.failure(.unauthorized))
			}
			return promise(.failure(.invalidHTTPResponse(response.statusCode)))
		}

		promise(.success(true))
	}

	private func reportUnauthorizedRequest() {
		NotificationCenter.default.post(name: NSNotification.Name.Account.Unauthorized, object: nil)
	}
}
