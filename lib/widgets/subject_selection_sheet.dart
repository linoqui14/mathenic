import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SubjectSelectionSheet extends StatelessWidget {
  final Function(String) onSubjectSelected;

  const SubjectSelectionSheet({
    super.key,
    required this.onSubjectSelected,
  });

  static Future<void> show(BuildContext context, Function(String) onSubjectSelected) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SubjectSelectionSheet(
        onSubjectSelected: onSubjectSelected,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with drag handle and cancel button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 40), // Spacer for centering
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  color: textColor,
                ),
              ],
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  children: [
                    Text(
                      'What is the question\nrelated to?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    _buildSubjectButton(context, 'Math', Icons.calculate_outlined),
                    const SizedBox(height: 10),
                    _buildSubjectButton(context, 'Biology', Icons.biotech_outlined),
                    const SizedBox(height: 10),
                    _buildSubjectButton(context, 'Physics', Icons.science_outlined),
                    const SizedBox(height: 10),
                    _buildSubjectButton(context, 'Chemistry', Icons.water_drop_outlined),
                    const SizedBox(height: 10),
                    _buildSubjectButton(context, 'History', Icons.history_edu_outlined),
                    const SizedBox(height: 10),
                    _buildSubjectButton(context, 'Geography', Icons.public_outlined),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectButton(BuildContext context, String subject, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          onSubjectSelected(subject);
        },
        borderRadius: BorderRadius.circular(14), // Slightly smaller radius
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16), // Reduced padding
          decoration: BoxDecoration(
            color: isDark
                ? Colors.grey[800]?.withOpacity(0.3)
                : Colors.grey[200],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: textColor, size: 22), // Slightly smaller icon
              const SizedBox(width: 14),
              Text(
                subject,
                style: TextStyle(
                  fontSize: 15, // Slightly smaller text
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}