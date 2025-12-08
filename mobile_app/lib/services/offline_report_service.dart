import 'dart:io';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Service for managing offline emergency reports
/// Stores reports locally when offline and syncs when connection is restored
class OfflineReportService {
  static final OfflineReportService _instance = OfflineReportService._internal();
  factory OfflineReportService() => _instance;
  OfflineReportService._internal();

  static Database? _database;
  final String _tableName = 'offline_reports';

  /// Initialize the database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'offline_reports.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        description TEXT,
        latitude REAL,
        longitude REAL,
        image_path TEXT,
        image_bytes BLOB,
        user_id TEXT,
        phone TEXT,
        timestamp TEXT,
        status TEXT DEFAULT 'pending',
        retry_count INTEGER DEFAULT 0,
        created_at TEXT,
        error_message TEXT
      )
    ''');
  }

  /// Save a report for offline submission
  Future<String> saveOfflineReport({
    required String? description,
    required double latitude,
    required double longitude,
    required File imageFile,
    String? userId,
    String? phone,
  }) async {
    final db = await database;
    final id = const Uuid().v4();
    final timestamp = DateTime.now().toIso8601String();

    // Read image bytes
    final imageBytes = await imageFile.readAsBytes();

    // Get image file path (relative path for storage reference)
    final imagePath = imageFile.path;

    await db.insert(
      _tableName,
      {
        'id': id,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'image_path': imagePath,
        'image_bytes': imageBytes,
        'user_id': userId,
        'phone': phone,
        'timestamp': timestamp,
        'status': 'pending',
        'retry_count': 0,
        'created_at': timestamp,
        'error_message': null,
      },
    );

    print('✅ Offline report saved: $id');
    return id;
  }

  /// Get all pending offline reports
  Future<List<Map<String, dynamic>>> getPendingReports() async {
    final db = await database;
    return await db.query(
      _tableName,
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );
  }

  /// Get all offline reports (including failed)
  Future<List<Map<String, dynamic>>> getAllOfflineReports() async {
    final db = await database;
    return await db.query(
      _tableName,
      orderBy: 'created_at DESC',
    );
  }

  /// Get a specific offline report by ID
  Future<Map<String, dynamic>?> getOfflineReport(String id) async {
    final db = await database;
    final results = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (results.isEmpty) return null;
    return results.first;
  }

  /// Update report status after sync attempt
  Future<void> updateReportStatus(
    String id, {
    String? status,
    String? errorMessage,
    int? retryCount,
  }) async {
    final db = await database;
    final updates = <String, dynamic>{};

    if (status != null) updates['status'] = status;
    if (errorMessage != null) updates['error_message'] = errorMessage;
    if (retryCount != null) updates['retry_count'] = retryCount;

    if (updates.isNotEmpty) {
      await db.update(
        _tableName,
        updates,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  /// Delete a synced report
  Future<void> deleteReport(String id) async {
    // Get report first to get image path
    final report = await getOfflineReport(id);
    
    final db = await database;
    await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    print('🗑️ Offline report deleted: $id');

    // Also try to delete the image file if it exists
    if (report != null && report['image_path'] != null) {
      try {
        final imageFile = File(report['image_path'] as String);
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      } catch (e) {
        print('⚠️ Could not delete image file: $e');
      }
    }
  }

  /// Get count of pending reports
  Future<int> getPendingCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $_tableName WHERE status = ?',
      ['pending'],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Clear all reports (for testing/debugging)
  Future<void> clearAllReports() async {
    final db = await database;
    
    // Clean up image files first
    final reports = await getAllOfflineReports();
    for (final report in reports) {
      if (report['image_path'] != null) {
        try {
          final imageFile = File(report['image_path'] as String);
          if (await imageFile.exists()) {
            await imageFile.delete();
          }
        } catch (e) {
          print('⚠️ Could not delete image file: $e');
        }
      }
    }
    
    await db.delete(_tableName);
  }

  /// Convert offline report to FormData format for submission
  Map<String, dynamic> toFormData(Map<String, dynamic> report) {
    return {
      'description': report['description'] ?? 'Emergency reported from mobile app',
      'lat': report['latitude'].toString(),
      'lng': report['longitude'].toString(),
      'phone': report['phone'],
      'timestamp': report['timestamp'],
      if (report['user_id'] != null) 'user_id': report['user_id'],
    };
  }

  /// Get image file from offline report
  Future<File?> getImageFile(String reportId) async {
    final report = await getOfflineReport(reportId);
    if (report == null || report['image_path'] == null) return null;

    final imageFile = File(report['image_path'] as String);
    if (await imageFile.exists()) {
      return imageFile;
    }

    // If file doesn't exist but we have bytes, recreate it
    if (report['image_bytes'] != null) {
      try {
        final bytes = report['image_bytes'] as Uint8List;
        await imageFile.writeAsBytes(bytes);
        return imageFile;
      } catch (e) {
        print('❌ Error recreating image file: $e');
        return null;
      }
    }

    return null;
  }
}
