import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

// how to measure: safety, electrode placement, skin, how to sit, how long to record
// electrode placement from the ECG 2 Click manual: left arm, right arm,
// left side of the abdomen (below the heart) / left leg
class InstructionsScreen extends StatelessWidget {
  const InstructionsScreen({super.key});

  // the colors of the leads on the cable of this kit (not the IEC or AHA standard colors!)
  static const Color rightArmColor = Color(0xFF43A047);   // green, marked R
  static const Color leftArmColor = Color(0xFFE53935);    // red, no letter
  static const Color leftLegColor = Color(0xFFFDD835);    // yellow, marked L

  // black text on a light color (yellow), white on a dark one
  static Color textOn(Color color) =>
      ThemeData.estimateBrightnessForColor(color) == Brightness.light ? Colors.black : Colors.white;

  @override
  Widget build(BuildContext context) {
    ColorScheme colors = Theme.of(context).colorScheme;
    AppLocalizations t = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(t.homeHowToMeasure)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // safety first, in the error colors so it is not skipped
            Card(
              color: colors.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${t.instrSafetyTitle}\n'
                  '• ${t.instrSafety1}\n'
                  '• ${t.instrSafety2}\n'
                  '• ${t.instrSafety3}',
                  style: TextStyle(color: colors.onErrorContainer),
                ),
              ),
            ),

            _section(context, t.instrElectrodesTitle),
            Text(t.instrElectrodesIntro),
            const SizedBox(height: 8),
            // the roles measured on 2026-11-25: red = the "-" input, yellow = the "+" input,
            // green = the reference (right leg drive), whatever the letters on the cable say
            // 3 tested sets (notatki/ulozenie_elektrod_2026-11-25.md): option 1 = lead I on the body
            // (the least noise, a clear T wave), option 2 = lead II, option 3 = lead I on the wrists
            Text(t.instrVariant1, style: const TextStyle(fontWeight: FontWeight.bold)),
            _ElectrodeRow('−', t.instrMinus, t.instrMinusWhere, leftArmColor, t.instrCableLeftArm),
            _ElectrodeRow('+', t.instrPlus, t.instrPlusWhere, leftLegColor, t.instrCableLeftLeg),
            _ElectrodeRow('REF', t.instrReference, t.instrReferenceWhere, rightArmColor, t.instrCableRightArm),
            const SizedBox(height: 12),
            Center(
              child: CustomPaint(
                size: const Size(220, 230),
                painter: _ElectrodeMapPainter(
                  bodyColor: colors.onSurfaceVariant,
                  textColor: colors.onSurface,
                ),
              ),
            ),
            Text(
              t.instrFrontView,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            _Bullet(t.instrVariant2),
            _Bullet(t.instrVariant3),
            const SizedBox(height: 8),
            Text(t.instrRule, style: const TextStyle(fontWeight: FontWeight.bold)),

            _section(context, t.instrSkinTitle),
            _Bullet(t.instrSkin1),
            _Bullet(t.instrSkin2),
            _Bullet(t.instrSkin3),

            _section(context, t.instrDuringTitle),
            _Bullet(t.instrDuring1),
            _Bullet(t.instrDuring2),
            _Bullet(t.instrDuring3),
            _Bullet(t.instrDuring4),

            _section(context, t.instrLengthTitle),
            _Bullet(t.instrLength1),
            _Bullet(t.instrLength2),
            _Bullet(t.instrLength3),
            _Bullet(t.instrLength4),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );
}

// "RA  Right arm" + where + the lead on the cable, one row per electrode
class _ElectrodeRow extends StatelessWidget {
  const _ElectrodeRow(this.label, this.name, this.where, this.color, this.cable);

  final String label;
  final String name;
  final String where;
  final Color color;    // the color of the lead on the cable
  final String cable;   // "green lead, marked R"

  @override
  Widget build(BuildContext context) {
    ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color,
            child: Text(label, style: TextStyle(fontSize: 11, color: InstructionsScreen.textOn(color))),
          ),
          const SizedBox(width: 12),
          // Expanded: the long text wraps instead of overflowing to the right
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$name: $where'),
                Text(cable, style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

// simple body seen from the front, with the 3 electrode positions
class _ElectrodeMapPainter extends CustomPainter {
  _ElectrodeMapPainter({required this.bodyColor, required this.textColor});

  final Color bodyColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    double w = size.width;
    double h = size.height;
    double cx = w / 2;   // middle of the body

    Paint outline = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // head
    canvas.drawCircle(Offset(cx, h * 0.10), h * 0.08, outline);
    // torso
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(cx - w * 0.22, h * 0.22, cx + w * 0.22, h * 0.68),
        const Radius.circular(18),
      ),
      outline,
    );
    // arms, from the shoulders down and out
    canvas.drawLine(Offset(cx - w * 0.22, h * 0.26), Offset(cx - w * 0.42, h * 0.62), outline);
    canvas.drawLine(Offset(cx + w * 0.22, h * 0.26), Offset(cx + w * 0.42, h * 0.62), outline);
    // legs
    canvas.drawLine(Offset(cx - w * 0.10, h * 0.68), Offset(cx - w * 0.14, h * 0.98), outline);
    canvas.drawLine(Offset(cx + w * 0.10, h * 0.68), Offset(cx + w * 0.14, h * 0.98), outline);

    // electrodes: the person's right is on the left of the picture
    // every dot in the color of its lead on the cable
    // the labels inside the body, so they never cross the lines of the arms or the torso:
    // RA / LA under their dot, LL (near the bottom edge) to the left of it
    // option 1, lead I on the body: "-" below the right collarbone, "+" below the left one,
    // the reference on the left side of the belly below the heart
    _electrode(canvas, Offset(cx - w * 0.15, h * 0.29), '−', InstructionsScreen.leftArmColor, labelBelow: true);
    _electrode(canvas, Offset(cx + w * 0.15, h * 0.29), '+', InstructionsScreen.leftLegColor, labelBelow: true);
    _electrode(canvas, Offset(cx + w * 0.13, h * 0.58), 'REF', InstructionsScreen.rightArmColor, labelBelow: false);
  }

  void _electrode(Canvas canvas, Offset at, String label, Color color, {required bool labelBelow}) {
    canvas.drawCircle(at, 7, Paint()..color = color);
    // a thin ring, so the yellow dot is visible on a light background too
    canvas.drawCircle(at, 7, Paint()
      ..color = bodyColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);
    TextPainter text = TextPainter(
      text: TextSpan(text: label, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    // under the dot (centered), or to the left of it
    Offset where = labelBelow
        ? Offset(at.dx - text.width / 2, at.dy + 10)
        : Offset(at.dx - 12 - text.width, at.dy - text.height / 2);
    text.paint(canvas, where);
  }

  @override
  bool shouldRepaint(covariant _ElectrodeMapPainter oldDelegate) =>
      oldDelegate.bodyColor != bodyColor ||
      oldDelegate.textColor != textColor;
}
