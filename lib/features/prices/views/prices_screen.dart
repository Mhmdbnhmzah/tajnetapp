import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme.dart';
import '../../store/viewmodels/store_viewmodel.dart';

class PricesScreen extends StatelessWidget {
  const PricesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storeVM = Provider.of<StoreViewModel>(context, listen: false);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: const TajNetAppBar(
        title: 'قائمة الأسعار والباقات 🏷️',
      ),
      body: TajNetBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: storeVM.activePackages,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: CircularProgressIndicator(color: AppTheme.primaryColor),
                        ),
                      );
                    }

                    final packages = snapshot.data ?? [];
                    
                    if (packages.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: Text('لا توجد أسعار متاحة حالياً', style: TextStyle(color: AppTheme.subtitleColor)),
                        ),
                      );
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderColor),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Table(
                        border: TableBorder.all(
                          color: AppTheme.borderColor,
                          width: 1,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        children: [
                          TableRow(
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.15),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                            ),
                            children: const [
                              Padding(padding: EdgeInsets.all(12), child: Text('الفئة', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor))),
                              Padding(padding: EdgeInsets.all(12), child: Text('السعة', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor))),
                              Padding(padding: EdgeInsets.all(12), child: Text('الصلاحية', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor))),
                            ],
                          ),
                          ...packages.map((p) => TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(12), child: Text(p['priceText'] ?? '', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.bold))),
                              Padding(padding: const EdgeInsets.all(12), child: Text(p['transfer'] ?? '', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textColor))),
                              Padding(padding: const EdgeInsets.all(12), child: Text(p['validity'] ?? '', textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textColor))),
                            ],
                          )),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
