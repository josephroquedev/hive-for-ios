//
//  Metrics.swift
//  Hive-for-iOS
//
//  Created by Joseph Roque on 2020-01-13.
//  Copyright © 2020 Joseph Roque. All rights reserved.
//

import SwiftUI

enum Metrics { }

// MARK: - Spacing

extension Metrics {
	enum Spacing {
		case xxl
		case xl
		case l
		case m
		case s
		case xs
		case custom(CGFloat)

		var rawValue: CGFloat {
			switch self {
			case .xxl: return 40
			case .xl:  return 32
			case .l:   return 24
			case .m:   return 16
			case .s:   return 8
			case .xs:  return 4
			case .custom(let value): return value
			}
		}

		static func + (lhs: Metrics.Spacing, rhs: Metrics.Spacing) -> Metrics.Spacing {
			.custom(lhs.rawValue + rhs.rawValue)
		}

		static func + (lhs: Metrics.Spacing, rhs: Metrics.Image) -> CGFloat {
			lhs.rawValue + rhs.rawValue
		}
	}
}

extension View {
	func frame(width: Metrics.Spacing, height: Metrics.Spacing) -> some View {
		return frame(width: width.rawValue, height: height.rawValue)
	}

	func padding(_ length: Metrics.Spacing) -> some View {
		return padding(length.rawValue)
	}

	func padding(_ edges: Edge.Set = .all, length: Metrics.Spacing) -> some View {
		return padding(edges, length.rawValue)
	}
}

// MARK: - Image

extension Metrics {
	enum Image {
		case xxl
		case xl
		case l
		case m
		case s
		case custom(CGFloat)

		var rawValue: CGFloat {
			switch self {
			case .xxl: return 128
			case .xl:  return 64
			case .l:   return 48
			case .m:   return 32
			case .s:   return 16
			case .custom(let value): return value
			}
		}

		static func + (lhs: Metrics.Image, rhs: Metrics.Image) -> Metrics.Image {
			.custom(lhs.rawValue + rhs.rawValue)
		}

		static func + (lhs: Metrics.Image, rhs: Metrics.Spacing) -> CGFloat {
			lhs.rawValue + rhs.rawValue
		}
	}
}

extension View {
	func squareImage(_ size: Metrics.Image) -> some View {
		return frame(width: size.rawValue, height: size.rawValue)
	}

	func imageFrame(width: Metrics.Image, height: Metrics.Image) -> some View {
		return frame(width: width.rawValue, height: height.rawValue)
	}
}

// MARK: - Text

extension Metrics {
	enum Text {
		case title
		case subtitle
		case body
		case caption
		case custom(CGFloat)

		var rawValue: CGFloat {
			switch self {
			case .title:    return 32
			case .subtitle: return 24
			case .body:     return 16
			case .caption:  return 12
			case .custom(let value): return value
			}
		}
	}
}

extension View {
	func title() -> some View {
		return self.font(.system(size: Metrics.Text.title.rawValue))
	}

	func subtitle() -> some View {
		return self.font(.system(size: Metrics.Text.subtitle.rawValue))
	}

	func body() -> some View {
		return self.font(.system(size: Metrics.Text.body.rawValue))
	}

	func caption() -> some View {
		return self.font(.system(size: Metrics.Text.caption.rawValue))
	}
}
