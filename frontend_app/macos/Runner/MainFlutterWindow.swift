import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    // Cỡ mở đầu 600×760 (khổ đứng, vừa MacBook 13") nằm ở MainMenu.xib; không cho nhỏ hơn điện thoại nhỏ.
    // Các lần mở sau, macOS tự khôi phục cỡ và vị trí người dùng đã chỉnh (đè lên giá trị ở đây).
    self.contentMinSize = NSSize(width: 360, height: 560)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
