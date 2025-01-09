// ignore_for_file: use_build_context_synchronously

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
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

  @override
  void initState() {
    super.initState();
    // Automatically trigger image picker when the view is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickImages();
    });
  }

  @override
  dispose() {
    noteDatabase.close();
    super.dispose();
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
          // Get the first 5 images
          List<AssetEntity> media = await albums[0].getAssetListRange(
            start: 0,
            end: 5, // Get 5 images
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
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
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
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _images[index],
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickImages,
        tooltip: 'Refresh Images',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}