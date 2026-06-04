import 'dart:convert';
import 'dart:typed_data';

class BinaryWriter {
  final BytesBuilder _bytes = BytesBuilder(copy: false);

  void writeUint8(int value) {
    _bytes.add(<int>[value & 0xff]);
  }

  void writeBool(bool value) {
    writeUint8(value ? 1 : 0);
  }

  void writeUint16BigEndian(int value) {
    final data = ByteData(2)..setUint16(0, value, Endian.big);
    _bytes.add(data.buffer.asUint8List());
  }

  void writeUint16LittleEndian(int value) {
    final data = ByteData(2)..setUint16(0, value, Endian.little);
    _bytes.add(data.buffer.asUint8List());
  }

  void writeUint64BigEndian(int value) {
    final data = ByteData(8)..setUint64(0, value, Endian.big);
    _bytes.add(data.buffer.asUint8List());
  }

  void writeBytes(List<int> bytes) {
    _bytes.add(bytes);
  }

  void writeRakNetString(String value) {
    final encoded = utf8.encode(value);
    writeUint16BigEndian(encoded.length);
    writeBytes(encoded);
  }

  void writeVarUint(int value) {
    var remaining = value;
    while (true) {
      if ((remaining & ~0x7f) == 0) {
        writeUint8(remaining);
        return;
      }
      writeUint8((remaining & 0x7f) | 0x80);
      remaining >>= 7;
    }
  }

  void writeVarString(String value) {
    final encoded = utf8.encode(value);
    writeVarUint(encoded.length);
    writeBytes(encoded);
  }

  Uint8List takeBytes() => _bytes.takeBytes();
}
