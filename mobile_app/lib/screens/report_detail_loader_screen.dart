import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'report_detail_edit_screen.dart';

/// Loads a report by ID from Supabase then shows [ReportDetailEditScreen].
/// Used when navigating from push notification tap or in-app notification.
class ReportDetailLoaderScreen extends StatefulWidget {
  final String reportId;

  const ReportDetailLoaderScreen({
    super.key,
    required this.reportId,
  });

  @override
  State<ReportDetailLoaderScreen> createState() => _ReportDetailLoaderScreenState();
}

class _ReportDetailLoaderScreenState extends State<ReportDetailLoaderScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _report;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    if (widget.reportId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Invalid report ID';
      });
      return;
    }
    try {
      final response = await SupabaseService.client
          .from('reports')
          .select('''
            *,
            responder:responder_id(id, name, role)
          ''')
          .eq('id', widget.reportId)
          .maybeSingle();

      if (!mounted) return;
      if (response != null && response is Map<String, dynamic>) {
        final report = Map<String, dynamic>.from(response);
        // Enrich with assignment_status if available
        try {
          final assignmentResponse = await SupabaseService.client
              .from('assignment')
              .select('status, responder:responder_id(id, name, role)')
              .eq('report_id', widget.reportId)
              .inFilter('status', ['assigned', 'accepted', 'enroute', 'on_scene'])
              .order('assigned_at', ascending: false)
              .limit(1);
          if (assignmentResponse != null && assignmentResponse.isNotEmpty) {
            final a = assignmentResponse[0] as Map<String, dynamic>;
            report['assignment_status'] = a['status'];
            if (a['responder'] != null) {
              final r = a['responder'] as Map<String, dynamic>;
              report['responder_name'] = r['name'];
              report['responder_role'] = r['role'];
            }
          }
        } catch (_) {}
        setState(() {
          _report = report;
          _loading = false;
          _error = null;
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'Report not found';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load report: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null || _report == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Report details')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  _error ?? 'Report not found',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return ReportDetailEditScreen(report: _report!);
  }
}
