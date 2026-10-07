import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api_key_store.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/panel.dart';

/// Where someone enters their own Anthropic API key.
///
/// Each person supplies their own rather than the team sharing one, because a
/// shared key would have to ship inside the APK, where anyone who installed
/// the app could extract it.
class ApiKeyScreen extends ConsumerStatefulWidget {
  const ApiKeyScreen({super.key});

  @override
  ConsumerState<ApiKeyScreen> createState() => _ApiKeyScreenState();
}

class _ApiKeyScreenState extends ConsumerState<ApiKeyScreen> {
  final _controller = TextEditingController();
  final _store = const ApiKeyStore();

  String? _existing;
  bool _loading = true;
  bool _obscured = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final key = await _store.read();
    if (!mounted) return;
    setState(() {
      _existing = key;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final value = _controller.text.trim();

    // Catches the most common mistake — pasting something that is not a key —
    // before it becomes a 401 the user has to interpret.
    if (!value.startsWith('sk-ant-')) {
      setState(() => _error = 'An Anthropic key starts with "sk-ant-".');
      return;
    }

    await _store.write(value);
    await ref.read(assistantProvider.notifier).refreshConfiguration();
    if (!mounted) return;
    _controller.clear();
    setState(() {
      _existing = value;
      _error = null;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Key saved')));
  }

  Future<void> _remove() async {
    await _store.clear();
    await ref.read(assistantProvider.notifier).refreshConfiguration();
    if (!mounted) return;
    setState(() => _existing = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Assistant API key')),
      body: _loading
          ? const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Tokens.slate,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                Tokens.space4,
                Tokens.space2,
                Tokens.space4,
                Tokens.space7,
              ),
              children: [
                Panel(
                  title: 'Why your own key',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'The assistant sends your project data to Anthropic to '
                        'answer questions. It uses a key you supply, which '
                        'stays on this device and is never shared with your '
                        'team or stored in the database.',
                        style: AppType.bodyMuted,
                      ),
                      const SizedBox(height: Tokens.space3),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            size: 16,
                            color: Tokens.slate,
                          ),
                          const SizedBox(width: Tokens.space3),
                          Expanded(
                            child: Text(
                              'Only squad-level data is sent. No individual is '
                              'identified, because the app does not hold '
                              'per-person data to send.',
                              style: AppType.bodyMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Tokens.space4),
                if (_existing != null) ...[
                  Panel(
                    title: 'Saved key',
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            ApiKeyStore.mask(_existing!),
                            style: AppType.dataStrong,
                          ),
                        ),
                        TextButton(
                          onPressed: _remove,
                          child: Text(
                            'Remove',
                            style: AppType.bodyStrong.copyWith(
                              color: Tokens.flare,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Tokens.space4),
                ],
                Text(
                  _existing == null ? 'API KEY' : 'REPLACE KEY',
                  style: AppType.label,
                ),
                const SizedBox(height: Tokens.space2),
                TextField(
                  controller: _controller,
                  obscureText: _obscured,
                  style: AppType.data.copyWith(color: Tokens.chalk),
                  decoration: InputDecoration(
                    hintText: 'sk-ant-...',
                    hintStyle: AppType.bodyMuted,
                    filled: true,
                    fillColor: Tokens.seam,
                    errorText: _error,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscured
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                        color: Tokens.slate,
                      ),
                      onPressed: () => setState(() => _obscured = !_obscured),
                      tooltip: _obscured ? 'Show' : 'Hide',
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Tokens.space3,
                      vertical: Tokens.space3,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Tokens.radiusSm),
                      borderSide: const BorderSide(color: Tokens.rule),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Tokens.radiusSm),
                      borderSide: const BorderSide(color: Tokens.rule),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Tokens.radiusSm),
                      borderSide: const BorderSide(
                        color: Tokens.beacon,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: Tokens.space3),
                Text(
                  'Create one at console.anthropic.com under API keys. Usage '
                  'is billed to your own account; answering a question costs a '
                  'fraction of a cent.',
                  style: AppType.bodyMuted,
                ),
                const SizedBox(height: Tokens.space5),
                FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: Tokens.beacon,
                    foregroundColor: Tokens.shaft,
                    padding: const EdgeInsets.symmetric(
                      vertical: Tokens.space4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Tokens.radiusSm),
                    ),
                  ),
                  child: Text(
                    'Save key',
                    style: AppType.bodyStrong.copyWith(color: Tokens.shaft),
                  ),
                ),
              ],
            ),
    );
  }
}
