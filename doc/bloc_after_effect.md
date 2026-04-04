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

A widget that subscribes to `effects` and invokes a callback for each effect.

```dart
class BlocEffectListener<B extends EffectBloc<dynamic, dynamic, E>, E>
```

Parameters:
- `listener` (required) — `void Function(BuildContext context, E effect)`
- `child` (required) — child widget
- `bloc` (optional) — if omitted, resolved via `context.read<B>()`

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

If `bloc` is not passed to `BlocEffectListener`, it's resolved via `context.read<B>()` from `flutter_bloc`. This works when the Bloc is provided via `BlocProvider`:

```dart
BlocProvider(
  create: (_) => ProfileBloc(repo),
  child: BlocEffectListener<ProfileBloc, ProfileEffect>(
    listener: (context, effect) { ... },
    child: ProfilePageBody(),
  ),
)
```

If the Bloc is created outside the widget tree, pass it explicitly:

```dart
BlocEffectListener<ProfileBloc, ProfileEffect>(
  bloc: myBloc,
  listener: (context, effect) { ... },
  child: ProfilePageBody(),
)
```

---

## Lifecycle

1. `BlocEffectListener` subscribes to `effects` in `didChangeDependencies`
2. On each effect, `listener` is invoked (only if the widget is `mounted`)
3. On widget `dispose`, the subscription is cancelled
4. On Bloc `close()`, the `StreamController` is closed, then `super.close()`

---

## Dependencies

- `bloc: ^8.1.0`
- `flutter_bloc: ^8.1.0`

---

## Package structure

```
packages/effect_bloc/
  lib/
    effect_bloc.dart              # barrel export
    src/
      effect_bloc.dart            # EffectBloc base class
      bloc_effect_listener.dart   # BlocEffectListener widget
  test/
    effect_bloc_test.dart         # unit tests
    bloc_effect_listener_test.dart # widget tests
  example/
    lib/main.dart                 # Counter app with effects
```
