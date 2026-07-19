//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2026 Jellyfin & Jellyfin Contributors
//

import SwiftUI
import UIKit

extension VideoPlayer {

    struct Overlay: View {

        @Environment(\.isPresentingOverlay)
        @Binding
        private var isPresentingOverlay

        @Environment(\.isPresentingDanmakuToolbox)
        @Binding
        private var isPresentingDanmakuToolbox

        @Environment(\.safeAreaInsets)
        private var safeAreaInsets

        @State
        private var currentOverlayType: VideoPlayer.OverlayType = .main

        var body: some View {
            ZStack {

                MainOverlay()
                    .visible(currentOverlayType == .main)

                ChapterOverlay()
                    .visible(currentOverlayType == .chapters)

                if isPresentingDanmakuToolbox {
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isPresentingDanmakuToolbox = false
                            }
                        }

                    HStack(spacing: 0) {
                        Spacer(minLength: 0)

                        Overlay.DanmakuToolboxPanel()
                            .frame(width: min(340, UIScreen.main.bounds.width * 0.42))
                            .padding(.trailing, max(12, safeAreaInsets.trailing))
                            .padding(.vertical, 12)
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(200)
                }
            }
            .animation(.linear(duration: 0.1), value: currentOverlayType)
            .animation(.easeInOut(duration: 0.25), value: isPresentingDanmakuToolbox)
            .environment(\.currentOverlayType, $currentOverlayType)
            .onChange(of: isPresentingOverlay) { newValue in
                guard newValue else { return }
                currentOverlayType = .main
            }
        }
    }
}
