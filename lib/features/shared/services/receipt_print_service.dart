import 'dart:typed_data';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../../core/components/gardi_logo.dart';
import '../../../core/utils/formatters.dart';
import '../models/receipt_data.dart';
import 'receipt_file_service.dart';

enum ReceiptImageFormat { a4, receipt }

abstract interface class ReceiptImageActions {
  Future<void> download(Uint8List bytes, String fileName);
  Future<void> share(Uint8List bytes, String fileName);
}

class PlatformReceiptImageActions implements ReceiptImageActions {
  const PlatformReceiptImageActions();

  @override
  Future<void> download(Uint8List bytes, String fileName) =>
      downloadReceiptImage(bytes, fileName);

  @override
  Future<void> share(Uint8List bytes, String fileName) =>
      shareReceiptImage(bytes, fileName);
}

class ReceiptPrintService {
  const ReceiptPrintService._();

  static Future<void> show(
    BuildContext context,
    ReceiptData receipt, {
    ReceiptImageActions actions = const PlatformReceiptImageActions(),
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ReceiptImageDialog(
        receipt: receipt,
        actions: actions,
      ),
    );
  }
}

class _ReceiptImageDialog extends StatefulWidget {
  final ReceiptData receipt;
  final ReceiptImageActions actions;

  const _ReceiptImageDialog({
    required this.receipt,
    required this.actions,
  });

  @override
  State<_ReceiptImageDialog> createState() => _ReceiptImageDialogState();
}

class _ReceiptImageDialogState extends State<_ReceiptImageDialog> {
  final GlobalKey _receiptKey = GlobalKey();
  ReceiptImageFormat? _format;
  Uint8List? _pngBytes;
  String? _error;
  String? _success;
  bool _isGenerating = false;
  bool _isExporting = false;

  double get _logicalWidth =>
      _format == ReceiptImageFormat.a4 ? 793.6 : 302;

  Future<void> _generate(ReceiptImageFormat format) async {
    setState(() {
      _format = format;
      _pngBytes = null;
      _error = null;
      _success = null;
      _isGenerating = true;
    });

    try {
      await precacheImage(const AssetImage('assets/images/1.png'), context);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final boundary =
          _receiptKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null || boundary.size.isEmpty) {
        throw StateError('ناوەڕۆکی پسوڵە بۆ دروستکردنی وێنە ئامادە نییە.');
      }

      final pixelRatio = format == ReceiptImageFormat.a4
          ? 300 / 96
          : 576 / _logicalWidth;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      try {
        final byteData = await image.toByteData(
          format: ImageByteFormat.png,
        );
        if (byteData == null) {
          throw StateError('وێنەی PNG دروست نەکرا.');
        }
        if (!mounted) return;
        setState(() {
          _pngBytes = byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          );
          _isGenerating = false;
        });
      } finally {
        image.dispose();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isGenerating = false;
      });
    }
  }

  String get _fileName {
    final number = widget.receipt.receiptNumber
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final format = _format == ReceiptImageFormat.a4 ? 'a4' : 'receipt';
    return 'gardi_${format}_${number.isEmpty ? 'image' : number}.png';
  }

  Future<void> _download() async {
    final bytes = _pngBytes;
    if (bytes == null) return;
    setState(() {
      _isExporting = true;
      _error = null;
      _success = null;
    });
    try {
      await widget.actions.download(bytes, _fileName);
      if (!mounted) return;
      setState(() {
        _success = 'وێنەی PNG بە سەرکەوتوویی دابەزێنرا.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _share() async {
    final bytes = _pngBytes;
    if (bytes == null) return;
    setState(() {
      _isExporting = true;
      _error = null;
      _success = null;
    });
    try {
      await widget.actions.share(bytes, _fileName);
      if (!mounted) return;
      setState(() {
        _success = 'وێنەکە لە ڕێگەی شیتی هاوبەشکردنەوە کراوەتەوە.';
      });
    } catch (error) {
      if (!mounted) return;
      if (kIsWeb && error is UnsupportedError) {
        try {
          await widget.actions.download(bytes, _fileName);
          if (!mounted) return;
          setState(() {
            _success = 'هاوبەشکردن لەم وێبگەڕەدا بەردەست نییە؛ وێنەکە دابەزێنرا.';
          });
        } catch (downloadError) {
          if (!mounted) return;
          setState(() {
            _error = downloadError.toString().replaceFirst('Exception: ', '');
          });
        }
      } else {
        setState(() {
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final canvasWidth = _logicalWidth;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: screenSize.width < 620 ? screenSize.width - 32 : 588,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHeader(),
                const SizedBox(height: 12),
                if (_format == null)
                  _buildFormatChoices()
                else if (_pngBytes == null)
                  _buildGeneratingReceipt(canvasWidth)
                else
                  _buildImagePreview(screenSize, canvasWidth),
                if (_error != null) _buildMessage(_error!, isError: true),
                if (_success != null) _buildMessage(_success!),
                if (_pngBytes != null) ...[
                  const SizedBox(height: 12),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isExporting ? null : _download,
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Download'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _isExporting ? null : _share,
                            icon: const Icon(Icons.share_outlined),
                            label: const Text('Share'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_isExporting) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          IconButton(
            tooltip: 'داخستن',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Text(
                _pngBytes == null
                    ? 'دروستکردنی وێنەی پسوڵە'
                    : 'پێشبینینی وێنەی پسوڵە',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatChoices() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _generate(ReceiptImageFormat.a4),
              icon: const Icon(Icons.description_outlined),
              label: const Text('A4'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _generate(ReceiptImageFormat.receipt),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Receipt'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratingReceipt(double canvasWidth) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.65,
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: RepaintBoundary(
                key: _receiptKey,
                child: SizedBox(
                  width: canvasWidth,
                  child: ReceiptCanvas(
                    data: widget.receipt,
                    format: _format!,
                  ),
                ),
              ),
            ),
          ),
          if (_isGenerating)
            const Positioned(
              top: 8,
              right: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImagePreview(Size screenSize, double canvasWidth) {
    final imageWidth = canvasWidth < screenSize.width - 64
        ? canvasWidth
        : screenSize.width - 64;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: screenSize.height * 0.68),
      child: SingleChildScrollView(
        child: Image.memory(
          _pngBytes!,
          width: imageWidth,
          fit: BoxFit.fitWidth,
          errorBuilder: (context, error, stackTrace) => Text(
            'پێشبینینی وێنە سەرکەوتوو نەبوو: $error',
            textDirection: TextDirection.rtl,
          ),
        ),
      ),
    );
  }

  Widget _buildMessage(String message, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          message,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            color: isError ? Theme.of(context).colorScheme.error : Colors.green,
          ),
        ),
      ),
    );
  }
}

class ReceiptCanvas extends StatelessWidget {
  final ReceiptData data;
  final ReceiptImageFormat format;

  const ReceiptCanvas({super.key, required this.data, required this.format});

  bool get _isA4 => format == ReceiptImageFormat.a4;

  @override
  Widget build(BuildContext context) {
    final fontSize = _isA4 ? 20.0 : 14.0;
    final date = DateTime.tryParse(data.date ?? '');
    final receiptContent = DefaultTextStyle(
      style: TextStyle(
        color: const Color(0xFF171717),
        fontFamily: 'Rudaw',
        fontSize: fontSize,
        height: 1.35,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: GardiLogo(
              width: _isA4 ? 210 : 172,
              height: _isA4 ? 210 : 172,
            ),
          ),
          const SizedBox(height: 4),
          if (data.title.isEmpty)
            _marketCustomerHeader(data, fontSize + (_isA4 ? 6 : 3))
          else
            Center(
              child: Text(
                data.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: fontSize + (_isA4 ? 8 : 3),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 8),
          _receiptNumberDateRow(
            data.receiptNumber,
            date == null ? null : Formatters.date(date),
          ),
          if (data.title.isNotEmpty && data.partyName != null)
            _personInfoRow(
              data.partyLabel ?? 'لایەن',
              data.partyName!,
              data.partyPhone,
            )
          else if (data.title.isNotEmpty && data.partyPhone != null)
            _infoRow(
              'مۆبایلی لایەن',
              data.partyPhone!,
              valueDirection: TextDirection.ltr,
              boldValue: true,
            ),
          if (data.title.isNotEmpty && data.marketName != null)
            _infoRow('مارکێت', data.marketName!),
          if (data.paymentMethod != null)
            _infoRow('شێوازی پارەدان', data.paymentMethod!),
          if (data.salesmanName != null)
            _personInfoRow(
              data.salesmanLabel,
              data.salesmanName!,
              data.salesmanPhone,
            )
          else if (data.salesmanPhone != null)
            _infoRow(
              'مۆبایلی ${data.salesmanLabel}',
              data.salesmanPhone!,
              valueDirection: TextDirection.ltr,
              boldValue: true,
            ),
          if (data.employeeName != null)
            _personInfoRow(
              'کاشڤان / کارمەند',
              data.employeeName!,
              data.employeePhone,
            )
          else if (data.employeePhone != null)
            _infoRow(
              'مۆبایلی کارمەند',
              data.employeePhone!,
              valueDirection: TextDirection.ltr,
              boldValue: true,
            ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFF777777)),
          if (_isA4)
            _a4ItemsHeader(fontSize)
          else
            _receiptItemsHeader(fontSize),
          const Divider(color: Color(0xFF777777)),
          if (data.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'هیچ کاڵایەک لەم پسوڵەیەدا نییە.',
                textAlign: TextAlign.center,
              ),
            )
          else
            ...data.items.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final item = entry.value;
              return _isA4
                  ? _a4Item(item, fontSize, index)
                  : _receiptItem(item, fontSize, index);
            }),
          if (data.amounts.isNotEmpty) ...[
            const Divider(color: Color(0xFF777777)),
            ...data.amounts.map((amount) => _amountRow(amount, fontSize)),
          ],
          if (data.note != null) ...[
            const SizedBox(height: 8),
            const Divider(color: Color(0xFF777777)),
            Text('تێبینی: ${data.note}'),
          ],
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF777777)),
          Center(
            child: Text(
              'سوپاس بۆ مامەڵەکردنتان',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: fontSize),
            ),
          ),
        ],
      ),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.white,
        child: _isA4
            ? SizedBox(
                width: 793.6,
                height: 1122.56,
                child: Padding(
                  padding: const EdgeInsets.all(42),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: 709.6,
                      child: receiptContent,
                    ),
                  ),
                ),
              )
            : SizedBox(
                width: 302,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 8,
                  ),
                  child: receiptContent,
                ),
              ),
      ),
    );
  }

  Widget _marketCustomerHeader(ReceiptData data, double fontSize) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          data.marketName == null ? 'مارکێت' : 'مارکێت: ${data.marketName}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: fontSize + 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Text(
                '${data.partyLabel ?? 'بەڕێز'}${data.partyName == null ? '' : ': ${data.partyName}'}',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (data.partyPhone != null)
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  data.partyPhone!,
                  style: TextStyle(
                    fontSize: fontSize - 2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _infoRow(
    String label,
    String value, {
    TextDirection? valueDirection,
    bool boldValue = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
          Expanded(
            child: Directionality(
              textDirection: valueDirection ?? TextDirection.rtl,
              child: Text(
                value,
                style: TextStyle(
                  fontWeight: boldValue ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptNumberDateRow(String receiptNumber, String? date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'ژمارەی پسوڵە: '),
                  TextSpan(
                    text: receiptNumber,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
          if (date != null)
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                date,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _personInfoRow(String label, String name, String? phone) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              '$label: $name',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (phone != null) ...[
            const SizedBox(width: 4),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                phone,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _a4ItemsHeader(double fontSize) {
    return Row(
      children: [
        Expanded(flex: 6, child: Text('کاڵا', style: _headerStyle(fontSize))),
        Expanded(flex: 3, child: Text('بڕ', style: _headerStyle(fontSize))),
        Expanded(flex: 3, child: Text('کۆ', style: _headerStyle(fontSize))),
      ],
    );
  }

  Widget _receiptItemsHeader(double fontSize) {
    return Text('کاڵاکان', style: _headerStyle(fontSize + 1));
  }

  Widget _a4Item(ReceiptItem item, double fontSize, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 6,
            child: _itemName(item, fontSize, index),
          ),
          Expanded(
            flex: 3,
            child: _ltr(_receiptQuantity(item), bold: true),
          ),
          Expanded(flex: 3, child: _ltr(Formatters.currency(item.total))),
        ],
      ),
    );
  }

  Widget _receiptItem(ReceiptItem item, double fontSize, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 7,
                child: _itemName(item, fontSize, index, bold: true),
              ),
              Expanded(
                flex: 2,
                child: _ltr(
                  _receiptQuantity(item),
                  bold: true,
                  style: TextStyle(fontSize: fontSize - 1),
                ),
              ),
              Expanded(
                flex: 3,
                child: _ltr(
                  Formatters.currency(item.total),
                  bold: true,
                  style: TextStyle(fontSize: fontSize - 1),
                  textAlign: TextAlign.left,
                ),
              ),
            ],
          ),
          const Divider(height: 8, color: Color(0xFFDDDDDD)),
        ],
      ),
    );
  }

  String _receiptQuantity(ReceiptItem item) {
    final quantity = Formatters.number(item.quantity);
    return '${item.unitsPerCarton}*$quantity';
  }

  Widget _itemName(
    ReceiptItem item,
    double fontSize,
    int index, {
    bool bold = false,
  }) {
    final note = item.note;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$index. ${item.name}',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
            if (note != null && note.trim().isNotEmpty)
              TextSpan(
                text: ' (تێبینی: ${note.trim()})',
                style: TextStyle(
                  fontSize: fontSize - 2,
                  color: const Color(0xFF666666),
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
        maxLines: 1,
        softWrap: false,
        textAlign: TextAlign.right,
      ),
    );
  }

  Widget _amountRow(ReceiptAmount amount, double fontSize) {
    final style = TextStyle(
      fontSize: fontSize + (amount.emphasized ? 2 : 0),
      fontWeight: amount.emphasized ? FontWeight.w700 : FontWeight.w400,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(amount.label, style: style)),
          _ltr(Formatters.currency(amount.amount), bold: true, style: style),
        ],
      ),
    );
  }

  Widget _ltr(
    String value, {
    bool bold = false,
    TextStyle? style,
    TextAlign textAlign = TextAlign.right,
  }) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        value,
        textAlign: textAlign,
        style: style?.copyWith(
          fontWeight: bold ? FontWeight.w700 : style.fontWeight,
        ) ??
            TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400),
      ),
    );
  }

  TextStyle _headerStyle(double fontSize) => TextStyle(
    fontSize: fontSize,
    fontWeight: FontWeight.w700,
  );
}
