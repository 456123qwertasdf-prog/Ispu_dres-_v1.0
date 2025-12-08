import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'learning_module_detail_screen.dart';

class LearningModulesScreen extends StatefulWidget {
  const LearningModulesScreen({super.key});

  @override
  State<LearningModulesScreen> createState() => _LearningModulesScreenState();
}

class _LearningModulesScreenState extends State<LearningModulesScreen> {
  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _modules = [];
  List<Map<String, dynamic>> _userProgress = [];
  String? _selectedCourseId;
  bool _isLoading = true;
  // Get user ID from Supabase auth
  String get _userId => SupabaseService.currentUserId ?? 'demo_user';

  // Use centralized Supabase service
  String get _supabaseUrl => SupabaseService.supabaseUrl;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use Supabase Dart client instead of raw HTTP so that RLS/auth work properly.
      final client = SupabaseService.client;

      // Load courses
      final coursesResponse = await client
          .from('lms_courses')
          .select('*')
          .order('created_at', ascending: true);

      // Load active modules
      final modulesResponse = await client
          .from('learning_modules')
          .select('*')
          .eq('active', true)
          .order('order', ascending: true);

      // Load user progress (may be empty)
      List<Map<String, dynamic>> progressResponse = [];
      if (_userId.isNotEmpty) {
        progressResponse = await client
            .from('learning_progress')
            .select('*')
            .eq('user_id', _userId);
      }

      final courses = List<Map<String, dynamic>>.from(coursesResponse);
      final modules = List<Map<String, dynamic>>.from(modulesResponse);
      final progress = List<Map<String, dynamic>>.from(progressResponse);

      setState(() {
        _courses = courses;
        _modules = modules;
        _userProgress = progress;
        
        if (_courses.isNotEmpty && _selectedCourseId == null) {
          _selectedCourseId = _courses[0]['id'].toString();
        }
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load modules: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredModules {
    if (_selectedCourseId == null || _courses.isEmpty) {
      return _modules;
    }
    return _modules.where((m) => m['course_id']?.toString() == _selectedCourseId).toList();
  }

  Map<String, dynamic>? _getProgress(String moduleId) {
    Map<String, dynamic>? latest;
    DateTime? latestTime;

    for (final progress in _userProgress) {
      if (progress['module_id']?.toString() != moduleId.toString()) {
        continue;
      }
      final candidateTime = DateTime.tryParse(
            progress['updated_at']?.toString() ?? '',
          ) ??
          DateTime.tryParse(progress['completed_at']?.toString() ?? '') ??
          DateTime.tryParse(progress['created_at']?.toString() ?? '');
      final candidateProgress = _normalizeProgressValue(progress['progress']);

      if (latest == null) {
        latest = progress;
        latestTime = candidateTime;
        continue;
      }

      final latestProgress = _normalizeProgressValue(latest['progress']);
      final isNewer = candidateTime != null &&
          (latestTime == null || candidateTime.isAfter(latestTime!));

      if (isNewer || candidateProgress > latestProgress) {
        latest = progress;
        latestTime = candidateTime;
      }
    }

    return latest;
  }

  bool _isModuleUnlocked(int index) {
    if (index == 0) return true;
    final prevModule = _filteredModules[index - 1];
    final prevProgress = _getProgress(prevModule['id'].toString());
    return prevProgress?['status']?.toString().toLowerCase() == 'completed';
  }

  int _normalizeProgressValue(dynamic value) {
    int parsed;
    if (value is int) {
      parsed = value;
    } else if (value is double) {
      parsed = value.round();
    } else if (value is String) {
      parsed = int.tryParse(value) ?? 0;
    } else {
      parsed = 0;
    }

    if (parsed < 0) return 0;
    if (parsed > 100) return 100;
    return parsed;
  }

  Future<void> _markCompleted(String moduleId) async {
    try {
      final now = DateTime.now().toIso8601String();
      final progress = _getProgress(moduleId);

      final payload = <String, dynamic>{
        'user_id': _userId,
        'module_id': moduleId,
        'status': 'completed',
        'progress': 100,
        'started_at': progress?['started_at'] ?? now,
        'completed_at': now,
      };

      // Upsert progress using Supabase client so it works with RLS.
      final client = SupabaseService.client;
      await client
          .from('learning_progress')
          .upsert(payload, onConflict: 'user_id,module_id');

      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Module marked as completed!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark as completed: $e')),
        );
      }
    }
  }

  Future<void> _openModuleDetail({
    required Map<String, dynamic> module,
    required String moduleId,
    required int progressPct,
    required String status,
    required bool unlocked,
    required bool hasQuiz,
    int initialTabIndex = 0,
  }) async {
    final pdfUrl = module['pdf_url'] ??
        (module['pdf_path'] != null
            ? '$_supabaseUrl/storage/v1/object/public/learning-modules/${module['pdf_path']}'
            : null);
    final htmlContent = module['content_html']?.toString();
    final quizUrl = module['quiz_url']?.toString();

    final shouldReload = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LearningModuleDetailScreen(
          module: module,
          pdfUrl: pdfUrl,
          htmlContent: htmlContent,
          status: status,
          progressPct: progressPct,
          unlocked: unlocked,
          quizUrl: quizUrl,
          onMarkCompleted: unlocked && status != 'completed'
              ? () => _markCompleted(moduleId)
              : null,
          initialTabIndex: hasQuiz ? initialTabIndex : 0,
        ),
      ),
    );

    if (shouldReload == true) {
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Section
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                        ),
                        child: Icon(
                          Icons.menu_book,
                          size: 32,
                          color: const Color(0xFF1e293b),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Learning Modules',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1e293b),
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Learn emergency preparedness. Track your progress like an academy.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Course Selector
                  if (_courses.isNotEmpty) ...[
                    Row(
                      children: [
                        const Text(
                          'Course:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6b7280),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCourseId,
                                isExpanded: true,
                                items: _courses.map((course) {
                                  return DropdownMenuItem<String>(
                                    value: course['id'].toString(),
                                    child: Text(
                                      course['title'] ?? 'Untitled Course',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedCourseId = value;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Modules List
                  if (_filteredModules.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(Icons.menu_book, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No modules available',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._filteredModules.asMap().entries.map((entry) {
                      final index = entry.key;
                      final module = entry.value;
                      final moduleId = module['id'].toString();
                      final progress = _getProgress(moduleId);
                      final normalizedProgress =
                          _normalizeProgressValue(progress?['progress']);
                      final status = progress?['status']?.toString().toLowerCase() ?? 'not_started';
                      final unlocked = _isModuleUnlocked(index);
                      final hasQuiz = module['quiz_url'] != null && 
                                     module['quiz_url'].toString().isNotEmpty;

                      return _buildModuleCard(
                        module: module,
                        progressPct: normalizedProgress,
                        status: status,
                        unlocked: unlocked,
                        hasQuiz: hasQuiz,
                        onView: unlocked
                            ? () => _openModuleDetail(
                                  module: module,
                                  moduleId: moduleId,
                                  progressPct: normalizedProgress,
                                  status: status,
                                  unlocked: unlocked,
                                  hasQuiz: hasQuiz,
                                )
                            : null,
                        onMarkCompleted: unlocked && status != 'completed'
                            ? () => _markCompleted(moduleId)
                            : null,
                        onTakeQuiz: unlocked && status == 'completed' && hasQuiz
                            ? () => _openModuleDetail(
                                  module: module,
                                  moduleId: moduleId,
                                  progressPct: normalizedProgress,
                                  status: status,
                                  unlocked: unlocked,
                                  hasQuiz: hasQuiz,
                                  initialTabIndex: 1,
                                )
                            : null,
                      );
                    }),
                ],
              ),
    );
  }

  Widget _buildModuleCard({
    required Map<String, dynamic> module,
    required int progressPct,
    required String status,
    required bool unlocked,
    required bool hasQuiz,
    VoidCallback? onView,
    VoidCallback? onMarkCompleted,
    VoidCallback? onTakeQuiz,
  }) {
    final statusText = status == 'completed'
        ? 'COMPLETED'
        : status == 'in_progress'
            ? 'IN PROGRESS'
            : 'NOT STARTED';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        module['title'] ?? 'Untitled Module',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: unlocked ? Colors.grey.shade900 : Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        module['description'] ?? 'No description',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Progress',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '$progressPct%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressPct / 100,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFF3b82f6),
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onView != null)
                  OutlinedButton.icon(
                    onPressed: onView,
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade800,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                if (onView != null && onMarkCompleted != null)
                  const SizedBox(width: 8),
                if (onMarkCompleted != null)
                  ElevatedButton.icon(
                    onPressed: onMarkCompleted,
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: const Text('Mark Completed'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3b82f6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                if (onTakeQuiz != null)
                  ElevatedButton.icon(
                    onPressed: onTakeQuiz,
                    icon: const Icon(Icons.quiz, size: 16),
                    label: const Text('Take Quiz'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

