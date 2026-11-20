import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/notification_bloc.dart';
import '../bloc/setup_bloc.dart';
import '../bloc/studio_bloc.dart';
import '../engine/code_generator.dart';
import '../engine/dart_syntax_highlighter.dart';

/// The right-side code editor panel displaying generated Dart code
/// with copy, reset, and live preview actions.
///
/// Reads `StudioSetup` from `SetupBloc` and `NotificationDraft`
/// from `NotificationBloc`.
class CodeEditorPanel extends StatefulWidget {
  const CodeEditorPanel({super.key});

  @override
  State<CodeEditorPanel> createState() => _CodeEditorPanelState();
}

class _CodeEditorPanelState extends State<CodeEditorPanel> {
  CodeSnippetScope _selectedScope = CodeSnippetScope.fullSetup;

  @override
  Widget build(final BuildContext context) =>
      BlocBuilder<SetupBloc, SetupState>(
        builder: (final context, final setupState) =>
            BlocBuilder<NotificationBloc, NotificationDraft>(
          builder: (final context, final draft) {
            final code = generateCode(
              setup: setupState.setup,
              draft: draft,
              scope: _selectedScope,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.03),
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.code,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'GENERATED CODE',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.54),
                          ),
                        ),
                      ),
                      const Spacer(),
                      _ActionChip(
                        icon: Icons.content_copy,
                        label: 'Copy',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${_selectedScope.label} snippet '
                                'copied to clipboard',
                              ),
                              backgroundColor:
                                  Theme.of(context).colorScheme.primary,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      _ActionChip(
                        icon: Icons.refresh,
                        label: 'Reset',
                        onPressed: () {
                          context.read<SetupBloc>().add(const ResetSetup());
                          context
                              .read<NotificationBloc>()
                              .add(const ResetDraft());
                        },
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Collapse Code Panel',
                        child: InkWell(
                          onTap: () => context
                              .read<StudioBloc>()
                              .add(const ToggleCodeEditor(open: false)),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Snippet Scope Tabs ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: CodeSnippetScope.values.map((final scope) {
                        final isSelected = _selectedScope == scope;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => setState(() => _selectedScope = scope),
                            borderRadius: BorderRadius.circular(6),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withValues(alpha: 0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.1),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    scope.icon,
                                    size: 13,
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    scope.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // ── Hints ──
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.05),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 14,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _hintForState(setupState, draft),
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.7),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Code Display (syntax highlighted) ──
                Expanded(
                  child: Container(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF0D1117)
                        : const Color(0xFFF6F8FA),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                      child: _HighlightedCodeView(code: code),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

  String _hintForState(
    final SetupState setupState,
    final NotificationDraft draft,
  ) =>
      switch (_selectedScope) {
        CodeSnippetScope.fullSetup =>
          '📁 Place in lib/main.dart — wraps your root MaterialApp via builder.',
        CodeSnippetScope.scopedOverlay =>
          '📦 Embedded / Multi-Tenant — wraps local panels with useRootOverlay: false.',
        CodeSnippetScope.dispatchOnly =>
          '⚡ Contextless dispatch — call from any Bloc, Service, or ViewModel '
              'without BuildContext.',
        CodeSnippetScope.channelsOnly =>
          '📁 Place in lib/config/notification_channels.dart — defines channel routing table.',
        CodeSnippetScope.queuesOnly =>
          '📁 Place in lib/config/notification_queues.dart — defines screen positions & gesture rules.',
      };
}

/// Renders [code] with a line-number gutter and Dart syntax highlighting.
class _HighlightedCodeView extends StatefulWidget {
  const _HighlightedCodeView({required this.code});
  final String code;

  @override
  State<_HighlightedCodeView> createState() => _HighlightedCodeViewState();
}

class _HighlightedCodeViewState extends State<_HighlightedCodeView> {
  late TextSpan _highlightedCode;
  late List<String> _lines;
  late String _gutterText;
  String? _lastCode;
  bool? _lastIsDark;

  void _updateHighlight(final bool isDark) {
    if (_lastCode == widget.code && _lastIsDark == isDark) {
      return;
    }
    _lastCode = widget.code;
    _lastIsDark = isDark;
    _highlightedCode = DartSyntaxHighlighter.highlight(
      widget.code,
      isDark: isDark,
    );
    _lines = widget.code.split('\n');
    _gutterText =
        List.generate(_lines.length, (final i) => '${i + 1}').join('\n');
  }

  @override
  void initState() {
    super.initState();
    _updateHighlight(true);
  }

  @override
  void didUpdateWidget(covariant final _HighlightedCodeView oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(final BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _updateHighlight(isDark);
    final gutterColor =
        isDark ? const Color(0xFF161B22) : const Color(0xFFEAECEF);
    final gutterTextColor =
        isDark ? const Color(0xFF484F58) : const Color(0xFFAFB8C1);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Line number gutter ──
        RepaintBoundary(
          child: Container(
            color: gutterColor,
            padding: const EdgeInsets.fromLTRB(12, 0, 10, 0),
            child: Text(
              _gutterText,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13, // Matches font size of code
                height: 1.6, // Matches line-height of code
                color: gutterTextColor,
              ),
            ),
          ),
        ),
        // ── Highlighted code ──
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: SelectableText.rich(
              _highlightedCode,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(final BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.54),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.54),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
