//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import Defaults
import SwiftUI

// MARK: - DanmakuActionButton

struct DanmakuActionButton: View {

    @Default(.VideoPlayer.Overlay.danmakuEnabled)
    private var isDanmakuEnabled

    @Environment(\.isPresentingDanmakuToolbox)
    @Binding
    private var isPresentingDanmakuToolbox

    @Environment(\.isPresentingOverlay)
    @Binding
    private var isPresentingOverlay

    @EnvironmentObject
    private var overlayTimer: TimerProxy

    var body: some View {
        Button {
            overlayTimer.stop()
            isPresentingOverlay = true
            withAnimation(.easeInOut(duration: 0.25)) {
                isPresentingDanmakuToolbox = true
            }
        } label: {
            Image(systemName: isDanmakuEnabled ? "bubble.left.fill" : "bubble.left")
                .font(.title2)
                .foregroundColor(.white)
        }
        .buttonStyle(.plain)
        .help("弹幕工具箱")
    }
}

// MARK: - Preview

#if DEBUG
struct DanmakuActionButton_Previews: PreviewProvider {
    static var previews: some View {
        DanmakuActionButton()
            .padding()
            .background(Color.black.opacity(0.5))
            .previewLayout(.sizeThatFits)
    }
}
#endif
