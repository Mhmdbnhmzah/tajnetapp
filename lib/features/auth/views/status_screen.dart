import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme.dart';
import '../viewmodels/auth_viewmodel.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<AuthViewModel>(context, listen: false).checkStatus(isPolling: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = Provider.of<AuthViewModel>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: TajNetBackground(
        child: SafeArea(
          child: RefreshIndicator(
            color: AppTheme.primaryColor,
            backgroundColor: AppTheme.surfaceColor,
            onRefresh: () async {
              await authViewModel.checkStatus(isPolling: false);
              await Future.delayed(const Duration(milliseconds: 300));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                children: [
                  // Network Warning Banner if disconnected from Wi-Fi (Fix M-08)
                  if (authViewModel.errorMessage != null) ...[
                    _buildNetworkWarning(authViewModel),
                    const SizedBox(height: 16),
                  ],

                  // Connection Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.35)),
                    boxShadow: AppTheme.primaryGlow,
                  ),
                  child: Column(
                    children: [
                      // Pulsing connected icon with cyan glow rings
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 5)
                              ]
                            ),
                          ),
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.4), blurRadius: 15, spreadRadius: 2)
                              ]
                            ),
                          ),
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.wifi_rounded, color: Colors.white, size: 24),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'متصل بالشبكة',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'شبكة تاج نت • تمتع بتصفح سريع وآمن',
                        style: TextStyle(color: AppTheme.subtitleColor, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Stats Grid
                _buildStatsGrid(authViewModel),

                const SizedBox(height: 20),

                // Disconnect Button (Full Width, Red Gradient)
                TajNetButton(
                  onPressed: authViewModel.isLoading
                      ? null
                      : () async => await authViewModel.logout(),
                  isLoading: authViewModel.isLoading,
                  gradientColors: const [Color(0xFFDC2626), Color(0xFFEF4444)],
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.power_settings_new_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'قطع الاتصال بالشبكة',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildStatsGrid(AuthViewModel authViewModel) {
    final stats = [
      {
        'icon': Icons.download_rounded,
        'label': 'التنزيل',
        'value': authViewModel.bytesOut,
        'color': AppTheme.accentCyan, // cyan
      },
      {
        'icon': Icons.upload_rounded,
        'label': 'الرفع',
        'value': authViewModel.bytesIn,
        'color': AppTheme.primaryDark, // blue
      },
      {
        'icon': Icons.data_usage_rounded,
        'label': 'المتبقي من الباقة',
        'value': authViewModel.remainBytes,
        'color': AppTheme.accentGold, // gold
      },
      {
        'icon': Icons.timer_rounded,
        'label': 'الوقت المنقضي',
        'value': authViewModel.uptime,
        'color': AppTheme.accentPurple, // purple
      },
      {
        'icon': Icons.hourglass_top_rounded,
        'label': 'الوقت المتبقي',
        'value': authViewModel.timeRemain,
        'color': AppTheme.primaryColor, // primary cyan
      },
    ];

    return Column(
      children: stats.map((stat) => _buildStatRow(stat)).toList(),
    );
  }

  Widget _buildStatRow(Map<String, dynamic> stat) {
    final value = stat['value'] as String? ?? '';
    final color = stat['color'] as Color;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        color: AppTheme.surfaceColor,
        borderColor: color.withValues(alpha: 0.3),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(stat['icon'] as IconData, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                stat['label'] as String,
                style: const TextStyle(color: AppTheme.subtitleColor, fontSize: 14),
              ),
            ),
            Text(
              value.isEmpty ? '...' : value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: value.isEmpty ? AppTheme.subtitleColor : AppTheme.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkWarning(AuthViewModel authViewModel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.warningColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.45)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.warningColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_off_rounded, color: AppTheme.warningColor, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'تنبيه الاتصال بشبكة الواي فاي',
                  style: TextStyle(
                    color: AppTheme.warningColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            authViewModel.errorMessage ?? 'تعذر الاتصال ببوابة الشبكة حالياً.',
            style: const TextStyle(
              color: AppTheme.textColor,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.warningColor,
                side: BorderSide(color: AppTheme.warningColor.withValues(alpha: 0.6)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('إعادة المحاولة والتحديث', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () => authViewModel.checkStatus(isPolling: false),
            ),
          ),
        ],
      ),
    );
  }
}
