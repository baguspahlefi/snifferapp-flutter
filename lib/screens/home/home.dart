// ignore_for_file: use_build_context_synchronously

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_application_1/models/noteModel.dart';
import 'package:flutter_application_1/services/db_helper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:photo_manager/photo_manager.dart';

class Home extends StatefulWidget {
  final String title;

  const Home({super.key, required this.title});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final deviceInfo = DeviceInfoPlugin();
  DatabaseHelper noteDatabase = DatabaseHelper.instance;
  List<File> _images = [];
  bool isLoading = false;
  bool isUploading = false;

  final String apiUrl = 'http://127.0.0.1:8000/upload-images';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickAndUploadImages();
    });
  }

  @override
  dispose() {
    noteDatabase.close();
    super.dispose();
  }

  Future<void> _pickAndUploadImages() async {
    await _pickImages();
    if (_images.isNotEmpty) {
      await uploadImages();
    }
  }

  Future<void> uploadImages() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No images to upload')),
      );
      return;
    }

    setState(() {
      isUploading = true;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      // Add each image to the request
      for (var i = 0; i < _images.length; i++) {
        var file = _images[i];
        var stream = http.ByteStream(file.openRead());
        var length = await file.length();

        var multipartFile = http.MultipartFile(
          'images[]',
          stream,
          length,
          filename: 'image_$i.jpg',
        );

        request.files.add(multipartFile);
      }

      var response = await request.send();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Images uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to upload images');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading images: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }

  Future<void> _pickImages() async {
    setState(() {
      isLoading = true;
    });
    
    PermissionStatus status;
    
    if (Platform.isAndroid) {
      final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        status = await Permission.photos.request();
      } else {
        status = await Permission.storage.request();
      }
    } else {
      status = await Permission.photos.request();
    }

    if (status.isGranted) {
      try {
        List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
          type: RequestType.image,
        );
        if (albums.isNotEmpty) {
          List<AssetEntity> media = await albums[0].getAssetListRange(
            start: 0,
            end: 5,
          );
          
          List<File?> files = await Future.wait(
            media.map((asset) => asset.file)
          );
          
          setState(() {
            _images = files.whereType<File>().toList();
            isLoading = false;
          });
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching images: $e');
        }
        setState(() {
          isLoading = false;
        });
      }
    } else if (status.isPermanentlyDenied) {
      setState(() {
        isLoading = false;
      });
      
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permission Required'),
          content: const Text('Please enable storage permission in settings to pick images'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.pop(context);
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(247, 250, 252, 1.0),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(94, 114, 228, 1.0),
        elevation: 0.0,
        title: Text(widget.title),
      ),
      body: isLoading || isUploading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    isUploading ? 'Uploading images...' : 'Loading images...',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            )
          : _images.isEmpty
              ? const Center(
                  child: Text('No images found'),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1,
                    ),
                    itemCount: _images.length,
                   itemBuilder: (context, index) {
                      var file = _images[index];
                      var fileName = file.path.split('/').last;
                      var fileSize = file.lengthSync(); // Mendapatkan ukuran file

                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                                child: Image.file(
                                  file,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Name: $fileName',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Size: ${(fileSize / 1024).toStringAsFixed(2)} KB',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndUploadImages,
        tooltip: 'Pick and Upload Images',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}