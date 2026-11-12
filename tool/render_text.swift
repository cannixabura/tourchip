// 用 macOS CoreText 把一行字畫成透明背景的白字 PNG（gen_ads.py 畫泰文用：PIL 沒有 raqm 時泰文聲調符號位置會錯）
// 編譯：swiftc -O tool/render_text.swift -o tool/.build/render_text（gen_ads.py 會自動編譯）
// 用法：render_text <PostScript 字型名> <字級> <文字> <輸出.png>
// 輸出到 stdout：<字寬> <上方留白>，圖片高度 = 上方留白 + ascent + descent + 下方留白
import CoreText
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let a = CommandLine.arguments
guard a.count == 5, let size = Double(a[2]) else {
    FileHandle.standardError.write("usage: render_text font size text out.png\n".data(using: .utf8)!)
    exit(2)
}
let font = CTFontCreateWithName(a[1] as CFString, CGFloat(size), nil)
let attrs: [NSAttributedString.Key: Any] = [
    NSAttributedString.Key(kCTFontAttributeName as String): font,
    NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: 1, green: 1, blue: 1, alpha: 1),
]
let line = CTLineCreateWithAttributedString(NSAttributedString(string: a[3], attributes: attrs))
var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
let pad = ceil(CGFloat(size) * 0.35)
let w = Int(ceil(width + pad * 2)), h = Int(ceil(ascent + descent + pad * 2))
let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.setShouldAntialias(true)
ctx.textPosition = CGPoint(x: pad, y: pad + descent)
CTLineDraw(line, ctx)
let url = URL(fileURLWithPath: a[4]) as CFURL
let dest = CGImageDestinationCreateWithURL(url, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
CGImageDestinationFinalize(dest)
print(String(format: "%.2f %.0f", Double(width), Double(pad)))
