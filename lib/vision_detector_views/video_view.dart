import 'dart:io';
import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:image/image.dart' as img;

import 'painters/pose_painter.dart';

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
  bool isVideoLoaded = false;
  bool imageProcessing = false;
  Map<int, dynamic> posesMap = {};
  final PoseDetector _poseDetector =
      PoseDetector(options: PoseDetectorOptions());
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  int cmiliseconds = 0;
  double imgWidth = 0;
  double imgHeight = 0;

  @override
  void initState() {
    super.initState();
    initPath();
    // plyVideo();
  }

  initPath() async {
    _tempDir = (await getExternalStorageDirectory())?.path;
    _inputVideoPath = widget.video.absolute.path;
    setState(() {});
    extractFrameFromVideo();
  }

  plyVideo() {
    print('call video');
    _controller = VideoPlayerController.file(widget.video,
        videoPlayerOptions: VideoPlayerOptions())
      ..initialize().then((_) {
        setState(() {
          isVideoLoaded = true;
        });
      });
    _controller.addListener(() {
      setState(() {
        print(
            'current duration-ssss--${_controller.value.position.inMilliseconds ~/ 1000}');
        cmiliseconds = _controller.value.position.inMilliseconds;
      });
      // if (_controller.value.position.inMilliseconds == 0) return;
      // processVideo(_controller.value.position.inMilliseconds);
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
        imageProcessing = false;
        // CANCEL
      } else {
        final failStackTrace = await session.getArguments();
        print("error----${failStackTrace}");
        imageProcessing = false;
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

  Future<void> extractFrameFromVideo() async {
    await FFmpegKit.execute(
            '-i $_inputVideoPath -r 10 -f image2 $_tempDir/frame_%03d.png')
        .then((session) async {
      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        List<File> processedFrames = [];
        for (int i = 1;; i++) {
          File frameFile =
              File('$_tempDir/frame_${i.toString().padLeft(3, '0')}.png');
          if (!frameFile.existsSync()) break;
          processedFrames.add(frameFile);
          InputImage? inputImage = await _inputImageFromCameraImage(frameFile);
          if (inputImage != null) {
            CustomPaint? customPaint =
                await _processImage(inputImage, frameFile);
            print('process image $i $customPaint');
            posesMap.addEntries({i * 100: customPaint}.entries);
          }
        }
        print(
            "processed Frames---${processedFrames.length} ${posesMap.length}");
        print("processed Frames map---${posesMap}");
        plyVideo();
        imageProcessing = false;
      } else if (ReturnCode.isCancel(returnCode)) {
        imageProcessing = false;
        // CANCEL
      } else {
        final failStackTrace = await session.getArguments();
        print("error----${failStackTrace}");
        imageProcessing = false;
        // ERROR
      }
    });
  }

  Widget? getCustomPainter(int miliseconds) {
    print('object1111111111dddddd--${roundToNearest100(miliseconds)}');
    return posesMap[roundToNearest100(miliseconds)];
  }

  int roundToNearest100(int value) {
    return ((value + 50) ~/ 100) * 100;
  }

  Future<CustomPaint?> _processImage(InputImage inputImage, File frame) async {
    print("call input imagee-");
    if (!_canProcess) return null;
    if (_isBusy) return null;
    _isBusy = true;

    final poses = await _poseDetector.processImage(inputImage);
    poses.forEach((element) {
      print("landmarks---->${element.landmarks}");
    });
    if (imgWidth == 0 || imgHeight == 0) {
      List<int> bytes = await frame.readAsBytes();

      // Decode the image
      img.Image? image = img.decodeImage(bytes);
      if (image != null) {
        imgWidth = image.width.toDouble();
        imgHeight = image.height.toDouble();
        setState(() {});
        print('Image width: $imgWidth, height: $imgHeight');
      }
    }
    final painter = PosePainter(
      poses,
      Size(imgWidth, imgHeight),
      InputImageRotation.rotation0deg,
      CameraLensDirection.back,
    );
    _customPaint = CustomPaint(painter: painter);

    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
    return _customPaint;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
          child: isVideoLoaded
              ? _controller.value.isInitialized
                  ? Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: _controller.value.aspectRatio,
                          child: VideoPlayer(_controller),
                        ),
                        // if (widget.customPaint != null)
                        Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: getCustomPainter(cmiliseconds) ??
                                Container(
                                  height: 100,
                                  width: 100,
                                ))
                      ],
                    )
                  : Container()
              : Center(
                  child: CircularProgressIndicator(),
                ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            if (isVideoLoaded) {
              setState(() {
                _controller.value.isPlaying
                    ? _controller.pause()
                    : _controller.play();
              });
            }
          },
          child: isVideoLoaded
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
