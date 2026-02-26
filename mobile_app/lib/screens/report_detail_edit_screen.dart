import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

class ReportDetailEditScreen extends StatefulWidget {
  final Map<String, dynamic> report;

  const ReportDetailEditScreen({
    super.key,
    required this.report,
  });

  @override
  State<ReportDetailEditScreen> createState() => _ReportDetailEditScreenState();
}

class _ReportDetailEditScreenState extends State<ReportDetailEditScreen> {
  bool _isEditMode = false;
  bool _isLoading = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _responders = [];
  List<Map<String, dynamic>> _ungroupedResponders = [];
  List<({String label, List<Map<String, dynamic>> responders})> _responderTeams = [];
  Map<String, dynamic>? _currentAssignment;
  /// Responder IDs that already have an active assignment (cannot assign another until finished).
  Set<String> _busyResponderIds = {};

  // Form controllers
  late TextEditingController _messageController;
  String _selectedType = 'other';
  String _selectedStatus = 'pending';
  String _selectedLifecycleStatus = 'pending';
  String? _selectedResponderId;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    _loadResponders();
    _loadAssignment();
  }

  void _initializeForm() {
    _messageController = TextEditingController(
      text: widget.report['message']?.toString() ?? '',
    );
    _selectedType = widget.report['type']?.toString() ?? 'other';
    _selectedStatus = widget.report['status']?.toString() ?? 'pending';
    _selectedLifecycleStatus =
        widget.report['lifecycle_status']?.toString() ?? 'pending';
    _selectedResponderId = widget.report['responder_id']?.toString();
  }

  static const List<String> _activeAssignmentStatuses = [
    'assigned', 'accepted', 'enroute', 'in_progress', 'on_scene',
  ];

  /// Server-side check: which of [responderIds] have an active assignment to a *different* report.
  /// When assigning to [reportId], pass it so we only treat "busy" as having another report's assignment.
  Future<Set<String>> _fetchBusyResponderIdsFromServer(List<String> responderIds, {String? reportId}) async {
    if (responderIds.isEmpty) return {};
    try {
      var query = SupabaseService.client
          .from('assignment')
          .select('responder_id')
          .inFilter('responder_id', responderIds)
          .inFilter('status', _activeAssignmentStatuses);
      if (reportId != null && reportId.isNotEmpty) {
        query = query.neq('report_id', reportId);
      }
      final response = await query;
      if (response == null || response.isEmpty) return {};
      final list = response as List;
      return list
          .map((a) => (a['responder_id']?.toString().trim() ?? '').toLowerCase())
          .where((s) => s.isNotEmpty)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> _loadResponders() async {
    try {
      final response = await SupabaseService.client
          .from('responder')
          .select('id, name, role, is_available, status, leader_id, team_name')
          .eq('is_available', true)
          .order('name');

      if (response != null) {
        final list = List<Map<String, dynamic>>.from(response);
        _buildResponderTeams(list);
        final allIds = list.map((r) => r['id']?.toString()).whereType<String>().toList();
        if (allIds.isNotEmpty) {
          try {
            final reportId = widget.report['id']?.toString();
            var query = SupabaseService.client
                .from('assignment')
                .select('responder_id')
                .inFilter('responder_id', allIds)
                .inFilter('status', _activeAssignmentStatuses);
            if (reportId != null && reportId.isNotEmpty) {
              query = query.neq('report_id', reportId);
            }
            final activeAssignments = await query;
            if (activeAssignments != null && activeAssignments.isNotEmpty) {
              _busyResponderIds = (activeAssignments as List)
                  .map((a) => a['responder_id']?.toString())
                  .whereType<String>()
                  .toSet();
            } else {
              _busyResponderIds = {};
            }
          } catch (_) {
            _busyResponderIds = {};
          }
        } else {
          _busyResponderIds = {};
        }
        setState(() {
          _responders = list;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load responders: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _buildResponderTeams(List<Map<String, dynamic>> available) {
    final leaderIds = <String>{};
    for (final r in available) {
      if (r['leader_id'] == null) leaderIds.add(r['id']?.toString() ?? '');
    }
    final teams = <({String label, List<Map<String, dynamic>> responders})>[];
    final ungrouped = <Map<String, dynamic>>[];

    for (final r in available) {
      final leaderId = r['leader_id']?.toString();
      if (leaderId == null || leaderId.isEmpty) {
        final members = available.where((x) => x['leader_id']?.toString() == r['id']?.toString()).toList();
        final teamList = [r, ...members];
        final teamName = (r['team_name'] as String?)?.trim().isNotEmpty == true
            ? r['team_name'] as String
            : (r['name']?.toString() ?? 'Team');
        teams.add((label: teamName, responders: teamList));
      } else if (!leaderIds.contains(leaderId)) {
        ungrouped.add(r);
      }
    }

    _responderTeams = teams;
    _ungroupedResponders = ungrouped;
  }

  Future<void> _loadAssignment() async {
    try {
      final reportId = widget.report['id']?.toString();
      if (reportId == null) return;

      final response = await SupabaseService.client
          .from('assignment')
          .select('''
            *,
            responder:responder_id(id, name, role, phone)
          ''')
          .eq('report_id', reportId)
          .order('assigned_at', ascending: false)
          .limit(1);

      if (response != null && response.isNotEmpty) {
        setState(() {
          _currentAssignment = Map<String, dynamic>.from(response[0]);
          if (_currentAssignment?['responder'] != null) {
            final responder = _currentAssignment!['responder'];
            _selectedResponderId = responder['id']?.toString();
          }
        });
      }
    } catch (e) {
      // Silently fail - assignment might not exist
      print('Could not load assignment: $e');
    }
  }

  Future<void> _saveChanges() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final reportId = widget.report['id']?.toString();
      if (reportId == null) {
        throw Exception('Report ID is missing');
      }

      // Update report basic info
      final updateData = {
        'type': _selectedType,
        'status': _selectedStatus,
        'lifecycle_status': _selectedLifecycleStatus,
        'message': _messageController.text,
        'last_update': DateTime.now().toIso8601String(),
      };

      await SupabaseService.client
          .from('reports')
          .update(updateData)
          .eq('id', reportId);

      // Handle responder assignment using Edge Function
      final previousResponderId = widget.report['responder_id']?.toString();
      final hasNewAssignment = _selectedResponderId != null && 
                                _selectedResponderId!.isNotEmpty;
      final hasChangedAssignment = previousResponderId != _selectedResponderId;

      if (hasNewAssignment && hasChangedAssignment) {
        // Call the assign-responder Edge Function
        // This will handle notifications automatically
        debugPrint('🚀 Calling assign-responder Edge Function for report $reportId');
        
        try {
          // Get current user ID
          final currentUser = SupabaseService.client.auth.currentUser;
          if (currentUser == null) {
            throw Exception('User not authenticated');
          }

          final response = await SupabaseService.client.functions.invoke(
            'assign-responder',
            body: {
              'report_id': reportId,
              'responder_id': _selectedResponderId!,
              'assigned_by': currentUser.id,
            },
          );

          debugPrint('✅ Assignment successful: ${response.data}');
        } catch (e) {
          debugPrint('❌ Error calling assign-responder: $e');
          throw Exception('Failed to assign responder: $e');
        }
      } else if (!hasNewAssignment && previousResponderId != null) {
        // Unassign responder - cancel active assignments
        final assignments = await SupabaseService.client
            .from('assignment')
            .select('*')
            .eq('report_id', reportId)
            .or('status.eq.assigned,status.eq.accepted,status.eq.enroute,status.eq.on_scene');

        if (assignments != null && assignments.isNotEmpty) {
          for (final assignment in assignments) {
            await SupabaseService.client
                .from('assignment')
                .update({'status': 'cancelled'})
                .eq('id', assignment['id']);
          }
        }

        // Clear responder from report
        await SupabaseService.client
            .from('reports')
            .update({
              'responder_id': null,
              'assignment_id': null,
              'lifecycle_status': _selectedLifecycleStatus,
            })
            .eq('id', reportId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save changes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Report' : 'Report Details'),
        backgroundColor: const Color(0xFF3b82f6),
        foregroundColor: Colors.white,
        actions: [
          if (!_isEditMode)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditMode = true;
                });
              },
              tooltip: 'Edit',
            )
          else
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _isEditMode = false;
                  _initializeForm(); // Reset form
                });
              },
              tooltip: 'Cancel',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isEditMode
              ? _buildEditView()
              : _buildDetailView(),
    );
  }

  Widget _buildDetailView() {
    final report = widget.report;
    final type = report['type']?.toString() ?? 'Unknown';
    final status = report['status']?.toString() ?? 'Unknown';
    final lifecycleStatus =
        report['lifecycle_status']?.toString() ?? status;
    final message = report['message']?.toString() ?? 'No description';
    final createdAt = report['created_at']?.toString();
    final lastUpdate = report['last_update']?.toString();
    final reporterName = report['reporter_name']?.toString() ?? 'Unknown';
    final responderName = _currentAssignment?['responder']?['name']?.toString() ??
        report['responder_name']?.toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type and Status Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _getTypeEmoji(type),
                        style: const TextStyle(fontSize: 40),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildStatusChip(status, 'Status'),
                                _buildStatusChip(lifecycleStatus, 'Lifecycle'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Details Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Details',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow('Message', message),
                  const Divider(),
                  _buildDetailRow('Reporter', reporterName),
                  const Divider(),
                  _buildDetailRow(
                    'Created',
                    createdAt != null
                        ? _formatDate(createdAt)
                        : 'Unknown',
                  ),
                  if (lastUpdate != null) ...[
                    const Divider(),
                    _buildDetailRow(
                      'Last Updated',
                      _formatDate(lastUpdate),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Responder Assignment Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Responder Assignment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (responderName != null)
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                responderName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_currentAssignment?['responder']?['role'] !=
                                  null)
                                Text(
                                  _currentAssignment!['responder']['role']
                                      .toString(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    )
                  else
                    Row(
                      children: [
                        const Icon(Icons.person_outline,
                            color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(
                          'Not assigned',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showAssignResponderDialog,
                      icon: Icon(responderName != null ? Icons.refresh : Icons.person_add),
                      label: Text(responderName != null ? 'Change Responder' : 'Assign Responder'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: responderName != null 
                            ? const Color(0xFF3b82f6)
                            : const Color(0xFF16a34a),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type Dropdown
          _buildDropdown(
            label: 'Type',
            value: _selectedType,
            items: const [
              'fire',
              'medical',
              'flood',
              'earthquake',
              'accident',
              'other',
            ],
            onChanged: (value) {
              setState(() {
                _selectedType = value!;
              });
            },
          ),
          const SizedBox(height: 16),

          // Status Dropdown
          _buildDropdown(
            label: 'Status',
            value: _selectedStatus,
            items: const [
              'pending',
              'processing',
              'classified',
              'assigned',
              'completed',
              'resolved',
              'closed',
            ],
            onChanged: (value) {
              setState(() {
                _selectedStatus = value!;
              });
            },
          ),
          const SizedBox(height: 16),

          // Lifecycle Status Dropdown
          _buildDropdown(
            label: 'Lifecycle Status',
            value: _selectedLifecycleStatus,
            items: const [
              'pending',
              'classified',
              'assigned',
              'accepted',
              'enroute',
              'on_scene',
              'resolved',
              'closed',
            ],
            onChanged: (value) {
              setState(() {
                _selectedLifecycleStatus = value!;
              });
            },
          ),
          const SizedBox(height: 16),

          // Responder Assignment Dropdown
          _buildResponderDropdown(),
          const SizedBox(height: 16),

          // Message Text Field
          TextField(
            controller: _messageController,
            decoration: const InputDecoration(
              labelText: 'Message / Description',
              border: OutlineInputBorder(),
              hintText: 'Enter report description...',
            ),
            maxLines: 5,
            minLines: 3,
          ),
          const SizedBox(height: 24),

          // Save Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3b82f6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item.toUpperCase()),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildResponderDropdown() {
    final responderItems = [
      const DropdownMenuItem<String>(
        value: null,
        child: Text('-- Select Responder --'),
      ),
      ..._responders.map((responder) {
        final name = responder['name']?.toString() ?? 'Unknown';
        final role = responder['role']?.toString() ?? '';
        final isAvailable = responder['is_available'] == true;
        return DropdownMenuItem<String>(
          value: responder['id']?.toString(),
          child: Text(
            '$name ($role)${isAvailable ? '' : ' - Busy'}',
          ),
        );
      }),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assign Responder',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          value: _selectedResponderId,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          ),
          items: responderItems,
          onChanged: (value) {
            setState(() {
              _selectedResponderId = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, String label) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
      case 'completed':
      case 'closed':
        return const Color(0xFF10b981);
      case 'pending':
        return const Color(0xFFf97316);
      case 'assigned':
      case 'accepted':
      case 'enroute':
      case 'on_scene':
        return const Color(0xFF3b82f6);
      default:
        return const Color(0xFF6b7280);
    }
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

  Future<void> _showAssignResponderDialog() async {
    if (_responders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No responders available'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Set<String> selectedIds = {};
    final reportId = widget.report['id']?.toString();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void toggleTeam(({String label, List<Map<String, dynamic>> responders}) team) {
            final ids = team.responders.map((r) => r['id']?.toString()).whereType<String>().toSet();
            final anyBusy = ids.any(_busyResponderIds.contains);
            if (anyBusy) return;
            if (ids.every(selectedIds.contains)) {
              selectedIds = Set.from(selectedIds)..removeAll(ids);
            } else {
              selectedIds = Set.from(selectedIds)..addAll(ids);
            }
            setDialogState(() {});
          }

          void toggleResponder(String id) {
            if (_busyResponderIds.contains(id)) return;
            if (selectedIds.contains(id)) {
              selectedIds = Set.from(selectedIds)..remove(id);
            } else {
              selectedIds = Set.from(selectedIds)..add(id);
            }
            setDialogState(() {});
          }

          return AlertDialog(
            title: const Text('Assign Responder(s)'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select one or more responders, or assign a whole team.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._responderTeams.map((team) {
                      final ids = team.responders.map((r) => r['id']?.toString()).whereType<String>().toSet();
                      final anyBusy = ids.any(_busyResponderIds.contains);
                      final allSelected = ids.isNotEmpty && ids.every(selectedIds.contains);
                      final someSelected = ids.any(selectedIds.contains);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: allSelected ? true : (someSelected ? null : false),
                                tristate: true,
                                onChanged: anyBusy ? null : (_) => toggleTeam(team),
                              ),
                              Expanded(
                                child: Text(
                                  'Assign whole team: ${team.label} (${team.responders.length})${anyBusy ? " • Has busy member" : ""}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: anyBusy ? Colors.grey : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          ...team.responders.map((r) {
                            final id = r['id']?.toString() ?? '';
                            final name = r['name']?.toString() ?? 'Unknown';
                            final role = r['role']?.toString() ?? '';
                            final isBusy = _busyResponderIds.contains(id);
                            return Padding(
                              padding: const EdgeInsets.only(left: 32, bottom: 4),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: selectedIds.contains(id),
                                    onChanged: isBusy ? null : (_) => toggleResponder(id),
                                  ),
                                  Expanded(
                                    child: Text(
                                      '$name ($role)${isBusy ? " • Has active assignment" : ""}',
                                      style: TextStyle(
                                        color: isBusy ? Colors.grey : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                        ],
                      );
                    }),
                    if (_ungroupedResponders.isNotEmpty) ...[
                      const Text(
                        'Ungrouped',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ..._ungroupedResponders.map((r) {
                        final id = r['id']?.toString() ?? '';
                        final name = r['name']?.toString() ?? 'Unknown';
                        final role = r['role']?.toString() ?? '';
                        final isBusy = _busyResponderIds.contains(id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Checkbox(
                                value: selectedIds.contains(id),
                                onChanged: isBusy ? null : (_) => toggleResponder(id),
                              ),
                              Expanded(
                                child: Text(
                                  '$name ($role)${isBusy ? " • Has active assignment" : ""}',
                                  style: TextStyle(color: isBusy ? Colors.grey : null),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: selectedIds.isEmpty
                    ? null
                    : () async {
                        Navigator.of(context).pop();
                        if (selectedIds.length == 1) {
                          await _assignResponder(reportId, selectedIds.single);
                        } else {
                          await _assignResponders(reportId, selectedIds.toList());
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16a34a),
                  foregroundColor: Colors.white,
                ),
                child: Text(selectedIds.isEmpty ? 'Assign' : 'Assign (${selectedIds.length})'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _assignResponders(String? reportId, List<String> responderIds) async {
    if (reportId == null || responderIds.isEmpty) {
      if (reportId == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report ID is missing'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Server-side check: responders with active assignment to another report cannot be assigned
      final busyFromServer = await _fetchBusyResponderIdsFromServer(responderIds, reportId: reportId);
      var busyIds = responderIds.where((id) => busyFromServer.contains(id.trim().toLowerCase())).toList();
      if (busyIds.isEmpty && busyFromServer.isEmpty) {
        busyIds = responderIds.where((id) => _busyResponderIds.contains(id)).toList();
      }
      if (busyIds.isNotEmpty) {
        if (mounted) {
          Navigator.of(context).pop();
          final names = busyIds.map((id) {
            try {
              final r = _responders.firstWhere((r) => r['id']?.toString() == id);
              return r['name']?.toString() ?? id;
            } catch (_) {
              return id;
            }
          }).join(', ');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Cannot assign: ${names.isEmpty ? "Selected responder(s)" : names} already have an active assignment. They must finish it first.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }
      final now = DateTime.now().toIso8601String();
      for (final responderId in responderIds) {
        await SupabaseService.client.from('assignment').insert({
          'report_id': reportId,
          'responder_id': responderId,
          'status': 'assigned',
          'assigned_at': now,
        });
      }

      await SupabaseService.client
          .from('reports')
          .update({
            'status': 'assigned',
            'lifecycle_status': 'assigned',
            'last_update': now,
          })
          .eq('id', reportId);

      await _loadAssignment();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${responderIds.length} responder(s) assigned successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error assigning responders: $e');
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _assignResponder(String? reportId, String responderId) async {
    if (reportId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report ID is missing'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Server-side check: responder must not already have an active assignment to another report
      final busyFromServer = await _fetchBusyResponderIdsFromServer([responderId], reportId: reportId);
      if (busyFromServer.contains(responderId.trim().toLowerCase())) {
        if (mounted) {
          Navigator.of(context).pop();
          String name = responderId;
          try {
            final r = _responders.firstWhere((r) => r['id']?.toString() == responderId);
            name = r['name']?.toString() ?? responderId;
          } catch (_) {}
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$name already has an active assignment. They must finish it first.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      // Check if report already has an active assignment
      final existingAssignments = await SupabaseService.client
          .from('assignment')
          .select('id, status, responder_id')
          .eq('report_id', reportId)
          .inFilter('status', ['assigned', 'accepted', 'enroute', 'on_scene'])
          .limit(1);

      if (existingAssignments != null && existingAssignments.isNotEmpty) {
        final existing = existingAssignments[0];
        if (mounted) {
          Navigator.of(context).pop(); // Close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Report already has an active assignment (status: ${existing['status']}). Please cancel the existing assignment first.',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // Get current user ID
      final currentUser = SupabaseService.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      debugPrint('🚀 Calling assign-responder Edge Function for report $reportId');

      // Call the assign-responder Edge Function
      final response = await SupabaseService.client.functions.invoke(
        'assign-responder',
        body: {
          'report_id': reportId,
          'responder_id': responderId,
          'assigned_by': currentUser.id,
        },
      );

      debugPrint('📦 Edge Function response: ${response.data}');

      if (response.data == null || response.data['success'] != true) {
        throw Exception(response.data?['error'] ?? response.data?['message'] ?? 'Failed to assign responder');
      }

      // Update the report status to 'assigned' (lifecycle_status is already updated by Edge Function)
      await SupabaseService.client
          .from('reports')
          .update({
            'status': 'assigned',
            'last_update': DateTime.now().toIso8601String(),
          })
          .eq('id', reportId);

      debugPrint('✅ Assignment successful');

      // Reload assignment data
      await _loadAssignment();

      if (mounted) {
        Navigator.of(context).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Responder assigned successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh the view
        setState(() {});
      }
    } catch (e) {
      debugPrint('❌ Error assigning responder: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to assign responder: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

