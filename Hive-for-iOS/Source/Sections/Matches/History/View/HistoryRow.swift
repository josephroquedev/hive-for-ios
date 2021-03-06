//
//  HistoryRow.swift
//  Hive-for-iOS
//
//  Created by Joseph Roque on 2020-05-11.
//  Copyright © 2020 Joseph Roque. All rights reserved.
//

import SwiftUI
import HiveEngine

struct HistoryRow: View {
	let match: Match
	let withLastMove: Bool

	init(match: Match, withLastMove: Bool = false) {
		self.match = match
		self.withLastMove = withLastMove
	}

	var body: some View {
		VStack {
			HStack {
				UserPreview(
					match.host?.summary,
					highlight: isWinner(user: match.host?.id)
				)
				Spacer(minLength: Metrics.Spacing.s.rawValue)
				UserPreview(
					match.opponent?.summary,
					highlight: isWinner(user: match.opponent?.id),
					alignment: .trailing
				)
			}

			if !match.isComplete, withLastMove {
				lastMove
			} else if match.isComplete {
				if let duration = match.duration,
					 let formattedDate = match.createdAt?.addingTimeInterval(duration).formatted {
					Text("Played \(formattedDate)")
						.font(.caption2)
						.foregroundColor(Color(.textSecondary))
				}
			}
		}
	}

	private var lastMove: some View {
		let text: String
		if let move = match.moves.last {
			text = "Last move by \(player(of: move.ordinal)) \(formattedDate(move.date))"
		} else {
			text = "The match has not started"
		}

		return lastMoveText(text)
	}

	private func lastMoveText(_ text: String) -> some View {
		Text(text)
			.font(.caption)
			.multilineTextAlignment(.leading)
			.frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
	}

	private func isWinner(user: User.ID?) -> Bool {
		user != nil && match.winner?.id == user
	}

	private func player(of move: Int) -> String {
		if move % 2 == 0 {
			return match.optionSet.contains(.hostIsWhite)
				? match.host?.displayName ?? "White"
				: match.opponent?.displayName ?? "Black"
		} else {
			return match.optionSet.contains(.hostIsWhite)
				? match.opponent?.displayName ?? "White"
				: match.host?.displayName ?? "Black"
		}
	}

	private func formattedDate(_ date: Date) -> String {
		let prefix: String
		let formatter = DateFormatter()

		if date.isToday {
			prefix = "at"
			formatter.dateStyle = .none
			formatter.timeStyle = .short
		} else if date.isThisYear {
			prefix = "on"
			formatter.dateStyle = .long
			formatter.timeStyle = .short
		} else {
			prefix = "on"
			formatter.dateStyle = .long
			formatter.timeStyle = .none
		}

		return "\(prefix) \(formatter.string(from: date))"
	}
}

private extension GameState.Option {
	var preview: String? {
		switch self {
		case .mosquito: return "M"
		case .ladyBug: return "L"
		case .pillBug: return "P"
		case .noFirstMoveQueen, .allowSpecialAbilityAfterYoink: return nil
		}
	}
}

private extension Date {
	var formatted: String {
		RelativeDateTimeFormatter().localizedString(for: self, relativeTo: Date())
	}
}

// MARK: - Preview

#if DEBUG
struct HistoryRowPreview: PreviewProvider {
	static var previews: some View {
		HistoryRow(match: Match.matches[0])
	}
}
#endif
