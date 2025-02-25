// import 'package:flutter/material.dart';
// import 'package:flutter_quick_video_encoder/flutter_quick_video_encoder.dart';
//
// void main() {
//   runApp(MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   final VideoEncoder _videoEncoder = VideoEncoder();
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(title: Text('Video Encoding Example')),
//         body: Center(
//           child: ElevatedButton(
//             onPressed: () async {
//               // Example video file path (make sure it's a valid path)
//               String inputFilePath = '/path/to/input/video.mp4';
//               String outputFilePath = '/path/to/output/video.mp4';
//
//               // Encode video
//               bool result = await _videoEncoder.encodeVideo(inputFilePath, outputFilePath);
//
//               if (result) {
//                 print('Video encoded successfully!');
//               } else {
//                 print('Failed to encode video.');
//               }
//             },
//             child: Text('Encode Video'),
//           ),
//         ),
//       ),
//     );
//   }
// }
