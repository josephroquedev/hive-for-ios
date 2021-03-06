//
//  PlayerGameViewModel.swift
//  Hive-for-iOS
//
//  Created by Joseph Roque on 2020-08-24.
//  Copyright © 2020 Joseph Roque. All rights reserved.
//

import Combine
import HiveEngine
import Loaf
import SwiftUI

class PlayerGameViewModel: GameViewModel {
	@Published var state: State = .begin

	var playingAs: Player?
	var activePlayer: Player {
		playingAs ?? gameState.currentPlayer
	}

	override var isSpectating: Bool {
		false
	}

	override var inGame: Bool {
		state.inGame
	}

	override var hasGameEnded: Bool {
		gameState.hasGameEnded || state.hasGameEnded
	}

	override init(setup: Game.Setup) {
		let clientMode: ClientInteractorConfiguration
		switch setup.mode {
		case .singlePlayer(let player, let configuration):
			self.playingAs = player
			clientMode = configuration
		case .twoPlayer:
			self.playingAs = nil
			clientMode = .local
		case .spectate:
			fatalError("Cannot spectate with PlayerGameViewModel")
		}
		super.init(setup: setup)
		self.clientMode = clientMode
	}

	override func postViewAction(_ viewAction: GameViewAction) {
		super.postViewAction(viewAction)

		switch viewAction {
		case .openHand(let player):
			promptFeedbackGenerator.impactOccurred()
			postViewAction(
				.presentInformation(
					.playerHand(
						GameInformation.PlayerHand(
							owner: player,
							title: playingAs == nil
								? "\(player)'s hand"
								: (playingAs == player ? "Your" : "Opponent's") + " hand",
							isPlayable: playingAs == nil || (playingAs == player && gameState.currentPlayer == player),
							state: gameState
						)
					)
				)
			)
		case .selectedFromHand(let player, let pieceClass):
			selectFromHand(player, pieceClass)

		case .gamePieceSnapped(let piece, let position):
			updatePosition(of: piece, to: position, shouldMove: false)
		case .gamePieceMoved(let piece, let position):
			logger.debug("Moving \(piece) to \(position)")
			updatePosition(of: piece, to: position, shouldMove: true)
		case .movementConfirmed(let movement):
			logger.debug("Sending move \(movement)")
			apply(movement: movement)
		case .cancelMovement:
			clearSelectedPiece()
			updateGameState(to: gameState)

		case .forfeit:
			promptForfeit()
		case .forfeitConfirmed:
			forfeitGame()
		case .arViewError(let error):
			loafState.send(LoafState(error.localizedDescription, style: .error()))

		case .toggleDebug:
			debugMode.toggle()

		// Not used in PlayerGameViewModel
		case .onAppear, .viewContentDidLoad, .viewContentReady, .viewInteractionsReady, .presentInformation,
				 .closeInformation, .enquiredFromHand, .tappedPiece, .tappedGamePiece, .toggleEmojiPicker,
				 .pickedEmoji, .hasMovedInBounds, .hasMovedOutOfBounds, .returnToGameBounds, .openAppSettings,
				 .replayLastMove, .dismissReplayTooltip, .openGameSettings, .returnToLobby, .onDisappear:
			break
		}
	}

	// MARK: State transitions

	override func setupNewGame() {
		guard !inGame && viewContentReady && viewInteractionsReady else { return }
		if gameState.currentPlayer == activePlayer {
			transition(to: .playerTurn)
		} else {
			transition(to: .opponentTurn)
		}

		// Let the computer know it's time to play, if offline
		if case .local = clientMode {
			clientInteractor.send(.local, .readyToPlay, completionHandler: nil)
		}
	}

	override func setupView(content: GameViewContent) {
		if gameContent == nil {
			super.setupView(content: content)
			transition(to: .gameStart)
		}
	}

	override func showEndGame(withWinner winner: Player?) {
		presentedGameInformation = .gameEnd(
			GameInformation.EndState(
				winner: winner,
				playingAs: playingAs,
				wasForfeit: false,
				wasSpectating: false
			)
		)
	}

	override func showForfeit(byPlayer player: Player) {
		presentedGameInformation = .gameEnd(
			GameInformation.EndState(
				winner: player.next,
				playingAs: playingAs,
				wasForfeit: true,
				wasSpectating: false
			)
		)
	}

	override func endGame() {
		guard inGame else { return }
		transition(to: .gameEnd)
	}

	override func updateGameState(to newState: GameState) {
		guard inGame else { return }
		let previousState = gameState
		self.gameState = newState

		let opponent = playingAs?.next
		guard let previousUpdate = newState.updates.last,
			previousUpdate != previousState.updates.last else {
			return
		}

		let wasOpponentMove = previousUpdate.player == opponent

		if newState.hasGameEnded {
			endGame()
		} else {
			transition(to: playingAs == nil ? .playerTurn : (wasOpponentMove ? .playerTurn : .opponentTurn))
		}

		guard let opp = opponent, wasOpponentMove else { return }
		presentMovement(from: opp, movement: previousUpdate.movement)
	}

	// MARK: Interactions

	private func selectFromHand(_ player: Player, _ pieceClass: Piece.Class) {
		guard inGame else { return }
		if player == activePlayer {
			placeFromHand(pieceClass)
		} else {
			enquireFromHand(pieceClass)
		}
	}

	private func placeFromHand(_ pieceClass: Piece.Class) {
		guard inGame else { return }
		actionFeedbackGenerator.impactOccurred()
		if let piece = gameState.firstUnplayed(of: pieceClass, inHand: activePlayer) {
			let position = selectedPieceDefaultPosition
			selectedPiece = (
				selectedPiece.selected,
				SelectedPiece(
					piece: piece,
					position: position
				)
			)
			animateToPosition.send(position)
		}
	}

	private func updatePosition(of piece: Piece, to position: Position?, shouldMove: Bool) {
		guard inGame else { return }
		guard let targetPosition = position else {
			selectedPiece = (selectedPiece.selected, nil)
			return
		}

		guard shouldMove else {
			selectedPiece = (selectedPiece.selected, SelectedPiece(piece: piece, position: targetPosition))
			return
		}

		guard let movement = gameState.availableMoves.first(where: {
			$0.movedUnit == piece && $0.targetPosition == targetPosition
		}), let relativeMovement = movement.relative(in: gameState) else {
			logger.debug("Did not find \"\(piece) to \(targetPosition)\" in \(gameState.availableMoves)")
			notificationFeedbackGenerator.notificationOccurred(.warning)
			return
		}

		selectedPiece = (selectedPiece.selected, SelectedPiece(piece: piece, position: targetPosition))

		let inHand = gameState.position(of: piece) == nil

		let config = GameEvent.Config(
			title: "\(inHand ? "Place" : "Move") \(piece.class.description)?",
			message: description(of: relativeMovement, inHand: inHand),
			buttons: [
				GameEvent.ButtonConfig(
					title: inHand ? "Place" : "Move",
					type: .default
				) { [weak self] in
					self?.postViewAction(.movementConfirmed(movement))
					self?.presentedGameEvent = nil
				},
				GameEvent.ButtonConfig(
					title: "Cancel",
					type: .cancel
				) { [weak self] in
					self?.postViewAction(.cancelMovement)
					self?.presentedGameEvent = nil
				},
			]
		)

		promptFeedbackGenerator.impactOccurred()
		presentedGameEvent = GameEvent(config: config) { [weak self] in
			self?.postViewAction(.cancelMovement)
		}
	}

	private func apply(movement: Movement) {
		guard let relativeMovement = movement.relative(in: gameState) else {
			notificationFeedbackGenerator.notificationOccurred(.error)
			return
		}

		notificationFeedbackGenerator.notificationOccurred(.success)
		transition(to: .sendingMovement(movement))
		clientInteractor.send(clientMode, .movement(relativeMovement), completionHandler: nil)
	}

	// MARK: Forfeit

	private func promptForfeit() {
		guard inGame else { return }

		let config = GameEvent.Config(
			title: "Forfeit match?",
			message: "This will count as a loss in your statistics. Are you sure?",
			buttons: [
				GameEvent.ButtonConfig(
					title: "Forfeit",
					type: .destructive
				) { [weak self] in
					self?.postViewAction(.forfeitConfirmed)
					self?.presentedGameEvent = nil
				},
				GameEvent.ButtonConfig(
					title: "Cancel",
					type: .cancel
				) { [weak self] in
					self?.presentedGameEvent = nil
				},
			]
		)

		promptFeedbackGenerator.impactOccurred()
		presentedGameEvent = GameEvent(config: config, onClose: nil)
	}

	private func forfeitGame() {
		guard inGame else { return }

		clientInteractor.send(clientMode, .forfeit, completionHandler: nil)
		transition(to: .forfeit)
	}

	// MARK: UI

	override var displayState: String {
		switch state {
		case .playerTurn:
			return playingAs == nil
				? ("\(gameState.currentPlayer)'s turn")
				: "Your turn"
		case .sendingMovement:
			return "Sending movement..."
		case .opponentTurn:
			return "Opponent's turn"
		case .gameEnd:
			return gameState.displayWinner ?? ""
		case .begin, .forfeit, .gameStart:
			return ""
		}
	}

	override func handImage(for player: Player) -> UIImage {
		if player == activePlayer {
			return state == .playerTurn ? ImageAsset.Icon.handFilled : ImageAsset.Icon.handOutlined
		} else {
			return state == .opponentTurn ? ImageAsset.Icon.handFilled : ImageAsset.Icon.handOutlined
		}
	}

	private func description(of movement: RelativeMovement, inHand: Bool) -> String {
		if let adjacent = movement.adjacent {
			let direction = adjacent.direction.flipped
			return "\(inHand ? "Place" : "Move") "
				+ "\(movement.movedUnit.description) \(direction.description.lowercased()) of \(adjacent.unit)?"
		} else {
			return "Place \(movement.movedUnit.description)?"
		}
	}
}

// MARK: Position

extension PlayerGameViewModel {
	private var selectedPieceDefaultPosition: Position {
		let piecePositions = Set(gameState.stacks.keys)
		let placeablePositions = gameState.placeablePositions(for: activePlayer)
		let adjacentToPiecePositions = Set(piecePositions.flatMap { $0.adjacent() })
			.subtracting(piecePositions)
		let adjacentToAdjacentPositions = Set(adjacentToPiecePositions.flatMap { $0.adjacent() })
			.subtracting(adjacentToPiecePositions)
			.subtracting(piecePositions)
			.sorted()

		guard let startingPosition = adjacentToAdjacentPositions.first else {
			// Fallback for when the algorithm fails, which it shouldn't ever do
			// Places the piece to the far left of the board, vertically centred.
			let startX = piecePositions.first?.x ?? 0
			let minX = piecePositions.reduce(startX, { minX, position in min(minX, position.x) })
			let x = minX - 2
			let z = x < 0 ? -x / 2 : Int((Double(-x) / 2.0).rounded(.down))
			return Position(x: x, y: -x - z, z: z)
		}

		let closest = adjacentToAdjacentPositions.reduce(
			(startingPosition, CGFloat.greatestFiniteMagnitude)
		) { closest, position in
			let totalDistanceToPlaceable = placeablePositions.reduce(.zero) { total, next in
				total + position.distance(to: next)
			}

			return totalDistanceToPlaceable < closest.1
				? (position, totalDistanceToPlaceable)
				: closest
		}

		return closest.0
	}
}

private extension Direction {
	var flipped: Direction {
		switch self {
		case .north: return .south
		case .northWest: return .southWest
		case .northEast: return .southEast
		case .south: return .north
		case .southWest: return .northWest
		case .southEast: return .northEast
		case .onTop: return .onTop
		}
	}
}

// MARK: State

extension PlayerGameViewModel {
	enum State: Equatable {
		case begin
		case gameStart
		case playerTurn
		case opponentTurn
		case sendingMovement(Movement)
		case gameEnd
		case forfeit

		var inGame: Bool {
			switch self {
			case .begin, .gameStart, .gameEnd, .forfeit: return false
			case .playerTurn, .opponentTurn, .sendingMovement: return true
			}
		}

		var hasGameEnded: Bool {
			switch self {
			case .gameEnd, .forfeit: return true
			case .begin, .gameStart, .playerTurn, .opponentTurn, .sendingMovement: return false
			}
		}
	}

	func transition(to nextState: State) {
		guard canTransition(from: state, to: nextState) else { return }
		state = nextState
		objectWillChange.send()

		guard nextState == .playerTurn else { return }

		if gameState.currentPlayer == activePlayer && gameState.availableMoves == [.pass] {
			presentedGameInformation = .playerMustPass(activePlayer)
		}
	}

	private func canTransition(from currentState: State, to nextState: State) -> Bool {
		switch (currentState, nextState) {

		// Forfeit and gameEnd are final states
		case (.forfeit, _): return false
		case (.gameEnd, _): return false

		// Forfeiting possible at any time
		case (_, .forfeit): return true

		// Game can be ended at any time
		case (_, .gameEnd): return true

		// Beginning the game always transitions to the start of a game
		case (.begin, .gameStart): return true
		case (.begin, _): return false
		case (_, .begin): return false
		case (_, .gameStart): return false

		// The start of a game leads to a player's turn or an opponent's turn
		case (.gameStart, .playerTurn), (.gameStart, .opponentTurn): return true
		case (.gameStart, _): return false

		// The player must send moves
		case (.playerTurn, .sendingMovement): return true
		case (.playerTurn, _): return false

		// A played move leads to a new turn
		case (.sendingMovement, .opponentTurn), (.sendingMovement, .playerTurn): return true
		case (.opponentTurn, .playerTurn): return true
		case (.opponentTurn, _): return false

		case (.sendingMovement, _), (_, .sendingMovement): return false
		case (_, .playerTurn), (_, .opponentTurn): return false
		}
	}
}
