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
      startPointId: fields[3] as String?,
      endPointId: fields[4] as String?,
      snapStartToFirst: fields[5] as bool,
      snapEndToLast: fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, RouteModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.routePoints)
      ..writeByte(3)
      ..write(obj.startPointId)
      ..writeByte(4)
      ..write(obj.endPointId)
      ..writeByte(5)
      ..write(obj.snapStartToFirst)
      ..writeByte(6)
      ..write(obj.snapEndToLast);
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
