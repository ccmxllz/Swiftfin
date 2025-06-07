//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Combine
import Defaults
import SwiftUI

#if canImport(UIKit)
import UIKit

// MARK: - DanmakuView

struct DanmakuView: UIViewRepresentable {

    // MARK: - Properties

    @ObservedObject
    var viewModel: DanmakuViewModel
    let currentTime: Double

    // MARK: - Coordinator

    class Coordinator: NSObject {
        var parent: DanmakuView
        var renderer: DanmakuRenderer?
        var lastUpdateTime: Double = 0
        var cancellable: AnyCancellable?

        init(parent: DanmakuView) {
            self.parent = parent
            super.init()

            // 订阅弹幕数据变化
            cancellable = parent.viewModel.$currentDanmakus
                .throttle(for: .milliseconds(100), scheduler: DispatchQueue.global(), latest: true)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] danmakus in
                    self?.processDanmakus(danmakus)
                }
        }

        deinit {
            cancellable?.cancel()
        }

        func processDanmakus(_ danmakus: [DanmakuItem]) {
            guard parent.viewModel.isEnabled, !danmakus.isEmpty else { return }
            renderer?.addDanmakuItems(danmakus)
        }

        func updateSettings() {
            renderer?.setOpacity(CGFloat(parent.viewModel.opacity))
            renderer?.setSpeedMultiplier(CGFloat(parent.viewModel.speed))
            renderer?.setEnabled(parent.viewModel.isEnabled)
        }

        func updateTime(_ currentTime: Double) {
            if abs(currentTime - lastUpdateTime) > 0.2 {
                lastUpdateTime = currentTime
                Task {
                    await parent.viewModel.send(.updateCurrentTime(currentTime))
                }
            }
        }
    }

    // MARK: - UIViewRepresentable

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false

        let renderer = DanmakuRenderer(containerView: view)
        context.coordinator.renderer = renderer

        // 初始化设置
        renderer.setOpacity(CGFloat(viewModel.opacity))
        renderer.setSpeedMultiplier(CGFloat(viewModel.speed))
        renderer.setEnabled(viewModel.isEnabled)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if uiView.bounds.size != .zero {
            context.coordinator.renderer?.setContainerSize(uiView.bounds.size)
        }

        context.coordinator.updateSettings()
        context.coordinator.updateTime(currentTime)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.renderer?.stopAnimation()
        coordinator.renderer?.clearAllDanmaku()
        coordinator.cancellable?.cancel()
    }
}

#else
// 非 UIKit 平台的占位实现
struct DanmakuView: View {
    @ObservedObject
    var viewModel: DanmakuViewModel
    let currentTime: Double

    var body: some View {
        Text("弹幕功能仅支持iOS平台")
            .foregroundColor(.white)
            .font(.caption)
            .opacity(0.7)
    }
}
#endif
