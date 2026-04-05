## 0.2.0

* Added `BlocEffectConsumer<B, S, E>` — combines `BlocBuilder` with an optional state `listener` and an optional `effectListener` in a single widget. Parallels `flutter_bloc`'s `BlocConsumer`, but the state listener is optional and an effect listener is added.
* Example app migrated to `BlocEffectConsumer`.

## 0.1.0

* Initial release.
* `EffectBloc<Event, State, Effect>` base class with broadcast `effects` stream and `emitEffect()`.
* `BlocEffectListener<B, E>` widget for subscribing to effects with `BuildContext`.
