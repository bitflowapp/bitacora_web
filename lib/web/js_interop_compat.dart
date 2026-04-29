import 'dart:js_interop';
import 'dart:js_interop_unsafe';

JSObject get globalThis => globalContext;

bool hasProperty(Object? object, Object property) {
  final jsObject = _asJsObject(object);
  return jsObject.has(_propertyName(property));
}

T? getProperty<T>(Object? object, Object property) {
  final jsObject = _asJsObject(object);
  final value = jsObject[_propertyName(property)];
  return _fromJsAny(value) as T?;
}

R callMethod<R>(Object? object, String method, List<Object?> args) {
  final jsObject = _asJsObject(object);
  final jsArgs = args.map(_toJsAny).toList(growable: false);
  final value = jsObject.callMethodVarArgs<JSAny?>(method.toJS, jsArgs);
  return _fromJsAny(value) as R;
}

R callConstructor<R>(Object? constructor, List<Object?> args) {
  final jsFunction = _asJsFunction(constructor);
  final jsArgs = args.map(_toJsAny).toList(growable: false);
  final value = jsFunction.callAsConstructorVarArgs<JSObject>(jsArgs);
  return _fromJsAny(value as JSAny?) as R;
}

Future<T> promiseToFuture<T>(Object? promise) async {
  late final JSPromise<JSAny?> jsPromise;
  try {
    jsPromise = promise as JSPromise<JSAny?>;
  } catch (_) {
    throw StateError('Expected a JavaScript Promise.');
  }
  final value = await jsPromise.toDart;
  return _fromJsAny(value) as T;
}

JSAny? _toJsAny(Object? value) {
  if (value == null) return null;
  try {
    return value as JSAny;
  } catch (_) {}
  if (value is String) return value.toJS;
  if (value is bool) return value.toJS;
  if (value is int) return value.toJS;
  if (value is double) return value.toJS;
  return value.jsify();
}

Object? _fromJsAny(JSAny? value) {
  if (value == null) return null;
  try {
    return (value as JSString).toDart;
  } catch (_) {}
  try {
    return (value as JSBoolean).toDart;
  } catch (_) {}
  try {
    return (value as JSNumber).toDartDouble;
  } catch (_) {}
  return value;
}

String _propertyName(Object property) {
  if (property is String) return property;
  if (property is num) return property.toString();
  return property.toString();
}

JSObject _asJsObject(Object? object) {
  try {
    return object as JSObject;
  } catch (_) {
    throw StateError('Expected a JavaScript object.');
  }
}

JSFunction _asJsFunction(Object? object) {
  try {
    return object as JSFunction;
  } catch (_) {
    throw StateError('Expected a JavaScript function.');
  }
}
