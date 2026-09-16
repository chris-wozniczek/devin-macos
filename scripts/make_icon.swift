// Renders a 1024x1024 app icon PNG. Usage: swift make_icon.swift <battleship|boards> <output.png>
import AppKit
import CoreGraphics

let args = CommandLine.arguments
guard args.count == 3 else { fputs("usage: make_icon.swift <battleship|boards> <out.png>\n", stderr); exit(1) }
let style = args[1]
let outURL = URL(fileURLWithPath: args[2])
let size = 1024.0

let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
    guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
    let colors: [CGColor]
    if style == "battleship" {
        colors = [CGColor(red: 0.10, green: 0.27, blue: 0.40, alpha: 1), CGColor(red: 0.04, green: 0.09, blue: 0.15, alpha: 1)]
    } else {
        colors = [CGColor(red: 0.42, green: 0.36, blue: 0.95, alpha: 1), CGColor(red: 0.20, green: 0.16, blue: 0.55, alpha: 1)]
    }
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])

    if style == "battleship" {
        // grid
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.08))
        ctx.setLineWidth(3)
        for i in 1..<10 {
            let p = size / 10 * Double(i)
            ctx.move(to: CGPoint(x: p, y: 0)); ctx.addLine(to: CGPoint(x: p, y: size))
            ctx.move(to: CGPoint(x: 0, y: p)); ctx.addLine(to: CGPoint(x: size, y: p))
        }
        ctx.strokePath()
        // ship hull
        let hull = CGColor(red: 0.55, green: 0.58, blue: 0.60, alpha: 1)
        ctx.setFillColor(hull)
        let hullPath = CGMutablePath()
        hullPath.move(to: CGPoint(x: 140, y: 420))
        hullPath.addLine(to: CGPoint(x: 884, y: 420))
        hullPath.addLine(to: CGPoint(x: 800, y: 300))
        hullPath.addLine(to: CGPoint(x: 240, y: 300))
        hullPath.closeSubpath()
        ctx.addPath(hullPath); ctx.fillPath()
        ctx.fill(CGRect(x: 380, y: 420, width: 280, height: 110))
        ctx.fill(CGRect(x: 440, y: 530, width: 150, height: 90))
        ctx.fill(CGRect(x: 495, y: 620, width: 40, height: 130))
        // guns
        ctx.setLineWidth(22); ctx.setStrokeColor(hull); ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: 330, y: 470)); ctx.addLine(to: CGPoint(x: 200, y: 500))
        ctx.move(to: CGPoint(x: 700, y: 470)); ctx.addLine(to: CGPoint(x: 830, y: 500))
        ctx.strokePath()
        // hit marker
        ctx.setStrokeColor(CGColor(red: 0.87, green: 0.28, blue: 0.20, alpha: 1))
        ctx.setLineWidth(34)
        ctx.move(to: CGPoint(x: 700, y: 640)); ctx.addLine(to: CGPoint(x: 840, y: 780))
        ctx.move(to: CGPoint(x: 840, y: 640)); ctx.addLine(to: CGPoint(x: 700, y: 780))
        ctx.strokePath()
        // waves
        ctx.setStrokeColor(CGColor(red: 0.62, green: 0.78, blue: 0.88, alpha: 0.7))
        ctx.setLineWidth(16)
        for row in 0..<3 {
            let y = 250.0 - Double(row) * 60
            ctx.move(to: CGPoint(x: 80, y: y))
            var x = 80.0
            while x < 944 { ctx.addCurve(to: CGPoint(x: x + 80, y: y), control1: CGPoint(x: x + 20, y: y + 30), control2: CGPoint(x: x + 60, y: y - 30)); x += 80 }
        }
        ctx.strokePath()
    } else {
        // three kanban columns with cards
        let colX = [112.0, 392.0, 672.0]
        let cardHeights: [[Double]] = [[150, 110, 200], [220, 140], [120, 180, 90]]
        for (i, x) in colX.enumerated() {
            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.14))
            let col = CGPath(roundedRect: CGRect(x: x, y: 120, width: 240, height: 784), cornerWidth: 36, cornerHeight: 36, transform: nil)
            ctx.addPath(col); ctx.fillPath()
            var y = 830.0
            for h in cardHeights[i] {
                y -= h + 24
                ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.92))
                let card = CGPath(roundedRect: CGRect(x: x + 24, y: y, width: 192, height: h), cornerWidth: 24, cornerHeight: 24, transform: nil)
                ctx.addPath(card); ctx.fillPath()
                ctx.setFillColor(colors[0].copy(alpha: 0.5)!)
                ctx.fill(CGRect(x: x + 48, y: y + h - 44, width: 100, height: 16))
                ctx.setFillColor(CGColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 0.35))
                ctx.fill(CGRect(x: x + 48, y: y + h - 80, width: 140, height: 12))
            }
        }
    }
    return true
}

guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
try! png.write(to: outURL)
