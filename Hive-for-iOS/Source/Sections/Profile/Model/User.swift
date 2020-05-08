//
//  User.swift
//  Hive-for-iOS
//
//  Created by Joseph Roque on 2020-03-30.
//  Copyright © 2020 Joseph Roque. All rights reserved.
//

import Foundation

struct User: Identifiable, Decodable {
	let id: UUID
	let displayName: String
	let elo: Double
	let avatarUrl: URL?
	let activeMatches: [Match]
	let pastMatches: [Match]
}