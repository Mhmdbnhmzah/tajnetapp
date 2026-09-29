import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../core/theme/theme.dart';
import '../viewmodels/admin_viewmodel.dart';

class UploadCardsScreen extends StatefulWidget {
  const UploadCardsScreen({super.key});

  @override
  State<UploadCardsScreen> createState() => _UploadCardsScreenState();
}

class _UploadCardsScreenState extends State<UploadCardsScreen> {
  String? _selectedProfilePrice;
  final _pinController = TextEditingController();
  final _serialController = TextEditingController();
  final _bulkTextController = TextEditingController();

  double _parsePriceValue(String priceStr) {
    final clean = priceStr.replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(clean) ?? 0.0;
  }

  @override
  void dispose() {
    _pinController.dispose();
    _serialController.dispose();
    _bulkTextController.dispose();
    super.dispose();
  }

  /// Strictly extracts 10-digit card PIN numbers (handles PDF streams, brackets, and large multi-page file batches)
  List<String> _extractPinsFromText(String input) {
    final List<String> extractedPins = [];
    final Set<String> seenPins = {};

    // 1. Direct 10-digit number extraction
    final regex = RegExp(r'\d{10}');
    final matches = regex.allMatches(input);

    for (var m in matches) {
      final pin = m.group(0);
      if (pin != null && pin.length == 10) {
        // Exclude PDF xref table offsets (e.g. 0000000017, 0000000120)
        if (pin.startsWith('00000')) continue;
        // Exclude repeated identical digits (e.g. 0000000000)
        if (RegExp(r'^(\d)\1{9}$').hasMatch(pin)) continue;
        // Exclude contact service phone number printed on cards (784336270)
        if (pin.contains('784336270')) continue;

        if (!seenPins.contains(pin)) {
          seenPins.add(pin);
          extractedPins.add(pin);
        }
      }
    }
    return extractedPins;
  }

  void _submitSingleCard() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة رمز الكارت (PIN)')),
      );
      return;
    }

    final adminViewModel = Provider.of<AdminViewModel>(context, listen: false);
    if (_selectedProfilePrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى اختيار فئة الكارت')));
      return;
    }
    final priceVal = _parsePriceValue(_selectedProfilePrice!);

    final success = await adminViewModel.uploadCardsBulk([
      {
        'profilePrice': _selectedProfilePrice!,
        'priceValue': priceVal,
        'pin': pin,
        'serialNumber': _serialController.text.trim(),
      }
    ]);

    if (success && mounted) {
      _pinController.clear();
      _serialController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إضافة الكارت بنجاح إلى المخزون!'), backgroundColor: Colors.green),
      );
    }
  }

  void _submitBulkText() async {
    final text = _bulkTextController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى لصق قائمة الرموز أو اختيار ملف الكروت')),
      );
      return;
    }

    final pins = _extractPinsFromText(text);
    if (pins.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لم يتم العثور على أرقام كروت صحيحة (10 أرقام) في النص')),
      );
      return;
    }

    if (_selectedProfilePrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى اختيار الفئة')));
      return;
    }
    final List<Map<String, dynamic>> cardsData = [];
    final priceVal = _parsePriceValue(_selectedProfilePrice!);

    for (var pin in pins) {
      cardsData.add({
        'profilePrice': _selectedProfilePrice!,
        'priceValue': priceVal,
        'pin': pin,
        'serialNumber': '',
      });
    }

    final adminViewModel = Provider.of<AdminViewModel>(context, listen: false);
    final success = await adminViewModel.uploadCardsBulk(cardsData);

    if (success && mounted) {
      _bulkTextController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🎉 تم تغذية المخزون بـ ${cardsData.length} كارت لفئة ($_selectedProfilePrice) بنجاح!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _extractPdfStreamText(List<int> pdfBytes) {
    StringBuffer buffer = StringBuffer();

    // 1. Raw decode attempts (for uncompressed PDF streams)
    final rawLatin1 = latin1.decode(pdfBytes, allowInvalid: true);
    buffer.writeln(rawLatin1);

    // Extract PDF string literals (0685813205) directly from raw PDF
    final pdfLiteralRegex = RegExp(r'\(\s*(\d{10})\s*\)');
    for (var m in pdfLiteralRegex.allMatches(rawLatin1)) {
      if (m.group(1) != null) {
        buffer.writeln(m.group(1));
      }
    }

    // 2. Scan and decompress all FlateDecode streams across all pages
    final streamMarker = [115, 116, 114, 101, 97, 109]; // 'stream'
    final endStreamMarker = [101, 110, 100, 115, 116, 114, 101, 97, 109]; // 'endstream'

    int index = 0;
    while (index < pdfBytes.length) {
      int streamStart = _indexOfSublist(pdfBytes, streamMarker, index);
      if (streamStart == -1) break;

      int contentStart = streamStart + 6;
      while (contentStart < pdfBytes.length && (pdfBytes[contentStart] == 13 || pdfBytes[contentStart] == 10 || pdfBytes[contentStart] == 32)) {
        contentStart++;
      }

      int streamEnd = _indexOfSublist(pdfBytes, endStreamMarker, contentStart);
      if (streamEnd == -1) break;

      int contentEnd = streamEnd;
      while (contentEnd > contentStart && (pdfBytes[contentEnd - 1] == 13 || pdfBytes[contentEnd - 1] == 10 || pdfBytes[contentEnd - 1] == 32)) {
        contentEnd--;
      }

      if (contentEnd > contentStart) {
        final streamData = pdfBytes.sublist(contentStart, contentEnd);
        try {
          final decompressed = zlib.decode(streamData);
          final decompStrLatin = latin1.decode(decompressed, allowInvalid: true);
          final decompStrUtf8 = utf8.decode(decompressed, allowMalformed: true);

          buffer.writeln(decompStrLatin);
          buffer.writeln(decompStrUtf8);

          for (var m in pdfLiteralRegex.allMatches(decompStrLatin)) {
            if (m.group(1) != null) {
              buffer.writeln(m.group(1));
            }
          }
        } catch (_) {
          // Skip non-zlib binary data (e.g. embedded JPEGs)
        }
      }

      index = streamEnd + 9;
    }

    return buffer.toString();
  }

  int _indexOfSublist(List<int> source, List<int> needle, int start) {
    if (needle.isEmpty) return -1;
    for (int i = start; i <= source.length - needle.length; i++) {
      bool match = true;
      for (int j = 0; j < needle.length; j++) {
        if (source[i + j] != needle[j]) {
          match = false;
          break;
        }
      }
      if (match) return i;
    }
    return -1;
  }

  Future<void> _pickTextOrPdfFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'csv', 'pdf', 'log'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final file = File(filePath);
        String content = '';
        List<String> extractedPins = [];

        // 1. High-Precision Syncfusion PdfTextExtractor (resolves CMap / CID subsets & CorelDraw fonts)
        if (filePath.toLowerCase().endsWith('.pdf')) {
          try {
            final bytes = await file.readAsBytes();
            final PdfDocument document = PdfDocument(inputBytes: bytes);
            content = PdfTextExtractor(document).extractText();
            document.dispose();
            extractedPins = _extractPinsFromText(content);
          } catch (e) {
            debugPrint("Syncfusion PDF Extraction note: $e");
          }
        }

        // 2. Fallback to standard text reading
        if (extractedPins.isEmpty) {
          try {
            content = await file.readAsString();
            extractedPins = _extractPinsFromText(content);
          } catch (_) {}
        }

        // 3. Fallback to raw PDF stream byte decompression
        if (extractedPins.isEmpty) {
          final bytes = await file.readAsBytes();
          final streamDecodedContent = _extractPdfStreamText(bytes);
          extractedPins = _extractPinsFromText(streamDecodedContent);
        }

        if (!mounted) return;

        if (extractedPins.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذر قراءة الكروت تلقائياً من الملف. يمكنك نسخ الرموز المكونة من 10 أرقام ولصقها يدوياً.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        } else {
          setState(() {
            _bulkTextController.text = extractedPins.join('\n');
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 تم قراءة الملف بنجاح واكتشاف ${extractedPins.length} كارت (10 أرقام) وتجهيزهم للرفع!'),
              backgroundColor: AppTheme.primaryColor,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking or parsing cards file: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر قراءة محتوى الملف. تأكد من صيغة الملف والمحاولة مجدداً.'), backgroundColor: AppTheme.errorColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminViewModel = Provider.of<AdminViewModel>(context, listen: false);

    final currentExtractedCount = _extractPinsFromText(_bulkTextController.text).length;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تغذية مخزون الكروت 📥'),
          bottom: const TabBar(
            indicatorColor: AppTheme.primaryColor,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.subtitleColor,
            tabs: [
              Tab(icon: Icon(Icons.drive_folder_upload), text: 'رفع مجمع (ملف/نص)'),
              Tab(icon: Icon(Icons.add_card), text: 'إضافة يدوية'),
            ],
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Category Profile Selector
                const Text('اختر فئة كروت تاج نت المراد تغذيتها:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: adminViewModel.allPackages,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final packages = snapshot.data ?? [];
                    if (packages.isEmpty) {
                      return const Text('لا توجد باقات متاحة حالياً. يرجى إضافتها من إدارة الباقات.', style: TextStyle(color: AppTheme.errorColor));
                    }
                    
                    final currentSelected = _selectedProfilePrice ?? (packages.isNotEmpty ? packages.first['priceText'] as String? : null);

                    return DropdownButtonFormField<String>(
                      initialValue: currentSelected,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.style, color: AppTheme.primaryColor),
                      ),
                      items: packages.map((p) {
                        return DropdownMenuItem<String>(
                          value: p['priceText'],
                          child: Text(
                            'فئة ${p['priceText']} - (${p['transfer']} | ${p['validity']})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedProfilePrice = val;
                          });
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),

                Expanded(
                  child: TabBarView(
                    children: [
                      // TAB 1: BULK UPLOAD FROM FILE / PASTED TEXT
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.24)),
                              ),
                              child: const Text(
                                '💡 يدعم النظام قراءة نصوص وملفات كروت شبكة تاج نت تلقائياً واستخراج كافة رموز الـ 10 أرقام وحفظها بالمخزون.',
                                style: TextStyle(fontSize: 13, color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
                                    onPressed: _pickTextOrPdfFile,
                                    icon: const Icon(Icons.attach_file),
                                    label: const Text('اختيار ملف الكروت (TXT/CSV)'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            TextField(
                              controller: _bulkTextController,
                              maxLines: 8,
                              keyboardType: TextInputType.multiline,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: 'أو قم بلصق رموز الكروت هنا مباشرة (مثلاً:\n0041145287\n0603915389\n0107936898...)',
                                alignLabelWithHint: true,
                                suffixIcon: currentExtractedCount > 0
                                    ? Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Chip(
                                          backgroundColor: AppTheme.primaryColor,
                                          label: Text('$currentExtractedCount كارت مكتشف', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 11)),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 20),

                            Consumer<AdminViewModel>(
                              builder: (context, adminVM, child) {
                                return ElevatedButton.icon(
                                  icon: const Icon(Icons.cloud_upload),
                                  label: Text(
                                    currentExtractedCount > 0
                                        ? 'حفظ وتغذية المخزون بـ ($currentExtractedCount كارت) 🚀'
                                        : 'تغذية الكروت في المخزون',
                                  ),
                                  onPressed: adminVM.isLoading ? null : _submitBulkText,
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      // TAB 2: MANUAL SINGLE CARD ENTRY
                      SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('رمز الكارت السرّي (PIN):', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _pinController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'أدخل رمز الكارت (مثلاً 0041145287)',
                                prefixIcon: Icon(Icons.pin, color: AppTheme.subtitleColor),
                              ),
                            ),
                            const SizedBox(height: 16),

                            const Text('الرقم التسلسلي (اختياري):', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _serialController,
                              decoration: const InputDecoration(
                                hintText: 'أدخل الرقم التسلسلي إن وجد',
                                prefixIcon: Icon(Icons.numbers, color: AppTheme.subtitleColor),
                              ),
                            ),
                            const SizedBox(height: 24),

                            Consumer<AdminViewModel>(
                              builder: (context, adminVM, child) {
                                return ElevatedButton.icon(
                                  icon: const Icon(Icons.add_circle),
                                  label: const Text('إضافة الكارت للمخزون'),
                                  onPressed: adminVM.isLoading ? null : _submitSingleCard,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
