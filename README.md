# effect_bloc

An extension of [bloc](https://pub.dev/packages/bloc) that adds a one-shot UI effect stream alongside state — for navigation, dialogs, snackbars, and other fire-and-forget UI actions that don't belong in `State`.

- **Bloc** decides *what* happened: `emitEffect(ShowErrorDialog('Save failed'))`
- **UI** decides *how* to show it: `showDialog(context: context, ...)`

## Install

```bash
flutter pub add effect_bloc
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

## State vs Effect

| | State | Effect |
|---|---|---|
| Stored | Yes, in the Bloc | No, fire-and-forget |
| Replayed on rebuild | Yes | No |
| Examples | `isLoading`, `items`, `error` | `showDialog`, `navigate`, `showSnackBar` |

If the UI must *render it on every build* — it's State. If the UI must *do it once* — it's an Effect.

The `effects` stream is a broadcast stream: effects emitted with no active listener are dropped.

## Documentation & example

- Full documentation: [doc/effect_bloc.md](doc/effect_bloc.md)
- Runnable example: [example/](example/)

## License

MIT — see [LICENSE](LICENSE).
