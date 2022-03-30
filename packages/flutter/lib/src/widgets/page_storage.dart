// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import 'framework.dart';

/// A key can be used to persist the widget state in storage after
/// the destruction and will be restored when recreated.
///
/// Each key with its value plus the ancestor chain of other PageStorageKeys need to
/// be unique within the widget's closest ancestor [PageStorage]. To make it possible for a
/// saved value to be found when a widget is recreated, the key's value must
/// not be objects whose identity will change each time the widget is created.
///
/// See also:
///
///  * [PageStorage], which is the closet ancestor for [PageStorageKey].
class PageStorageKey<T> extends ValueKey<T> {
  /// Creates a [ValueKey] that defines where [PageStorage] values will be saved.
  const PageStorageKey(T value) : super(value);
}

@immutable
class _StorageEntryIdentifier {
  const _StorageEntryIdentifier(this.keys)
    : assert(keys != null);

  final List<PageStorageKey<dynamic>> keys;

  bool get isNotEmpty => keys.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType)
      return false;
    return other is _StorageEntryIdentifier
        && listEquals<PageStorageKey<dynamic>>(other.keys, keys);
  }

  @override
  int get hashCode => Object.hashAll(keys);

  @override
  String toString() {
    return 'StorageEntryIdentifier(${keys.join(":")})';
  }
}

/// A storage bucket associated with a page in an app.
///
/// Useful for storing per-page state that persists across navigations from one
/// page to another.
class PageStorageBucket {
  static bool _maybeAddKey(BuildContext context, List<PageStorageKey<dynamic>> keys) {
    final Widget widget = context.widget;
    final Key? key = widget.key;
    if (key is PageStorageKey)
      keys.add(key);
    return widget is! PageStorage;
  }

  List<PageStorageKey<dynamic>> _allKeys(BuildContext context) {
    final List<PageStorageKey<dynamic>> keys = <PageStorageKey<dynamic>>[];
    if (_maybeAddKey(context, keys)) {
      context.visitAncestorElements((Element element) {
        return _maybeAddKey(element, keys);
      });
    }
    return keys;
  }

  _StorageEntryIdentifier _computeIdentifier(BuildContext context) {
    return _StorageEntryIdentifier(_allKeys(context));
  }

  Map<Object, dynamic>? _storage;

  /// Write the given data into this page storage bucket using the
  /// specified identifier or an identifier computed from the given context.
  /// The computed identifier is based on the [PageStorageKey]s
  /// found in the path from context to the [PageStorage] widget that
  /// owns this page storage bucket.
  ///
  /// If an explicit identifier is not provided and no [PageStorageKey]s
  /// are found, then the `data` is not saved.
  void writeState(BuildContext context, dynamic data, { Object? identifier }) {
    _storage ??= <Object, dynamic>{};
    if (identifier != null) {
      _storage![identifier] = data;
    } else {
      final _StorageEntryIdentifier contextIdentifier = _computeIdentifier(context);
      if (contextIdentifier.isNotEmpty)
        _storage![contextIdentifier] = data;
    }
  }

  /// Read given data from into this page storage bucket using the specified
  /// identifier or an identifier computed from the given context.
  /// The computed identifier is based on the [PageStorageKey]s
  /// found in the path from context to the [PageStorage] widget that
  /// owns this page storage bucket.
  ///
  /// If an explicit identifier is not provided and no [PageStorageKey]s
  /// are found, then null is returned.
  dynamic readState(BuildContext context, { Object? identifier }) {
    if (_storage == null)
      return null;
    if (identifier != null)
      return _storage![identifier];
    final _StorageEntryIdentifier contextIdentifier = _computeIdentifier(context);
    return contextIdentifier.isNotEmpty ? _storage![contextIdentifier] : null;
  }
}

/// Establish a subtree in which widgets can opt into persisting states after
/// being destroyed.
///
/// [PageStorage] is used to save and restore values that can outlive the widget.
/// For example, when multiple pages are grouped in tabs, when a page is
/// switched out, its widget is destroyed and its state is lost. By adding a
/// [PageStorage] at the root and adding a [PageStorageKey] to each page, some of the
/// page's state (e.g. the scroll position of a [Scrollable] widget) will be stored
/// automatically in its closest ancestor [PageStorage], and restored when it's
/// switched back.
///
/// Usually you don't need to explicitly use a [PageStorage], since it's already
/// included in routes.
///
/// [PageStorageKey] is used by [Scrollable] if [ScrollController.keepScrollOffset]
/// is enabled to save their [ScrollPosition]s. When more than one
/// scrollable ([ListView], [SingleChildScrollView], [TextField], etc.) appears
/// within the widget's closest ancestor [PageStorage] (such as within the same route),
/// if you want to save all of their positions independently,
/// you should give each of them unique [PageStorageKey]s, or set some of their
/// `keepScrollOffset` false to prevent saving.
///
/// {@tool dartpad}
/// This sample shows how to explicitly use a [PageStorage] to
/// store the states of its children pages. Each page includes a scrollable
/// list, whose position is preserved when switching between the tabs thanks to
/// the help of [PageStorageKey].
///
/// ** See code in examples/api/lib/widgets/page_storage/page_storage.0.dart **
/// {@end-tool}
///
/// See also:
///
///  * [ModalRoute], which includes this class.
class PageStorage extends StatelessWidget {
  /// Creates a widget that provides a storage bucket for its descendants.
  ///
  /// The [bucket] argument must not be null.
  const PageStorage({
    Key? key,
    required this.bucket,
    required this.child,
  }) : assert(bucket != null),
       super(key: key);

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  final Widget child;

  /// The page storage bucket to use for this subtree.
  final PageStorageBucket bucket;

  /// The bucket from the closest instance of this class that encloses the given context.
  ///
  /// Returns null if none exists.
  ///
  /// Typical usage is as follows:
  ///
  /// ```dart
  /// PageStorageBucket bucket = PageStorage.of(context);
  /// ```
  ///
  /// This method can be expensive (it walks the element tree).
  static PageStorageBucket? of(BuildContext context) {
    final PageStorage? widget = context.findAncestorWidgetOfExactType<PageStorage>();
    return widget?.bucket;
  }

  @override
  Widget build(BuildContext context) => child;
}
