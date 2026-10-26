## Reference

https://blog.logrocket.com/dependency-injection-flutter-using-getit-injectable/


### Why dependency injection

- Dependency injection is simply a way of making a class independent of its own dependencies. 

- Allow to separate different parts of application in a more maintainable way. 

- Because every class can make calls to any dependency it needs. This creates a loosely coupled application that helps in running and writing tests, bug fixes, improvements easier and faster.

### Pros and cons

- **Pros**
  - Maintaining code will be simpler since the classes will be loosely coupled == less dependent on one another
  - Improved unit tests
  - Collaboration

- **Cons**
  - A lot of code
  - Complexity + effort. It becomes a bit difficult adds more effort to completing one task.


### GetIt

- GetIt allow to create interfaces and their implementations, and access those implementations globally, anywhere in app. 
- Injectable allows us to focus on logic and less about how to access it.
