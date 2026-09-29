import 'package:flutter/material.dart';
import '../../../core/constants/config.dart';
import '../../../core/theme/theme.dart';

class SellPointsScreen extends StatelessWidget {
  const SellPointsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: const TajNetAppBar(
        title: 'نقاط بيع كروت تاج نت 📍',
      ),
      body: TajNetBackground(
        child: SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: AppConfig.sellPoints.length,
            itemBuilder: (context, index) {
              final pointName = AppConfig.sellPoints[index]['name'] ?? 'نقطة بيع';
              return AppCard(
                color: AppTheme.surfaceColor,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.storefront_rounded, color: AppTheme.primaryColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        pointName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor,
                        ),
                      ),
                    ),
                    const Icon(Icons.location_on_outlined, color: AppTheme.subtitleColor, size: 20),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
