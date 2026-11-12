/// 搜索页：FTS 拼音即时检索（防抖 250ms）。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/design_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../state/library_providers.dart';
import '../shared/common.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        setState(() => _query = v.trim());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = context.ia;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                IaSpacing.xl, IaSpacing.l, IaSpacing.xl, IaSpacing.s),
            child: Text(s.navSearch,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700, color: p.mainText)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: IaSpacing.xl),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: s.searchHint,
                prefixIcon: Icon(Icons.search, color: p.secondaryText),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(Icons.close, size: 18, color: p.secondaryText),
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: _query.isEmpty
                ? const SizedBox.shrink()
                : _Results(query: _query),
          ),
        ],
      ),
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = S.of(context);
    final p = context.ia;
    final results = ref.watch(searchResultsProvider(query));

    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
          child: Text(s.errorGeneric, style: TextStyle(color: p.secondaryText))),
      data: (tracks) {
        if (tracks.isEmpty) {
          return EmptyState(
            icon: Icons.search_off,
            title: s.emptySearchTitle(query),
            subtitle: s.emptySearchHint,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  IaSpacing.xl, IaSpacing.m, IaSpacing.xl, 0),
              child: Text(s.searchResults,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: p.secondaryText)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                    horizontal: IaSpacing.xl, vertical: IaSpacing.s),
                itemCount: tracks.length,
                itemBuilder: (_, i) => TrackRow(tracks: tracks, index: i),
              ),
            ),
          ],
        );
      },
    );
  }
}
