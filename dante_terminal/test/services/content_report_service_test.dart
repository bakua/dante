import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dante_terminal/services/content_report_service.dart';

void main() {
  group('ContentReportService', () {
    late ContentReportService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = ContentReportService();
    });

    test('reportContent stores a report with timestamp', () async {
      await service.reportContent('offensive text');

      final reports = await service.getReports();
      expect(reports.length, 1);
      expect(reports.first.flaggedText, 'offensive text');
      expect(
        reports.first.timestamp.difference(DateTime.now()).inSeconds.abs(),
        lessThan(5),
      );
    });

    test('multiple reports accumulate', () async {
      await service.reportContent('first');
      await service.reportContent('second');
      await service.reportContent('third');

      final reports = await service.getReports();
      expect(reports.length, 3);
      expect(reports[0].flaggedText, 'first');
      expect(reports[1].flaggedText, 'second');
      expect(reports[2].flaggedText, 'third');
    });

    test('getReports returns empty list when none stored', () async {
      final reports = await service.getReports();
      expect(reports, isEmpty);
    });

    test('clearReports removes all stored reports', () async {
      await service.reportContent('some text');
      expect((await service.getReports()).length, 1);

      await service.clearReports();
      expect(await service.getReports(), isEmpty);
    });

    test('reports persist as JSON in SharedPreferences', () async {
      await service.reportContent('test content');

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(ContentReportService.storageKey);
      expect(stored, isNotNull);
      expect(stored!.length, 1);

      final decoded = jsonDecode(stored.first) as Map<String, dynamic>;
      expect(decoded['flaggedText'], 'test content');
      expect(decoded['timestamp'], isA<String>());
    });
  });

  group('ContentReport', () {
    test('serializes to and from JSON', () {
      final report = ContentReport(
        flaggedText: 'bad content',
        timestamp: DateTime(2026, 3, 28, 12, 0, 0),
      );

      final json = report.toJson();
      expect(json['flaggedText'], 'bad content');
      expect(json['timestamp'], '2026-03-28T12:00:00.000');

      final restored = ContentReport.fromJson(json);
      expect(restored.flaggedText, 'bad content');
      expect(restored.timestamp, DateTime(2026, 3, 28, 12, 0, 0));
    });
  });
}
