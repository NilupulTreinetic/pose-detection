import 'dart:io';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

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
  bool imageProcessing = false;

  @override
  void initState() {
    super.initState();
    initPath();
    plyVideo();
  }

  initPath() async {
    _tempDir = (await getExternalStorageDirectory())?.path;
    _inputVideoPath = widget.video.absolute.path;
    setState(() {});
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
      print(
          'current duration---${_controller.value.position.inMilliseconds ~/ 1000}');
      if (_controller.value.position.inMilliseconds == 0) return;
      processVideo(_controller.value.position.inMilliseconds);
    });
  }

  Future<void> processVideo(int currentTime) async {
    // Extract frames from input video
    if (imageProcessing) return;
    imageProcessing = true;
    await FFmpegKit.execute(
            '-i $_inputVideoPath -ss ${currentTime ~/ 1000} -vframes 1 -f image2 $_tempDir/frame_$currentTime.png')
        .then((session) async {
      final returnCode = await session.getReturnCode();
      print(
          "hhehehehehehehehehheheheheheh-------${await session.getDuration()}");
      if (ReturnCode.isSuccess(returnCode)) {
        // SUCCESS
        File frameFile = File('$_tempDir/frame_$currentTime.png');
        if (!frameFile.existsSync()) return;
        print("processed Frames exist---${frameFile.existsSync()}");
        InputImage? inputImage = await _inputImageFromCameraImage(frameFile);

        if (inputImage != null) {
          widget.onImage(inputImage);
        }
        imageProcessing = false;
      } else if (ReturnCode.isCancel(returnCode)) {
        // setState(() {
        imageProcessing = false;
        // });
        // CANCEL
      } else {
        final failStackTrace = await session.getArguments();
        print("error----${failStackTrace}");
        // setState(() {
        imageProcessing = false;
        // });
        // ERROR
      }
    });
  }

  Future<InputImage?> _inputImageFromCameraImage(File image) async {
    // Uint8List bytes = await image.readAsBytes();
    // var decodedImage = await decodeImageFromList(image.readAsBytesSync());
    return InputImage.fromFilePath(image.path);
    // return InputImage.fromBytes(
    //   bytes: bytes,
    //   metadata: InputImageMetadata(
    //     size:
    //         Size(decodedImage.width.toDouble(), decodedImage.height.toDouble()),
    //     rotation: InputImageRotation.rotation0deg, // used only in Android
    //     format: InputImageFormat.nv21, // used only in iOS
    //     bytesPerRow: 1, // used only in iOS
    //   ),
    // );
  }

  @override
  Widget build(BuildContext context) {
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
