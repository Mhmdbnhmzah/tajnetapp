import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/package_profile.dart';
import '../../../core/theme/theme.dart';
import '../viewmodels/admin_viewmodel.dart';

class ManagePackagesScreen extends StatefulWidget {
  const ManagePackagesScreen({super.key});

  @override
  State<ManagePackagesScreen> createState() => _ManagePackagesScreenState();
}

class _ManagePackagesScreenState extends State<ManagePackagesScreen> {
  void _showPackageDialog({Map<String, dynamic>? packageData}) {
    final isEditing = packageData != null;
    final priceTextCtrl = TextEditingController(text: isEditing ? packageData['priceText'] : '');
    final priceValueCtrl = TextEditingController(text: isEditing ? packageData['priceValue'].toString() : '');
    final transferCtrl = TextEditingController(text: isEditing ? packageData['transfer'] : '');
    final validityCtrl = TextEditingController(text: isEditing ? packageData['validity'] : '');
    final colorHexCtrl = TextEditingController(text: isEditing ? (packageData['colorHex'] ?? '') : '');
    final orderCtrl = TextEditingController(text: isEditing ? (packageData['order'] ?? 0).toString() : '0');
    bool isActive = isEditing ? (packageData['isActive'] ?? true) : true;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.surfaceColor,
            title: Text(
              isEditing ? 'تعديل الباقة' : 'إضافة باقة جديدة',
              style: const TextStyle(color: AppTheme.textColor),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: priceTextCtrl,
                      decoration: const InputDecoration(labelText: 'نص السعر (مثال: 200 ريال)'),
                      validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: priceValueCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'القيمة الرقمية (مثال: 200)'),
                      validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: transferCtrl,
                      decoration: const InputDecoration(labelText: 'السعة (مثال: 3 قيقا)'),
                      validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: validityCtrl,
                      decoration: const InputDecoration(labelText: 'الصلاحية (مثال: يومين)'),
                      validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: colorHexCtrl,
                      decoration: const InputDecoration(
                        labelText: 'كود لون الباقة HEX (اختياري)',
                        hintText: 'مثال: #FF5733 أو اتركه للتلوين الآلي',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: orderCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'الترتيب (0، 1، 2...)'),
                      validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      title: const Text('مفعلة؟', style: TextStyle(color: AppTheme.textColor)),
                      value: isActive,
                      onChanged: (val) => setDialogState(() => isActive = val),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle(color: AppTheme.subtitleColor)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState?.validate() == true) {
                    final adminVm = Provider.of<AdminViewModel>(context, listen: false);
                    final hexVal = colorHexCtrl.text.trim();
                    final data = {
                      'priceText': priceTextCtrl.text.trim(),
                      'priceValue': double.tryParse(priceValueCtrl.text.trim()) ?? 0.0,
                      'transfer': transferCtrl.text.trim(),
                      'validity': validityCtrl.text.trim(),
                      'colorHex': hexVal.isNotEmpty ? hexVal : null,
                      'order': int.tryParse(orderCtrl.text.trim()) ?? 0,
                      'isActive': isActive,
                    };
                    Navigator.pop(ctx);
                    if (isEditing) {
                      await adminVm.updatePackage(packageData['id'], data);
                    } else {
                      await adminVm.addPackage(data);
                    }
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(String packageId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('تأكيد الحذف', style: TextStyle(color: AppTheme.errorColor)),
        content: const Text('هل أنت متأكد من حذف هذه الباقة؟', style: TextStyle(color: AppTheme.textColor)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء', style: TextStyle(color: AppTheme.subtitleColor)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            onPressed: () async {
              Navigator.pop(ctx);
              await Provider.of<AdminViewModel>(context, listen: false).deletePackage(packageId);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminVm = Provider.of<AdminViewModel>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('إدارة باقات الكروت'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        onPressed: () => _showPackageDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          if (adminVm.isLoading) const LinearProgressIndicator(),
          if (adminVm.errorMessage != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: AppTheme.errorColor,
              width: double.infinity,
              child: Text(adminVm.errorMessage!, style: const TextStyle(color: Colors.white)),
            ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: adminVm.allPackages,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final packages = snapshot.data ?? [];
                if (packages.isEmpty) {
                  return const Center(
                    child: Text('لا توجد باقات. اضغط على + لإضافة باقة.', style: TextStyle(color: AppTheme.subtitleColor)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: packages.length,
                  itemBuilder: (context, index) {
                    final pkg = packages[index];
                    final p = PackageProfile.fromMap(pkg, pkg['id']);
                    final palette = PackageColorHelper.getPalette(
                      p.priceText,
                      customHex: p.colorHex,
                      index: index,
                    );

                    return Card(
                      color: AppTheme.surfaceColor,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: palette.accentColor.withValues(alpha: 0.4)),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: p.isActive ? palette.accentColor : AppTheme.subtitleColor,
                          child: const Icon(Icons.wifi, color: Colors.white),
                        ),
                        title: Text(
                          '${p.priceText} - ${p.transfer}',
                          style: const TextStyle(color: AppTheme.textColor, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'الصلاحية: ${p.validity} | الترتيب: ${p.order}${p.colorHex != null ? ' | اللون: ${p.colorHex}' : ''}',
                          style: const TextStyle(color: AppTheme.subtitleColor),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: AppTheme.accentCyan),
                              onPressed: () => _showPackageDialog(packageData: pkg),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: AppTheme.errorColor),
                              onPressed: () => _confirmDelete(p.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
