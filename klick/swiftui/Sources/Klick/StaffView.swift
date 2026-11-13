// SPDX-License-Identifier: GPL-2.0-or-later
// Licence of the program this interface drives (klick).

import SwiftUI
import KlickKit
import AppearanceKit

/// One bar on a single-line percussion staff: the signs come from `StaffLayout`, this view only draws them. The beat that is
/// heard now (`lit`) takes the colour of the accent.
struct StaffView: View {
    @Environment(\.appAccentColor) private var accent
    let layout: StaffLayout
    var lit: Int?
    var scale: CGFloat = 1.3

    var body: some View {
        Canvas { context, _ in
            context.scaleBy(x: scale, y: scale)
            draw(&context)
        }
        .frame(width: layout.width * scale, height: StaffLayout.height * scale)
        .accessibilityElement()
        .accessibilityLabel("Notation de la mesure")
    }

    private func draw(_ context: inout GraphicsContext) {
        let y = StaffLayout.lineY
        let ink = GraphicsContext.Shading.foreground
        let hot = GraphicsContext.Shading.color(accent)

        // the line, and the barlines at both ends
        var line = Path(); line.move(to: CGPoint(x: 8, y: y)); line.addLine(to: CGPoint(x: layout.width - 6, y: y))
        context.stroke(line, with: ink, lineWidth: 1.2)
        for (x, w) in [(8.0, 1.6), (layout.width - 6, 1.6)] {
            var bar = Path(); bar.move(to: CGPoint(x: x, y: y - 14)); bar.addLine(to: CGPoint(x: x, y: y + 14))
            context.stroke(bar, with: ink, lineWidth: w)
        }

        if layout.showsSignature {
            let font = Font.system(size: 19, weight: .bold, design: .serif)
            context.draw(Text(verbatim: "\(layout.beats)").font(font), at: CGPoint(x: 20, y: y - 2), anchor: .bottom)
            context.draw(Text(verbatim: "\(layout.denominator)").font(font), at: CGPoint(x: 20, y: y + 20), anchor: .bottom)
        }

        for i in 0..<layout.beats {
            let x = layout.noteX[i]
            let shading = lit == i ? hot : ink
            if layout.rests.contains(i) {
                var rest = Path()
                rest.move(to: CGPoint(x: x - 3, y: y - 11))
                rest.addLine(to: CGPoint(x: x + 2, y: y - 5))
                rest.addLine(to: CGPoint(x: x - 3, y: y))
                rest.addLine(to: CGPoint(x: x + 3, y: y + 6))
                rest.addQuadCurve(to: CGPoint(x: x - 1, y: y + 12), control: CGPoint(x: x - 4, y: y + 5))
                context.stroke(rest, with: shading, style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                continue
            }
            // head, slightly tilted
            let head = Path(ellipseIn: CGRect(x: -5.4, y: -3.9, width: 10.8, height: 7.8))
                .applying(CGAffineTransform(rotationAngle: -22 * .pi / 180))
                .applying(CGAffineTransform(translationX: x, y: y))
            if layout.hasOpenHeads { context.stroke(head, with: shading, lineWidth: 1.5) } else { context.fill(head, with: shading) }
            var stem = Path()
            stem.move(to: CGPoint(x: StaffLayout.stemX(x), y: y)); stem.addLine(to: CGPoint(x: StaffLayout.stemX(x), y: y - StaffLayout.stemHeight))
            context.stroke(stem, with: shading, lineWidth: 1.5)
            if layout.accented.contains(i) {
                var accent = Path()
                accent.move(to: CGPoint(x: x - 5, y: y - 38)); accent.addLine(to: CGPoint(x: x + 5, y: y - 34.5)); accent.addLine(to: CGPoint(x: x - 5, y: y - 31))
                context.stroke(accent, with: shading, style: StrokeStyle(lineWidth: 1.7, lineCap: .round, lineJoin: .round))
            }
        }

        for beam in layout.beams {
            var path = Path()
            let by = y - StaffLayout.stemHeight + Double(beam.level) * 7
            path.move(to: CGPoint(x: beam.x1, y: by)); path.addLine(to: CGPoint(x: beam.x2, y: by))
            context.stroke(path, with: ink, lineWidth: StaffLayout.beamWidth)
        }
        for flag in layout.flags {
            var path = Path()
            let fy = y - StaffLayout.stemHeight + Double(flag.level) * 7
            path.move(to: CGPoint(x: flag.x, y: fy))
            path.addQuadCurve(to: CGPoint(x: flag.x + 6, y: fy + 15), control: CGPoint(x: flag.x + 9, y: fy + 6))
            context.stroke(path, with: ink, style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
        }
    }
}
