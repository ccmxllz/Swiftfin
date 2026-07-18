//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import Foundation
import UIKit

/// Snapshot of danmaku visual settings so the render/draw path avoids reading Defaults.
struct DanmakuRenderSettings: Equatable {
    var opacity: CGFloat
    var speedMultiplier: CGFloat
    var fontSize: CGFloat
    var enhancedShadow: Bool
    var smoothMode: Bool
    var trackCount: Int
    var displayAreaRatio: CGFloat
    var displayAreaPosition: String

    static func current() -> DanmakuRenderSettings {
        DanmakuRenderSettings(
            opacity: CGFloat(Defaults[.VideoPlayer.Overlay.danmakuOpacity]),
            speedMultiplier: CGFloat(Defaults[.VideoPlayer.Overlay.danmakuSpeed]),
            fontSize: CGFloat(Defaults[.VideoPlayer.Overlay.danmakuFontSize]),
            enhancedShadow: Defaults[.VideoPlayer.Overlay.danmakuEnhancedShadow],
            smoothMode: Defaults[.VideoPlayer.Overlay.danmakuSmoothMode],
            trackCount: Defaults[.VideoPlayer.Overlay.danmakuTrackCount],
            displayAreaRatio: CGFloat(Defaults[.VideoPlayer.Overlay.danmakuDisplayArea]),
            displayAreaPosition: Defaults[.VideoPlayer.Overlay.danmakuAreaPosition]
        )
    }
}
