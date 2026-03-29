/// Service for reporting and persisting flagged AI-generated content.
///
/// Stores reports locally via [SharedPreferences] as JSON entries with
/// timestamps. This satisfies Apple App Store guideline 1.2 and Google
/// Play Deceptive Behavior policy by providing a user-facing mechanism
/// to flag problematic AI-generated content (BL-279).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// A single content report created when the player flags an AI response.
class ContentReport {
  /// The AI-generated text that was flagged.
  final String flaggedText;

  /// When the report was created.
  final DateTime timestamp;

  ContentReport({required this.flaggedText, required this.timestamp});

  Map<String, dynamic> toJson() => {
        'flaggedText': flaggedText,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ContentReport.fromJson(Map<String, dynamic> json) => ContentReport(
        flaggedText: json['flaggedText'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

/// Manages local storage of content reports via [SharedPreferences].
///
/// Reports are stored as a JSON string list under the key `content_reports`.
/// Each entry is a serialized [ContentReport] with the flagged text and an
/// ISO-8601 timestamp.
class ContentReportService {
  /// SharedPreferences key for the reports list.
  static const storageKey = 'content_reports';

  /// Flag [text] as inappropriate and persist the report.
  Future<void> reportContent(String text) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getStringList(storageKey) ?? [];
    final report = ContentReport(
      flaggedText: text,
      timestamp: DateTime.now(),
    );
    existing.add(jsonEncode(report.toJson()));
    await prefs.setStringList(storageKey, existing);
  }

  /// Retrieve all stored reports.
  Future<List<ContentReport>> getReports() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(storageKey) ?? [];
    return jsonList
        .map((s) =>
            ContentReport.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  /// Remove all stored reports.
  Future<void> clearReports() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }
}
