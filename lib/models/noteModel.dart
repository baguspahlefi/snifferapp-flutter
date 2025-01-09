class NoteModel {
  // Define class properties
  int? id;
  String? title;
  String? description;
  String? imagePath; // Tambahkan property untuk image path

  // Constructor with optional 'id' parameter
  NoteModel(this.title, this.description, {this.id, this.imagePath});

  // Convert a Note into a Map from JSON
  NoteModel.fromJson(Map<String, dynamic> map) {
    id = map['id'];
    title = map['title'];
    description = map['description'];
    imagePath = map['imagePath']; // Tambahkan konversi untuk image path
  }

  // Method to convert a 'NoteModel' to a map
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'imagePath': imagePath, // Tambahkan image path ke JSON
    };
  }

  // Method untuk membuat salinan objek dengan nilai yang diperbarui
  NoteModel copyWith({
    int? id,
    String? title,
    String? description,
    String? imagePath,
  }) {
    return NoteModel(
      title ?? this.title,
      description ?? this.description,
      id: id ?? this.id,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}