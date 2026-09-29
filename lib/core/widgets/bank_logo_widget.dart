import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/theme.dart';

class BankLogoWidget extends StatelessWidget {
  final String? imageUrl;
  final String bankName;
  final double size;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;

  const BankLogoWidget({
    super.key,
    this.imageUrl,
    this.bankName = '',
    this.size = 54.0,
    this.width,
    this.height,
    this.radius = 14.0,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveWidth = width ?? size;
    final effectiveHeight = height ?? size;
    final hasImage = imageUrl != null && imageUrl!.trim().isNotEmpty;

    return Container(
      width: effectiveWidth,
      height: effectiveHeight,
      decoration: BoxDecoration(
        color: hasImage ? Colors.white : AppTheme.surfaceColorElevated,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: hasImage
              ? AppTheme.primaryColor.withValues(alpha: 0.4)
              : AppTheme.borderColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1.5),
        child: hasImage ? _buildImage(imageUrl!.trim()) : _buildFallback(),
      ),
    );
  }

  Widget _buildImage(String url) {
    if (url.startsWith('data:image')) {
      try {
        final commaIdx = url.indexOf(',');
        final base64Str = commaIdx != -1 ? url.substring(commaIdx + 1) : url;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: fit,
          errorBuilder: (context, error, stackTrace) => _buildFallback(),
        );
      } catch (e) {
        return _buildFallback();
      }
    }

    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primaryColor,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => _buildFallback(),
    );
  }

  Widget _buildFallback() {
    return Container(
      color: AppTheme.surfaceColorElevated,
      child: Center(
        child: Icon(
          Icons.account_balance_rounded,
          color: AppTheme.primaryColor,
          size: size * 0.48,
        ),
      ),
    );
  }
}
