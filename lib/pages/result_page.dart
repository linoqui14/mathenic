import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../models/math_result.dart';
import '../providers/result_provider.dart';
import '../theme/app_theme.dart';

class ResultPage extends StatefulWidget {
  final MathResult? result;
  final VoidCallback? onNavigateToCamera;
  const ResultPage({super.key, this.result, this.onNavigateToCamera});

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.darkPrimary : AppColors.lightPrimary;

    return Consumer<ResultProvider>(
      builder: (BuildContext context, resultProvider, Widget? child) {
        final result = resultProvider.currentResult;

        if (result == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt_outlined,
                    size: 80,
                    color: Colors.grey.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No results yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: widget.onNavigateToCamera,
                    icon: const Icon(Icons.camera),
                    label: const Text('Scan a problem'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: Container(
            margin: const EdgeInsets.only(bottom: 70),
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 250,
                  pinned: true,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  elevation: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    background: _ImageHeader(imagePath: result.imagePath),
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: widget.onNavigateToCamera,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _ResultContent(
                    result: result,
                    primaryColor: primaryColor,
                    fadeController: _fadeController,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ImageHeader extends StatelessWidget {
  final String imagePath;

  const _ImageHeader({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Consumer<ResultProvider>(
      builder: (context, resultProvider, child) {
        final result = resultProvider.currentResult;
        final isLoading = result != null && _isResultLoading(result);

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
                ? Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
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
                ),
                if(isLoading)
                  Container(
                  // margin: const EdgeInsets.fromLTRB(10, 50, 10, 10),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(20)),
                    color: Colors.black.withOpacity(0.5),
                  ),
                  child: Center(
                    child: Lottie.asset(
                      'assets/lottie/scan.json',
                      // width:1000,
                      height: 300,
                      fit: BoxFit.fitWidth,
                    ),
                  ),
                ),
              ],
            )
                : Container(
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.image_not_supported, size: 50),
              ),
            ),
          ),
        );
      },
    );
  }

  bool _isResultLoading(MathResult result) {
    return _isLoadingText(result.question) ||
        _isLoadingText(result.answer) ||
        _isLoadingText(result.solution);
  }

  bool _isLoadingText(String text) {
    return text == 'Analyzing question...' ||
        text == 'Generating solution...' ||
        text == 'Calculating answer...' ||
        text == 'Preparing...' ||
        text == 'Loading...' ||
        text == 'Please wait...';
  }
}

class _ResultContent extends StatelessWidget {
  final MathResult result;
  final Color primaryColor;
  final AnimationController fadeController;

  const _ResultContent({
    required this.result,
    required this.primaryColor,
    required this.fadeController,
  });

  bool _isLoading(String text) {
    return text == 'Analyzing question...' ||
        text == 'Generating solution...' ||
        text == 'Calculating answer...' ||
        text == 'Preparing...' ||
        text == 'Loading...' ||
        text == 'Please wait...';
  }

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
          _buildLazySection(
            context,
            'Question',
            result.question,
            Icons.help_outline,
            primaryColor,
          ),
          const SizedBox(height: 16),
          _buildLazySection(
            context,
            'Answer',
            result.answer,
            Icons.check_circle_outline,
            primaryColor,
          ),
          const SizedBox(height: 16),
          _buildLazySection(
            context,
            'Solution',
            result.solution,
            Icons.lightbulb_outline,
            primaryColor,
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    context,
                    'Share',
                    Icons.share_outlined,
                    primaryColor,
                        () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    context,
                    'Save',
                    Icons.bookmark_outline,
                    primaryColor,
                        () {},
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildLazySection(
      BuildContext context,
      String title,
      String content,
      IconData icon,
      Color color,
      ) {
    final isLoading = _isLoading(content);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AnimatedOpacity(
        opacity: isLoading ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[850]
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withOpacity(0.2),
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
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  if (isLoading) ...[
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              if (isLoading)
                _buildLoadingShimmer(context)
              else
                MarkdownBody(
                  data: content,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : Colors.black87,
                    ),
                    code: TextStyle(
                      backgroundColor: color.withOpacity(0.1),
                      color: color,
                      fontFamily: 'monospace',
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: color.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: color.withOpacity(0.2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            height: 16,
            width: double.infinity * (index == 2 ? 0.6 : 1.0),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[800]
                  : Colors.grey[300],
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildActionButton(
      BuildContext context,
      String label,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
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