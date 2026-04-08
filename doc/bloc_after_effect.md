# EffectBloc

## Purpose

EffectBloc is an extension of [Bloc](https://pub.dev/packages/bloc) that adds a separate stream of one-shot UI effects.

Bloc manages **state** (State). But some actions aren't state:
- show a dialog
- navigate to another screen
- show a snackbar
- copy to the clipboard

These are **one-shot UI events** that shouldn't be stored in State.
EffectBloc solves this: the Bloc decides *what* happened, the UI knows *how* to display it.

---

## Core idea

```
Bloc defines the effect:    emitEffect(ShowErrorDialog('Save failed'))
UI interprets the effect:   showDialog(context: context, ...)
```

The Bloc doesn't know about `BuildContext`. The UI doesn't decide business logic.

---

## Entities

### EffectBloc

Abstract class extending `Bloc<Event, State>` with a third parameter `Effect`.

```dart
abstract class EffectBloc<Event, State, Effect> extends Bloc<Event, State>
```

Adds:
- `Stream<Effect> effects` — the effect stream (broadcast)
- `void emitEffect(Effect effect)` — send an effect to the UI

### BlocEffectListener

A widget that subscribes to `effects` and invokes a callback for each effect. Does not rebuild the UI — just wraps a child widget.

```dart
class BlocEffectListener<B extends EffectBloc<dynamic, dynamic, E>, E>
```

Parameters:
- `listener` (required) — `void Function(BuildContext context, E effect)`
- `child` (required) — child widget
- `bloc` (optional) — if omitted, resolved via `context.read<B>()`

Lifecycle:
1. Subscribes to `effects` in `didChangeDependencies`
2. On each effect, `listener` is invoked (only if the widget is `mounted`)
3. On widget `dispose`, the subscription is cancelled
4. Re-subscribes when the bloc identity changes (in `didUpdateWidget`)

### BlocEffectBuilder

A widget that combines `BlocBuilder` with an effect listener. Rebuilds the UI from state and reacts to effects. This is the primary widget for most use cases.

```dart
class BlocEffectBuilder<B extends EffectBloc<dynamic, S, E>, S, E>
```

Parameters:
- `builder` (required) — `Widget Function(BuildContext context, S state)`
- `effectListener` (required) — `void Function(BuildContext context, E effect)`
- `bloc` (optional) — if omitted, resolved via `context.read<B>()`
- `buildWhen` (optional) — `bool Function(S previous, S current)` filter for rebuilds

Lifecycle:
1. Subscribes to `effects` in `didChangeDependencies`
2. On each effect, `effectListener` is invoked (only if `mounted`)
3. State changes trigger `BlocBuilder` rebuilds (filtered by `buildWhen`)
4. Re-subscribes to effects when the bloc identity changes
5. Unsubscribes on `dispose`

### BlocEffectConsumer (migration only)

> **Not recommended for new code.** Use `BlocEffectBuilder` instead.

A migration helper that combines `BlocBuilder` with an optional state listener and an optional effect listener. Use it when gradually transitioning from `flutter_bloc`'s `BlocConsumer` — it lets you keep the existing state listener while you move one-shot side-effects into proper Effects one callback at a time. Once migration is complete, replace with `BlocEffectBuilder`.

```dart
class BlocEffectConsumer<B extends EffectBloc<dynamic, S, E>, S, E>
```

Parameters:
- `builder` (required) — `Widget Function(BuildContext context, S state)`
- `listener` (optional) — `void Function(BuildContext context, S state)` — state listener
- `effectListener` (optional) — `void Function(BuildContext context, E effect)`
- `bloc` (optional) — if omitted, resolved via `context.read<B>()`
- `buildWhen` (optional) — `bool Function(S previous, S current)` filter for rebuilds
- `listenWhen` (optional) — `bool Function(S previous, S current)` filter for state listener

Key differences from `flutter_bloc`'s `BlocConsumer`:
- **State `listener` is optional** (required in `BlocConsumer`)
- **Adds optional `effectListener`** for the `effects` stream

---

## Usage

### 1. Define effects

```dart
abstract class ProfileEffect {}

class ShowErrorDialog extends ProfileEffect {
  ShowErrorDialog(this.message);
  final String message;
}

class ShowSuccessSnackBar extends ProfileEffect {
  ShowSuccessSnackBar(this.text);
  final String text;
}

class NavigateToEdit extends ProfileEffect {
  NavigateToEdit(this.userId);
  final int userId;
}
```

### 2. Create a Bloc

```dart
class ProfileBloc extends EffectBloc<ProfileEvent, ProfileState, ProfileEffect> {
  ProfileBloc(this._repo) : super(ProfileState.initial()) {
    on<SavePressed>(_onSave);
  }

  final ProfileRepo _repo;

  Future<void> _onSave(SavePressed event, Emitter<ProfileState> emit) async {
    emit(state.copyWith(isSaving: true));

    try {
      await _repo.save();
      emit(state.copyWith(isSaving: false));
      emitEffect(ShowSuccessSnackBar('Saved'));
    } catch (e) {
      emit(state.copyWith(isSaving: false));
      emitEffect(ShowErrorDialog('Save failed'));
    }
  }
}
```

### 3. Wire it into the UI

**BlocEffectListener** — only effects, no building:

```dart
BlocEffectListener<ProfileBloc, ProfileEffect>(
  listener: (context, effect) {
    if (effect is ShowErrorDialog) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(content: Text(effect.message)),
      );
    } else if (effect is ShowSuccessSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(effect.text)),
      );
    } else if (effect is NavigateToEdit) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => EditPage(userId: effect.userId)),
      );
    }
  },
  child: ProfilePageBody(),
)
```

**BlocEffectBuilder** — build from state + handle effects:

```dart
BlocEffectBuilder<ProfileBloc, ProfileState, ProfileEffect>(
  effectListener: (context, effect) {
    if (effect is ShowErrorDialog) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(content: Text(effect.message)),
      );
    }
  },
  buildWhen: (prev, curr) => prev.isSaving != curr.isSaving,
  builder: (context, state) {
    if (state.isSaving) return const CircularProgressIndicator();
    return ProfileView(state: state);
  },
)
```

**BlocEffectConsumer** — build + state listener + effects (migration only, not for new code):

```dart
BlocEffectConsumer<ProfileBloc, ProfileState, ProfileEffect>(
  effectListener: (context, effect) {
    if (effect is NavigateToEdit) Navigator.of(context).push(...);
  },
  listener: (context, state) {
    if (state.error != null) logger.error(state.error);
  },
  listenWhen: (prev, curr) => prev.error != curr.error,
  builder: (context, state) => ProfileView(state: state),
)
```

---

## Migration from flutter_bloc

### From BlocBuilder

Replace `BlocBuilder` with `BlocEffectBuilder` and add an `effectListener`:

```dart
// Before
BlocBuilder<CounterBloc, CounterState>(
  builder: (context, state) => CounterView(state: state),
)

// After
BlocEffectBuilder<CounterBloc, CounterState, CounterEffect>(
  effectListener: (context, effect) { /* handle effects */ },
  builder: (context, state) => CounterView(state: state),
)
```

### From BlocListener + BlocBuilder

Move one-shot side-effects from the state listener into proper Effects:

```dart
// Before
BlocListener<CounterBloc, CounterState>(
  listener: (context, state) {
    if (state.saved) ScaffoldMessenger.of(context).showSnackBar(...);
  },
  child: BlocBuilder<CounterBloc, CounterState>(
    builder: (context, state) => CounterView(state: state),
  ),
)

// After
BlocEffectBuilder<CounterBloc, CounterState, CounterEffect>(
  effectListener: (context, effect) {
    if (effect is ShowSavedSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(...);
    }
  },
  builder: (context, state) => CounterView(state: state),
)
```

### From BlocConsumer (gradual migration)

If you still need a state listener during migration, temporarily use `BlocEffectConsumer`. Once all one-shot side-effects have been moved to Effects, replace it with `BlocEffectBuilder`:

```dart
// Before
BlocEffectListener<CounterBloc, CounterEffect>(
  listener: (context, effect) {
    if (effect is ShowSavedSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved! ${effect.count}')),
      );
    }
  },
  child: BlocConsumer<CounterBloc, CounterState>(
    listener: (context, state) {
      if (state.error != null) logger.error(state.error);
    },
    listenWhen: (prev, curr) => prev.error != curr.error,
    buildWhen: (prev, curr) => prev.count != curr.count,
    builder: (context, state) => CounterView(state: state),
  ),
)

// After
BlocEffectConsumer<CounterBloc, CounterState, CounterEffect>(
  effectListener: (context, effect) {
    if (effect is ShowSavedSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved! ${effect.count}')),
      );
    }
  },
  listener: (context, state) {
    if (state.error != null) logger.error(state.error);
  },
  listenWhen: (prev, curr) => prev.error != curr.error,
  buildWhen: (prev, curr) => prev.count != curr.count,
  builder: (context, state) => CounterView(state: state),
)
```

### Checklist

1. Replace `BlocConsumer<B, S>` with `BlocEffectConsumer<B, S, E>` — add the Effect type parameter.
2. Unwrap the surrounding `BlocEffectListener` — move its `listener` into `effectListener`.
3. If you don't need effects, drop `effectListener`.
4. If you don't need the state listener, drop `listener` — it's optional here (unlike `BlocConsumer`).
5. `buildWhen` and `listenWhen` carry over unchanged.

---

## Separation of concerns

| Layer | Knows | Doesn't know |
|-------|-------|--------------|
| **Bloc** | Which effect is needed (`emitEffect`) | `BuildContext`, how to show a dialog |
| **UI** | How to display the effect via `context` | Business logic, when the effect is needed |

---

## State vs Effect

| | State | Effect |
|---|---|---|
| Stored | Yes, in the Bloc | No, fire-and-forget |
| Replayed on rebuild | Yes | No |
| Examples | `isLoading`, `items`, `error` | `showDialog`, `navigate`, `showSnackBar` |
| Stream | `bloc.stream` | `bloc.effects` |

Rule: if the UI must *render it on every build* — it's State.
If the UI must *do it once* — it's an Effect.

---

## Broadcast stream

`effects` is a broadcast stream. This means:
- Multiple subscribers receive the same effect
- If no subscriber exists at emit time, the effect is dropped
- This is the correct behavior: UI effects are only relevant while the UI is listening

---

## Bloc lookup

If `bloc` is not passed to any of the widgets, it's resolved via `context.read<B>()` from `flutter_bloc`. This works when the Bloc is provided via `BlocProvider`:

```dart
BlocProvider(
  create: (_) => ProfileBloc(repo),
  child: BlocEffectBuilder<ProfileBloc, ProfileState, ProfileEffect>(
    effectListener: (context, effect) { ... },
    builder: (context, state) => ProfilePageBody(state: state),
  ),
)
```

If the Bloc is created outside the widget tree, pass it explicitly:

```dart
BlocEffectBuilder<ProfileBloc, ProfileState, ProfileEffect>(
  bloc: myBloc,
  effectListener: (context, effect) { ... },
  builder: (context, state) => ProfilePageBody(state: state),
)
```

---

## Lifecycle

### BlocEffectListener
1. Subscribes to `effects` in `didChangeDependencies`
2. On each effect, `listener` is invoked (only if the widget is `mounted`)
3. On widget `dispose`, the subscription is cancelled
4. On Bloc `close()`, the `StreamController` is closed, then `super.close()`

### BlocEffectBuilder
1. Subscribes to `effects` in `didChangeDependencies`
2. On each effect, `effectListener` is invoked (only if `mounted`)
3. State changes trigger `BlocBuilder` rebuilds (filtered by `buildWhen`)
4. Re-subscribes when bloc identity changes
5. On widget `dispose`, the effect subscription is cancelled

### BlocEffectConsumer
1. Subscribes to `effects` in `didChangeDependencies` (if `effectListener` provided)
2. State changes trigger both `listener` (filtered by `listenWhen`) and `builder` rebuilds (filtered by `buildWhen`)
3. Re-subscribes when bloc identity changes or `effectListener` reference changes
4. On widget `dispose`, all subscriptions are cancelled

---

## Dependencies

- `bloc: ^8.1.0`
- `flutter_bloc: ^8.1.0`

---

## Package structure

```
lib/
  bloc_after_effect.dart              # barrel export
  src/
    effect_bloc.dart                  # EffectBloc base class
    bloc_effect_listener.dart         # BlocEffectListener widget
    bloc_effect_builder.dart          # BlocEffectBuilder widget
    bloc_effect_consumer.dart         # BlocEffectConsumer widget (legacy migration)
test/
  effect_bloc_test.dart               # unit tests
  bloc_effect_listener_test.dart      # widget tests
  bloc_effect_builder_test.dart       # widget tests
  bloc_effect_consumer_test.dart      # widget tests
example/
  lib/main.dart                       # Counter app with effects
```
