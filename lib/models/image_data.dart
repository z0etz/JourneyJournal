import 'package:hive/hive.dart';

part 'image_data.g.dart';

@HiveType(typeId: 4)
class ImageData {
  @HiveField(0)
  String path;

  @HiveField(1)
  List<String> tags;

  @HiveField(2)
  int order;

  ImageData({
    required this.path,
    this.tags = const [],
    required this.order,
  });
}