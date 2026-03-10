import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../utils/report_date_helper.dart';
import 'report_detail_edit_screen.dart';

class SuperUserReportsScreen extends StatefulWidget {
  const SuperUserReportsScreen({super.key});

  @override
  State<SuperUserReportsScreen> createState() => _SuperUserReportsScreenState();
}

class _SuperUserReportsScreenState extends State<SuperUserReportsScreen> {
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _filterStatus = 'All';

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await SupabaseService.client
          .from('reports')
          .select('''
            *,
            responder:responder_id(id, name, role)
          ''')
          .order('created_at', ascending: false)
          .limit(100);

      if (response != null) {
        final reports = response as List;
        
        // Fetch assignment data for each report to get responder status
        final reportsWithAssignments = await Future.wait(
          reports.map((report) async {
            try {
              final reportId = report['id']?.toString();
              if (reportId == null) return report;
              
              final assignmentResponse = await SupabaseService.client
                  .from('assignment')
                  .select('status, responder:responder_id(id, name, role)')
                  .eq('report_id', reportId)
                  .inFilter('status', ['assigned', 'accepted', 'enroute', 'on_scene'])
                  .order('assigned_at', ascending: false)
                  .limit(1);
              
              if (assignmentResponse != null && assignmentResponse.isNotEmpty) {
                final assignment = assignmentResponse[0] as Map<String, dynamic>;
                report['assignment_status'] = assignment['status'];
                if (assignment['responder'] != null) {
                  final responder = assignment['responder'] as Map<String, dynamic>;
                  report['responder_name'] = responder['name'];
                  report['responder_role'] = responder['role'];
                }
              }
            } catch (e) {
              // Ignore assignment fetch errors
              print('Could not load assignment for report: $e');
            }
            return report;
          }),
        );
        
        setState(() {
          _reports = List<Map<String, dynamic>>.from(reportsWithAssignments);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load reports: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredReports {
    if (_filterStatus == 'All') return _reports;
    return _reports.where((r) {
      final status = (r['status'] ?? '').toString().toLowerCase();
      return status == _filterStatus.toLowerCase();
    }).toList();
  }

  String _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'resolved':
      case 'completed':
        return 'green';
      case 'pending':
      case 'assigned':
        return 'orange';
      case 'active':
        return 'red';
      default:
        return 'blue';
    }
  }

  /// Human-readable title from AI classification (e.g. "Medical Emergency - Sports Injury") or type.
  String _getReportDisplayTitle(Map<String, dynamic> report) {
    final aiDesc = report['ai_description']?.toString()?.trim();
    if (aiDesc != null && aiDesc.isNotEmpty && aiDesc.contains('-')) {
      return aiDesc;
    }
    final type = report['type']?.toString()?.trim();
    if (type != null && type.isNotEmpty) {
      return '${type[0].toUpperCase()}${type.substring(1).toLowerCase()} Emergency';
    }
    return 'Emergency Report';
  }

  String _getTypeEmoji(String? type) {
    switch (type?.toLowerCase()) {
      case 'fire':
        return '🔥';
      case 'medical':
        return '🏥';
      case 'accident':
        return '🚗';
      case 'flood':
        return '🌊';
      case 'storm':
        return '⛈️';
      case 'earthquake':
        return '🌍';
      default:
        return '⚠️';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy • h:mm a').format(date.toLocal());
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf1f5f9),
      appBar: AppBar(
        title: const Text(
          'Recent Reports',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2563eb), Color(0xFF1d4ed8)],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadReports,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All'),
                  const SizedBox(width: 10),
                  _buildFilterChip('Pending'),
                  const SizedBox(width: 10),
                  _buildFilterChip('Assigned'),
                  const SizedBox(width: 10),
                  _buildFilterChip('Active'),
                  const SizedBox(width: 10),
                  _buildFilterChip('Resolved'),
                ],
              ),
            ),
          ),
          // Reports List
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF3b82f6),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading reports...',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFfef2f2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.error_outline_rounded,
                                  size: 48,
                                  color: Colors.red.shade400,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: _loadReports,
                                icon: const Icon(Icons.refresh_rounded, size: 20),
                                label: const Text('Retry'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF3b82f6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _filteredReports.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFeff6ff),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.assignment_outlined,
                                    size: 56,
                                    color: Colors.blue.shade300,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'No reports found',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadReports,
                            color: const Color(0xFF3b82f6),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredReports.length,
                              itemBuilder: (context, index) {
                                final report = _filteredReports[index];
                                return _buildReportCard(report);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filterStatus == label;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _filterStatus = label),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF3b82f6)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF3b82f6).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    final type = report['type']?.toString() ?? 'Unknown';
    final status = report['status']?.toString() ?? 'Unknown';
    final message = report['message']?.toString() ?? 'No description';
    final displayTitle = _getReportDisplayTitle(report);
    final createdAt = report['created_at']?.toString();
    final createdAtFormatted = ReportDateHelper.formatReportCreatedAt(createdAt);
    final reporterName = report['reporter_name']?.toString() ?? 'Unknown';
    final statusColor = _getStatusColor(status);
    final hasResponder = report['responder_id'] != null ||
        report['responder_name'] != null;
    final assignmentStatus = report['assignment_status']?.toString();
    final hasAiClassification = (report['ai_description']?.toString()?.trim() ?? '').isNotEmpty;

    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReportDetailEditScreen(report: report),
          ),
        );
        if (result == true) {
          // Reload reports if changes were saved
          _loadReports();
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border(
            left: BorderSide(
              color: _getStatusColorValue(statusColor),
              width: 4,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _getTypeEmoji(type),
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColorValue(statusColor)
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _getStatusColorValue(statusColor),
                                ),
                              ),
                            ),
                            if (hasResponder)
                              _buildAssignmentStatusBadge(assignmentStatus),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.grey.shade400, size: 24),
                ],
              ),
              const SizedBox(height: 12),
              if (hasAiClassification)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 14, color: Colors.blue.shade700),
                      const SizedBox(width: 6),
                      Text(
                        'Identified: $displayTitle',
                        style: TextStyle(
                          color: Colors.blue.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              Text(
                message,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 14,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    reporterName,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    createdAtFormatted,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColorValue(String colorName) {
    switch (colorName) {
      case 'green':
        return const Color(0xFF10b981);
      case 'orange':
        return const Color(0xFFf97316);
      case 'red':
        return const Color(0xFFef4444);
      default:
        return const Color(0xFF3b82f6);
    }
  }

  Widget _buildAssignmentStatusBadge(String? assignmentStatus) {
    String label;
    IconData icon;
    Color color;
    
    if (assignmentStatus == 'enroute') {
      label = 'EN ROUTE';
      icon = Icons.local_shipping;
      color = const Color(0xFF3b82f6);
    } else if (assignmentStatus == 'on_scene') {
      label = 'ON SCENE';
      icon = Icons.location_on;
      color = const Color(0xFF0ea5e9);
    } else if (assignmentStatus == 'accepted') {
      label = 'ACCEPTED';
      icon = Icons.check_circle;
      color = const Color(0xFFf59e0b);
    } else {
      label = 'ASSIGNED';
      icon = Icons.person;
      color = Colors.green.shade700;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

