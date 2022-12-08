class Person {
  late String name;
  late int age;

  Person({required String name, required int age}) {
    this.name = name;
    this.age = age;
  }
}

class Pet {
  late String name;
  late int age;

  Pet({String name = 'A', int age = 0}) {
    this.name = name;
    this.age = age;
  }
}

class Shoe {
  late String brand;
  late int size;

  Shoe({required this.brand, required this.size});

  Shoe.large(this.brand) {
    size = 50;
  }
}