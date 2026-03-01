import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/search_result.dart';
import '../services/api_service.dart';
import '../services/logging_service.dart';
import 'service_providers.dart';

class SearchState {
  final String query;
  final List<SearchResult> results;
  final bool isSearching;
  final bool isSearchActive;
  final String? error;

  const SearchState({
    this.query = '',
    this.results = const [],
    this.isSearching = false,
    this.isSearchActive = false,
    this.error,
  });

  SearchState copyWith({
    String? query,
    List<SearchResult>? results,
    bool? isSearching,
    bool? isSearchActive,
    String? error,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isSearching: isSearching ?? this.isSearching,
      isSearchActive: isSearchActive ?? this.isSearchActive,
      error: error,
    );
  }
}

class SearchNotifier extends Notifier<SearchState> {
  final _logger = LoggingService.logger;

  ApiService get _apiService => ref.read(apiServiceProvider);

  @override
  SearchState build() => const SearchState();

  Future<void> search(String query) async {
    if (query.isEmpty) {
      clearSearch();
      return;
    }

    state = state.copyWith(
      query: query,
      isSearching: true,
      isSearchActive: true,
      error: null,
    );

    try {
      final response = await _apiService.search(query);
      state = state.copyWith(results: response.results, isSearching: false);
    } catch (e) {
      _logger.severe('Search error: $e');
      state = state.copyWith(isSearching: false, error: e.toString());
    }
  }

  void clearSearch() {
    state = const SearchState();
  }

  void deactivateSearch() {
    state = state.copyWith(isSearchActive: false);
  }
}

final searchProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);
