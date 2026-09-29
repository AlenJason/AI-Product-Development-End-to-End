// Gói các ảnh PNG vuông (≤ 256 px) thành một file .ico cho bản Windows. Mỗi mục giữ nguyên dạng PNG —
// Windows Vista trở lên và trình biên dịch tài nguyên của Visual Studio đều đọc được.
//   swift tool/make_ico.swift <out.ico> <16.png> <32.png> ...
import Foundation

let args = Array(CommandLine.arguments.dropFirst())
guard args.count > 1 else { fatalError("Cách dùng: swift tool/make_ico.swift <out.ico> <png>...") }
let images = try args.dropFirst().map { try Data(contentsOf: URL(fileURLWithPath: $0)) }

func le16(_ value: Int) -> [UInt8] { [UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF)] }
func le32(_ value: Int) -> [UInt8] { le16(value & 0xFFFF) + le16(value >> 16) }
// Chiều rộng nằm ở byte 16–19 của PNG (khối IHDR, big-endian).
func width(_ png: Data) -> Int { png[16..<20].reduce(0) { $0 << 8 | Int($1) } }

var header = le16(0) + le16(1) + le16(images.count)  // dự trữ, loại 1 = icon, số ảnh
var offset = 6 + 16 * images.count
for png in images {
  let side = width(png)
  precondition(side <= 256, "Ảnh \(side) px lớn hơn 256 px")
  // Rộng, cao (256 ghi là 0), số màu, dự trữ, số mặt phẳng, số bit mỗi điểm ảnh, độ dài, vị trí
  header += [UInt8(side % 256), UInt8(side % 256), 0, 0] + le16(1) + le16(32) + le32(png.count) + le32(offset)
  offset += png.count
}
try images.reduce(Data(header), +).write(to: URL(fileURLWithPath: args[0]))
