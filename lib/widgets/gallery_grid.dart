import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/saved_session.dart';

/// Grid view of saved session artwork
class GalleryGrid extends StatelessWidget {
  final List<SavedSession> sessions;
  final void Function(SavedSession session) onSessionTap;
  final void Function(SavedSession session)? onSessionLongPress;
  final bool isEditMode;

  const GalleryGrid({
    super.key,
    required this.sessions,
    required this.onSessionTap,
    this.onSessionLongPress,
    this.isEditMode = false,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.palette_outlined,
              size: 80,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            Text(
              'No artwork yet',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete a meditation to create your first piece',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        return _GalleryItem(
          session: sessions[index],
          onTap: () => onSessionTap(sessions[index]),
          onLongPress: onSessionLongPress != null 
            ? () => onSessionLongPress!(sessions[index])
            : null,
          isEditMode: isEditMode,
        );
      },
    );
  }
}

class _GalleryItem extends StatefulWidget {
  final SavedSession session;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isEditMode;

  const _GalleryItem({
    required this.session,
    required this.onTap,
    this.onLongPress,
    this.isEditMode = false,
  });

  @override
  State<_GalleryItem> createState() => _GalleryItemState();
}

class _GalleryItemState extends State<_GalleryItem>
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firstDrawing = widget.session.validDrawings.isNotEmpty 
      ? widget.session.validDrawings.first 
      : null;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryMedium,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  // Image preview
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      child: firstDrawing != null
                          ? Image.memory(
                              firstDrawing,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.white10,
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                color: Colors.white24,
                                size: 40,
                              ),
                            ),
                    ),
                  ),
                  // Info section
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.session.meditationTitle,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: Colors.white54,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(widget.session.sessionDate),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white54,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.calmBlue.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${widget.session.drawingCount}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.calmBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                    ],
                  ),
                ),
                // Delete badge in edit mode
                if (widget.isEditMode)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppTheme.highlight,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
