import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({
    super.key,
    required this.isLight,
    required this.onToggleTheme,
  });

  final bool isLight;
  final VoidCallback onToggleTheme;

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _scale = Tween<double>(begin: 0.985, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: const _LandingCard(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LandingCard extends StatelessWidget {
  const _LandingCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 0.75),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A111827),
            blurRadius: 28,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _BrandMark(),
            const SizedBox(height: 32),
            const Text(
              'BitFlow',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 42,
                fontWeight: FontWeight.w700,
                height: 1.05,
                letterSpacing: -1.2,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Informes de campo en tiempo real, sin fricción.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _LandingButton(
                    label: 'Abrir demo',
                    isPrimary: true,
                    onPressed: () => context.go('/demo'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _LandingButton(
                    label: 'Nuevo registro',
                    onPressed: () => context.go('/app'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x263B82F6),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: const SizedBox(
            width: 48,
            height: 48,
            child: Icon(
              Icons.table_chart_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 14),
        const Text(
          'BitFlow',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _LandingButton extends StatefulWidget {
  const _LandingButton({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  @override
  State<_LandingButton> createState() => _LandingButtonState();
}

class _LandingButtonState extends State<_LandingButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isPrimary ? const Color(0xFF3B82F6) : Colors.white;
    final fg = widget.isPrimary ? Colors.white : const Color(0xFF111827);
    final border =
        widget.isPrimary ? const Color(0xFF3B82F6) : const Color(0xFFE5E7EB);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.985 : 1,
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border, width: 0.85),
              boxShadow: [
                if (widget.isPrimary)
                  BoxShadow(
                    color: const Color(0xFF3B82F6)
                        .withValues(alpha: _hovered ? 0.20 : 0.14),
                    blurRadius: _hovered ? 20 : 14,
                    offset: Offset(0, _hovered ? 10 : 7),
                  )
                else
                  BoxShadow(
                    color: const Color(0xFF111827)
                        .withValues(alpha: _hovered ? 0.07 : 0.035),
                    blurRadius: _hovered ? 16 : 10,
                    offset: Offset(0, _hovered ? 8 : 5),
                  ),
              ],
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: fg,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
