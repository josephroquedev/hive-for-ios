//
//  ProfileViewModel.swift
//  Hive-for-iOS
//
//  Created by Joseph Roque on 2020-05-15.
//  Copyright © 2020 Joseph Roque. All rights reserved.
//

import Combine

enum ProfileViewAction: BaseViewAction {
	case onAppear
	case openSettings
	case loadProfile
}

enum ProfileAction: BaseAction {
	case loadProfile
	case openSettings
}

class ProfileViewModel: ViewModel<ProfileViewAction>, ObservableObject {
	@Published var user: Loadable<User>
	@Published var searchText: String = ""

	private let actions = PassthroughSubject<ProfileAction, Never>()
	var actionsPublisher: AnyPublisher<ProfileAction, Never> {
		actions.eraseToAnyPublisher()
	}

	init(user: Loadable<User>) {
		_user = .init(initialValue: user)
	}

	override func postViewAction(_ viewAction: ProfileViewAction) {
		switch viewAction {
		case .onAppear:
			actions.send(.loadProfile)
		case .openSettings:
			actions.send(.openSettings)
		case .loadProfile:
			actions.send(.loadProfile)
		}
	}
}

// MARK: - Strings

extension ProfileViewModel {
	var title: String {
		user.value?.displayName ?? "Profile"
	}

	func errorMessage(from error: Error) -> String {
		guard let userError = error as? UserRepositoryError else {
			return error.localizedDescription
		}

		switch userError {
		case .missingID: return "Account missing"
		case .apiError(let apiError): return apiError.errorDescription ?? apiError.localizedDescription
		case .usingOfflineAccount: return "You're currently playing offline"
		}
	}
}
