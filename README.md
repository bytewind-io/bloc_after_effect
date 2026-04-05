# bloc_after_effect

An extension of [bloc](https://pub.dev/packages/bloc) that adds a one-shot UI side-effect stream alongside state — for navigation, dialogs, snackbars, and other fire-and-forget UI actions that don't belong in `State`.

- **Bloc** decides *what* happened: `emitEffect(ShowErrorDialog('Save failed'))`
- **UI** decides *how* to show it: `showDialog(context: context, ...)`

## Install

```bash
flutter pub add bloc_after_effect
```

## Usage

Define your effects, extend `EffectBloc`, and emit effects from event handlers:

```dart
abstract class ProfileEffect {}
class ShowErrorSnackBar extends ProfileEffect {
  ShowErrorSnackBar(this.message);
  final String message;
}

class ProfileBloc extends EffectBloc<ProfileEvent, ProfileState, ProfileEffect> {
  ProfileBloc() : super(ProfileState.initial()) {
    on<SavePressed>((event, emit) async {
      try {
        await repo.save();
        emitEffect(ShowSuccessSnackBar('Saved'));
      } catch (_) {
        emitEffect(ShowErrorSnackBar('Save failed'));
      }
    });
  }
}
```

Listen for effects in the widget tree with `BlocEffectListener`:

```dart
BlocEffectListener<ProfileBloc, ProfileEffect>(
  listener: (context, effect) {
    if (effect is ShowErrorSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(effect.message)),
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

If `bloc` is not passed explicitly, it is resolved via `context.read<B>()`, so it works with `BlocProvider` out of the box.

## BlocEffectConsumer — state + effects in one widget

`BlocEffectConsumer` combines `BlocBuilder`, an optional state listener, and an optional effect listener into a single widget. Use it when you need to rebuild the UI from state **and** react to effects:

```dart
BlocEffectConsumer<ProfileBloc, ProfileState, ProfileEffect>(
  effectListener: (context, effect) {
    if (effect is NavigateToEdit) Navigator.of(context).push(...);
  },
  listener: (context, state) {                           // optional
    if (state.error != null) logger.error(state.error);
  },
  listenWhen: (prev, curr) => prev.error != curr.error,  // optional
  buildWhen: (prev, curr) => prev.profile != curr.profile, // optional
  builder: (context, state) => ProfileView(state: state),
)
```

Only `builder` is required. Drop `effectListener` if you only need state; drop `listener` if you only need effects — unlike `flutter_bloc`'s `BlocConsumer`, the state listener is optional.

### Migrating from `BlocConsumer`

If you currently wrap `BlocConsumer` with `BlocEffectListener`, collapse them into one widget:

```dart
// Before
BlocEffectListener<CounterBloc, CounterEffect>(
  listener: (context, effect) { /* show snackbar */ },
  child: BlocConsumer<CounterBloc, CounterState>(
    listener: (context, state) { /* log */ },
    builder: (context, state) => CounterView(state: state),
  ),
)

// After
BlocEffectConsumer<CounterBloc, CounterState, CounterEffect>(
  effectListener: (context, effect) { /* show snackbar */ },
  listener: (context, state) { /* log */ },
  builder: (context, state) => CounterView(state: state),
)
```

Migration steps:
1. Replace `BlocConsumer<B, S>` with `BlocEffectConsumer<B, S, E>` (add the Effect type parameter).
2. Unwrap the surrounding `BlocEffectListener` — move its `listener` into `effectListener`.
3. `buildWhen` / `listenWhen` carry over unchanged.

## State vs Effect

| | State | Effect |
|---|---|---|
| Stored | Yes, in the Bloc | No, fire-and-forget |
| Replayed on rebuild | Yes | No |
| Examples | `isLoading`, `items`, `error` | `showDialog`, `navigate`, `showSnackBar` |

If the UI must *render it on every build* — it's State. If the UI must *do it once* — it's an Effect.

The `effects` stream is a broadcast stream: effects emitted with no active listener are dropped.

## Documentation & example

- Full documentation: [doc/bloc_after_effect.md](doc/bloc_after_effect.md)
- Runnable example: [example/](example/)

## License

MIT — see [LICENSE](LICENSE).
