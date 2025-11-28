class SearchResult {
  final String type;
  final int id;
  final String title;
  final String? subtitle;

  SearchResult({
    required this.type,
    required this.id,
    required this.title,
    this.subtitle,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      type: json['type'] as String,
      id: json['id'] as int,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
    );
  }

  bool get isTask => type == 'task';
  bool get isProject => type == 'project';
}

class SearchResponse {
  final List<SearchResult> results;
  final int count;

  SearchResponse({required this.results, required this.count});

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    return SearchResponse(
      results: (json['results'] as List?)
              ?.map((r) => SearchResult.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      count: json['count'] as int? ?? 0,
    );
  }
}
