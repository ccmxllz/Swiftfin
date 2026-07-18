//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Foundation
import SwiftUI
import UIKit

// MARK: - DanmakuConfiguration

struct DanmakuConfiguration {

    let isEnabled: Bool
    let opacity: Double
    let fontSize: CGFloat
    let speed: Double
    let maxDisplayCount: Int
    let trackCount: Int

    static let `default` = DanmakuConfiguration(
        isEnabled: true,
        opacity: 0.92,
        fontSize: 17,
        speed: 1.0,
        maxDisplayCount: 20,
        trackCount: 4
    )
}

// MARK: - DanmakuFontConfiguration

struct DanmakuFontConfiguration {

    // MARK: - Font Names

    /// Prefer Medium — closer to Tencent's clean luminous weight than Semibold.
    private let preferredFontNames: [String] = [
        "PingFangSC-Medium",
        "PingFangSC-Regular",
        "HiraginoSansGB-W3",
        "PingFangSC-Semibold",
        "STHeitiSC-Medium",
        "HelveticaNeue-Medium",
    ]

    // MARK: - Shadow Configuration

    struct ShadowConfiguration {
        let opacity: Float
        let radius: CGFloat
        let offset: CGSize
        let color: CGColor

        static let standard = ShadowConfiguration(
            opacity: 0.45,
            radius: 1.5,
            offset: CGSize(width: 0, height: 1.0),
            color: UIColor.black.cgColor
        )

        static let enhanced = ShadowConfiguration(
            opacity: 0.55,
            radius: 2.0,
            offset: CGSize(width: 0, height: 1.2),
            color: UIColor.black.cgColor
        )
    }

    // MARK: - Methods

    func getBestAvailableFont(size: CGFloat) -> UIFont {
        for fontName in preferredFontNames {
            if let font = UIFont(name: fontName, size: size) {
                return font
            }
        }
        return UIFont.systemFont(ofSize: size, weight: .medium)
    }

    func getSwiftUIFont(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        if UIFont(name: "PingFangSC-Medium", size: size) != nil {
            return .custom("PingFangSC-Medium", size: size)
        } else if UIFont(name: "PingFangSC-Regular", size: size) != nil {
            return .custom("PingFangSC-Regular", size: size)
        }
        return .system(size: size, weight: weight, design: .default)
    }

    func getShadowConfiguration(enhanced: Bool = false) -> ShadowConfiguration {
        enhanced ? .enhanced : .standard
    }

    func calculateTextWidth(text: String, font: UIFont) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .kern: 0.2,
        ]

        let size = (text as NSString).size(withAttributes: attributes)
        let padding: CGFloat = 8.0
        return ceil(size.width) + padding
    }

    func adjustFontSize(baseSize: CGFloat, content: String) -> CGFloat {
        var multiplier: CGFloat = 1.0

        let contentLength = content.count
        if contentLength <= 3 {
            multiplier *= 1.02
        } else if contentLength > 20 {
            multiplier *= 0.98
        }

        let adjustedSize = baseSize * multiplier
        return max(15.0, min(24.0, adjustedSize))
    }
}
