//
//  PieceStack.swift
//  Hive-for-iOS
//
//  Created by Joseph Roque on 2020-03-27.
//  Copyright © 2020 Joseph Roque. All rights reserved.
//

import SwiftUI

struct PieceStack: View {
	@Environment(\.container) private var container
	@EnvironmentObject var viewModel: GameViewModel
	let stack: [Piece]

	func row(piece: Piece) -> some View {
		Button {
			viewModel.postViewAction(.closeInformation(withFeedback: false))
			viewModel.postViewAction(.tappedPiece(piece))
		} label: {
			HStack(spacing: .m) {
				Image(uiImage: piece.image(forScheme: container.preferences.pieceColorScheme))
					.resizable()
					.scaledToFit()
					.squareImage(.m)
				Text("\(piece.owner.description) \(piece.class.description) #\(piece.index)")
					.font(.body)
					.foregroundColor(Color(piece.owner.color))
					.frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
				if piece == stack.first || piece == stack.last {
					Spacer()
					Text(piece == stack.first ? "BOTTOM" : "TOP")
						.font(.caption)
				}
			}
		}
		.frame(minWidth: 0, maxWidth: .infinity)
	}

	var body: some View {
		VStack {
			ForEach(stack.reversed(), id: \.description, content: row)
		}
	}
}

// MARK: - Preview

#if DEBUG
struct PieceStackPreview: PreviewProvider {
	static var previews: some View {
		PieceStack(stack: [
			Piece(class: .ant, owner: .white, index: 1),
			Piece(class: .beetle, owner: .black, index: 1),
			Piece(class: .beetle, owner: .white, index: 1),
		])
	}
}
#endif
