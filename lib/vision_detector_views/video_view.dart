import 'dart:io';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'dart:ui' as ui;
import 'dart:io';

class VideoView extends StatefulWidget {
  final File video;
  final Function(InputImage inputImage) onImage;
  final CustomPaint? customPaint;
  const VideoView(
      {Key? key, required this.video, required this.onImage, this.customPaint})
      : super(key: key);

  @override
  State<VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<VideoView> {
  late VideoPlayerController _controller;
  String? _tempDir;
  String? _inputVideoPath;
  String? _outputVideoPath;
  bool isvideoLoaded = false;

  @override
  void initState() {
    super.initState();
    plyVideo();
    // initPaths();
  }

  plyVideo() {
    _controller = VideoPlayerController.file(widget.video,
        videoPlayerOptions: VideoPlayerOptions())
      ..initialize().then((_) {
        setState(() {
          isvideoLoaded = true;
        });
      });
    _controller.addListener(() {
      print('current duration---${_controller.value.position.inMilliseconds}');
      processVideo(_controller.value.position.inMilliseconds);
    });
  }

  Future<void> initPaths() async {
    // Get the temporary directory path
    _tempDir = (await getTemporaryDirectory()).path;
    setState(() {
      _inputVideoPath = widget.video.absolute.path;
    });

    _outputVideoPath = '$_tempDir/output.mp4';
    print("input video path---$_inputVideoPath");
  }

  Future<void> processVideo(int currentTime) async {
    initPaths();
    // Extract frames from input video
    await FFmpegKit.execute(
            '-i $_inputVideoPath -r 10 -ss ${currentTime ~/ 1000} -vframes 1 -f image2 $_tempDir/frame_%03d.png')
        .then((session) async {
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        // SUCCESS
        List<File> processedFrames = [];
        for (int i = 1;; i++) {
          File frameFile =
              File('$_tempDir/frame_${i.toString().padLeft(3, '0')}.png');
          if (!frameFile.existsSync()) break;
          processedFrames.add(frameFile);
        }
        print("processed Frames---${processedFrames.length}");
        // Combine processed frames back into a video
        // await FFmpegKit.execute(
        //         '-framerate 10 -i $_tempDir/frame_%03d.png -y $_outputVideoPath')
        //     .then((session) {
        //   if (ReturnCode.isSuccess(returnCode)) {
        //     print("Successes");
        // Directory directory = Directory(_tempDir!);
        // List<FileSystemEntity> files = directory.listSync();
        // for (FileSystemEntity file in files) {
        //   if (file is File) {
        //     // Add file name to the list
        //     print("ddaffafdddddf${file.path}");
        //   }
        // }

        //   print(
        //       'current duration---${_controller.value.position.inMilliseconds}');
        // } else {
        //   print("Error");
        // }
        // });
      } else if (ReturnCode.isCancel(returnCode)) {
        // CANCEL
      } else {
        final failStackTrace = await session.getArguments();
        print("error----${failStackTrace}");

        // ERROR
      }
    });

    // Process each frame (add custom drawings)
  }

  Future<InputImage?> _inputImageFromCameraImage(String imagePath) async {
    Uint8List bytes = await File(imagePath).readAsBytes();
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(1200, 900),
        rotation: InputImageRotation.rotation0deg, // used only in Android
        format: InputImageFormat.bgra8888, // used only in iOS
        bytesPerRow: 1, // used only in iOS
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('$_tempDir');
    return Scaffold(
        body: Center(
          child: isvideoLoaded
              ? _controller.value.isInitialized
                  ? Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: _controller.value.aspectRatio,
                          child: VideoPlayer(_controller),
                        ),
                        if (widget.customPaint != null)
                          Positioned(
                              top: 0,
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: widget.customPaint!)
                      ],
                    )
                  : Container()
              : Center(
                  child: CircularProgressIndicator(),
                ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // initPaths();
            if (isvideoLoaded) {
              setState(() {
                _controller.value.isPlaying
                    ? _controller.pause()
                    : _controller.play();
              });
            }
          },
          child: isvideoLoaded
              ? Icon(
                  _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                )
              : SizedBox(),
        ));
  }

  @override
  void dispose() {
    super.dispose();
    _controller.dispose();
  }
}
