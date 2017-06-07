// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';

import 'package:typed_data/typed_buffers.dart' show Uint8Buffer;

/// Write-only buffer for incrementally building a [ByteData] instance.
///
/// A WriteBuffer instance can be used only once. Attempts to reuse will result
/// in [NoSuchMethodError]s being thrown.
///
/// The byte order used is [Endianness.HOST_ENDIAN] throughout.
class WriteBuffer {
  /// Creates an interface for incrementally building a [ByteData] instance.
  WriteBuffer() {
    _buffer = new Uint8Buffer();
    _eightBytes = new ByteData(8);
    _eightBytesAsList = _eightBytes.buffer.asUint8List();
  }

  Uint8Buffer _buffer;
  ByteData _eightBytes;
  Uint8List _eightBytesAsList;

  /// Write a Uint8 into the buffer.
  void putUint8(int byte) {
    _buffer.add(byte);
  }

  /// Write a Uint16 into the buffer.
  void putUint16(int value) {
    _eightBytes.setUint16(0, value, Endianness.HOST_ENDIAN);
    _buffer.addAll(_eightBytesAsList, 0, 2);
  }

  /// Write a Uint32 into the buffer.
  void putUint32(int value) {
    _eightBytes.setUint32(0, value, Endianness.HOST_ENDIAN);
    _buffer.addAll(_eightBytesAsList, 0, 4);
  }

  /// Write an Int32 into the buffer.
  void putInt32(int value) {
    _eightBytes.setInt32(0, value, Endianness.HOST_ENDIAN);
    _buffer.addAll(_eightBytesAsList, 0, 4);
  }

  /// Write an Int64 into the buffer.
  void putInt64(int value) {
    _eightBytes.setInt64(0, value, Endianness.HOST_ENDIAN);
    _buffer.addAll(_eightBytesAsList, 0, 8);
  }

  /// Write an Float64 into the buffer.
  void putFloat64(double value) {
    _eightBytes.setFloat64(0, value, Endianness.HOST_ENDIAN);
    _buffer.addAll(_eightBytesAsList);
  }

  /// Write all the values from a [Uint8List] into the buffer.
  void putUint8List(Uint8List list) {
    _buffer.addAll(list);
  }

  /// Write all the values from a [Int32List] into the buffer.
  void putInt32List(Int32List list) {
    _alignTo(4);
    _buffer.addAll(list.buffer.asUint8List(list.offsetInBytes, 4 * list.length));
  }

  /// Write all the values from an [Int64List] into the buffer.
  void putInt64List(Int64List list) {
    _alignTo(8);
    _buffer.addAll(list.buffer.asUint8List(list.offsetInBytes, 8 * list.length));
  }

  /// Write all the values from a [Float64List] into the buffer.
  void putFloat64List(Float64List list) {
    _alignTo(8);
    _buffer.addAll(list.buffer.asUint8List(list.offsetInBytes, 8 * list.length));
  }

  void _alignTo(int alignment) {
    final int mod = _buffer.length % alignment;
    if (mod != 0) {
      for (int i = 0; i < alignment - mod; i++)
        _buffer.add(0);
    }
  }

  /// Finalize and return the written [ByteData].
  ByteData done() {
    final ByteData result = _buffer.buffer.asByteData(0, _buffer.lengthInBytes);
    _buffer = null;
    return result;
  }
}

/// Read-only buffer for reading sequentially from a [ByteData] instance.
///
/// The byte order used is [Endianness.HOST_ENDIAN] throughout.
class ReadBuffer {
  /// Creates a [ReadBuffer] for reading from the specified [data].
  ReadBuffer(this.data)
    : assert(data != null);

  /// The underlying data being read.
  final ByteData data;

  /// The position to read next.
  int _position = 0;

  /// Whether the buffer has data remaining to read.
  bool get hasRemaining => _position < data.lengthInBytes;

  /// Reads a Uint8 from the buffer.
  int getUint8() {
    return data.getUint8(_position++);
  }

  /// Reads a Uint16 from the buffer.
  int getUint16() {
    final int value = data.getUint16(_position, Endianness.HOST_ENDIAN);
    _position += 2;
    return value;
  }

  /// Reads a Uint32 from the buffer.
  int getUint32() {
    final int value = data.getUint32(_position, Endianness.HOST_ENDIAN);
    _position += 4;
    return value;
  }

  /// Reads an Int32 from the buffer.
  int getInt32() {
    final int value = data.getInt32(_position, Endianness.HOST_ENDIAN);
    _position += 4;
    return value;
  }

  /// Reads an Int64 from the buffer.
  int getInt64() {
    final int value = data.getInt64(_position, Endianness.HOST_ENDIAN);
    _position += 8;
    return value;
  }

  /// Reads a Float64 from the buffer.
  double getFloat64() {
    final double value = data.getFloat64(_position, Endianness.HOST_ENDIAN);
    _position += 8;
    return value;
  }

  /// Reads the given number of Uint8s from the buffer.
  Uint8List getUint8List(int length) {
    final Uint8List list = data.buffer.asUint8List(data.offsetInBytes + _position, length);
    _position += length;
    return list;
  }

  /// Reads the given number of Int32s from the buffer.
  Int32List getInt32List(int length) {
    _alignTo(4);
    final Int32List list = data.buffer.asInt32List(data.offsetInBytes + _position, length);
    _position += 4 * length;
    return list;
  }

  /// Reads the given number of Int64s from the buffer.
  Int64List getInt64List(int length) {
    _alignTo(8);
    final Int64List list = data.buffer.asInt64List(data.offsetInBytes + _position, length);
    _position += 8 * length;
    return list;
  }

  /// Reads the given number of Float64s from the buffer.
  Float64List getFloat64List(int length) {
    _alignTo(8);
    final Float64List list = data.buffer.asFloat64List(data.offsetInBytes + _position, length);
    _position += 8 * length;
    return list;
  }

  void _alignTo(int alignment) {
    final int mod = _position % alignment;
    if (mod != 0)
      _position += alignment - mod;
  }
}
