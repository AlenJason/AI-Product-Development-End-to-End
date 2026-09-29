// Vẽ icon SmartFit AI (giai đoạn 6, PLAN 6.8): nền xanh thương hiệu, chữ "S" trắng bo tròn và một chiếc lá.
// Chạy trên macOS: swift tool/make_icon.swift assets/icon
//   icon.png            1024×1024, nền đầy, không kênh trong suốt (iOS bắt buộc) — nguồn cho mọi icon vuông
//   icon_foreground.png 1024×1024, nền trong suốt — lớp trước của icon thích ứng Android 8+ và màn khởi động Android 12+
import AppKit

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
  CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
          blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

// Hình chính nằm trong ô vuông tâm, cạnh = size × scale.
func drawSymbol(_ ctx: CGContext, size: CGFloat, scale: CGFloat) {
  let box = size * scale
  let origin = (size - box) / 2
  let base = NSFont.systemFont(ofSize: box * 0.92, weight: .black)
  let font = NSFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: box * 0.92) ?? base
  let text = NSAttributedString(string: "S", attributes: [.font: font, .foregroundColor: NSColor.white])
  let line = CTLineCreateWithAttributedString(text)
  let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
  ctx.textPosition = CGPoint(x: origin + (box - bounds.width) / 2 - bounds.minX - box * 0.04,
                             y: origin + (box - bounds.height) / 2 - bounds.minY - box * 0.02)
  CTLineDraw(line, ctx)

  // Chiếc lá: hai cung tròn giao nhau, nghiêng 45°, góc trên bên phải chữ S.
  ctx.saveGState()
  ctx.translateBy(x: origin + box * 0.80, y: origin + box * 0.80)
  ctx.rotate(by: .pi / 4)
  let leaf = CGMutablePath()
  let w = box * 0.30, h = box * 0.15
  leaf.move(to: CGPoint(x: -w / 2, y: 0))
  leaf.addQuadCurve(to: CGPoint(x: w / 2, y: 0), control: CGPoint(x: 0, y: h))
  leaf.addQuadCurve(to: CGPoint(x: -w / 2, y: 0), control: CGPoint(x: 0, y: -h))
  ctx.addPath(leaf)
  ctx.setFillColor(color(0xA7F3D0))
  ctx.fillPath()
  ctx.restoreGState()
}

func render(_ name: String, opaque: Bool, scale: CGFloat) {
  let size: CGFloat = 1024
  let space = CGColorSpace(name: CGColorSpace.sRGB)!
  let info = opaque ? CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue
  let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                      space: space, bitmapInfo: info)!
  if opaque {
    let gradient = CGGradient(colorsSpace: space, colors: [color(0x10B981), color(0x047857)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
  }
  drawSymbol(ctx, size: size, scale: scale)
  let image = ctx.makeImage()!
  let rep = NSBitmapImageRep(cgImage: image)
  try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
}

render("icon.png", opaque: true, scale: 0.62)
// Vùng an toàn của icon thích ứng: 72/108 dp ở giữa — hình nằm gọn trong đó.
render("icon_foreground.png", opaque: false, scale: 0.50)
