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
        // Enrich with reporter real name: try user_profiles first, then get-users
        final reporterUid = report['reporter_uid']?.toString().trim();
        final reportUserId = report['user_id']?.toString().trim();
        final uidsToTry = <String>{
          if (reporterUid != null && reporterUid.isNotEmpty) reporterUid.toLowerCase(),
          if (reportUserId != null && reportUserId.isNotEmpty) reportUserId.toLowerCase(),
        };
        if (uidsToTry.isNotEmpty) {
          try {
            // 1) Try direct user_profiles read (works when current user has admin/super_user policy)
            for (final uid in uidsToTry) {
              final profileResponse = await SupabaseService.client
                  .from('user_profiles')
                  .select('name, email, student_number')
                  .eq('user_id', uid)
                  .maybeSingle();
              if (profileResponse != null && profileResponse is Map<String, dynamic>) {
                final name = profileResponse['name']?.toString().trim();
                if (name != null && name.isNotEmpty) {
                  report['reporter_full_name'] = name;
                  report['reporter_email'] = profileResponse['email']?.toString();
                  report['reporter_student_number'] = profileResponse['student_number']?.toString();
                  break;
                }
              }
            }
            // 2) If still no real name, try get-users (service role returns all users)
            if (report['reporter_full_name'] == null ||
                (report['reporter_full_name'] as String).isEmpty) {
              final usersResponse = await SupabaseService.client.functions.invoke(
                'get-users',
                body: {},
              );
              final data = usersResponse.data;
              if (data is Map && data['users'] is List) {
                final users = data['users'] as List;
                for (final u in users) {
                  if (u is! Map) continue;
                  final uid = (u['user_id']?.toString() ?? u['id']?.toString() ?? '')
                      .trim()
                      .toLowerCase();
                  if (uid.isEmpty) continue;
                  if (uidsToTry.contains(uid)) {
                    final fullName = u['name']?.toString().trim() ??
                        u['full_name']?.toString().trim() ??
                        report['reporter_name']?.toString();
                    if (fullName != null && fullName.isNotEmpty) {
                      report['reporter_full_name'] = fullName;
                    }
                    report['reporter_email'] = u['email']?.toString();
                    report['reporter_phone'] = u['phone']?.toString() ?? u['contactNumber']?.toString();
                    report['reporter_student_number'] =
                        u['student_number']?.toString() ?? u['studentNumber']?.toString();
                    break;
                  }
                }
              }
            }
          } catch (_) {}
        }
        // Enrich with assignment_status if available
        try {
          final assignmentResponse = await SupabaseService.client
              .from('assignment')
              .select('status, needs_backup, responder:responder_id(id, name, role, needs_assistance)')
              .eq('report_id', widget.reportId)
              .inFilter('status', ['assigned', 'accepted', 'enroute', 'on_scene'])
              .order('assigned_at', ascending: false)
              .limit(1);
          if (assignmentResponse != null && assignmentResponse.isNotEmpty) {
            final a = assignmentResponse[0] as Map<String, dynamic>;
            report['assignment_status'] = a['status'];
            report['assignment_needs_backup'] = a['needs_backup'] == true;
            if (a['responder'] != null) {
              final r = a['responder'] as Map<String, dynamic>;
              report['responder_name'] = r['name'];
              report['responder_role'] = r['role'];
              report['responder_needs_assistance'] = r['needs_assistance'] == true;
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
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          title: const Text(
            'Report details',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Loading report...',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_error != null || _report == null) {
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          title: const Text(
            'Report details',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 56,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _error ?? 'Report not found',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  label: const Text('Back'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
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
