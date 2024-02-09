import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:image_picker/image_picker.dart';

import 'utils.dart';
import 'video_view.dart';

class GalleryView extends StatefulWidget {
  GalleryView(
      {Key? key,
      required this.title,
      this.text,
      required this.onImage,
      this.customPaint,
      required this.onDetectorViewModeChanged})
      : super(key: key);

  final String title;
  final String? text;
  final CustomPaint? customPaint;
  final Function(InputImage inputImage) onImage;
  final Function()? onDetectorViewModeChanged;

  @override
  State<GalleryView> createState() => _GalleryViewState();
}

class _GalleryViewState extends State<GalleryView> {
  File? _image;
  File? _video;
  String? _path;
  ImagePicker? _imagePicker;

  @override
  void initState() {
    super.initState();

    _imagePicker = ImagePicker();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 20.0),
              child: GestureDetector(
                onTap: widget.onDetectorViewModeChanged,
                child: Icon(
                  Platform.isIOS ? Icons.camera_alt_outlined : Icons.camera,
                ),
              ),
            ),
          ],
        ),
        body: _galleryBody());
  }

  Widget _galleryBody() {
    return ListView(shrinkWrap: true, children: [
      _image != null
          ? Container(
              child: Stack(
                // fit: StackFit.expand,
                children: <Widget>[
                  Image.file(
                    _image!,
                  ),
                  if (widget.customPaint != null)
                    Positioned(
                        bottom: 0,
                        top: 0,
                        left: 0,
                        right: 0,
                        child: widget.customPaint!)
                ],
              ),
            )
          : _video != null
              ? SizedBox(
                  height: 500,
                  child: VideoView(
                    video: _video!,
                    onImage: widget.onImage,
                    customPaint: widget.customPaint,
                  ),
                )
              : Icon(
                  Icons.image,
                  size: 200,
                ),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton(
          onPressed: _getImageAsset,
          child: Text('From Assets'),
        ),
      ),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton(
          child: Text('From Gallery'),
          onPressed: () => _getImage(ImageSource.gallery),
        ),
      ),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton(
          child: Text('Take a picture'),
          onPressed: () => _getImage(ImageSource.camera),
        ),
      ),
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: ElevatedButton(
          child: Text('Take a video'),
          onPressed: () => _getVideo(),
        ),
      ),
      if (_image != null)
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
              '${_path == null ? '' : 'Image path: $_path'}\n\n${widget.text ?? ''}'),
        ),
    ]);
  }

  Future _getImage(ImageSource source) async {
    setState(() {
      _image = null;
      _path = null;
    });
    final pickedFile = await _imagePicker?.pickImage(source: source);
    if (pickedFile != null) {
      _processFile(pickedFile.path);
    }
  }

  Future _getVideo() async {
    setState(() {
      _image = null;
      _path = null;
    });
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      _video = File(result.files.single.path!);
      print("video path---${result.files.single.path!}");
      setState(() {});
    } else {
      // User canceled the picker
    }
  }

  Future _getImageAsset() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);
    final assets = manifestMap.keys
        .where((String key) => key.contains('images/'))
        .where((String key) =>
            key.contains('.jpg') ||
            key.contains('.jpeg') ||
            key.contains('.png') ||
            key.contains('.webp'))
        .toList();

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30.0)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select image',
                    style: TextStyle(fontSize: 20),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.7),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (final path in assets)
                            GestureDetector(
                              onTap: () async {
                                Navigator.of(context).pop();
                                _processFile(await getAssetPath(path));
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Image.asset(path),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancel')),
                ],
              ),
            ),
          );
        });
  }

  Future _processFile(String path) async {
    setState(() {
      _image = File(path);
    });
    _path = path;
    Size imgSize = await getImageSize(_image!);
    print("---nnvnvnvddddddn$imgSize");
    final inputImage = InputImage.fromFilePath(path);
    widget.onImage(inputImage);
  }

  Future<Size> getImageSize(File imageFile) async {
    final Completer<Size> completer = Completer<Size>();

    final Image image = Image.file(imageFile);
    image.image.resolve(ImageConfiguration()).addListener(
      ImageStreamListener(
        (ImageInfo imageInfo, bool synchronousCall) {
          final Size size = Size(
            imageInfo.image.width.toDouble(),
            imageInfo.image.height.toDouble(),
          );
          completer.complete(
              size); // Resolve the completer with the image dimensions
        },
      ),
    );

    return completer.future; // Return a Future<Size> with the image dimensions
  }
}
