# FishGo

`wow` 分支新增原生 macOS 后台自动化客户端，实现在 `macos/`。原 Scala/Jython 项目保留在原路径。

## macOS 版

- 游戏窗口实时捕获，不截取整个桌面。
- 定向键盘与鼠标输入，不激活游戏或移动系统光标。
- JSON 控制序列、循环、等待、运行与取消。
- 浮漂定位、咬钩识别、可视化区域选择和阈值调整。

```sh
cd macos
./build.sh
./Start.command
```

需要 macOS 14+ 和 Apple Command Line Tools。首次运行按提示授予屏幕录制和辅助功能权限。默认演练模式不发送输入。

[使用说明](macos/README.md) · [验证记录](macos/VALIDATION.md)
