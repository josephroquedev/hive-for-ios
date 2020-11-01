//
//  SpectatorGameViewModel.swift
//  Hive-for-iOS
//
//  Created by Joseph Roque on 2020-08-23.
//  Copyright © 2020 Joseph Roque. All rights reserved.
//

import Combine
import HiveEngine
import SwiftUI

class SpectatorGameViewModel: GameViewModel {
	override var isSpectating: Bool {
		true
	}

	override var inGame: Bool {
		false
	}

	private var _hasGameEnded: Bool = false
	override var hasGameEnded: Bool {
		_hasGameEnded
	}

	override init(setup: Game.Setup) {
		switch setup.mode {
		case .spectate: break
		case .play:
			fatalError("Cannot play with SpectatorViewModel")
		}
		super.init(setup: setup)
	}

	override func postViewAction(_ viewAction: GameViewAction) {
		super.postViewAction(viewAction)

		switch viewAction {
		case .openHand(let player):
			promptFeedbackGenerator.impactOccurred()
			postViewAction(.presentInformation(.playerHand(.init(player: player, playingAs: player.next, state: gameState))))
		case .selectedFromHand(_, let pieceClass):
			enquireFromHand(pieceClass)

		default:
			break
		}
	}

	// State transitions

	override func setupNewGame() {
		// Does nothing
	}

	override func setupView(content: GameViewContent) {
		if gameContent == nil {
			super.setupView(content: content)
		}
	}

	override func showEndGame(withWinner winner: Player?) {
		_hasGameEnded = true
		presentedGameInformation = .gameEnd(.init(
			winner: winner,
			playingAs: nil,
			wasForfeit: false
		))
	}

	override func showForfeit(byPlayer player: Player) {
		_hasGameEnded = true
		presentedGameInformation = .gameEnd(
			.init(
				winner: player.next,
				playingAs: nil,
				wasForfeit: true
			)
		)
	}

	override func endGame() {
		// Does nothing
	}

	override func updateGameState(to newState: GameState) {
		let previousState = gameState
		self.gameState = newState

		guard let previousUpdate = newState.updates.last,
			previousUpdate != previousState.updates.last else {
			return
		}

		if newState.hasGameEnded {
			endGame()
		}

		presentMovement(from: previousUpdate.player, movement: previousUpdate.movement)
	}
}
