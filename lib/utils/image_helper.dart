import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

Future<String> saveImageLocally(XFile image) async {
  // Get the directory for storing images
  final Directory appDir = await getApplicationDocumentsDirectory();
  final Directory imageDir = Directory('${appDir.path}/images');
  if (!await imageDir.exists()) {
    await imageDir.create(recursive: true);
  }

  // Decode the image for resizing
  final img.Image? decodedImage = img.decodeImage(await image.readAsBytes());
  if (decodedImage == null) throw Exception("Failed to decode image");

  // Resize the image
  final img.Image resizedImage = img.copyResize(decodedImage, width: 800);

  // Save the resized image
  final String imageName = path.basename(image.path);
  final File newImageFile = File('${imageDir.path}/$imageName')
    ..writeAsBytesSync(img.encodeJpg(resizedImage));

  return newImageFile.path;
}
