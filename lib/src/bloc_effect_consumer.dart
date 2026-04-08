import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc_effect_listener.dart';
import 'effect_bloc.dart';

/// A widget that combines [BlocBuilder], a state listener, and an effect
/// listener for an [EffectBloc] into a single widget.
///
/// **Deprecated for new code.** This widget exists to ease migration from
/// `flutter_bloc`'s `BlocConsumer`. It lets you gradually adopt effects while
/// keeping the existing state listener, so you can transition one callback at
/// a time. For new code, use [BlocEffectBuilder] instead.
///
/// Unlike `flutter_bloc`'s `BlocConsumer`:
///  - [listener] (state listener) is optional
///  - [effectListener] is an additional optional listener for the effect stream
///
/// ```dart
/// BlocEffectConsumer<ProfileBloc, ProfileState, ProfileEffect>(
///   effectListener: (context, effect) {
///     if (effect is NavigateToEdit) Navigator.of(context).push(...);
///   },
///   listener: (context, state) {
///     if (state.error != null) logger.error(state.error);
///   },
///   buildWhen: (prev, curr) => prev.profile != curr.profile,
///   builder: (context, state) => ProfileView(state: state),
/// )
/// ```
class BlocEffectConsumer<B extends EffectBloc<dynamic, S, E>, S, E>
    extends StatefulWidget {
  const BlocEffectConsumer({
    super.key,
    required this.builder,
    this.listener,
    this.effectListener,
    this.bloc,
    this.buildWhen,
    this.listenWhen,
  });

  /// The bloc to subscribe to. If null, resolved via `context.read<B>()`.
  final B? bloc;

  /// Builds the UI from the current state.
  final BlocWidgetBuilder<S> builder;

  /// Optional callback invoked on state changes (after [listenWhen] passes).
  final BlocWidgetListener<S>? listener;

  /// Optional callback invoked for each effect emitted by the bloc.
  final EffectListenerCallback<E>? effectListener;

  /// Optional predicate controlling whether [builder] re-runs on state change.
  final BlocBuilderCondition<S>? buildWhen;

  /// Optional predicate controlling whether [listener] is called on state change.
  final BlocListenerCondition<S>? listenWhen;

  @override
  State<BlocEffectConsumer<B, S, E>> createState() =>
      _BlocEffectConsumerState<B, S, E>();
}

class _BlocEffectConsumerState<B extends EffectBloc<dynamic, S, E>, S, E>
    extends State<BlocEffectConsumer<B, S, E>> {
  StreamSubscription<E>? _effectSubscription;
  B? _bloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newBloc = widget.bloc ?? context.read<B>();
    if (!identical(_bloc, newBloc)) {
      _unsubscribe();
      _bloc = newBloc;
      _subscribeIfNeeded();
    }
  }

  @override
  void didUpdateWidget(BlocEffectConsumer<B, S, E> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newBloc = widget.bloc ?? context.read<B>();
    final blocChanged = !identical(_bloc, newBloc);
    final effectListenerChanged =
        widget.effectListener != oldWidget.effectListener;

    if (blocChanged) {
      _unsubscribe();
      _bloc = newBloc;
      _subscribeIfNeeded();
    } else if (effectListenerChanged) {
      _unsubscribe();
      _subscribeIfNeeded();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _subscribeIfNeeded() {
    if (widget.effectListener == null || _bloc == null) return;
    _effectSubscription = _bloc!.effects.listen((effect) {
      if (mounted) {
        widget.effectListener!(context, effect);
      }
    });
  }

  void _unsubscribe() {
    _effectSubscription?.cancel();
    _effectSubscription = null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<B, S>(
      bloc: _bloc,
      builder: widget.builder,
      buildWhen: (previous, current) {
        if (widget.listener != null &&
            (widget.listenWhen?.call(previous, current) ?? true)) {
          widget.listener!(context, current);
        }
        return widget.buildWhen?.call(previous, current) ?? true;
      },
    );
  }
}
