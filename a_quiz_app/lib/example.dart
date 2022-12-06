class Person {
  String name;
  int age;

  Person({String name, int age}) {
    this.name = name;
    this.age = age;
  }
}

class Pet {
  String name;
  int age;

  Pet({String name = 'A', int age = 0}) {
    this.name = name;
    this.age = age;
  }
}

class Shoe {
  String brand;
  int size;

  Shoe({this.brand, this.size});

  Shoe.large(this.brand) {
    size = 50;
  }
}