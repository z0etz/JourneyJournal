// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'route_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RouteModelAdapter extends TypeAdapter<RouteModel> {
  @override
  final int typeId = 1;

  @override
  RouteModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RouteModel(
      id: fields[0] as String,
      name: fields[1] as String,
      routePoints: (fields[2] as List?)?.cast<RoutePoint>(),
      startIndex: fields[3] as int,
      endIndex: fields[4] as int,
    );
  }

  @override
  void write(BinaryWriter writer, RouteModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.routePoints)
      ..writeByte(3)
      ..write(obj.startIndex)
      ..writeByte(4)
      ..write(obj.endIndex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RouteModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
