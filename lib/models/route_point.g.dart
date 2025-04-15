// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_point.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RoutePointAdapter extends TypeAdapter<RoutePoint> {
  @override
  final int typeId = 3;

  @override
  RoutePoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RoutePoint(
      title: fields[1] as String,
      description: fields[2] as String,
      images: (fields[3] as List?)?.cast<ImageData>(),
      date: fields[4] as DateTime?,
      id: fields[5] as String,
    ).._point = (fields[0] as List).cast<double>();
  }

  @override
  void write(BinaryWriter writer, RoutePoint obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj._point)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.images)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoutePointAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
