String formatDateTodayYmd(DateTime now) {
  final y = now.year.toString().padLeft(4, '0');
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

List<int> buildProgressiveSeries({
  required int start,
  required int step,
  required int count,
}) {
  if (count <= 0) return const <int>[];
  final safeStep = step == 0 ? 1 : step;
  return List<int>.generate(
    count,
    (index) => start + (index * safeStep),
    growable: false,
  );
}
