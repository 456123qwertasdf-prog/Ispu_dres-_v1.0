import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/supabase_service.dart';

class MyReportsScreen extends StatefulWidget {
  /// When set (e.g. from notification tap), scroll to and highlight this report after load.
  final String? highlightReportId;

  const MyReportsScreen({super.key, this.highlightReportId});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  final List<EmergencyReport> _reports = [];
  bool _isLoading = true;
  String? _errorMessage;
  final GlobalKey _highlightCardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    final userId = SupabaseService.currentUserId;

    if (userId == null) {
      setState(() {
        _isLoading = false;
        _reports.clear();
        _errorMessage = 'Please sign in to view your reports.';
      });
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await SupabaseService.client
          .from('reports')
          .select(
              'id, type, status, lifecycle_status, priority, severity, confidence, ai_confidence, ai_description, message, location, created_at')
          .eq('reporter_uid', userId)
          .order('created_at', ascending: false);

      final data = (response as List<dynamic>? ?? [])
          .map((item) => EmergencyReport.fromMap(
              Map<String, dynamic>.from(item as Map<String, dynamic>)))
          .toList();

      if (!mounted) return;

      setState(() {
        _reports
          ..clear()
          ..addAll(data);
        _errorMessage = null;
      });

      if (widget.highlightReportId != null && _reports.any((r) => r.id == widget.highlightReportId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToReport(widget.highlightReportId!);
        });
      }
    } catch (error) {
      final friendly = _cleanError(error);
      if (!mounted) return;
      setState(() {
        _errorMessage = friendly;
        _reports.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load reports: $friendly'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _scrollToReport(String reportId) {
    if (_highlightCardKey.currentContext != null) {
      Scrollable.ensureVisible(
        _highlightCardKey.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.2,
      );
    }
  }

  String _cleanError(Object error) {
    final text = error.toString();
    if (text.startsWith('Exception: ')) {
      return text.substring(11);
    }
    return text;
  }

  int get _totalReports => _reports.length;
  int get _resolvedReports =>
      _reports.where((r) => r.isResolved).toList().length;
  int get _assignedReports =>
      _reports.where((r) => r.isAssignedOrPending).toList().length;
  int get _highPriorityReports => _reports
      .where((r) =>
          r.priorityLabel == 'high' ||
          r.priorityLabel == 'critical' ||
          r.priorityLabel == 'urgent')
      .toList()
      .length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'My Reports',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF3b82f6),
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _loadReports,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF3b82f6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Fetching your reports...',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_reports.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: const Color(0xFF3b82f6),
      onRefresh: _loadReports,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildStatsGrid(),
          const SizedBox(height: 24),
          Text(
            'Reports History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Track every emergency you have submitted.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          ..._reports.map(
            (report) {
              final useHighlightKey = widget.highlightReportId != null && report.id == widget.highlightReportId;
              return Padding(
                key: useHighlightKey ? _highlightCardKey : null,
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildReportCard(report),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Unable to load reports',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Please try again later.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadReports,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3b82f6),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                Icons.note_alt_outlined,
                size: 56,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Reports Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Once you submit an emergency, it will appear here so you can monitor the response.',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/emergency-report'),
              icon: const Icon(Icons.emergency_outlined),
              label: const Text('Report an Emergency'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFef4444),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: [
        _buildStatCard(
          title: 'Total Reports',
          value: _totalReports.toString(),
          icon: Icons.history_rounded,
          color: const Color(0xFF3b82f6),
        ),
        _buildStatCard(
          title: 'Resolved',
          value: _resolvedReports.toString(),
          icon: Icons.verified_rounded,
          color: const Color(0xFF10b981),
        ),
        _buildStatCard(
          title: 'Assigned',
          value: _assignedReports.toString(),
          icon: Icons.assignment_turned_in_rounded,
          color: const Color(0xFFF59E0B),
        ),
        _buildStatCard(
          title: 'High Priority',
          value: _highPriorityReports.toString(),
          icon: Icons.priority_high_rounded,
          color: const Color(0xFFEF4444),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey.shade900,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(EmergencyReport report) {
    final accentColor = _typeAccentColor(report.typeLabel);
    final statusColor = _statusColor(report.statusLabel);
    final priorityColor = _priorityColor(report.priorityLabel);
    final confidenceLabel = _confidenceText(report);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.25), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getEmergencyEmoji(report.typeLabel),
                style: const TextStyle(fontSize: 32),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade900,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _buildBadge(
                          label: report.statusLabel.replaceAll('_', ' '),
                          color: statusColor,
                        ),
                        _buildBadge(
                          label:
                              '${report.priorityLabel.toUpperCase()} priority',
                          color: priorityColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(14),
            child: Text(
              report.descriptionText,
              style: TextStyle(
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_outlined,
                color: Colors.grey.shade500,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _formatLocation(report),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                color: Colors.grey.shade500,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                _formatDate(report.createdAt),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          if (confidenceLabel != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE0ECFF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFF1D4ED8),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    confidenceLabel,
                    style: const TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _typeAccentColor(String type) {
    switch (type) {
      case 'fire':
        return const Color(0xFFEF4444);
      case 'medical':
        return const Color(0xFFE11D48);
      case 'accident':
        return const Color(0xFFF97316);
      case 'flood':
        return const Color(0xFF2563EB);
      case 'earthquake':
        return const Color(0xFF7C3AED);
      case 'storm':
        return const Color(0xFF0EA5E9);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'resolved':
      case 'completed':
      case 'closed':
        return const Color(0xFF10B981);
      case 'assigned':
      case 'accepted':
      case 'classified':
      case 'in_progress':
      case 'enroute':
      case 'on_scene':
        return const Color(0xFFF59E0B);
      case 'pending':
      default:
        return const Color(0xFF3B82F6);
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'critical':
      case 'urgent':
      case 'high':
        return const Color(0xFFEF4444);
      case 'medium':
        return const Color(0xFFF97316);
      case 'low':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF6366F1);
    }
  }

  String? _confidenceText(EmergencyReport report) {
    final confidence = report.normalizedConfidence;
    if (confidence == null) {
      return null;
    }
    final percent =
        (confidence * 100).clamp(0, 100).toStringAsFixed(confidence < 0.1 ? 1 : 0);
    return 'AI confidence: $percent%';
  }

  String _formatLocation(EmergencyReport report) {
    final location = report.parsedLocation;
    if (location == null) {
      return 'Location not specified';
    }

    final address = location['address'] ??
        location['formatted'] ??
        location['description'];

    if (address is String && address.trim().isNotEmpty) {
      return address.trim();
    }

    final lat = _doubleFrom(location['lat'] ?? location['latitude']);
    final lng = _doubleFrom(location['lng'] ?? location['longitude']);

    if (lat != null && lng != null) {
      return 'Lat ${lat.toStringAsFixed(4)}, Lng ${lng.toStringAsFixed(4)}';
    }

    return 'Location detected';
  }

  double? _doubleFrom(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Unknown time';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final month = months[date.month - 1];
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    return '$month ${date.day}, ${date.year} • $hour:$minute $amPm';
  }

  String _getEmergencyEmoji(String type) {
    switch (type) {
      case 'fire':
        return '🔥';
      case 'medical':
        return '🏥';
      case 'accident':
        return '🚗';
      case 'flood':
        return '🌊';
      case 'earthquake':
        return '🌍';
      case 'storm':
        return '⛈️';
      default:
        return '⚠️';
    }
  }
}

class EmergencyReport {
  EmergencyReport({
    required this.id,
    this.type,
    this.status,
    this.lifecycleStatus,
    this.priority,
    this.severity,
    this.confidence,
    this.aiConfidence,
    this.aiDescription,
    this.message,
    this.location,
    this.createdAt,
  });

  final String id;
  final String? type;
  final String? status;
  final String? lifecycleStatus;
  final dynamic priority;
  final String? severity;
  final dynamic confidence;
  final dynamic aiConfidence;
  final String? aiDescription;
  final String? message;
  final dynamic location;
  final DateTime? createdAt;

  factory EmergencyReport.fromMap(Map<String, dynamic> map) {
    return EmergencyReport(
      id: map['id']?.toString() ?? '',
      type: map['type'] as String?,
      status: map['status'] as String?,
      lifecycleStatus: map['lifecycle_status'] as String?,
      priority: map['priority'],
      severity: map['severity'] as String?,
      confidence: map['confidence'],
      aiConfidence: map['ai_confidence'],
      aiDescription: map['ai_description'] as String?,
      message: (map['description'] ?? map['message']) as String?,
      location: map['location'],
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  String get typeLabel => (type ?? 'other').toLowerCase();

  String get statusLabel =>
      (status ?? lifecycleStatus ?? 'pending').toLowerCase();

  String get priorityLabel {
    final value = priority;
    if (value == null) return 'medium';

    if (value is String) {
      return value.toLowerCase();
    }
    if (value is num) {
      if (value <= 2) return 'high';
      if (value == 3) return 'medium';
      if (value == 4) return 'low';
      return value <= 1 ? 'high' : 'low';
    }
    return 'medium';
  }

  bool get isResolved =>
      {'resolved', 'completed', 'closed'}.contains(statusLabel);

  bool get isAssignedOrPending => {
        'pending',
        'assigned',
        'classified',
        'accepted',
        'in_progress',
        'enroute',
        'on_scene'
      }.contains(statusLabel);

  String get title {
    if (aiDescription != null && aiDescription!.contains('-')) {
      return aiDescription!;
    }
    if ((type ?? '').isNotEmpty) {
      return '${type!.toUpperCase()} Emergency';
    }
    return 'Emergency Report';
  }

  String get descriptionText =>
      (message != null && message!.trim().isNotEmpty)
          ? message!.trim()
          : 'No description provided';

  Map<String, dynamic>? get parsedLocation {
    if (location == null) {
      return null;
    }
    if (location is Map<String, dynamic>) {
      return location as Map<String, dynamic>;
    }
    if (location is String) {
      try {
        final decoded = jsonDecode(location as String);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  double? get normalizedConfidence {
    final raw = confidence ?? aiConfidence;
    if (raw == null) return null;

    double? value;
    if (raw is num) {
      value = raw.toDouble();
    } else if (raw is String) {
      value = double.tryParse(raw);
    }

    if (value == null) return null;

    if (value > 1) {
      value = value / 100;
    }

    final normalized = value.clamp(0, 1);
    return normalized.toDouble();
  }
}

