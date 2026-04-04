import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'effect_bloc.dart';

/// Callback for handling a UI effect with access to [BuildContext].
typedef EffectListenerCallback<E> = void Function(
  BuildContext context,
  E effect,
);

/// Listens to [EffectBloc.effects] and calls [listener] for each effect.
///
/// If [bloc] is not provided, it is resolved via `context.read<B>()`.
///
/// ```dart
/// BlocEffectListener<ProfileBloc, ProfileEffect>(
///   listener: (context, effect) {
///     if (effect is ShowErrorDialog) {
///       showDialog(
///         context: context,
///         builder: (_) => AlertDialog(content: Text(effect.message)),
///       );
///     } else if (effect is NavigateToEdit) {
///       Navigator.of(context).push(...);
///     }
///   },
///   child: ProfilePageBody(),
/// )
/// ```
class BlocEffectListener<B extends EffectBloc<dynamic, dynamic, E>, E>
    extends StatefulWidget {
  const BlocEffectListener({
    super.key,
    required this.listener,
    required this.child,
    this.bloc,
  });

  /// The bloc to listen to. If null, resolved via `context.read<B>()`.
  final B? bloc;

  /// Called for each effect emitted by the bloc.
  final EffectListenerCallback<E> listener;

  /// The child widget.
  final Widget child;

  @override
  State<BlocEffectListener<B, E>> createState() =>
      _BlocEffectListenerState<B, E>();
}

class _BlocEffectListenerState<B extends EffectBloc<dynamic, dynamic, E>, E>
    extends State<BlocEffectListener<B, E>> {
  StreamSubscription<E>? _subscription;
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
  void didUpdateWidget(BlocEffectListener<B, E> oldWidget) {
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
    _subscription = _bloc!.effects.listen((effect) {
      if (mounted) {
        widget.listener(context, effect);
      }
    });
  }

  void _unsubscribe() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
