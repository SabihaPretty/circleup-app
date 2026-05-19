import 'package:flutter/material.dart';
import '../core/app_theme.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 170 || constraints.maxWidth < 300;

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth.isFinite
                      ? constraints.maxWidth.clamp(180, 520)
                      : 360,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: compact ? 54 : 72,
                      height: compact ? 54 : 72,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(.10),
                        borderRadius: BorderRadius.circular(compact ? 18 : 24),
                      ),
                      child: Icon(
                        icon,
                        color: AppTheme.primary,
                        size: compact ? 30 : 42,
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 14),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 15 : 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.dark,
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 8),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: compact ? 1 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 12 : 14,
                        color: Colors.grey.shade700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
