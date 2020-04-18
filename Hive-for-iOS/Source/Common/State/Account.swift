//
//  Account.swift
//  Hive-for-iOS
//
//  Created by Joseph Roque on 2020-04-01.
//  Copyright © 2020 Joseph Roque. All rights reserved.
//

import Foundation
import Combine
import KeychainAccess

enum TokenStatus {
	case validating
	case valid
	case invalid
	case validationError
}

class Account: ObservableObject {
	private enum Key: String {
		case userId
		case token
	}

	private(set) var userId: User.ID?
	private(set) var token: String?

	@Published var isAuthenticated: Bool = false
	@Published var tokenStatus: TokenStatus?

	private let keychain = Keychain(service: "ca.josephroque.hive-for-ios")

	init() {
		do {
			guard let id = try keychain.get(Key.userId.rawValue),
				let token = try keychain.get(Key.token.rawValue) else { return }

			self.userId = UUID(uuidString: id)
			self.token = token
		} catch {
			print("Error retrieving login: \(error)")
		}
	}

	func clear() throws {
		try store(userId: nil)
		try store(token: nil)

		DispatchQueue.main.async {
			self.isAuthenticated = false
		}
	}

	func store(accessToken: AccessToken) throws {
		try store(userId: accessToken.userId)
		try store(token: accessToken.token)

		DispatchQueue.main.async {
			self.isAuthenticated = true
		}
	}

	private func store(userId: User.ID?) throws {
		self.userId = userId
		if let userId = userId {
			try keychain.set(userId.uuidString, key: Key.userId.rawValue)
		} else {
			try keychain.remove(Key.userId.rawValue)
		}
	}

	private func store(token: String?) throws {
		self.token = token
		if let token = token {
			try keychain.set(token, key: Key.token.rawValue)
		} else {
			try keychain.remove(Key.token.rawValue)
		}
	}

	func applyAuth(to request: inout URLRequest, overridingTokenWith token: String? = nil) {
		guard let token = token ?? self.token else { return }
		request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
	}
}
