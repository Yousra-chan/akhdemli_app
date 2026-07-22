import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:service_app/providers/language_provider.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';

class LoadingWidget extends StatelessWidget {
  final String? message;
  const LoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          ),
          const SizedBox(height: 16),
          Text(
            message ?? lang.tr('loading', category: 'common'),
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.white70 
                  : Colors.grey, 
              fontFamily: 'Exo2'
            ),
          ),
        ],
      ),
    );
  }
}

class SkeletonLoader extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final BoxShape shape;

  const SkeletonLoader({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[850]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[800]! : Colors.grey[100]!,
      child: Container(
        width: width ?? double.infinity,
        height: height ?? 20,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
          shape: shape,
        ),
      ),
    );
  }
}

class CategorySkeleton extends StatelessWidget {
  const CategorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: SkeletonLoader(
            borderRadius: 16,
            height: double.infinity,
          ),
        ),
        const SizedBox(height: 8),
        const SkeletonLoader(height: 12, width: 60),
      ],
    );
  }
}

class PostSkeleton extends StatelessWidget {
  const PostSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonLoader(width: 40, height: 40, shape: BoxShape.circle),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonLoader(width: 100, height: 14),
                  SizedBox(height: 4),
                  SkeletonLoader(width: 60, height: 10),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const SkeletonLoader(height: 150),
          const SizedBox(height: 12),
          const SkeletonLoader(width: double.infinity, height: 12),
          const SizedBox(height: 6),
          const SkeletonLoader(width: 150, height: 12),
        ],
      ),
    );
  }
}

class MessageSkeleton extends StatelessWidget {
  final bool isMe;
  const MessageSkeleton({super.key, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: SkeletonLoader(
          width: MediaQuery.of(context).size.width * 0.6,
          height: 50,
          borderRadius: 16,
        ),
      ),
    );
  }
}

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const SkeletonLoader(width: 100, height: 100, shape: BoxShape.circle),
          const SizedBox(height: 16),
          const SkeletonLoader(width: 150, height: 24),
          const SizedBox(height: 8),
          const SkeletonLoader(width: 100, height: 16),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SkeletonLoader(height: 200, borderRadius: 15),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: SkeletonLoader(height: 80, borderRadius: 15)),
                const SizedBox(width: 10),
                Expanded(child: SkeletonLoader(height: 80, borderRadius: 15)),
                const SizedBox(width: 10),
                Expanded(child: SkeletonLoader(height: 80, borderRadius: 15)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SkeletonLoader(height: 60, borderRadius: 15),
          ),
        ],
      ),
    );
  }
}

class ProviderSkeleton extends StatelessWidget {
  const ProviderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SkeletonLoader(width: 60, height: 60, shape: BoxShape.circle),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonLoader(width: 120, height: 16),
                    SizedBox(height: 10),
                    SkeletonLoader(width: 80, height: 12),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: SkeletonLoader(height: 48, borderRadius: 24)),
              const SizedBox(width: 12),
              Expanded(child: SkeletonLoader(height: 48, borderRadius: 24)),
            ],
          ),
        ],
      ),
    );
  }
}

class ProfessionalSuccessDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onDone;

  const ProfessionalSuccessDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.network(
              'https://assets10.lottiefiles.com/packages/lf20_qc9it9lr.json', // Professional checkmark
              width: 150,
              height: 150,
              repeat: false,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.check_circle, size: 80, color: Colors.green),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Exo2',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white70 
                    : Colors.grey,
                height: 1.4,
                fontFamily: 'Exo2',
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  context.watch<LanguageProvider>().tr('done', category: 'common'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorStateWidget extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  const ErrorStateWidget({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              message ?? lang.tr('something_went_wrong', category: 'common'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.w500,
                fontFamily: 'Exo2'
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(lang.tr('try_again', category: 'common')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  final String? message;
  final String? subtitle;
  final IconData icon;
  final Widget? action;
  const EmptyStateWidget({
    super.key,
    this.message,
    this.subtitle,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              message ?? lang.tr('no_data', category: 'common'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : Colors.grey.shade800,
                fontWeight: FontWeight.w600,
                fontFamily: 'Exo2'
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white70 
                      : Colors.grey.shade600,
                  fontFamily: 'Exo2'
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// A modern styled snackbar for messages
class AppSnackBar {
  static void showSuccess(BuildContext context, String message) {
    HapticFeedback.lightImpact();
    _show(context, message, Colors.green, Icons.check_circle_outline);
  }

  static void showError(BuildContext context, String message) {
    HapticFeedback.heavyImpact();
    _show(context, message, Colors.redAccent, Icons.error_outline);
  }

  static void showWarning(BuildContext context, String message) {
    HapticFeedback.mediumImpact();
    _show(context, message, Colors.orange, Icons.warning_amber_outlined);
  }

  static void showInfo(BuildContext context, String message) {
    HapticFeedback.selectionClick();
    _show(context, message, const Color.fromARGB(255, 12, 94, 153), Icons.info_outline);
  }

  static void _show(BuildContext context, String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Exo2'
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
