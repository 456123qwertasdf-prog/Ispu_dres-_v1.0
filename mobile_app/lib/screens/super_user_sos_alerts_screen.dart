import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/supabase_service.dart';

class SuperUserSOSAlertsScreen extends StatefulWidget {
  const SuperUserSOSAlertsScreen({super.key});

  @override
  State<SuperUserSOSAlertsScreen> createState() => _SuperUserSOSAlertsScreenState();
}

class _SuperUserSOSAlertsScreenState extends State<SuperUserSOSAlertsScreen> {
  List<Map<String, dynamic>> _alerts = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _filterStatus = 'All';
  
  // Stats
  int _totalAlerts = 0;
  int _activeAlerts = 0;
  int _acknowledgedAlerts = 0;
  int _resolvedAlerts = 0;

  @override
  void initState() {
    super.initState();
    _loadSOSAlerts();
  }

  Future<void> _loadSOSAlerts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await SupabaseService.client
          .from('sos_alerts')
          .select('*')
          .order('created_at', ascending: false);

      if (response != null) {
        final alerts = response as List;
        
        setState(() {
          _alerts = List<Map<String, dynamic>>.from(alerts);
          _updateStats();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load SOS alerts: $e';
        _isLoading = false;
      });
    }
  }

  void _updateStats() {
    _totalAlerts = _alerts.length;
    _activeAlerts = _alerts.where((a) => (a['status']?.toString() ?? '').toLowerCase() == 'active').length;
    _acknowledgedAlerts = _alerts.where((a) => (a['status']?.toString() ?? '').toLowerCase() == 'acknowledged').length;
    _resolvedAlerts = _alerts.where((a) => (a['status']?.toString() ?? '').toLowerCase() == 'resolved').length;
  }

  List<Map<String, dynamic>> get _filteredAlerts {
    if (_filterStatus == 'All') return _alerts;
    return _alerts.where((a) {
      final status = (a['status'] ?? '').toString().toLowerCase();
      return status == _filterStatus.toLowerCase();
    }).toList();
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return const Color(0xFFef4444);
      case 'acknowledged':
        return const Color(0xFFf59e0b);
      case 'resolved':
        return const Color(0xFF10b981);
      default:
        return Colors.grey;
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

  Future<void> _acknowledgeAlert(String alertId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Acknowledge Alert'),
        content: const Text('Acknowledge this SOS alert? This will mark it as acknowledged.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Acknowledge'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final currentUser = SupabaseService.currentUser;
      await SupabaseService.client
          .from('sos_alerts')
          .update({
            'status': 'acknowledged',
            'acknowledged_by': currentUser?.id,
            'acknowledged_at': DateTime.now().toIso8601String(),
          })
          .eq('id', alertId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ SOS alert acknowledged successfully'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadSOSAlerts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to acknowledge alert: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resolveAlert(String alertId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resolve Alert'),
        content: const Text('Resolve this SOS alert? This will mark it as resolved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await SupabaseService.client
          .from('sos_alerts')
          .update({
            'status': 'resolved',
            'resolved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', alertId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ SOS alert resolved successfully'),
          backgroundColor: Colors.green,
        ),
      );

      await _loadSOSAlerts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to resolve alert: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _viewOnMap(double latitude, double longitude) async {
    final url = Uri.parse('https://www.google.com/maps?q=$latitude,$longitude');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open map'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showAlertDetails(Map<String, dynamic> alert) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning,
                    color: Color(0xFFef4444),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'SOS Alert Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Alert ID', alert['id']?.toString() ?? 'N/A'),
                    const SizedBox(height: 12),
                    _buildDetailRow('Reporter', alert['reporter_name']?.toString() ?? 'Anonymous'),
                    const SizedBox(height: 12),
                    _buildDetailRowWidget('Status', _buildStatusBadge(alert['status']?.toString() ?? '')),
                    const SizedBox(height: 12),
                    _buildDetailRow('Location', alert['location_address']?.toString() ?? 'No address available'),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      'Coordinates',
                      '${(alert['latitude'] ?? 0).toStringAsFixed(6)}, ${(alert['longitude'] ?? 0).toStringAsFixed(6)}',
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow('Created At', _formatDate(alert['created_at']?.toString())),
                    if (alert['acknowledged_at'] != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow('Acknowledged At', _formatDate(alert['acknowledged_at']?.toString())),
                    ],
                    if (alert['resolved_at'] != null) ...[
                      const SizedBox(height: 12),
                      _buildDetailRow('Resolved At', _formatDate(alert['resolved_at']?.toString())),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          final lat = (alert['latitude'] ?? 0) as double;
                          final lng = (alert['longitude'] ?? 0) as double;
                          _viewOnMap(lat, lng);
                        },
                        icon: const Icon(Icons.map),
                        label: const Text('View on Map'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF3b82f6),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRowWidget(String label, Widget value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        value,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return _buildDetailRowWidget(
      label,
      Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final statusColor = _getStatusColor(status);
    final statusText = status.isEmpty ? 'Unknown' : status[0].toUpperCase() + status.substring(1);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: statusColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SOS Emergency Alerts',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFFef4444),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSOSAlerts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Cards
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFef4444),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard('Total', _totalAlerts, Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard('Active', _activeAlerts, Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard('Acknowledged', _acknowledgedAlerts, Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard('Resolved', _resolvedAlerts, Colors.white),
                ),
              ],
            ),
          ),
          // Filter Chips
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Active'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Acknowledged'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Resolved'),
                ],
              ),
            ),
          ),
          // Alerts List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.grey.shade600),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadSOSAlerts,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _filteredAlerts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.warning_outlined,
                                    size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'No SOS alerts found',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadSOSAlerts,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filteredAlerts.length,
                              itemBuilder: (context, index) {
                                final alert = _filteredAlerts[index];
                                return _buildAlertCard(alert);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, int value, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: textColor.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filterStatus == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterStatus = label;
        });
      },
      selectedColor: const Color(0xFFef4444).withOpacity(0.2),
      checkmarkColor: const Color(0xFFef4444),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFFef4444) : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final status = alert['status']?.toString() ?? 'Unknown';
    final reporterName = alert['reporter_name']?.toString() ?? 'Anonymous';
    final location = alert['location_address']?.toString() ?? 
        '${(alert['latitude'] ?? 0).toStringAsFixed(6)}, ${(alert['longitude'] ?? 0).toStringAsFixed(6)}';
    final createdAt = alert['created_at']?.toString();
    final statusColor = _getStatusColor(status);
    final isActive = status.toLowerCase() == 'active';
    final isAcknowledged = status.toLowerCase() == 'acknowledged';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showAlertDetails(alert),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.warning,
                      color: Color(0xFFef4444),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SOS Emergency',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 24),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      reporterName,
                      style: TextStyle(
                        color: Colors.grey.shade800,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      location,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(createdAt),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (isActive)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _acknowledgeAlert(alert['id']?.toString() ?? ''),
                        icon: const Icon(Icons.check_circle, size: 16),
                        label: const Text('Acknowledge'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFf59e0b),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  if (isActive || isAcknowledged) ...[
                    if (isActive) const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _resolveAlert(alert['id']?.toString() ?? ''),
                        icon: const Icon(Icons.done_all, size: 16),
                        label: const Text('Resolve'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF10b981),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
