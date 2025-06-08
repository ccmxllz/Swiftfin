# 弹幕调试指南

## 🔍 现在可以进行的调试步骤

我已经在弹幕系统中添加了详细的调试日志，现在你可以通过以下步骤来排查弹幕不显示的问题：

### 1. 重新编译并运行项目

```bash
cd /Users/jiayun/soft/gitee-projects/Swiftfin
# 清理缓存
rm -rf ~/Library/Developer/Xcode/DerivedData/Swiftfin-*
# 重新编译
xcodebuild -project Swiftfin.xcodeproj -scheme Swiftfin -destination 'platform=iOS Simulator,name=iPhone 16' build
```

### 2. 启用弹幕并查看控制台日志

1. **在 Xcode 中运行项目**
2. **打开 Xcode 控制台**（View → Debug Area → Activate Console）
3. **播放任意视频**
4. **启用弹幕按钮**（确保按钮变为紫色）
5. **观察控制台输出**

### 3. 预期的调试日志输出

如果弹幕系统正常工作，你应该看到以下日志：

#### 启用弹幕时：
```
💬 弹幕启用状态变更: true
```

#### 设置媒体时：
```
🎬 设置弹幕媒体: [视频标题]
📺 系列参数: SeriesDanmakuParams(season: 1, episode: 2, mediaType: 2)
🎯 媒体关键词: '[视频标题]'
📋 系列参数: SeriesDanmakuParams(season: 1, episode: 2, mediaType: 2)
✅ 弹幕系统准备就绪
```

#### 播放时间更新：
```
⏰ 更新播放时间: 10.5秒
⏰ 更新播放时间: 11.0秒
...
```

#### 弹幕加载：
```
🔄 开始加载弹幕段: 0-30秒
🎯 关键词: '[视频标题]', 平台: tencent
✅ 成功加载弹幕段 0-30: 15条弹幕
```

### 4. 常见问题诊断

#### 问题1: 没有看到任何弹幕相关日志
**可能原因**: 弹幕覆盖层没有正确集成
**解决方案**: 检查 VideoPlayer.swift 中是否包含 DanmakuOverlay

#### 问题2: 看到"弹幕启用状态变更: false"
**可能原因**: 弹幕按钮没有正确启用
**解决方案**: 确保点击弹幕按钮后它变为紫色

#### 问题3: 看到"媒体关键词为空"
**可能原因**: 视频标题提取失败
**解决方案**: 检查视频的 displayTitle 或 name 属性

#### 问题4: 看到"弹幕加载失败"
**可能原因**: 网络连接或服务器配置问题
**解决方案**: 检查弹幕服务器地址和网络连接

### 5. 网络请求调试

如果弹幕加载失败，可以检查网络请求：

1. **在浏览器中测试服务器地址**：
   ```
   http://your-server:port/danmu/api/danmu/tencent/segment.json?keyword=测试&start=0&end=30
   ```

2. **检查服务器响应**：
   - 状态码应该是 200
   - 响应应该是有效的 JSON 格式

### 6. 弹幕服务器配置检查

确认以下配置正确：

1. **进入设置** → **视频播放器设置** → **弹幕设置** → **服务器配置**
2. **检查服务器地址格式**：
   ```
   正确: http://192.168.50.112:8080/danmu/api/danmu
   错误: http://192.168.50.112:8080/danmu/api/danmu/
   ```
3. **选择正确的弹幕源**

### 7. 手动测试弹幕API

你可以手动测试弹幕API是否正常工作：

```bash
# 测试弹幕API
curl "http://192.168.50.112:8080/danmu/api/danmu/tencent/segment.json?keyword=测试&start=0&end=30"
```

预期响应格式：
```json
{
  "chatId": 123,
  "chatServer": "server",
  "source": "tencent",
  "items": [
    {
      "id": 1,
      "content": "弹幕内容",
      "progress": 5000,
      "mode": 1,
      "fontsize": 16,
      "opacity": 0.8,
      "color": 16777215
    }
  ]
}
```

### 8. 故障排除清单

请按顺序检查以下项目：

- [ ] 项目编译成功，无错误
- [ ] 弹幕按钮在菜单中可见
- [ ] 点击弹幕按钮后变为紫色
- [ ] 控制台显示"弹幕启用状态变更: true"
- [ ] 控制台显示媒体设置相关日志
- [ ] 控制台显示时间更新日志
- [ ] 控制台显示弹幕加载日志
- [ ] 弹幕服务器地址配置正确
- [ ] 网络连接正常，可以访问服务器

### 9. 下一步

完成上述调试后，请告诉我：

1. **控制台中看到了哪些日志？**
2. **是否有任何错误信息？**
3. **弹幕按钮的状态如何？**（白色/紫色）
4. **弹幕服务器地址是什么？**

这些信息将帮助我进一步诊断问题所在。
