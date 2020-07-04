//
//  BasicButton.swift
//  Hive-for-iOS
//
//  Created by Joseph Roque on 2020-06-28.
//  Copyright © 2020 Joseph Roque. All rights reserved.
//

import SwiftUI

struct BasicButton<Label>: View where Label: View {
	private let label: Label?
	private let title: String?
	private let action: () -> Void

	init(_ title: String, action: @escaping () -> Void) {
		self.title = title
		self.action = action
		self.label = nil
	}

	init(action: @escaping () -> Void, @ViewBuilder label: () -> Label) {
		self.title = nil
		self.action = action
		self.label = label()
	}

	var body: some View {
		Button(action: action, label: {
			if label != nil {
				label
			} else {
				Text(title ?? "")
					.body()
					.foregroundColor(Color(.text))
					.padding(.vertical, length: .m)
					.frame(minWidth: 0, maxWidth: .infinity)
					.frame(height: 48)
					.background(
						RoundedRectangle(cornerRadius: .s)
							.fill(Color(.primary))
					)
			}
		})
	}
}