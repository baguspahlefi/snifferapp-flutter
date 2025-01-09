
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter_application_1/models/noteModel.dart';
import 'package:flutter_application_1/services/db_helper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:photo_manager/photo_manager.dart';

class NoteView extends StatefulWidget {
  const NoteView({super.key, this.noteId});
  final int? noteId;

  @override
  State<NoteView> createState() => _NoteViewState();
}

class _NoteViewState extends State<NoteView> {
  final deviceInfo = DeviceInfoPlugin();
  final formKey = GlobalKey<FormState>();
  DatabaseHelper noteDatabase = DatabaseHelper.instance;

  TextEditingController titleController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  
  File? _image;
  final _picker = ImagePicker();

  late NoteModel note;
  bool isLoading = false;
  bool isNewNote = false;

  // Fungsi untuk memilih gambar dari galeri
 Future<void> _pickImage() async {
  PermissionStatus status;
  
   if (Platform.isAndroid) {
    final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
    if (androidInfo.version.sdkInt >= 33) {
      // Android 13 and above
      status = await Permission.photos.request();
    } else {
      // Android 12 and below
      status = await Permission.storage.request();
    }
  } else {
    // Non-Android platforms
    status = await Permission.photos.request();
  }
 if (status.isGranted) {
        try {
          // Mengambil file gambar pertama
          List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
            type: RequestType.image,
          );
          if (albums.isNotEmpty) {
            List<AssetEntity> media = await albums[0].getAssetListRange(
              start: 0,
              end: 1, // Hanya mengambil satu file
            );
            if (media.isNotEmpty) {
              File? file = await media[0].file;
              if (file != null) {
                setState(() {
                  _image = file;
                });
              }
            }
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error fetching image: $e');
          }
        }
      } else if (status.isPermanentlyDenied) {
    // Tampilkan dialog untuk mengarahkan ke settings
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
  void initState() {
    refreshNotes();
    super.initState();
  }

  refreshNotes() {
    if (widget.noteId == null) {
      setState(() {
        isNewNote = true;
      });
      return;
    }
    noteDatabase.read(widget.noteId!).then((value) {
      setState(() {
        note = value;
        titleController.text = note.title!;
        descriptionController.text = note.description!;
        if (note.imagePath != null) {
          _image = File(note.imagePath!);
        }
      });
    });
  }

  insert(NoteModel model) {
    noteDatabase.insert(model).then((respond) async {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Note successfully added."),
        backgroundColor: Color.fromARGB(255, 4, 160, 74),
      ));
      Navigator.pop(context, {
        'reload': true,
      });
    }).catchError((error) {
      if (kDebugMode) {
        print(error);
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Note failed to save."),
        backgroundColor: Color.fromARGB(255, 235, 108, 108),
      ));
    });
  }

  update(NoteModel model) {
    noteDatabase.update(model).then((respond) async {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Note successfully updated."),
        backgroundColor: Color.fromARGB(255, 4, 160, 74),
      ));
      Navigator.pop(context, {
        'reload': true,
      });
    }).catchError((error) {
      if (kDebugMode) {
        print(error);
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Note failed to update."),
        backgroundColor: Color.fromARGB(255, 235, 108, 108),
      ));
    });
  }

  createNote() async {
    setState(() {
      isLoading = true;
    });

    if (formKey.currentState != null && formKey.currentState!.validate()) {
      formKey.currentState?.save();

      NoteModel model = NoteModel(
        titleController.text, 
        descriptionController.text,
        imagePath: _image?.path,
      );

      if (isNewNote) {
        insert(model);
      } else {
        model.id = note.id;
        update(model);
      }
    }
    setState(() {
      isLoading = false;
    });
  }

  deleteNote() {
    noteDatabase.delete(note.id!);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Note successfully deleted."),
      backgroundColor: Color.fromARGB(255, 235, 108, 108),
    ));
    Navigator.pop(context);
  }

  String? validateTitle(String? value) {
    if (value == null || value.isEmpty) {
      return 'Enter a title.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(247, 250, 252, 1.0),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(94, 114, 228, 1.0),
        elevation: 0.0,
        title: Text(
          isNewNote ? 'Add a note' : 'Edit note',
        ),
      ),
      body: Form(
        key: formKey,
        child: Container(
          padding: const EdgeInsets.all(30),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Picker Section
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _image != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                _image!,
                                width: 200,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.add_photo_alternate,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "Tap to add image",
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        hintText: "Enter the title",
                        labelText: 'Title',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white,
                            width: 0.75,
                          ),
                          borderRadius: BorderRadius.all(
                            Radius.circular(10.0),
                          ),
                        ),
                      ),
                      validator: validateTitle,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Description Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        hintText: "Enter the description",
                        labelText: 'Description',
                        border: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Colors.white,
                            width: 0.75,
                          ),
                          borderRadius: BorderRadius.all(
                            Radius.circular(10.0),
                          ),
                        ),
                      ),
                      keyboardType: TextInputType.multiline,
                      maxLines: 3,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Save Button
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(10.0),
                  child: ElevatedButton(
                    onPressed: createNote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(94, 114, 228, 1.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.all(20),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : const Text(
                            "Save",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                  ),
                ),

                // Delete Button (only shown when editing)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(10.0),
                  child: Visibility(
                    visible: !isNewNote,
                    child: ElevatedButton(
                      onPressed: deleteNote,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 235, 108, 108),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.all(20),
                      ),
                      child: const Text(
                        "Delete",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}