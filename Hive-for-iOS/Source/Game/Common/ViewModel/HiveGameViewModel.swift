//
//  HiveGameViewModel.swift
//  Hive-for-iOS
//
//  Created by Joseph Roque on 2020-01-24.
//  Copyright © 2020 Joseph Roque. All rights reserved.
//

import SwiftUI
import Combine
import HiveEngine
import Loaf
import NIOWebSocket

enum HiveGameViewAction: BaseViewAction {
	case failedToStartGame
	case onAppear(GameState)
	case viewContentDidLoad(GameViewContent)
	case viewContentReady
	case viewInteractionsReady

	case presentInformation(GameInformation)
	case enquiredFromHand(Piece.Class)
	case selectedFromHand(Piece.Class)
	case tappedPiece(Piece)
	case tappedGamePiece(Piece)

	case gamePieceSnapped(Piece, Position)
	case gamePieceMoved(Piece, Position)
	case movementConfirmed(Movement)
	case cancelMovement

	case openSettings
	case arViewError(Error)

	case toggleDebug
	case onDisappear
}

class HiveGameViewModel: ViewModel<HiveGameViewAction>, ObservableObject {
	var client: HiveGameClient!

	@Published var handToShow: PlayerHand?
	@Published var informationToPresent: GameInformation?
	@Published var gameActionToPresent: GameAction?

	var loafSubject = PassthroughSubject<LoafState, Never>()
	var animateToPosition = PassthroughSubject<Position, Never>()

	struct SelectedPiece {
		let piece: Piece
		let position: Position
	}

	typealias DeselectedPiece = SelectedPiece

	var selectedPiece = CurrentValueSubject<(DeselectedPiece?, SelectedPiece?), Never>((nil, nil))
	var currentSelectedPiece: SelectedPiece? { selectedPiece.value.1 }

	var flowStateSubject = CurrentValueSubject<State, Never>(State.begin)
	var gameStateSubject = CurrentValueSubject<GameState?, Never>(nil)
	var debugEnabledSubject = CurrentValueSubject<Bool, Never>(false)

	var gameContent: GameViewContent!
	var playingAs: Player!

	var inGame: Bool {
		flowStateSubject.value.inGame
	}

	var gameState: GameState {
		gameStateSubject.value!
	}

	var currentState: State {
		flowStateSubject.value
	}

	var gameAnchor: Experience.HiveGame? {
		if case let .arExperience(anchor) = gameContent {
			return anchor
		} else {
			return nil
		}
	}

	var showPlayerHand: Binding<Bool> {
		Binding(
			get: { self.handToShow != nil },
			set: { newValue in
				guard !newValue else { return }
				self.handToShow = nil
			}
		)
	}

	var hasInformation: Binding<Bool> {
		Binding(
			get: { self.informationToPresent != nil },
			set: { newValue in
				guard !newValue else { return }
				self.informationToPresent = nil
			}
		)
	}

	var hasGameAction: Binding<Bool> {
		Binding(
			get: { self.gameActionToPresent != nil },
			set: { newValue in
				guard !newValue else { return }
				switch self.gameActionToPresent {
				case .confirmMovement: self.postViewAction(.cancelMovement)
				case .none: break
				}
				self.gameActionToPresent = nil
			}
		)
	}

	var displayState: String {
		switch flowStateSubject.value {
		case .playerTurn:
			return "Your turn"
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

	var shouldHideHUDControls: Bool {
		showPlayerHand.wrappedValue || hasInformation.wrappedValue || hasGameAction.wrappedValue
	}

	private var selectedPieceDefaultPosition: Position {
		let positions = gameState.stacks.keys
		let startX = positions.first?.x ?? 0
		let minX = positions.reduce(startX, { minX, position in min(minX, position.x) })
		let x = minX - 2
		let z = x < 0 ? -x / 2 : Int((Double(-x) / 2.0).rounded(.down))
		return Position(x: x, y: -x - z, z: z)
	}

	private var viewContentReady: Bool = false
	private var viewInteractionsReady: Bool = false

	override func postViewAction(_ viewAction: HiveGameViewAction) {
		switch viewAction {
		case .failedToStartGame:
			loafSubject.send(LoafState("Failed to start game", state: .error))
		case .onAppear(let state):
			initialize(withState: state)
		case .viewContentDidLoad(let content):
			setupView(content: content)
		case .viewContentReady:
			viewContentReady = true
			attemptSetupNewGame()
		case .viewInteractionsReady:
			viewInteractionsReady = true
			attemptSetupNewGame()

		case .presentInformation(let information):
			self.informationToPresent = information
		case .selectedFromHand(let pieceClass):
			placeFromHand(pieceClass)
		case .enquiredFromHand(let pieceClass):
			enquireFromHand(pieceClass)
		case .tappedPiece(let piece):
			tappedPiece(piece)
		case .tappedGamePiece(let piece):
			tappedPiece(piece, showStack: true)
		case .gamePieceSnapped(let piece, let position):
			updatePosition(of: piece, to: position, shouldMove: false)
		case .gamePieceMoved(let piece, let position):
			debugLog("Moving \(piece) to \(position)")
			updatePosition(of: piece, to: position, shouldMove: true)
		case .movementConfirmed(let movement):
			debugLog("Sending move \(movement)")
			apply(movement: movement)
		case .cancelMovement:
			pickUpHand()

		case .openSettings:
			#warning("TODO: open game settings")
		case .arViewError(let error):
			loafSubject.send(LoafState(error.localizedDescription, state: .error))

		case .toggleDebug:
			debugEnabledSubject.send(!debugEnabledSubject.value)
		case .onDisappear:
			cleanUp()
		}
	}

	private func initialize(withState state: GameState) {
		guard flowStateSubject.value == .begin else { return }
		client.delegate = self
		gameStateSubject.send(state)
	}

	private func cleanUp() {
		try? client.close()
	}

	private func attemptSetupNewGame() {
		guard !inGame && viewContentReady && viewInteractionsReady else { return }
		setupNewGame()
	}

	private func setupNewGame() {
		if gameState.currentPlayer == playingAs {
			transition(to: .playerTurn)
		} else {
			transition(to: .opponentTurn)
		}
	}

	private func setupView(content: GameViewContent) {
		if gameContent == nil {
			self.gameContent = content
			transition(to: .gameStart)
		}
	}

	private func placeFromHand(_ pieceClass: Piece.Class) {
		guard inGame else { return }

		if handToShow?.player == playingAs,
			let piece = gameState.firstUnplayed(of: pieceClass, inHand: playingAs) {
			let position = selectedPieceDefaultPosition
			selectedPiece.send((
				selectedPiece.value.1,
				SelectedPiece(
					piece: piece,
					position: position
				)
			))
			animateToPosition.send(position)
		}
		handToShow = nil
	}

	private func enquireFromHand(_ pieceClass: Piece.Class) {
		guard inGame else { return }
		handToShow = nil
		informationToPresent = .pieceClass(pieceClass)
	}

	private func tappedPiece(_ piece: Piece, showStack: Bool = false) {
		if showStack {
			let position = self.position(of: piece)
			guard let stack = gameState.stacks[position] else {
				informationToPresent = .piece(piece)
				return
			}

			let (_, stackCount) = self.positionInStack(of: piece)
			if stackCount > 1 {
				let stackAddition = stackCount > stack.count ? [selectedPiece.value.1?.piece].compactMap { $0 } : []
				informationToPresent = .stack(stack + stackAddition)
				return
			}
		}
		informationToPresent = .piece(piece)
	}

	private func pickUpHand() {
		self.gameState.unitsInHand[playingAs]?.forEach { updatePosition(of: $0, to: nil, shouldMove: true) }
	}

	private func updatePosition(of piece: Piece, to position: Position?, shouldMove: Bool) {
		guard inGame else { return }
		guard let targetPosition = position else {
			selectedPiece.send((selectedPiece.value.1, nil))
			return
		}

		guard shouldMove else {
			selectedPiece.send((selectedPiece.value.1, SelectedPiece(piece: piece, position: targetPosition)))
			return
		}

		guard let movement = gameState.availableMoves.first(where: {
			$0.movedUnit == piece && $0.targetPosition == targetPosition
		}) else {
			debugLog("Did not find \"\(piece) to \(targetPosition)\" in \(gameState.availableMoves)")
			return
		}

		selectedPiece.send((selectedPiece.value.1, SelectedPiece(piece: piece, position: targetPosition)))

		let currentPosition = gameState.position(of: piece)?.description ?? "in hand"

		let popoverSheet = PopoverSheetConfig(
			title: "Move \(piece.class.description)?",
			message: "From \(currentPosition) to \(targetPosition.description)",
			buttons: [
				PopoverSheetConfig.ButtonConfig(
					title: "Move",
					type: .default
				) { [weak self] in
					self?.postViewAction(.movementConfirmed(movement))
					self?.gameActionToPresent = nil
				},
				PopoverSheetConfig.ButtonConfig(
					title: "Cancel",
					type: .cancel
				) { [weak self] in
					self?.postViewAction(.cancelMovement)
					self?.gameActionToPresent = nil
				},
			]
		)
		gameActionToPresent = .confirmMovement(popoverSheet)
	}

	private func apply(movement: Movement) {
		guard let relativeMovement = movement.relative(in: gameState) else {
			#warning("TODO: present an error here when the move is invalid")
			return
		}

		transition(to: .sendingMovement(movement))
		client.send(.movement(relativeMovement))
	}

	private func didReceive(newState: GameState) {
		guard inGame else { return }
		self.gameStateSubject.send(newState)

		let previousState = gameState
		let opponent = playingAs.next
		guard let previousUpdate = newState.previousMoves.last,
			previousUpdate != previousState.previousMoves.last else {
			return
		}

		let wasOpponentMove = previousUpdate.player == opponent

		if wasOpponentMove {
			let message: String
			let image: UIImage
			switch previousUpdate.movement {
			case .pass:
				message = "\(opponent) passed"
				image = ImageAsset.Movement.pass
			case .move(let unit, _), .yoink(_, let unit, _):
				if unit.owner == opponent {
					message = "\(opponent) moved their \(unit.class)"
					image = ImageAsset.Movement.move
				} else {
					message = "\(opponent) yoinked your \(unit.class)"
					image = ImageAsset.Movement.yoink
				}
			case .place(let unit, _):
				message = "\(opponent) placed their \(unit.class)"
				image = ImageAsset.Movement.place
			}

			loafSubject.send(LoafState(
				message,
				state: .custom(Loaf.Style(
					backgroundColor: UIColor(.background),
					textColor: UIColor(.text),
					icon: image)
				)) { [weak self] dismissalReason in
					guard let self = self,
						dismissalReason == .tapped,
						let position = previousUpdate.movement.targetPosition else { return }
					self.animateToPosition.send(position)
				}
			)
		}
	}
}

// MARK: - Position

extension HiveGameViewModel {
	/// Returns the position in the stack and the total number of pieces in the stack
	func positionInStack(of piece: Piece) -> (Int, Int) {
		let position = self.position(of: piece)
		if let stack = gameState.stacks[position] {
			let selectedPieceInStack: Bool
			let selectedPieceOnStack: Bool
			let selectedPieceFromStack: Bool
			if let selectedPiece = currentSelectedPiece {
				selectedPieceInStack = stack.contains(selectedPiece.piece)
				selectedPieceOnStack = !selectedPieceInStack && selectedPiece.position == position
				selectedPieceFromStack = selectedPieceInStack && selectedPiece.position != position
			} else {
				selectedPieceInStack = false
				selectedPieceOnStack = false
				selectedPieceFromStack = false
			}

			let additionalStackPieces = selectedPieceOnStack ? 1 : (selectedPieceFromStack ? -1 : 0)
			let stackCount = stack.count + additionalStackPieces

			if let indexInStack = stack.firstIndex(of: piece) {
				return (indexInStack + 1, stackCount)
			} else {
				return (stackCount, stackCount)
			}
		} else {
			return (1, 1)
		}
	}

	/// Returns the current position of the piece, accounting for the selected piece, and it's in game position
	func position(of piece: Piece) -> Position {
		if currentSelectedPiece?.piece == piece,
			let selectedPosition = currentSelectedPiece?.position {
			return selectedPosition
		} else if let gamePosition = gameState.position(of: piece) {
			return gamePosition
		} else {
			return .origin
		}
	}
}

// MARK: - State

extension HiveGameViewModel {
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
	}

	func transition(to nextState: State) {
		guard canTransition(from: flowStateSubject.value, to: nextState) else { return }
		flowStateSubject.send(nextState)
	}

	private func canTransition(from currentState: State, to nextState: State) -> Bool {
		switch (currentState, nextState) {

		// Forfeiting possible at any time
		case (_, .forfeit): return true
		case (.forfeit, _): return false

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

		// A played move either leads to a new turn, or the end of the game
		case (.sendingMovement, .opponentTurn), (.sendingMovement, .gameEnd): return true
		case (.opponentTurn, .playerTurn), (.opponentTurn, .gameEnd): return true
		case (.opponentTurn, _): return false

		case (.sendingMovement, _), (_, .sendingMovement): return false
		case (_, .playerTurn), (_, .opponentTurn): return false

		case (_, .gameEnd): return false
		}
	}
}

// MARK: HiveGameClientDelegate

extension HiveGameViewModel: HiveGameClientDelegate {
	func clientDidReceiveMessage(_ hiveGameClient: HiveGameClient, message: GameServerMessage) {
		switch message {
		case .gameState(let state):
			self.didReceive(newState: state)
		default:
			debugLog("Received message: \(message)")
		}
	}

	func clientDidConnect(_ hiveGameClient: HiveGameClient) {
		debugLog("Connected to server")
	}

	func clientDidDisconnect(_ hiveGameClient: HiveGameClient, code: WebSocketErrorCode?) {
		debugLog("Disconnected from server, \(String(describing: code))")
	}
}

// MARK: - Logging

extension HiveGameViewModel {
	func debugLog(_ message: String) {
		guard debugEnabledSubject.value else { return }
		print("HIVE_DEBUG: \(message)")
	}
}
