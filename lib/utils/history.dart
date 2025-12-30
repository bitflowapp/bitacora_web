class History<T> {
  History({this.cap = 200});
  final int cap;
  final List<T> _stack = [];
  int _idx = -1;

  void push(T v) {
    if (_idx < _stack.length - 1) _stack.removeRange(_idx + 1, _stack.length);
    _stack.add(v);
    if (_stack.length > cap) {
      _stack.removeAt(0);
    } else {
      _idx++;
    }
  }

  T? undo() {
    if (_idx <= 0) return null;
    _idx--;
    return _stack[_idx];
  }

  T? redo() {
    if (_idx >= _stack.length - 1) return null;
    _idx++;
    return _stack[_idx];
  }
}
