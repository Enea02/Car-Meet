import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Bottone "Continua con Google" in stile design Raduni.
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: loading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.inkMuted,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _GoogleLogo(),
                  const SizedBox(width: 10),
                  const Text(
                    'Continua con Google',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.ink,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Logo Google "G" colorato.
class _GoogleLogo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Background circle (white)
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = Colors.white,
    );

    // Clip to circle
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)));

    final blue = const Color(0xFF4285F4);
    final red = const Color(0xFFEA4335);
    final yellow = const Color(0xFFFBBC05);
    final green = const Color(0xFF34A853);

    // Draw the G using arcs
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.78);

    // Blue (top-right arc)
    canvas.drawArc(rect, -0.3, 1.9, false,
        Paint()..color = blue..style = PaintingStyle.stroke..strokeWidth = r * 0.44..strokeCap = StrokeCap.butt);

    // Red (top-left arc)
    canvas.drawArc(rect, -2.2, -0.9, false,
        Paint()..color = red..style = PaintingStyle.stroke..strokeWidth = r * 0.44..strokeCap = StrokeCap.butt);

    // Yellow (bottom-left arc)
    canvas.drawArc(rect, 2.1, 0.8, false,
        Paint()..color = yellow..style = PaintingStyle.stroke..strokeWidth = r * 0.44..strokeCap = StrokeCap.butt);

    // Green (bottom arc)
    canvas.drawArc(rect, 1.6, 0.55, false,
        Paint()..color = green..style = PaintingStyle.stroke..strokeWidth = r * 0.44..strokeCap = StrokeCap.butt);

    // Horizontal bar of the G
    final barPaint = Paint()..color = blue..strokeWidth = r * 0.4..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, cy), Offset(cx + r * 0.7, cy), barPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
