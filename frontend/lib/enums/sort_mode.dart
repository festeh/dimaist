enum SortMode {
  order('order'),
  dueDate('due_date');

  const SortMode(this.value);
  final String value;

  static SortMode fromString(String value) {
    return SortMode.values.firstWhere(
      (mode) => mode.value == value,
      orElse: () => SortMode.order,
    );
  }
}