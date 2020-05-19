//
//  Settings.swift
//  Hive-for-iOS
//
//  Created by Joseph Roque on 2020-05-13.
//  Copyright © 2020 Joseph Roque. All rights reserved.
//

import Combine
import SwiftUI

struct Settings: View {
	@Environment(\.container) private var container: AppContainer

	@ObservedObject private var viewModel: SettingsViewModel

	@State private var preferences = Preferences()
	@State private var userProfile: Loadable<User>

	init(user: Loadable<User> = .notLoaded, logoutResult: Loadable<Bool> = .notLoaded) {
		self._userProfile = .init(initialValue: user)
		viewModel = SettingsViewModel(logoutResult: logoutResult)
	}

	var body: some View {
		NavigationView {
			ScrollView {
				VStack(spacing: .m) {
					sectionHeader(title: "Game")
					itemToggle(title: "Mode", selected: preferences.gameMode) {
						self.viewModel.postViewAction(.switchGameMode(current: $0))
					}

					sectionHeader(title: "Account")
					UserPreview(userProfile.value?.summary)

					logoutButton
				}
			}
			.background(Color(.background).edgesIgnoringSafeArea(.all))
			.navigationBarTitle("Settings")
			.navigationBarItems(leading: doneButton)
			.onReceive(viewModel.actionsPublisher) { self.handleAction($0) }
			.onReceive(preferencesUpdate) { self.preferences = $0 }
			.onReceive(userUpdate) { self.userProfile = $0 }
		}
		.navigationViewStyle(StackNavigationViewStyle())
	}

	// MARK: Content

	private func sectionHeader(title: String) -> some View {
		HStack {
			Text(title)
				.caption()
				.foregroundColor(Color(.text))
			Spacer()
		}
		.padding(.vertical, length: .s)
		.padding(.horizontal, length: .m)
		.background(Color(.backgroundLight))
	}

	private func itemToggle<I>(
		title: String,
		selected: I,
		onTap: @escaping (I) -> Void
	) -> some View where I: Identifiable, I: CustomStringConvertible {
		Button(action: {
			onTap(selected)
		}, label: {
			HStack {
				Text(title)
					.body()
					.foregroundColor(Color(.text))
				Spacer()
				Text(selected.description)
					.body()
					.foregroundColor(Color(.text))
			}
			.padding(.horizontal, length: .m)
		})
	}

	// MARK: Buttons

	private var logoutButton: some View {
		Button(action: {
			self.viewModel.postViewAction(.logout)
		}, label: {
			self.logoutButtonLabel
				.body()
				.foregroundColor(Color(.text))
				.frame(minWidth: 0, maxWidth: .infinity)
				.frame(height: 48)
				.background(
					RoundedRectangle(cornerRadius: .s)
						.fill(Color(.primary))
				)
				.padding(.horizontal, length: .m)
		})
	}

	private var logoutButtonLabel: AnyView {
		switch viewModel.logoutResult {
		case .notLoaded, .failed, .loaded: return AnyView(Text("Logout"))
		case .loading: return AnyView(ActivityIndicator(isAnimating: true, style: .white))
		}
	}

	private var doneButton: some View {
		Button(action: {
			self.viewModel.postViewAction(.exit)
		}, label: {
			Text("Done")
				.body()
				.foregroundColor(Color(.text))
		})
	}
}

// MARK: - Actions

extension Settings {
	private func handleAction(_ action: SettingsAction) {
		switch action {
		case .setGameMode(let mode):
			container.appState[\.preferences.gameMode] = mode

		case .exit:
			exit()
		case .logout:
			logout()
		}
	}

	private func exit() {
		container.appState[\.routing.mainRouting.settingsIsOpen] = false
	}

	private func logout() {
		guard let account = container.account else { return }
		container.interactors.accountInteractor.logout(
			fromAccount: account,
			result: $viewModel.logoutResult
		)
	}
}

// MARK: - Updates

extension Settings {
	private var preferencesUpdate: AnyPublisher<Preferences, Never> {
		container.appState.updates(for: \.preferences)
			.receive(on: DispatchQueue.main)
			.eraseToAnyPublisher()
	}

	private var userUpdate: AnyPublisher<Loadable<User>, Never> {
		container.appState.updates(for: \.userProfile)
			.receive(on: DispatchQueue.main)
			.eraseToAnyPublisher()
	}
}

#if DEBUG
struct Settings_Previews: PreviewProvider {
	static var previews: some View {
		Settings(
			user: .loaded(User.users[0]),
			logoutResult: .loading(cached: nil, cancelBag: CancelBag())
		)
	}
}
#endif
