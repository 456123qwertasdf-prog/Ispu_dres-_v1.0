import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart' as launcher;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

class LearningModuleDetailScreen extends StatefulWidget {
  const LearningModuleDetailScreen({
    super.key,
    required this.module,
    this.pdfUrl,
    this.htmlContent,
    required this.status,
    required this.progressPct,
    required this.unlocked,
    this.quizUrl,
    this.onMarkCompleted,
    this.initialTabIndex = 0,
  });

  final Map<String, dynamic> module;
  final String? pdfUrl;
  final String? htmlContent;
  final String status;
  final int progressPct;
  final bool unlocked;
  final String? quizUrl;
  final Future<void> Function()? onMarkCompleted;
  final int initialTabIndex;

  @override
  State<LearningModuleDetailScreen> createState() =>
      _LearningModuleDetailScreenState();
}

class _LearningModuleDetailScreenState
    extends State<LearningModuleDetailScreen> {
  PdfControllerPinch? _pdfController;
  bool _pdfLoading = false;
  String? _pdfError;
  bool _markingComplete = false;
  bool _hasChanges = false;
  late int _progressPct = widget.progressPct;
  late String _status = widget.status;
  WebViewController? _quizController;
  final ScrollController _contentScrollController = ScrollController();
  double _maxReadRatio = 0;
  bool _contentCompleted = false;
  bool _autoCompletionTriggered = false;
  int? _pdfPagesCount;

  @override
  void initState() {
    super.initState();
    _contentCompleted = widget.status == 'completed';
    _contentScrollController.addListener(_handleContentScrollProgress);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _handleContentScrollProgress();
      }
    });
    if (widget.pdfUrl != null) {
      _loadPdf();
    }
    _quizController = _createQuizController();
  }

  WebViewController? _createQuizController() {
    final rawUrl = widget.quizUrl?.trim();
    if (rawUrl == null || rawUrl.isEmpty) return null;
    return _buildWebViewController(rawUrl);
  }

  Future<void> _loadPdf() async {
    setState(() {
      _pdfLoading = true;
      _pdfError = null;
    });

    try {
      final uri = Uri.parse(widget.pdfUrl!);
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        throw Exception('Failed to load PDF (${response.statusCode})');
      }
      final documentFuture = PdfDocument.openData(response.bodyBytes);
      final controller = PdfControllerPinch(document: documentFuture);
      documentFuture.then((doc) {
        if (!mounted) return;
        setState(() {
          _pdfPagesCount = doc.pagesCount;
        });
        if (doc.pagesCount <= 1) {
          _updateReadingProgress(1.0);
        }
      }).catchError((_) {});

      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _pdfController = controller;
        _pdfLoading = false;
      });
    } catch (e) {
      setState(() {
        _pdfError = e.toString();
        _pdfLoading = false;
      });
    }
  }

  void _handleContentScrollProgress() {
    if (_status == 'completed' || _contentCompleted) return;
    if (!_contentScrollController.hasClients) return;

    final position = _contentScrollController.position;
    if (!position.hasPixels) return;

    if (position.maxScrollExtent <= 0) {
      _updateReadingProgress(1.0);
      return;
    }

    final ratio =
        (position.pixels / position.maxScrollExtent).clamp(0.0, 1.0);
    _updateReadingProgress(ratio);
  }

  void _handlePdfPageChanged(int page) {
    final total = _pdfPagesCount ?? page;
    if (total <= 0) return;
    final ratio = (page / total).clamp(0.0, 1.0);
    _updateReadingProgress(ratio);
  }

  bool get _hasQuiz => _quizController != null;
  bool get _isQuizLocked => _hasQuiz && !_contentCompleted && _status != 'completed';
  bool get _canAccessQuiz => !_isQuizLocked;

  void _updateReadingProgress(double ratio) {
    if (_status == 'completed') return;
    final clamped = ratio.clamp(0.0, 1.0);
    if (clamped <= _maxReadRatio) return;

    _maxReadRatio = clamped;
    final nextProgress = (clamped * 100).round().clamp(0, 100);
    setState(() {
      _progressPct = nextProgress;
    });

    if (!_autoCompletionTriggered && clamped >= 0.999) {
      _autoCompletionTriggered = true;
      setState(() {
        _contentCompleted = true;
      });
      _handleMarkCompleted();
    }
  }

  void _showCompleteFirstMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Finish the module content to unlock the quiz.'),
      ),
    );
  }

  void _handleGoToQuiz(BuildContext context) {
    if (!_hasQuiz) return;
    if (_isQuizLocked) {
      _showCompleteFirstMessage();
      DefaultTabController.of(context)?.animateTo(0);
      return;
    }
    DefaultTabController.of(context)?.animateTo(1);
  }

  void _openContentFullscreen() {
    if (widget.htmlContent != null && widget.htmlContent!.trim().isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FullscreenHtmlView(
            title: widget.module['title'] ?? 'Module Content',
            html: widget.htmlContent!,
          ),
        ),
      );
    } else if (widget.pdfUrl != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FullscreenPdfView(
            title: widget.module['title'] ?? 'Module Content',
            pdfUrl: widget.pdfUrl!,
          ),
        ),
      );
    }
  }

  void _openQuizFullscreen() {
    if (!_hasQuiz || _isQuizLocked || widget.quizUrl == null) {
      if (_isQuizLocked) {
        _showCompleteFirstMessage();
      }
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullscreenQuizView(
          title: widget.module['title'] ?? 'Quiz',
          quizUrl: widget.quizUrl!.trim(),
        ),
      ),
    );
  }

  WebViewController _buildWebViewController(String rawUrl) {
    final normalized = _normalizeUrl(rawUrl);

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    return WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..loadRequest(Uri.parse(normalized));
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    _contentScrollController.dispose();
    super.dispose();
  }

  String _normalizeUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    return 'https://$url';
  }

  Future<void> _handleMarkCompleted() async {
    if (widget.onMarkCompleted == null || _markingComplete) return;

    setState(() {
      _markingComplete = true;
    });

    try {
      await widget.onMarkCompleted!.call();
      if (!mounted) return;
      setState(() {
        _status = 'completed';
        _progressPct = 100;
        _contentCompleted = true;
        _maxReadRatio = 1;
        _hasChanges = true;
      });
    } finally {
      if (mounted) {
        setState(() {
          _markingComplete = false;
        });
      }
    }
  }

  Future<void> _openQuizInBrowser() async {
    if (_isQuizLocked) {
      _showCompleteFirstMessage();
      return;
    }
    final quizUrl = widget.quizUrl;
    if (quizUrl == null || quizUrl.isEmpty) return;
    final normalized = _normalizeUrl(quizUrl);
    await launcher.launchUrl(
      Uri.parse(normalized),
      mode: launcher.LaunchMode.externalApplication,
    );
  }

  Widget _buildHeaderCard({bool showActions = true}) {
    final module = widget.module;
    final statusLabel = _status == 'completed'
        ? 'Completed'
        : _status == 'in_progress'
            ? 'In Progress'
            : 'Not Started';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              module['title'] ?? 'Untitled Module',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              module['description'] ?? 'No description provided.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.blueGrey.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Progress: $_progressPct%',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _progressPct / 100,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF3b82f6)),
              ),
            ),
            if (showActions) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: widget.unlocked &&
                              !_markingComplete &&
                              (_contentCompleted || _status == 'completed')
                          ? _handleMarkCompleted
                          : null,
                      icon: const Icon(Icons.check_circle),
                      label: Text(
                        _status == 'completed'
                            ? 'Completed'
                            : !_contentCompleted
                                ? 'Read to Unlock'
                                : (_markingComplete ? 'Saving...' : 'Mark Completed'),
                      ),
                    ),
                  ),
                  if (_quizController != null) ...[
                    const SizedBox(width: 8),
                    Builder(
                      builder: (tabContext) => OutlinedButton.icon(
                        onPressed: _hasQuiz
                            ? () => _handleGoToQuiz(tabContext)
                            : null,
                        icon: const Icon(Icons.quiz),
                        label: Text(
                          _isQuizLocked ? 'Finish Content First' : 'Go to Quiz',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContentSection() {
    final html = widget.htmlContent?.trim();
    if (html != null && html.isNotEmpty) {
      return Stack(
        children: [
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: InteractiveViewer(
                panEnabled: false,
                minScale: 0.8,
                maxScale: 3,
                child: Html(
                  data: html,
                  style: {
                    'body': Style(
                      fontSize: FontSize(14),
                      color: Colors.grey.shade800,
                      lineHeight: LineHeight(1.6),
                    ),
                  },
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              tooltip: 'Open fullscreen',
              onPressed: _openContentFullscreen,
              icon: const Icon(Icons.fullscreen),
            ),
          ),
        ],
      );
    }

    if (widget.pdfUrl != null) {
      return Stack(
        children: [
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 1,
            child: SizedBox(
              height: 520,
              child: _buildPdfViewer(),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              tooltip: 'Open fullscreen',
              onPressed: _openContentFullscreen,
              icon: const Icon(Icons.fullscreen),
            ),
          ),
        ],
      );
    }

    return _buildPlaceholderCard(
      'Module content is not yet available for this lesson.',
    );
  }

  Widget _buildPdfViewer() {
    if (_pdfLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pdfError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Unable to load PDF: $_pdfError',
            style: TextStyle(color: Colors.red.shade600),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_pdfController == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: PdfViewPinch(
        controller: _pdfController!,
        onDocumentLoaded: (document) {
          _pdfPagesCount = document.pagesCount;
          if (document.pagesCount <= 1) {
            _updateReadingProgress(1.0);
          }
        },
        onPageChanged: _handlePdfPageChanged,
      ),
    );
  }

  Widget _buildQuizSection() {
    if (_quizController == null) {
      return _buildPlaceholderCard('No quiz is linked to this module yet.');
    }
    if (_isQuizLocked) {
      return _buildPlaceholderCard(
        'Read through the module to unlock this quiz.',
      );
    }

    return Stack(
      children: [
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 1,
          child: Column(
            children: [
              SizedBox(
                height: 520,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: WebViewWidget(controller: _quizController!),
                ),
              ),
              TextButton.icon(
                onPressed: _openQuizInBrowser,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open in browser'),
              ),
            ],
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: IconButton(
            tooltip: 'Open fullscreen',
            onPressed: _openQuizFullscreen,
            icon: const Icon(Icons.fullscreen),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderCard(String message) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.menu_book, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _handleWillPop() async {
    Navigator.of(context).pop(_hasChanges);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final hasQuiz = _quizController != null;
    final tabCount = hasQuiz ? 2 : 1;
    final initialTab =
        widget.initialTabIndex >= tabCount ? 0 : widget.initialTabIndex;

    Widget contentTab = ListView(
      controller: _contentScrollController,
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeaderCard(),
        const SizedBox(height: 16),
        _buildContentSection(),
      ],
    );

    Widget quizTab = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeaderCard(showActions: false),
        const SizedBox(height: 16),
        _buildQuizSection(),
      ],
    );

    return WillPopScope(
      onWillPop: _handleWillPop,
      child: DefaultTabController(
        length: tabCount,
        initialIndex: initialTab,
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.module['title'] ?? 'Module'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(_hasChanges),
            ),
            bottom: hasQuiz
                ? TabBar(
                    onTap: (index) {
                      if (index == 1 && _isQuizLocked) {
                        _showCompleteFirstMessage();
                        DefaultTabController.of(context)?.animateTo(0);
                      }
                    },
                    tabs: const [
                      Tab(text: 'Content'),
                      Tab(text: 'Quiz'),
                    ],
                  )
                : null,
          ),
          body: hasQuiz
              ? TabBarView(
                  physics:
                      _isQuizLocked ? const NeverScrollableScrollPhysics() : null,
                  children: [
                    contentTab,
                    quizTab,
                  ],
                )
              : contentTab,
        ),
      ),
    );
  }
}

class FullscreenHtmlView extends StatelessWidget {
  const FullscreenHtmlView({
    super.key,
    required this.title,
    required this.html,
  });

  final String title;
  final String html;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Html(
            data: html,
            style: {
              'body': Style(
                fontSize: FontSize(16),
                color: Colors.grey.shade800,
                lineHeight: const LineHeight(1.6),
              ),
            },
          ),
        ),
      ),
    );
  }
}

class FullscreenPdfView extends StatefulWidget {
  const FullscreenPdfView({
    super.key,
    required this.title,
    required this.pdfUrl,
  });

  final String title;
  final String pdfUrl;

  @override
  State<FullscreenPdfView> createState() => _FullscreenPdfViewState();
}

class _FullscreenPdfViewState extends State<FullscreenPdfView> {
  PdfControllerPinch? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await http.get(Uri.parse(widget.pdfUrl));
      if (!mounted) return;
      if (response.statusCode != 200) {
        throw Exception('Failed to load PDF (${response.statusCode})');
      }

      final documentFuture = PdfDocument.openData(response.bodyBytes);
      _controller?.dispose();
      setState(() {
        _controller = PdfControllerPinch(document: documentFuture);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Unable to load PDF:\n$_error',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red.shade600),
          ),
        ),
      );
    } else {
      body = PdfViewPinch(controller: _controller!);
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: body,
    );
  }
}

class FullscreenQuizView extends StatefulWidget {
  const FullscreenQuizView({
    super.key,
    required this.title,
    required this.quizUrl,
  });

  final String title;
  final String quizUrl;

  @override
  State<FullscreenQuizView> createState() => _FullscreenQuizViewState();
}

class _FullscreenQuizViewState extends State<FullscreenQuizView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _createFullscreenWebView(widget.quizUrl);
  }

  WebViewController _createFullscreenWebView(String rawUrl) {
    String normalized = rawUrl.trim();
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    return WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..loadRequest(Uri.parse(normalized));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: WebViewWidget(controller: _controller),
    );
  }
}

