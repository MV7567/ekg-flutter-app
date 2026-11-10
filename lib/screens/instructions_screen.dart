import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

// how to measure: safety, electrode placement, skin, how to sit, how long to record
// electrode placement from the ECG 2 Click manual: left arm, right arm,
// left side of the abdomen (below the heart) / left leg
class InstructionsScreen extends StatelessWidget {
  const InstructionsScreen({super.key});

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
            _ElectrodeRow('RA', t.instrRightArm, t.instrRightArmWhere),
            _ElectrodeRow('LA', t.instrLeftArm, t.instrLeftArmWhere),
            _ElectrodeRow('LL', t.instrLeftLeg, t.instrLeftLegWhere),
            const SizedBox(height: 12),
            Center(
              child: CustomPaint(
                size: const Size(220, 230),
                painter: _ElectrodeMapPainter(
                  bodyColor: colors.onSurfaceVariant,
                  dotColor: colors.primary,
                  textColor: colors.onSurface,
                ),
              ),
            ),
            Text(
              t.instrFrontView,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
            ),

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

// "RA  Right arm" + where, one line per electrode
class _ElectrodeRow extends StatelessWidget {
  const _ElectrodeRow(this.label, this.name, this.where);

  final String label;
  final String name;
  final String where;

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
            backgroundColor: colors.primary,
            child: Text(label, style: TextStyle(fontSize: 11, color: colors.onPrimary)),
          ),
          const SizedBox(width: 12),
          // Expanded: the long text wraps instead of overflowing to the right
          Expanded(child: Text('$name: $where')),
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
  _ElectrodeMapPainter({required this.bodyColor, required this.dotColor, required this.textColor});

  final Color bodyColor;
  final Color dotColor;
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
    _electrode(canvas, Offset(cx - w * 0.15, h * 0.29), 'RA', labelLeft: true);
    _electrode(canvas, Offset(cx + w * 0.15, h * 0.29), 'LA', labelLeft: false);
    _electrode(canvas, Offset(cx + w * 0.13, h * 0.58), 'LL', labelLeft: false);
  }

  void _electrode(Canvas canvas, Offset at, String label, {required bool labelLeft}) {
    canvas.drawCircle(at, 7, Paint()..color = dotColor);
    TextPainter text = TextPainter(
      text: TextSpan(text: label, style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    // the label next to the dot, outside the body when possible
    double x = labelLeft ? at.dx - 12 - text.width : at.dx + 12;
    text.paint(canvas, Offset(x, at.dy - text.height / 2));
  }

  @override
  bool shouldRepaint(covariant _ElectrodeMapPainter oldDelegate) =>
      oldDelegate.bodyColor != bodyColor ||
      oldDelegate.dotColor != dotColor ||
      oldDelegate.textColor != textColor;
}
