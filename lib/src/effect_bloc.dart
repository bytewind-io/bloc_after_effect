import 'dart:async';

import 'package:bloc/bloc.dart';

/// A [Bloc] extension that supports one-shot UI effects alongside state.
///
/// Effects are fire-and-forget signals meant for the UI layer
/// (dialogs, navigation, snackbars) — things that don't belong in state.
///
/// ```dart
/// class ProfileBloc extends EffectBloc<ProfileEvent, ProfileState, ProfileEffect> {
///   ProfileBloc() : super(ProfileState.initial()) {
///     on<SavePressed>((event, emit) async {
///       try {
///         await repo.save();
///         emitEffect(ShowSuccessSnackBar('Saved'));
///       } catch (_) {
///         emitEffect(ShowErrorDialog('Save failed'));
///       }
///     });
///   }
/// }
/// ```
abstract class EffectBloc<Event, State, Effect> extends Bloc<Event, State> {
  EffectBloc(super.initialState);

  final _effectsController = StreamController<Effect>.broadcast();

  /// Stream of one-shot UI effects.
  Stream<Effect> get effects => _effectsController.stream;

  /// Sends a one-shot effect to the UI layer.
  void emitEffect(Effect effect) {
    _effectsController.add(effect);
  }

  @override
  Future<void> close() async {
    await _effectsController.close();
    return super.close();
  }
}
