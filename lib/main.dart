import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

const _methodChannel = MethodChannel('keyboard_insets_repro/methods');

final _navigatorKey = GlobalKey<NavigatorState>();
final _diagnostics = DiagnosticsController();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ReproApp());
}

class ReproApp extends StatefulWidget {
  const ReproApp({super.key});

  @override
  State<ReproApp> createState() => _ReproAppState();
}

class _ReproAppState extends State<ReproApp> with WidgetsBindingObserver {
  Timer? _metricsSettledTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recordFlutterState('first frame');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _metricsSettledTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _recordFlutterState('lifecycle=$state');
  }

  @override
  void didChangeMetrics() {
    _metricsSettledTimer?.cancel();
    _metricsSettledTimer = Timer(const Duration(milliseconds: 150), () {
      _recordFlutterState('metrics settled');
    });
  }

  void _recordFlutterState(String reason) {
    final ui.FlutterView view =
        WidgetsBinding.instance.platformDispatcher.views.first;
    final mediaQuery = _navigatorKey.currentContext == null
        ? null
        : MediaQuery.maybeOf(_navigatorKey.currentContext!);
    _diagnostics.add(
      'flutter $reason '
      'focus=${FocusManager.instance.primaryFocus?.debugLabel ?? '-'} '
      'viewInsetsPx=${view.viewInsets.bottom.toStringAsFixed(1)} '
      'viewInsetsDp=${(view.viewInsets.bottom / view.devicePixelRatio).toStringAsFixed(1)} '
      'mediaQueryDp=${mediaQuery?.viewInsets.bottom.toStringAsFixed(1) ?? '-'} '
      'sizePx=${view.physicalSize.width.toStringAsFixed(0)}x'
      '${view.physicalSize.height.toStringAsFixed(0)}',
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigatorKey,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.orange, useMaterial3: true),
    home: const ObserverPage(),
  );
}

class ObserverPage extends StatefulWidget {
  const ObserverPage({super.key});

  @override
  State<ObserverPage> createState() => _ObserverPageState();
}

class _ObserverPageState extends State<ObserverPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshNativeHistory());
    });
  }

  Future<void> _openTriggerPage() async {
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const TriggerPage()));
    await _refreshNativeHistory();
  }

  Future<void> _refreshNativeHistory() async {
    await _loadNativeHistory();
    if (mounted) {
      setState(() {});
    }
    _diagnostics.refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('1. Observer page')),
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Reproduce on page 2, then press Back. If the phantom keyboard '
              'inset survives navigation, the orange bottom marker will remain '
              'above a blank area on this page.',
            ),
          ),
          const CurrentMetricsPanel(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _openTriggerPage,
                  child: const Text('Open trigger page'),
                ),
                OutlinedButton(
                  onPressed: () => unawaited(_runNativeAction('snapshot')),
                  child: const Text('Query native'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      unawaited(_runNativeAction('requestApplyInsets')),
                  child: const Text('Request Android insets'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Expanded(child: DiagnosticLogView()),
          const BottomMarker(label: 'OBSERVER PAGE BOTTOM'),
        ],
      ),
    ),
  );
}

class TriggerPage extends StatefulWidget {
  const TriggerPage({super.key});

  @override
  State<TriggerPage> createState() => _TriggerPageState();
}

class _TriggerPageState extends State<TriggerPage> {
  final _focusNode = FocusNode(debugLabel: 'repro-text-field');
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    _diagnostics.add('trigger page opened');
  }

  @override
  void dispose() {
    _diagnostics.add('trigger page disposed');
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    _diagnostics.add('text field focus=${_focusNode.hasFocus}');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: true,
    appBar: AppBar(title: const Text('2. Trigger page')),
    body: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '1. Tap the text field.\n'
              '2. Keep the keyboard open and press Home/Recent.\n'
              '3. Switch to another app, then return here through Recent.\n'
              '4. Press Back to inspect whether the blank area survives.',
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                expands: true,
                minLines: null,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Tap here to show the keyboard',
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton(
              onPressed: () => _diagnostics.add('bottom button tapped'),
              child: const Text('Bottom button'),
            ),
          ),
          const BottomMarker(label: 'TRIGGER PAGE BOTTOM'),
        ],
      ),
    ),
  );
}

class CurrentMetricsPanel extends StatelessWidget {
  const CurrentMetricsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    final mediaQuery = MediaQuery.of(context);
    final native = _diagnostics.latestNative;
    final flutterInsets = view.viewInsets.bottom / view.devicePixelRatio;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DefaultTextStyle(
          style: Theme.of(context).textTheme.bodySmall!,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'observer | focus='
                '${FocusManager.instance.primaryFocus?.debugLabel ?? '-'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'FlutterView.viewInsets.bottom: '
                '${flutterInsets.toStringAsFixed(1)} dp',
              ),
              Text(
                'MediaQuery.viewInsets.bottom: '
                '${mediaQuery.viewInsets.bottom.toStringAsFixed(1)} dp',
              ),
              Text(
                'Native IME: visible=${native['imeVisible'] ?? '-'}, '
                'bottom=${native['imeBottom'] ?? '-'} px',
              ),
              Text(
                'Native window: focus=${native['windowFocus'] ?? '-'}, '
                'lifecycle=${native['lifecycle'] ?? '-'}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DiagnosticLogView extends StatelessWidget {
  const DiagnosticLogView({super.key});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _diagnostics,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Event log (newest first)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: _diagnostics.copyableText),
                  );
                },
                child: const Text('Copy'),
              ),
              TextButton(
                onPressed: _diagnostics.clear,
                child: const Text('Clear'),
              ),
            ],
          ),
        ),
        Expanded(
          child: SelectionArea(
            child: ListView.builder(
              reverse: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              itemCount: _diagnostics.entries.length,
              itemBuilder: (context, index) {
                final entry = _diagnostics
                    .entries[_diagnostics.entries.length - index - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    entry,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    ),
  );
}

class BottomMarker extends StatelessWidget {
  const BottomMarker({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    height: 34,
    alignment: Alignment.center,
    color: Colors.deepOrange,
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class DiagnosticsController extends ChangeNotifier {
  static const _maxEntries = 300;

  final List<String> entries = [];
  final Set<String> _nativeEventKeys = {};
  Map<Object?, Object?> latestNative = const {};

  String get copyableText => entries.join('\n');

  void add(String message, {bool notify = false}) {
    final now = DateTime.now();
    final timestamp =
        '${_twoDigits(now.hour)}:${_twoDigits(now.minute)}:'
        '${_twoDigits(now.second)}.${now.millisecond.toString().padLeft(3, '0')}';
    entries.add('$timestamp $message');
    if (entries.length > _maxEntries) {
      entries.removeRange(0, entries.length - _maxEntries);
    }
    if (notify) {
      notifyListeners();
    }
  }

  void recordNative(Map<Object?, Object?> values, {bool notify = false}) {
    latestNative = values;
    final key = '${values['timestampMs']}:${values['reason']}';
    if (!_nativeEventKeys.add(key)) {
      return;
    }
    add(
      'native ${values['reason'] ?? '-'} '
      'lifecycle=${values['lifecycle'] ?? '-'} '
      'windowFocus=${values['windowFocus'] ?? '-'} '
      'imeVisible=${values['imeVisible'] ?? '-'} '
      'imeBottomPx=${values['imeBottom'] ?? '-'} '
      'systemBarsBottomPx=${values['systemBarsBottom'] ?? '-'} '
      'decor=${values['decorWidth'] ?? '-'}x${values['decorHeight'] ?? '-'} '
      'visibleFrameBottom=${values['visibleFrameBottom'] ?? '-'}',
      notify: notify,
    );
  }

  void refresh() => notifyListeners();

  void clear() {
    entries.clear();
    _nativeEventKeys.clear();
    notifyListeners();
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}

Future<void> _loadNativeHistory() async {
  try {
    final history = await _methodChannel.invokeListMethod<dynamic>('history');
    if (history == null) {
      return;
    }
    for (final event in history) {
      if (event case final Map<Object?, Object?> values) {
        _diagnostics.recordNative(values);
      }
    }
  } catch (error) {
    _diagnostics.add('native history error: $error');
  }
}

Future<void> _runNativeAction(String method) async {
  try {
    final values = await _methodChannel.invokeMapMethod<String, dynamic>(
      method,
    );
    if (values != null) {
      _diagnostics.recordNative(values, notify: true);
    }
  } catch (error) {
    _diagnostics.add('$method error: $error', notify: true);
  }
}
