import 'entities.dart';

/// A uniform bucket grid over the arena, so "what's near this monster?" costs
/// a handful of cells instead of a scan of every person and prop. It is what
/// keeps a round smooth with hundreds of things on the map.
class SpatialGrid<T extends Food> {
  SpatialGrid(double worldSize, {this.cell = 96}) : cols = (worldSize / cell).ceil() + 1 {
    _cells = List.generate(cols * cols, (_) => <T>[]);
  }

  final double cell;
  final int cols;
  late final List<List<T>> _cells;

  int _index(double x, double y) {
    final cx = (x / cell).floor().clamp(0, cols - 1);
    final cy = (y / cell).floor().clamp(0, cols - 1);
    return cy * cols + cx;
  }

  void insert(T item) => _cells[_index(item.x, item.y)].add(item);

  void clear() {
    for (final c in _cells) {
      c.clear();
    }
  }

  /// Drops dead entries (cheap; call now and then, not every frame).
  void compact() {
    for (final c in _cells) {
      c.removeWhere((f) => !f.alive);
    }
  }

  /// Calls [visit] for every live item whose cell touches the square around
  /// (x, y) of half-width [radius]. Callers do the exact distance check.
  void query(double x, double y, double radius, void Function(T item) visit) {
    final x0 = ((x - radius) / cell).floor().clamp(0, cols - 1);
    final x1 = ((x + radius) / cell).floor().clamp(0, cols - 1);
    final y0 = ((y - radius) / cell).floor().clamp(0, cols - 1);
    final y1 = ((y + radius) / cell).floor().clamp(0, cols - 1);
    for (var cy = y0; cy <= y1; cy++) {
      final row = cy * cols;
      for (var cx = x0; cx <= x1; cx++) {
        final c = _cells[row + cx];
        for (var i = 0; i < c.length; i++) {
          final f = c[i];
          if (f.alive) visit(f);
        }
      }
    }
  }
}
