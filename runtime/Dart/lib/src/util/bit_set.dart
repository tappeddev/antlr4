/*
 * Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */

import 'dart:math';
import 'dart:typed_data';

import 'package:bitcount/bitcount.dart';

class BitSet {
  static final Uint32List EmptyBits = Uint32List(0);
  static const BitsPerElement = 8 * 32;

  Uint32List _data = EmptyBits;

  BitSet([int nbits = 0]) {
    if (nbits == 0) {
      return;
    }
    if (nbits < 0) throw RangeError('nbits');

    if (nbits > 0) {
      final length = ((nbits + BitsPerElement - 1) / BitsPerElement).floor();
      _data = Uint32List(length);
    }
  }

  static int getBitCount(Uint32List value) {
    return value.fold<int>(
        0, (previousValue, element) => previousValue + element.bitCount());
  }

  static final List<int> index64 = [
    0,
    47,
    1,
    56,
    48,
    27,
    2,
    60,
    57,
    49,
    41,
    37,
    28,
    16,
    3,
    61,
    54,
    58,
    35,
    52,
    50,
    42,
    21,
    44,
    38,
    32,
    29,
    23,
    17,
    11,
    4,
    62,
    46,
    55,
    26,
    59,
    40,
    36,
    15,
    53,
    34,
    51,
    20,
    43,
    31,
    22,
    10,
    45,
    25,
    39,
    14,
    33,
    19,
    30,
    9,
    24,
    13,
    18,
    8,
    12,
    7,
    6,
    5,
    63
  ];

  static int bitScanForward(int value) {
    if (value == 0) return -1;

    final debruijn64 = BigInt.from(0x03f79d71b4cb0a89);

    final first = BigInt.from(value ^ (value - 1));

    final second = (first * debruijn64);

    return index64[((second >> 58) % BigInt.from(64)).toInt()];
  }

  BitSet clone() {
    final result = BitSet();
    result._data = Uint32List.fromList(_data);
    return result;
  }

  void clear(int index) {
    if (index < 0) throw RangeError('index');

    final element = (index / BitsPerElement).floor();
    if (element >= _data.length) return;

    _data[element] &= ~(1 << (index % BitsPerElement));
  }

  bool operator [](int index) {
    return get(index);
  }

  bool get(int index) {
    if (index < 0) throw RangeError('index');

    final element = (index / BitsPerElement).floor();
    if (element >= _data.length) return false;

    return (_data[element] & (1 << (index % BitsPerElement))) != 0;
  }

  void set(int index) {
    if (index < 0) throw RangeError('index');

    final element = (index / BitsPerElement).floor();
    if (element >= _data.length) {
      final newList = Uint32List(max(_data.length * 2, element + 1))
        ..setRange(0, _data.length, _data);
      _data = newList;
    }
    _data[element] |= 1 << (index % BitsPerElement);
  }

  bool get isEmpty {
    for (var i = 0; i < _data.length; i++) {
      if (_data[i] != 0) return false;
    }

    return true;
  }

  int get cardinality {
    return getBitCount(_data);
  }

  int nextset(int fromIndex) {
    if (fromIndex < 0) throw RangeError('fromIndex');

    if (isEmpty) return -1;

    var i = (fromIndex / BitsPerElement).floor();
    if (i >= _data.length) return -1;

    var current = _data[i] & ~((1 << (fromIndex % BitsPerElement)) - 1);

    while (true) {
      final bit = bitScanForward(current);
      if (bit >= 0) return bit + i * BitsPerElement;

      i++;
      if (i >= _data.length) break;

      current = _data[i];
    }

    return -1;
  }

  void and(BitSet set) {
    final length = min(_data.length, set._data.length);
    for (var i = 0; i < length; i++) {
      _data[i] &= set._data[i];
    }

    for (var i = length; i < _data.length; i++) {
      _data[i] = 0;
    }
  }

  void or(BitSet set) {
    if (set._data.length > _data.length) {
      final newList = Uint32List(set._data.length)
        ..setRange(0, _data.length, _data);
      _data = newList;
    }

    for (var i = 0; i < set._data.length; i++) {
      _data[i] |= set._data[i];
    }
  }

  @override
  bool operator ==(obj) {
    final other = obj as BitSet;

    if (isEmpty) return other.isEmpty;

    final minlength = min(_data.length, other._data.length);
    for (var i = 0; i < minlength; i++) {
      if (_data[i] != other._data[i]) return false;
    }

    for (var i = minlength; i < _data.length; i++) {
      if (_data[i] != 0) return false;
    }

    for (var i = minlength; i < other._data.length; i++) {
      if (other._data[i] != 0) return false;
    }

    return true;
  }

  @override
  int get hashCode {
    var result = 1;
    for (var i = 0; i < _data.length; i++) {
      if (_data[i] != 0) {
        result = result * 31 ^ i;
        result = result * 31 ^ _data[i];
      }
    }

    return result.hashCode;
  }

  @override
  String toString() {
    final builder = StringBuffer();
    builder.write('{');

    for (var i = nextset(0); i >= 0; i = nextset(i + 1)) {
      if (builder.length > 1) builder.write(', ');

      builder.write(i);
    }

    builder.write('}');
    return builder.toString();
  }
}
