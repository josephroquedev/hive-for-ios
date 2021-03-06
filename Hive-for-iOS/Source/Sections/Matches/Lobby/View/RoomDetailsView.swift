//
//  RoomDetailsView.swift
//  Hive-for-iOS
//
//  Created by Joseph Roque on 2020-06-11.
//  Copyright © 2020 Joseph Roque. All rights reserved.
//

import SwiftUI
import HiveEngine

struct RoomDetailsView: View {
	let host: UserPreview.UserSummary?
	let isHostReady: ReadyStatus
	let opponent: UserPreview.UserSummary?
	let isOpponentReady: ReadyStatus
	let optionsDisabled: Bool

	let gameOptionsEnabled: Set<GameState.Option>
	let matchOptionsEnabled: Set<Match.Option>
	let gameOptionBinding: (GameState.Option) -> Binding<Bool>
	let matchOptionBinding: (Match.Option) -> Binding<Bool>

	var body: some View {
		List {
			Section(header: SectionHeader("Players")) {
				playerSection
			}
			.listRowBackground(Color(.backgroundLight))

			Section(header: SectionHeader("Expansions")) {
				expansionsSection
			}
			.listRowBackground(Color(.backgroundLight))

			Section(header: SectionHeader("Match options")) {
				matchOptionsSection
			}
			.listRowBackground(Color(.backgroundLight))

			Section(header: SectionHeader("Other options")) {
				otherOptionsSection
			}
			.listRowBackground(Color(.backgroundLight))
		}
		.listStyle(InsetGroupedListStyle())
	}

	private var playerSection: some View {
		VStack(alignment: .leading) {
			summary(forPlayer: host, isReady: isHostReady)
			Divider()
			summary(forPlayer: opponent, isReady: isOpponentReady)
		}
	}

	private func summary(forPlayer player: UserPreview.UserSummary?, isReady: ReadyStatus) -> some View {
		HStack(spacing: 0) {
			UserPreview(
				player,
				highlight: isReady.shouldHighlight,
				iconSize: .l
			)
			Spacer(minLength: Metrics.Spacing.s.rawValue)

			switch isReady {
			case .ready:
				Text("READY")
					.font(.caption)
					.foregroundColor(Color(.highlightSuccess))
			case .notReady:
				Text("WAITING")
					.font(.caption)
					.foregroundColor(Color(.highlightDestructive))
			case .notApplicable:
				EmptyView()
			}
		}
	}

	private var expansionsSection: some View {
		ForEach(GameState.Option.expansions, id: \.rawValue) { option in
			Toggle(name(forOption: option), isOn: gameOptionBinding(option))
				.foregroundColor(Color(.textRegular))
				.disabled(optionsDisabled)
		}
	}

	private var matchOptionsSection: some View {
		ForEach(Match.Option.enabledOptions, id: \.rawValue) { option in
			Toggle(name(forOption: option), isOn: matchOptionBinding(option))
				.foregroundColor(Color(.textRegular))
				.disabled(optionsDisabled)
		}
	}

	private var otherOptionsSection: some View {
		ForEach(GameState.Option.nonExpansions, id: \.rawValue) { option in
			Toggle(name(forOption: option), isOn: gameOptionBinding(option))
				.foregroundColor(Color(.textRegular))
				.disabled(optionsDisabled)
		}
	}
}

// MARK: - Strings

extension RoomDetailsView {
	private func name(forOption option: Match.Option) -> String {
		switch option {
		case .asyncPlay: return "Asynchronous play"
		case .hostIsWhite: return "\(host?.displayName ?? "Host") is white"
		}
	}

	private func name(forOption option: GameState.Option) -> String {
		return option.displayName
	}
}

extension RoomDetailsView {
	enum ReadyStatus {
		case ready
		case notReady
		case notApplicable

		var shouldHighlight: Bool {
			switch self {
			case .ready: return true
			case .notReady, .notApplicable: return false
			}
		}

		init(_ isReady: Bool) {
			if isReady {
				self = .ready
			} else {
				self = .notReady
			}
		}
	}
}

// MARK: - Preview

#if DEBUG
struct RoomDetailsViewPreview: PreviewProvider {
	private static let gameOptions: Set<GameState.Option> = [.mosquito, .allowSpecialAbilityAfterYoink]
	private static let matchOptions: Set<Match.Option> = [.hostIsWhite]

	static var previews: some View {
		RoomDetailsView(
			host: User.users[0].summary,
			isHostReady: .ready,
			opponent: User.users[0].summary,
			isOpponentReady: .notReady,
			optionsDisabled: false,
			gameOptionsEnabled: Self.gameOptions,
			matchOptionsEnabled: Self.matchOptions,
			gameOptionBinding: { .constant(Self.gameOptions.contains($0)) },
			matchOptionBinding: { .constant(Self.matchOptions.contains($0)) }
		)
	}
}
#endif
