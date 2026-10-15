## Reference

https://bloclibrary.dev/bloc-concepts/
https://pub.dev/packages/flutter_bloc


## Bloc concept

### Cubti

A Cubit can expose functions which can be invoked to trigger state changes.

States are the output of a Cubit and represent a part of your application's state. UI components can be notified of states and redraw portions of themselves based on the current state.

Cubit State Changes: Each Cubit has the ability to output a new state via emit.

A Change occurs just before the state of the Cubit is updated. A Change consists of the currentState and the nextState.

Observing a Cubit: When a Cubit emits a new state, a Change occurs. We can observe all changes for a given Cubit by overriding onChange.

Cubit Error Handling: Every Cubit has an addError method which can be used to indicate that an error has occurred.

```dart
class CounterCubit extends Cubit<int> {
  CounterCubit() : super(0);

  void increment() { 
    addError(Exception('increment error!'), StackTrace.current);
    emit(state + 1);
  }

  @override
  void onChange(Change<int> change) {
    super.onChange(change);
    print(change);
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    print('$error, $stackTrace');
    super.onError(error, stackTrace);
  }
}

void main() {
  CounterCubit()
    ..increment()
    ..close();
}
```

BlocObserver: If we want to be able to do something in response to all Changes we can simply create our own BlocObserver. onError can also be overridden in BlocObserver to handle all reported errors globally.

```dart
class SimpleBlocObserver extends BlocObserver {
  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    print('${bloc.runtimeType} $change');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    print('${bloc.runtimeType} $error $stackTrace');
    super.onError(bloc, error, stackTrace);
  }
}
```

### Bloc

A Bloc is a more advanced class which relies on events to trigger state changes rather than functions. Bloc also extends BlocBase which means it has a similar public API as Cubit. However, rather than calling a function on a Bloc and directly emitting a new state, Blocs receive events and convert the incoming events into outgoing states.

Bloc State Changes: Bloc requires us to register event handlers via the on<Event> API. An event handler is responsible for converting any incoming events into zero or more outgoing states.

Observing a Bloc: observe all state changes for a Bloc using onChange

```dart
sealed class CounterEvent {}

final class CounterIncrementPressed extends CounterEvent {}

class CounterBloc extends Bloc<CounterEvent, int> {
  CounterBloc() : super(0) {
    on<CounterIncrementPressed>((event, emit) {
      emit(state + 1);
    });
  }

  <!-- @override
  void onEvent(CounterEvent event) {
    super.onEvent(event);
    ...
  } -->

  @override
  void onChange(Change<int> change) {
    super.onChange(change);
    ...
  }

  @override
  void onTransition(Transition<CounterEvent, int> transition) {
    super.onTransition(transition);
    ...
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    print('$error, $stackTrace');
    super.onError(error, stackTrace);
  }
}

Future<void> main() async {
  final bloc = CounterBloc();
  final subscription = bloc.stream.listen(print); // 1
  bloc.add(CounterIncrementPressed());
  await Future.delayed(Duration.zero);
  await subscription.cancel();
  await bloc.close();
}
```

Key differentiating Bloc >< Cubit is Bloc is event-driven => able to capture information about what triggered the state change => overriding onTransition

The change from one state to another is called a Transition. A Transition consists of the current state, the event, and the next state. 

BlocObserver:

```dart
class SimpleBlocObserver extends BlocObserver {
  ...
  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    print('${bloc.runtimeType} $transition');
  }
  ...
}
```

Another unique feature of Bloc instances is that they allow us to override onEvent which is called whenever a new event is added to the Bloc.


### Cubit >< Bloc

Cubit simplicity
Cubit: Define the state + functions to expose to change the state 
Bloc: Define the states, events, and the EventHandler

Bloc traceability
Bloc: Know the sequence of state changes + what triggered those changes.
Bloc Advanced Event Transformations
Bloc: Have reactive operators such as buffer, debounceTime, throttle,...

If unsure about which to use, start with Cubit and later refactor or scale-up to a Bloc as needed.

## flutter_bloc

BlocBuilder requires a bloc and a builder function. BlocBuilder handles building the widget in response to new states

BlocSelector = BlocBuilder + allows developers to filter updates by selecting a new value based on the current bloc state. Unnecessary builds are prevented if the selected value does not change. The selected value must be immutable in order for BlocSelector to accurately determine whether builder should be called again.

BlocProvider provides a bloc to its children via BlocProvider.of<T>(context). It is used as a dependency injection (DI) widget so that a single instance of a bloc can be provided to multiple widgets within a subtree. In most cases, BlocProvider should be used to create new blocs which will be made available to the rest of the subtree.

MultiBlocProvider merges multiple BlocProvider widgets into one.

BlocListener takes a BlocWidgetListener and an optional bloc and invokes the listener in response to state changes in the bloc. It should be used for functionality that needs to occur once per state change

MultiBlocListener merges multiple BlocListener widgets into one.

BlocConsumer  exposes a builder and listener in order react to new states. BlocConsumer = BlocListener + BlocBuilder

RepositoryProvider provides a repository to its children via RepositoryProvider.of<T>(context). It is used as a dependency injection (DI) widget so that a single instance of a repository can be provided to multiple widgets within a subtree. BlocProvider should be used to provide blocs whereas RepositoryProvider should only be used for repositories.

MultiRepositoryProvider merges multiple RepositoryProvider widgets into one.
