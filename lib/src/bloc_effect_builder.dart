import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'bloc_effect_listener.dart';
import 'effect_bloc.dart';

/// A widget that combines [BlocBuilder] with an effect listener for an
/// [EffectBloc].
///
/// Use this when you need to rebuild the UI from state **and** react to
/// one-shot effects, but don't need a state listener callback.
///
/// ```dart
/// BlocEffectBuilder<ProfileBloc, ProfileState, ProfileEffect>(
///   effectListener: (context, effect) {
///     if (effect is NavigateToEdit) Navigator.of(context).push(...);
///   },
///   buildWhen: (prev, curr) => prev.profile != curr.profile,
///   builder: (context, state) => ProfileView(state: state),
/// )
/// ```
class BlocEffectBuilder<B extends EffectBloc<dynamic, S, E>, S, E>
    extends StatefulWidget {
  const BlocEffectBuilder({
    super.key,
    required this.builder,
    required this.effectListener,
    this.bloc,
    this.buildWhen,
  });

  /// The bloc to subscribe to. If null, resolved via `context.read<B>()`.
  final B? bloc;

  /// Builds the UI from the current state.
  final BlocWidgetBuilder<S> builder;

  /// Called for each effect emitted by the bloc.
  final EffectListenerCallback<E> effectListener;

  /// Optional predicate controlling whether [builder] re-runs on state change.
  final BlocBuilderCondition<S>? buildWhen;

  @override
  State<BlocEffectBuilder<B, S, E>> createState() =>
      _BlocEffectBuilderState<B, S, E>();
}

class _BlocEffectBuilderState<B extends EffectBloc<dynamic, S, E>, S, E>
    extends State<BlocEffectBuilder<B, S, E>> {
  StreamSubscription<E>? _effectSubscription;
  B? _bloc;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newBloc = widget.bloc ?? context.read<B>();
    if (!identical(_bloc, newBloc)) {
      _unsubscribe();
      _bloc = newBloc;
      _subscribe();
    }
  }

  @override
  void didUpdateWidget(BlocEffectBuilder<B, S, E> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newBloc = widget.bloc ?? context.read<B>();
    if (!identical(_bloc, newBloc)) {
      _unsubscribe();
      _bloc = newBloc;
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    _effectSubscription = _bloc!.effects.listen((effect) {
      if (mounted) {
        widget.effectListener(context, effect);
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
      buildWhen: widget.buildWhen,
    );
  }
}
