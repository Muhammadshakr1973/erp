import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/features/shared/models/receipt_data.dart';
import 'package:pos_app/features/shared/services/receipt_print_service.dart';

void main() {
  testWidgets('renders receipt text RTL and keeps long item names', (
    tester,
  ) async {
    const longName = 'کاڵای زۆر درێژی تاقیکردنەوە';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReceiptCanvas(
            format: ReceiptImageFormat.receipt,
            data: const ReceiptData(
              title: 'پسوڵە',
              receiptNumber: 'R-1',
              items: [
                ReceiptItem(
                  name: longName,
                  quantity: 1,
                  unitPrice: 1000,
                  total: 1000,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final item = find.text(longName);
    expect(item, findsOneWidget);
    expect(Directionality.of(tester.element(item)), TextDirection.rtl);
  });

  testWidgets('renders an explicit empty-items message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReceiptCanvas(
            format: ReceiptImageFormat.receipt,
            data: ReceiptData(title: 'پسوڵە', receiptNumber: 'R-2'),
          ),
        ),
      ),
    );

    expect(find.text('هیچ کاڵایەک لەم پسوڵەیەدا نییە.'), findsOneWidget);
  });

  testWidgets('exports the same PNG bytes for Download and Share', (
    tester,
  ) async {
    final actions = _FakeReceiptImageActions();
    await _openReceiptPreview(tester, actions);

    expect(find.text('A4'), findsNothing);
    expect(find.text('Receipt'), findsNothing);
    expect(find.text('Print'), findsNothing);

    await tester.tap(find.text('Download'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    await tester.tap(find.text('Share'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(actions.downloadedBytes, isNotNull);
    expect(actions.sharedBytes, same(actions.downloadedBytes));
    expect(actions.sharedBytes!.take(8).toList(), [
      137,
      80,
      78,
      71,
      13,
      10,
      26,
      10,
    ]);
    expect(
      ByteData.sublistView(actions.sharedBytes!).getUint32(16, Endian.big),
      576,
    );
  });

  testWidgets('creates an A4 PNG with A4 pixel dimensions', (tester) async {
    final actions = _FakeReceiptImageActions();
    await _openReceiptPreview(tester, actions, format: 'A4');

    await tester.tap(find.text('Share'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    final png = ByteData.sublistView(actions.sharedBytes!);
    expect(png.getUint32(16, Endian.big), 2480);
    expect(png.getUint32(20, Endian.big), 3508);
  });

  testWidgets('shows image save errors to the user', (tester) async {
    final actions = _FakeReceiptImageActions(
      downloadError: StateError('File output failed'),
    );
    await _openReceiptPreview(tester, actions);

    await tester.tap(find.text('Download'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.textContaining('File output failed'), findsOneWidget);
  });

  testWidgets('shows share errors to the user', (tester) async {
    final actions = _FakeReceiptImageActions(
      shareError: StateError('Share failed'),
    );
    await _openReceiptPreview(tester, actions);

    await tester.tap(find.text('Share'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(find.textContaining('Share failed'), findsOneWidget);
  });
}

Future<void> _openReceiptPreview(
  WidgetTester tester,
  ReceiptImageActions actions, {
  String format = 'Receipt',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                ReceiptPrintService.show(
                  context,
                  const ReceiptData(
                    title: 'پسوڵەی فرۆشتن',
                    receiptNumber: 'S-1',
                  ),
                  actions: actions,
                );
              },
              child: const Text('Create'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Create'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(format));

  for (var frame = 0; frame < 40; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (find.text('Download').evaluate().isNotEmpty) break;
  }
  expect(find.text('Download'), findsOneWidget);
  expect(find.text('Share'), findsOneWidget);
}

class _FakeReceiptImageActions implements ReceiptImageActions {
  final Object? downloadError;
  final Object? shareError;
  Uint8List? downloadedBytes;
  Uint8List? sharedBytes;

  _FakeReceiptImageActions({this.downloadError, this.shareError});

  @override
  Future<void> download(Uint8List bytes, String fileName) async {
    if (downloadError != null) throw downloadError!;
    downloadedBytes = bytes;
  }

  @override
  Future<void> share(Uint8List bytes, String fileName) async {
    if (shareError != null) throw shareError!;
    sharedBytes = bytes;
  }
}
