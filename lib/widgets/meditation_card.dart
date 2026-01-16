import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/meditation_service.dart';

/// Minimal card widget displaying meditation info with blue outline style
class MeditationCard extends StatefulWidget {
  final MeditationInfo meditation;
  final VoidCallback onTap;

  const MeditationCard({
    super.key,
    required this.meditation,
    required this.onTap,
  });

  @override
  State<MeditationCard> createState() => _MeditationCardState();
}

class _MeditationCardState extends State<MeditationCard> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  MeditationInfo get meditation => widget.meditation;

  IconData get _meditationIcon {
    final title = meditation.title.toLowerCase();
    if (title.contains('relax')) return Icons.spa_outlined;
    if (title.contains('body scan')) return Icons.accessibility_new_outlined;
    if (title.contains('transform')) return Icons.change_circle_outlined;
    if (title.contains('situation')) return Icons.psychology_outlined;
    if (title.contains('pain')) return Icons.healing_outlined;
    if (title.contains('sad')) return Icons.sentiment_neutral_outlined;
    if (title.contains('help')) return Icons.support_outlined;
    return Icons.self_improvement_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  // Icon - simple blue outline style
                  Icon(
                    _meditationIcon,
                    color: AppTheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 14),
                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meditation.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          meditation.description,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Arrow
                  Icon(
                    Icons.chevron_right,
                    color: AppTheme.primary.withValues(alpha: 0.6),
                    size: 24,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
