import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/math_result.dart';
import '../theme/app_theme.dart';

class HistoryDetailPage extends StatelessWidget {
  final MathResult result;

  const HistoryDetailPage({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              background: _ImageHeader(imagePath: result.imagePath),
            ),
          ),
          SliverToBoxAdapter(
            child: _ResultContent(
              result: result,
              primaryColor: primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageHeader extends StatelessWidget {
  final String imagePath;

  const _ImageHeader({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 50, 10, 10),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        child: File(imagePath).existsSync()
            ? Image.file(
          File(imagePath),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.broken_image, size: 50),
              ),
            );
          },
        )
            : Container(
          color: Colors.grey[300],
          child: const Center(
            child: Icon(Icons.image_not_supported, size: 50),
          ),
        ),
      ),
    );
  }
}

class _ResultContent extends StatelessWidget {
  final MathResult result;
  final Color primaryColor;

  const _ResultContent({
    required this.result,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    result.subject,
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTime(result.timestamp),
                  style: TextStyle(
                    color: Colors.grey.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildSection(
            context,
            'Question',
            result.question,
            Icons.help_outline,
            primaryColor,
          ),
          const SizedBox(height: 16),
          if (result.answer.isNotEmpty)
            _buildSection(
              context,
              'Answer',
              result.answer,
              Icons.check_circle_outline,
              primaryColor,
            ),
          const SizedBox(height: 16),
          _buildSection(
            context,
            'Solution',
            result.solution,
            Icons.lightbulb_outline,
            primaryColor,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(
      BuildContext context,
      String title,
      String content,
      IconData icon,
      Color color,
      ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[900]
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            MarkdownBody(
              data: content,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(fontSize: 15, height: 1.6),
                strong: TextStyle(fontWeight: FontWeight.bold, color: color),
                code: TextStyle(
                  backgroundColor: color.withOpacity(0.1),
                  color: color,
                  fontFamily: 'monospace',
                ),
                codeblockDecoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                blockquote: TextStyle(
                  color: color.withOpacity(0.8),
                  fontStyle: FontStyle.italic,
                ),
                blockquoteDecoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: color, width: 3),
                  ),
                ),
                listBullet: TextStyle(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${time.day}/${time.month}/${time.year}';
    }
  }
}