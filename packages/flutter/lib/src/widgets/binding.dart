// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' show AccessibilityFeatures, AppExitResponse, AppLifecycleState, FrameTiming, Locale, PlatformDispatcher, TimingsCallback;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'debug.dart';
import 'focus_manager.dart';
import 'framework.dart';
import 'platform_menu_bar.dart';
import 'router.dart';
import 'service_extensions.dart';
import 'view.dart';
import 'widget_inspector.dart';

export 'dart:ui' show AppLifecycleState, Locale;

/// Interface for classes that register with the Widgets layer binding.
///
/// When used as a mixin, provides no-op method implementations.
///
/// See [WidgetsBinding.addObserver] and [WidgetsBinding.removeObserver].
///
/// This class can be extended directly, to get default behaviors for all of the
/// handlers, or can used with the `implements` keyword, in which case all the
/// handlers must be implemented (and the analyzer will list those that have
/// been omitted).
///
/// {@tool dartpad}
/// This sample shows how to implement parts of the [State] and
/// [WidgetsBindingObserver] protocols necessary to react to application
/// lifecycle messages. See [didChangeAppLifecycleState].
///
/// ** See code in examples/api/lib/widgets/binding/widget_binding_observer.0.dart **
/// {@end-tool}
///
/// To respond to other notifications, replace the [didChangeAppLifecycleState]
/// method above with other methods from this class.
abstract mixin class WidgetsBindingObserver {
  /// Called when the system tells the app to pop the current route.
  /// For example, on Android, this is called when the user presses
  /// the back button.
  ///
  /// Observers are notified in registration order until one returns
  /// true. If none return true, the application quits.
  ///
  /// Observers are expected to return true if they were able to
  /// handle the notification, for example by closing an active dialog
  /// box, and false otherwise. The [WidgetsApp] widget uses this
  /// mechanism to notify the [Navigator] widget that it should pop
  /// its current route if possible.
  ///
  /// This method exposes the `popRoute` notification from
  /// [SystemChannels.navigation].
  Future<bool> didPopRoute() => Future<bool>.value(false);

  /// Called when the host tells the application to push a new route onto the
  /// navigator.
  ///
  /// Observers are expected to return true if they were able to
  /// handle the notification. Observers are notified in registration
  /// order until one returns true.
  ///
  /// This method exposes the `pushRoute` notification from
  /// [SystemChannels.navigation].
  Future<bool> didPushRoute(String route) => Future<bool>.value(false);

  /// Called when the host tells the application to push a new
  /// [RouteInformation] and a restoration state onto the router.
  ///
  /// Observers are expected to return true if they were able to
  /// handle the notification. Observers are notified in registration
  /// order until one returns true.
  ///
  /// This method exposes the `pushRouteInformation` notification from
  /// [SystemChannels.navigation].
  ///
  /// The default implementation is to call the [didPushRoute] directly with the
  /// [RouteInformation.location].
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) {
    return didPushRoute(routeInformation.location!);
  }

  /// Called when the application's dimensions change. For example,
  /// when a phone is rotated.
  ///
  /// This method exposes notifications from
  /// [dart:ui.PlatformDispatcher.onMetricsChanged].
  ///
  /// {@tool snippet}
  ///
  /// This [StatefulWidget] implements the parts of the [State] and
  /// [WidgetsBindingObserver] protocols necessary to react when the device is
  /// rotated (or otherwise changes dimensions).
  ///
  /// ```dart
  /// class MetricsReactor extends StatefulWidget {
  ///   const MetricsReactor({ super.key });
  ///
  ///   @override
  ///   State<MetricsReactor> createState() => _MetricsReactorState();
  /// }
  ///
  /// class _MetricsReactorState extends State<MetricsReactor> with WidgetsBindingObserver {
  ///   late Size _lastSize;
  ///
  ///   @override
  ///   void initState() {
  ///     super.initState();
  ///     // [View.of] exposes the view from `WidgetsBinding.instance.platformDispatcher.views`
  ///     // into which this widget is drawn.
  ///     _lastSize = View.of(context).physicalSize;
  ///     WidgetsBinding.instance.addObserver(this);
  ///   }
  ///
  ///   @override
  ///   void dispose() {
  ///     WidgetsBinding.instance.removeObserver(this);
  ///     super.dispose();
  ///   }
  ///
  ///   @override
  ///   void didChangeMetrics() {
  ///     setState(() { _lastSize = View.of(context).physicalSize; });
  ///   }
  ///
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     return Text('Current size: $_lastSize');
  ///   }
  /// }
  /// ```
  /// {@end-tool}
  ///
  /// In general, this is unnecessary as the layout system takes care of
  /// automatically recomputing the application geometry when the application
  /// size changes.
  ///
  /// See also:
  ///
  ///  * [MediaQuery.of], which provides a similar service with less
  ///    boilerplate.
  void didChangeMetrics() { }

  /// Called when the platform's text scale factor changes.
  ///
  /// This typically happens as the result of the user changing system
  /// preferences, and it should affect all of the text sizes in the
  /// application.
  ///
  /// This method exposes notifications from
  /// [dart:ui.PlatformDispatcher.onTextScaleFactorChanged].
  ///
  /// {@tool snippet}
  ///
  /// ```dart
  /// class TextScaleFactorReactor extends StatefulWidget {
  ///   const TextScaleFactorReactor({ super.key });
  ///
  ///   @override
  ///   State<TextScaleFactorReactor> createState() => _TextScaleFactorReactorState();
  /// }
  ///
  /// class _TextScaleFactorReactorState extends State<TextScaleFactorReactor> with WidgetsBindingObserver {
  ///   @override
  ///   void initState() {
  ///     super.initState();
  ///     WidgetsBinding.instance.addObserver(this);
  ///   }
  ///
  ///   @override
  ///   void dispose() {
  ///     WidgetsBinding.instance.removeObserver(this);
  ///     super.dispose();
  ///   }
  ///
  ///   late double _lastTextScaleFactor;
  ///
  ///   @override
  ///   void didChangeTextScaleFactor() {
  ///     setState(() { _lastTextScaleFactor = WidgetsBinding.instance.platformDispatcher.textScaleFactor; });
  ///   }
  ///
  ///   @override
  ///   Widget build(BuildContext context) {
  ///     return Text('Current scale factor: $_lastTextScaleFactor');
  ///   }
  /// }
  /// ```
  /// {@end-tool}
  ///
  /// See also:
  ///
  ///  * [MediaQuery.of], which provides a similar service with less
  ///    boilerplate.
  void didChangeTextScaleFactor() { }

  /// Called when the platform brightness changes.
  ///
  /// This method exposes notifications from
  /// [dart:ui.PlatformDispatcher.onPlatformBrightnessChanged].
  void didChangePlatformBrightness() { }

  /// Called when the system tells the app that the user's locale has
  /// changed. For example, if the user changes the system language
  /// settings.
  ///
  /// This method exposes notifications from
  /// [dart:ui.PlatformDispatcher.onLocaleChanged].
  void didChangeLocales(List<Locale>? locales) { }

  /// Called when the system puts the app in the background or returns
  /// the app to the foreground.
  ///
  /// An example of implementing this method is provided in the class-level
  /// documentation for the [WidgetsBindingObserver] class.
  ///
  /// This method exposes notifications from [SystemChannels.lifecycle].
  void didChangeAppLifecycleState(AppLifecycleState state) { }

  /// Called when a request is received from the system to exit the application.
  ///
  /// If any observer responds with [AppExitResponse.cancel], it will cancel the
  /// exit. All observers will be asked before exiting.
  ///
  /// {@macro flutter.services.binding.ServicesBinding.requestAppExit}
  ///
  /// See also:
  ///
  /// * [ServicesBinding.exitApplication] for a function to call that will request
  ///   that the application exits.
  Future<AppExitResponse> didRequestAppExit() async {
    return AppExitResponse.exit;
  }

  /// Called when the system is running low on memory.
  ///
  /// This method exposes the `memoryPressure` notification from
  /// [SystemChannels.system].
  void didHaveMemoryPressure() { }

  /// Called when the system changes the set of currently active accessibility
  /// features.
  ///
  /// This method exposes notifications from
  /// [dart:ui.PlatformDispatcher.onAccessibilityFeaturesChanged].
  void didChangeAccessibilityFeatures() { }
}

/// The glue between the widgets layer and the Flutter engine.[小部件层和Flutter引擎之间的粘合剂。]
mixin WidgetsBinding on BindingBase, ServicesBinding, SchedulerBinding, GestureBinding, RendererBinding, SemanticsBinding {
  @override
  void initInstances() {
    super.initInstances();
    _instance = this;

    assert(() {
      _debugAddStackFilters();
      return true;
    }());

    // Initialization of [_buildOwner] has to be done after
    // [super.initInstances] is called, as it requires [ServicesBinding] to
    // properly setup the [defaultBinaryMessenger] instance.

    //创建一个管理Widgets的类对象
    //BuildOwner类用来跟踪哪些 Widget 需要重建，并处理用于 Widget 树的其他任务，例如管理不活跃的 Widget 等，调试模式触发重建等。
    _buildOwner = BuildOwner();
    //回调方法赋值，当第一个可构建元素被标记为脏时调用。[setState流程中，可见被赋值回调]
    buildOwner!.onBuildScheduled = _handleBuildScheduled;
    //回调方法赋值，当本地配置变化或者AccessibilityFeatures变化时调用。
    platformDispatcher.onLocaleChanged = handleLocaleChanged;
    SystemChannels.navigation.setMethodCallHandler(_handleNavigationInvocation);
    assert(() {
      FlutterErrorDetails.propertiesTransformers.add(debugTransformDebugCreator);
      return true;
    }());
    platformMenuDelegate = DefaultPlatformMenuDelegate();
  }

  /// The current [WidgetsBinding], if one has been created.
  ///
  /// Provides access to the features exposed by this mixin. The binding must
  /// be initialized before using this getter; this is typically done by calling
  /// [runApp] or [WidgetsFlutterBinding.ensureInitialized].
  static WidgetsBinding get instance => BindingBase.checkInstance(_instance);
  static WidgetsBinding? _instance;

  void _debugAddStackFilters() {
    const PartialStackFrame elementInflateWidget = PartialStackFrame(package: 'package:flutter/src/widgets/framework.dart', className: 'Element', method: 'inflateWidget');
    const PartialStackFrame elementUpdateChild = PartialStackFrame(package: 'package:flutter/src/widgets/framework.dart', className: 'Element', method: 'updateChild');
    const PartialStackFrame elementRebuild = PartialStackFrame(package: 'package:flutter/src/widgets/framework.dart', className: 'Element', method: 'rebuild');
    const PartialStackFrame componentElementPerformRebuild = PartialStackFrame(package: 'package:flutter/src/widgets/framework.dart', className: 'ComponentElement', method: 'performRebuild');
    const PartialStackFrame componentElementFirstBuild = PartialStackFrame(package: 'package:flutter/src/widgets/framework.dart', className: 'ComponentElement', method: '_firstBuild');
    const PartialStackFrame componentElementMount = PartialStackFrame(package: 'package:flutter/src/widgets/framework.dart', className: 'ComponentElement', method: 'mount');
    const PartialStackFrame statefulElementFirstBuild = PartialStackFrame(package: 'package:flutter/src/widgets/framework.dart', className: 'StatefulElement', method: '_firstBuild');
    const PartialStackFrame singleChildMount = PartialStackFrame(package: 'package:flutter/src/widgets/framework.dart', className: 'SingleChildRenderObjectElement', method: 'mount');
    const PartialStackFrame statefulElementRebuild = PartialStackFrame(package: 'package:flutter/src/widgets/framework.dart', className: 'StatefulElement', method: 'performRebuild');

    const String replacementString = '...     Normal element mounting';

    // ComponentElement variations
    FlutterError.addDefaultStackFilter(const RepetitiveStackFrameFilter(
      frames: <PartialStackFrame>[
        elementInflateWidget,
        elementUpdateChild,
        componentElementPerformRebuild,
        elementRebuild,
        componentElementFirstBuild,
        componentElementMount,
      ],
      replacement: replacementString,
    ));
    FlutterError.addDefaultStackFilter(const RepetitiveStackFrameFilter(
      frames: <PartialStackFrame>[
        elementUpdateChild,
        componentElementPerformRebuild,
        elementRebuild,
        componentElementFirstBuild,
        componentElementMount,
      ],
      replacement: replacementString,
    ));

    // StatefulElement variations
    FlutterError.addDefaultStackFilter(const RepetitiveStackFrameFilter(
      frames: <PartialStackFrame>[
        elementInflateWidget,
        elementUpdateChild,
        componentElementPerformRebuild,
        statefulElementRebuild,
        elementRebuild,
        componentElementFirstBuild,
        statefulElementFirstBuild,
        componentElementMount,
      ],
      replacement: replacementString,
    ));
    FlutterError.addDefaultStackFilter(const RepetitiveStackFrameFilter(
      frames: <PartialStackFrame>[
        elementUpdateChild,
        componentElementPerformRebuild,
        statefulElementRebuild,
        elementRebuild,
        componentElementFirstBuild,
        statefulElementFirstBuild,
        componentElementMount,
      ],
      replacement: replacementString,
    ));

    // SingleChildRenderObjectElement variations
    FlutterError.addDefaultStackFilter(const RepetitiveStackFrameFilter(
      frames: <PartialStackFrame>[
        elementInflateWidget,
        elementUpdateChild,
        singleChildMount,
      ],
      replacement: replacementString,
    ));
    FlutterError.addDefaultStackFilter(const RepetitiveStackFrameFilter(
      frames: <PartialStackFrame>[
        elementUpdateChild,
        singleChildMount,
      ],
      replacement: replacementString,
    ));
  }

  @override
  void initServiceExtensions() {
    super.initServiceExtensions();

    if (!kReleaseMode) {
      registerServiceExtension(
        name: WidgetsServiceExtensions.debugDumpApp.name,
        callback: (Map<String, String> parameters) async {
          final String data = _debugDumpAppString();
          return <String, Object>{
            'data': data,
          };
        },
      );

      registerServiceExtension(
        name: WidgetsServiceExtensions.debugDumpFocusTree.name,
        callback: (Map<String, String> parameters) async {
          final String data = focusManager.toStringDeep();
          return <String, Object>{
            'data': data,
          };
        },
      );

      if (!kIsWeb) {
        registerBoolServiceExtension(
          name: WidgetsServiceExtensions.showPerformanceOverlay.name,
          getter: () =>
          Future<bool>.value(WidgetsApp.showPerformanceOverlayOverride),
          setter: (bool value) {
            if (WidgetsApp.showPerformanceOverlayOverride == value) {
              return Future<void>.value();
            }
            WidgetsApp.showPerformanceOverlayOverride = value;
            return _forceRebuild();
          },
        );
      }

      registerServiceExtension(
        name: WidgetsServiceExtensions.didSendFirstFrameEvent.name,
        callback: (_) async {
          return <String, dynamic>{
            // This is defined to return a STRING, not a boolean.
            // Devtools, the Intellij plugin, and the flutter tool all depend
            // on it returning a string and not a boolean.
            'enabled': _needToReportFirstFrame ? 'false' : 'true',
          };
        },
      );

      registerServiceExtension(
        name: WidgetsServiceExtensions.didSendFirstFrameRasterizedEvent.name,
        callback: (_) async {
          return <String, dynamic>{
            // This is defined to return a STRING, not a boolean.
            // Devtools, the Intellij plugin, and the flutter tool all depend
            // on it returning a string and not a boolean.
            'enabled': firstFrameRasterized ? 'true' : 'false',
          };
        },
      );

      registerServiceExtension(
        name: WidgetsServiceExtensions.fastReassemble.name,
        callback: (Map<String, Object> params) async {
          // This mirrors the implementation of the 'reassemble' callback registration
          // in lib/src/foundation/binding.dart, but with the extra binding config used
          // to skip some reassemble work.
          final String? className = params['className'] as String?;
          BindingBase.debugReassembleConfig = DebugReassembleConfig(widgetName: className);
          try {
            await reassembleApplication();
          } finally {
            BindingBase.debugReassembleConfig = null;
          }
          return <String, String>{'type': 'Success'};
        },
      );

      // Expose the ability to send Widget rebuilds as [Timeline] events.
      registerBoolServiceExtension(
        name: WidgetsServiceExtensions.profileWidgetBuilds.name,
        getter: () async => debugProfileBuildsEnabled,
        setter: (bool value) async {
          debugProfileBuildsEnabled = value;
        }
      );
      registerBoolServiceExtension(
        name: WidgetsServiceExtensions.profileUserWidgetBuilds.name,
        getter: () async => debugProfileBuildsEnabledUserWidgets,
        setter: (bool value) async {
          debugProfileBuildsEnabledUserWidgets = value;
        }
      );
    }

    assert(() {
      registerBoolServiceExtension(
        name: WidgetsServiceExtensions.debugAllowBanner.name,
        getter: () => Future<bool>.value(WidgetsApp.debugAllowBannerOverride),
        setter: (bool value) {
          if (WidgetsApp.debugAllowBannerOverride == value) {
            return Future<void>.value();
          }
          WidgetsApp.debugAllowBannerOverride = value;
          return _forceRebuild();
        },
      );

      WidgetInspectorService.instance.initServiceExtensions(registerServiceExtension);

      return true;
    }());
  }

  Future<void> _forceRebuild() {
    if (rootElement != null) {
      buildOwner!.reassemble(rootElement!, null);
      return endOfFrame;
    }
    return Future<void>.value();
  }

  /// The [BuildOwner] in charge of executing the build pipeline for the
  /// widget tree rooted at this binding.
  BuildOwner? get buildOwner => _buildOwner;
  // Initialization of [_buildOwner] has to be done within the [initInstances]
  // method, as it requires [ServicesBinding] to properly setup the
  // [defaultBinaryMessenger] instance.
  BuildOwner? _buildOwner;

  /// The object in charge of the focus tree.
  ///
  /// Rarely used directly. Instead, consider using [FocusScope.of] to obtain
  /// the [FocusScopeNode] for a given [BuildContext].
  ///
  /// See [FocusManager] for more details.
  FocusManager get focusManager => _buildOwner!.focusManager;

  /// A delegate that communicates with a platform plugin for serializing and
  /// managing platform-rendered menu bars created by [PlatformMenuBar].
  ///
  /// This is set by default to a [DefaultPlatformMenuDelegate] instance in
  /// [initInstances].
  late PlatformMenuDelegate platformMenuDelegate;

  final List<WidgetsBindingObserver> _observers = <WidgetsBindingObserver>[];

  /// Registers the given object as a binding observer. Binding
  /// observers are notified when various application events occur,
  /// for example when the system locale changes. Generally, one
  /// widget in the widget tree registers itself as a binding
  /// observer, and converts the system state into inherited widgets.
  ///
  /// For example, the [WidgetsApp] widget registers as a binding
  /// observer and passes the screen size to a [MediaQuery] widget
  /// each time it is built, which enables other widgets to use the
  /// [MediaQuery.of] static method and (implicitly) the
  /// [InheritedWidget] mechanism to be notified whenever the screen
  /// size changes (e.g. whenever the screen rotates).
  ///
  /// See also:
  ///
  ///  * [removeObserver], to release the resources reserved by this method.
  ///  * [WidgetsBindingObserver], which has an example of using this method.
  void addObserver(WidgetsBindingObserver observer) => _observers.add(observer);

  /// Unregisters the given observer. This should be used sparingly as
  /// it is relatively expensive (O(N) in the number of registered
  /// observers).
  ///
  /// See also:
  ///
  ///  * [addObserver], for the method that adds observers in the first place.
  ///  * [WidgetsBindingObserver], which has an example of using this method.
  bool removeObserver(WidgetsBindingObserver observer) => _observers.remove(observer);

  @override
  Future<AppExitResponse> handleRequestAppExit() async {
    bool didCancel = false;
    for (final WidgetsBindingObserver observer in _observers) {
      if ((await observer.didRequestAppExit()) == AppExitResponse.cancel) {
        didCancel = true;
        // Don't early return. For the case where someone is just using the
        // observer to know when exit happens, we want to call all the
        // observers, even if we already know we're going to cancel.
      }
    }
    return didCancel ? AppExitResponse.cancel : AppExitResponse.exit;
  }

  @override
  void handleMetricsChanged() {
    super.handleMetricsChanged();
    for (final WidgetsBindingObserver observer in _observers) {
      observer.didChangeMetrics();
    }
  }

  @override
  void handleTextScaleFactorChanged() {
    super.handleTextScaleFactorChanged();
    for (final WidgetsBindingObserver observer in _observers) {
      observer.didChangeTextScaleFactor();
    }
  }

  @override
  void handlePlatformBrightnessChanged() {
    super.handlePlatformBrightnessChanged();
    for (final WidgetsBindingObserver observer in _observers) {
      observer.didChangePlatformBrightness();
    }
  }

  @override
  void handleAccessibilityFeaturesChanged() {
    super.handleAccessibilityFeaturesChanged();
    for (final WidgetsBindingObserver observer in _observers) {
      observer.didChangeAccessibilityFeatures();
    }
  }

  /// Called when the system locale changes.
  ///
  /// Calls [dispatchLocalesChanged] to notify the binding observers.
  ///
  /// See [dart:ui.PlatformDispatcher.onLocaleChanged].
  @protected
  @mustCallSuper
  void handleLocaleChanged() {
    dispatchLocalesChanged(platformDispatcher.locales);
  }

  /// Notify all the observers that the locale has changed (using
  /// [WidgetsBindingObserver.didChangeLocales]), giving them the
  /// `locales` argument.
  ///
  /// This is called by [handleLocaleChanged] when the
  /// [PlatformDispatcher.onLocaleChanged] notification is received.
  @protected
  @mustCallSuper
  void dispatchLocalesChanged(List<Locale>? locales) {
    for (final WidgetsBindingObserver observer in _observers) {
      observer.didChangeLocales(locales);
    }
  }

  /// Notify all the observers that the active set of [AccessibilityFeatures]
  /// has changed (using [WidgetsBindingObserver.didChangeAccessibilityFeatures]),
  /// giving them the `features` argument.
  ///
  /// This is called by [handleAccessibilityFeaturesChanged] when the
  /// [PlatformDispatcher.onAccessibilityFeaturesChanged] notification is received.
  @protected
  @mustCallSuper
  void dispatchAccessibilityFeaturesChanged() {
    for (final WidgetsBindingObserver observer in _observers) {
      observer.didChangeAccessibilityFeatures();
    }
  }

  /// Called when the system pops the current route.
  ///
  /// This first notifies the binding observers (using
  /// [WidgetsBindingObserver.didPopRoute]), in registration order, until one
  /// returns true, meaning that it was able to handle the request (e.g. by
  /// closing a dialog box). If none return true, then the application is shut
  /// down by calling [SystemNavigator.pop].
  ///
  /// [WidgetsApp] uses this in conjunction with a [Navigator] to
  /// cause the back button to close dialog boxes, return from modal
  /// pages, and so forth.
  ///
  /// This method exposes the `popRoute` notification from
  /// [SystemChannels.navigation].
  @protected
  Future<void> handlePopRoute() async {
    for (final WidgetsBindingObserver observer in List<WidgetsBindingObserver>.of(_observers)) {
      if (await observer.didPopRoute()) {
        return;
      }
    }
    SystemNavigator.pop();
  }

  /// Called when the host tells the app to push a new route onto the
  /// navigator.
  ///
  /// This notifies the binding observers (using
  /// [WidgetsBindingObserver.didPushRoute]), in registration order, until one
  /// returns true, meaning that it was able to handle the request (e.g. by
  /// opening a dialog box). If none return true, then nothing happens.
  ///
  /// This method exposes the `pushRoute` notification from
  /// [SystemChannels.navigation].
  @protected
  @mustCallSuper
  Future<void> handlePushRoute(String route) async {
    for (final WidgetsBindingObserver observer in List<WidgetsBindingObserver>.of(_observers)) {
      if (await observer.didPushRoute(route)) {
        return;
      }
    }
  }

  Future<void> _handlePushRouteInformation(Map<dynamic, dynamic> routeArguments) async {
    for (final WidgetsBindingObserver observer in List<WidgetsBindingObserver>.of(_observers)) {
      if (
        await observer.didPushRouteInformation(
          RouteInformation(
            location: routeArguments['location'] as String,
            state: routeArguments['state'] as Object?,
          ),
        )
      ) {
        return;
      }
    }
  }

  Future<dynamic> _handleNavigationInvocation(MethodCall methodCall) {
    switch (methodCall.method) {
      case 'popRoute':
        return handlePopRoute();
      case 'pushRoute':
        return handlePushRoute(methodCall.arguments as String);
      case 'pushRouteInformation':
        return _handlePushRouteInformation(methodCall.arguments as Map<dynamic, dynamic>);
    }
    return Future<dynamic>.value();
  }

  @override
  void handleAppLifecycleStateChanged(AppLifecycleState state) {
    super.handleAppLifecycleStateChanged(state);
    for (final WidgetsBindingObserver observer in _observers) {
      observer.didChangeAppLifecycleState(state);
    }
  }

  @override
  void handleMemoryPressure() {
    super.handleMemoryPressure();
    for (final WidgetsBindingObserver observer in _observers) {
      observer.didHaveMemoryPressure();
    }
  }

  bool _needToReportFirstFrame = true;

  final Completer<void> _firstFrameCompleter = Completer<void>();

  /// Whether the Flutter engine has rasterized the first frame.
  ///
  /// Usually, the time that a frame is rasterized is very close to the time that
  /// it gets presented on the display. Specifically, rasterization is the last
  /// expensive phase of a frame that's still in Flutter's control.
  ///
  /// See also:
  ///
  ///  * [waitUntilFirstFrameRasterized], the future when [firstFrameRasterized]
  ///    becomes true.
  bool get firstFrameRasterized => _firstFrameCompleter.isCompleted;

  /// A future that completes when the Flutter engine has rasterized the first
  /// frame.
  ///
  /// Usually, the time that a frame is rasterized is very close to the time that
  /// it gets presented on the display. Specifically, rasterization is the last
  /// expensive phase of a frame that's still in Flutter's control.
  ///
  /// See also:
  ///
  ///  * [firstFrameRasterized], whether this future has completed or not.
  Future<void> get waitUntilFirstFrameRasterized => _firstFrameCompleter.future;

  /// Whether the first frame has finished building.
  ///
  /// This value can also be obtained over the VM service protocol as
  /// `ext.flutter.didSendFirstFrameEvent`.
  ///
  /// See also:
  ///
  ///  * [firstFrameRasterized], whether the first frame has finished rendering.
  bool get debugDidSendFirstFrameEvent => !_needToReportFirstFrame;

  void _handleBuildScheduled() {
    // If we're in the process of building dirty elements, then changes
    // should not trigger a new frame.
    assert(() {
      if (debugBuildingDirtyElements) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('Build scheduled during frame.'),
          ErrorDescription(
            'While the widget tree was being built, laid out, and painted, '
            'a new frame was scheduled to rebuild the widget tree.',
          ),
          ErrorHint(
            'This might be because setState() was called from a layout or '
            'paint callback. '
            'If a change is needed to the widget tree, it should be applied '
            'as the tree is being built. Scheduling a change for the subsequent '
            'frame instead results in an interface that lags behind by one frame. '
            'If this was done to make your build dependent on a size measured at '
            'layout time, consider using a LayoutBuilder, CustomSingleChildLayout, '
            'or CustomMultiChildLayout. If, on the other hand, the one frame delay '
            'is the desired effect, for example because this is an '
            'animation, consider scheduling the frame in a post-frame callback '
            'using SchedulerBinding.addPostFrameCallback or '
            'using an AnimationController to trigger the animation.',
          ),
        ]);
      }
      return true;
    }());
    ensureVisualUpdate();
  }

  /// Whether we are currently in a frame. This is used to verify
  /// that frames are not scheduled redundantly.
  ///
  /// This is public so that test frameworks can change it.
  ///
  /// This flag is not used in release builds.
  @protected
  bool debugBuildingDirtyElements = false;

  /// Pump the build and rendering pipeline to generate a frame.
  ///
  /// This method is called by [handleDrawFrame], which itself is called
  /// automatically by the engine when it is time to lay out and paint a
  /// frame.
  ///
  /// Each frame consists of the following phases:
  ///
  /// 1. The animation phase: The [handleBeginFrame] method, which is registered
  /// with [PlatformDispatcher.onBeginFrame], invokes all the transient frame
  /// callbacks registered with [scheduleFrameCallback], in registration order.
  /// This includes all the [Ticker] instances that are driving
  /// [AnimationController] objects, which means all of the active [Animation]
  /// objects tick at this point.
  ///
  /// 2. Microtasks: After [handleBeginFrame] returns, any microtasks that got
  /// scheduled by transient frame callbacks get to run. This typically includes
  /// callbacks for futures from [Ticker]s and [AnimationController]s that
  /// completed this frame.
  ///
  /// After [handleBeginFrame], [handleDrawFrame], which is registered with
  /// [PlatformDispatcher.onDrawFrame], is called, which invokes all the
  /// persistent frame callbacks, of which the most notable is this method,
  /// [drawFrame], which proceeds as follows:
  ///
  /// 3. The build phase: All the dirty [Element]s in the widget tree are
  /// rebuilt (see [State.build]). See [State.setState] for further details on
  /// marking a widget dirty for building. See [BuildOwner] for more information
  /// on this step.
  ///
  /// 4. The layout phase: All the dirty [RenderObject]s in the system are laid
  /// out (see [RenderObject.performLayout]). See [RenderObject.markNeedsLayout]
  /// for further details on marking an object dirty for layout.
  ///
  /// 5. The compositing bits phase: The compositing bits on any dirty
  /// [RenderObject] objects are updated. See
  /// [RenderObject.markNeedsCompositingBitsUpdate].
  ///
  /// 6. The paint phase: All the dirty [RenderObject]s in the system are
  /// repainted (see [RenderObject.paint]). This generates the [Layer] tree. See
  /// [RenderObject.markNeedsPaint] for further details on marking an object
  /// dirty for paint.
  ///
  /// 7. The compositing phase: The layer tree is turned into a [Scene] and
  /// sent to the GPU.
  ///
  /// 8. The semantics phase: All the dirty [RenderObject]s in the system have
  /// their semantics updated (see [RenderObject.assembleSemanticsNode]). This
  /// generates the [SemanticsNode] tree. See
  /// [RenderObject.markNeedsSemanticsUpdate] for further details on marking an
  /// object dirty for semantics.
  ///
  /// For more details on steps 4-8, see [PipelineOwner].
  ///
  /// 9. The finalization phase in the widgets layer: The widgets tree is
  /// finalized. This causes [State.dispose] to be invoked on any objects that
  /// were removed from the widgets tree this frame. See
  /// [BuildOwner.finalizeTree] for more details.
  ///
  /// 10. The finalization phase in the scheduler layer: After [drawFrame]
  /// returns, [handleDrawFrame] then invokes post-frame callbacks (registered
  /// with [addPostFrameCallback]).
  //
  // When editing the above, also update rendering/binding.dart's copy.
  @override
  void drawFrame() {
    assert(!debugBuildingDirtyElements);
    assert(() {
      debugBuildingDirtyElements = true;
      return true;
    }());

    TimingsCallback? firstFrameCallback;
    if (_needToReportFirstFrame) {
      assert(!_firstFrameCompleter.isCompleted);

      firstFrameCallback = (List<FrameTiming> timings) {
        assert(sendFramesToEngine);
        if (!kReleaseMode) {
          // Change the current user tag back to the default tag. At this point,
          // the user tag should be set to "AppStartUp" (originally set in the
          // engine), so we need to change it back to the default tag to mark
          // the end of app start up for CPU profiles.
          developer.UserTag.defaultTag.makeCurrent();
          developer.Timeline.instantSync('Rasterized first useful frame');
          developer.postEvent('Flutter.FirstFrame', <String, dynamic>{});
        }
        SchedulerBinding.instance.removeTimingsCallback(firstFrameCallback!);
        firstFrameCallback = null;
        _firstFrameCompleter.complete();
      };
      // Callback is only invoked when FlutterView.render is called. When
      // sendFramesToEngine is set to false during the frame, it will not be
      // called and we need to remove the callback (see below).
      SchedulerBinding.instance.addTimingsCallback(firstFrameCallback!);
    }

    try {
      if (rootElement != null) {
        buildOwner!.buildScope(rootElement!);
      }
      super.drawFrame();
      buildOwner!.finalizeTree();
    } finally {
      assert(() {
        debugBuildingDirtyElements = false;
        return true;
      }());
    }
    if (!kReleaseMode) {
      if (_needToReportFirstFrame && sendFramesToEngine) {
        developer.Timeline.instantSync('Widgets built first useful frame');
      }
    }
    _needToReportFirstFrame = false;
    if (firstFrameCallback != null && !sendFramesToEngine) {
      // This frame is deferred and not the first frame sent to the engine that
      // should be reported.
      _needToReportFirstFrame = true;
      SchedulerBinding.instance.removeTimingsCallback(firstFrameCallback!);
    }
  }

  /// The [Element] that is at the root of the element tree hierarchy.
  ///
  /// This is initialized the first time [runApp] is called.
  Element? get rootElement => _rootElement;
  Element? _rootElement;

  /// Deprecated. Will be removed in a future version of Flutter.
  ///
  /// Use [rootElement] instead.
  @Deprecated(
    'Use rootElement instead. '
    'This feature was deprecated after v3.9.0-16.0.pre.'
  )
  Element? get renderViewElement => rootElement;

  bool _readyToProduceFrames = false;

  @override
  bool get framesEnabled => super.framesEnabled && _readyToProduceFrames;

  /// Used by [runApp] to wrap the provided `rootWidget` in the default [View].
  ///
  /// The [View] determines into what [FlutterView] the app is rendered into.
  /// This is currently [PlatformDispatcher.implicitView] from [platformDispatcher].
  ///
  /// The `rootWidget` widget provided to this method must not already be
  /// wrapped in a [View].
  Widget wrapWithDefaultView(Widget rootWidget) {
    //这里 View 继承自 StatelessWidget，实际返回的还是个Widget
    return View(
      view: platformDispatcher.implicitView!,
      child: rootWidget,
    );
  }

  /// Schedules a [Timer] for attaching the root widget.
  ///
  /// This is called by [runApp] to configure the widget tree. Consider using
  /// [attachRootWidget] if you want to build the widget tree synchronously.
  @protected
  void scheduleAttachRootWidget(Widget rootWidget) {
    //本质是异步执行了attachRootWidget(rootWidget)方法，
    // 这个方法完成了 Flutter Widget 到 Element 到 RenderObject 的整个关联过程
    //简单的异步快速执行，将attachRootWidget异步化
    Timer.run(() {
      attachRootWidget(rootWidget);
    });
  }

  /// Takes a widget and attaches it to the [rootElement], creating it if
  /// necessary.
  ///
  /// This is called by [runApp] to configure the widget tree.
  ///
  /// See also:
  ///
  ///  * [RenderObjectToWidgetAdapter.attachToRenderTree], which inflates a
  ///    widget and attaches it to the render tree.
  void attachRootWidget(Widget rootWidget) {
    //1、是不是 ’初始启动帧‘，即看 rootElement 是否有赋值，赋值时机为步骤2
    final bool isBootstrapFrame = rootElement == null;
    _readyToProduceFrames = true;//准备去生产帧布局
    //2、桥梁创建RenderObject、Element、Widget关系树，_renderViewElement值为attachToRenderTree方法返回值
    // 重点跟进 RenderObjectToWidgetAdapter
    // RenderObjectToWidgetAdapter 才是 widget 树的根节点
    _rootElement = RenderObjectToWidgetAdapter<RenderBox>(//只是构造器，具体看下面的函数：attachToRenderTree
      //3、RenderObjectWithChildMixin类型，继承自RenderObject，RenderObject继承自AbstractNode。
      //来自RendererBinding的_pipelineOwner.rootNode，_pipelineOwner来自其初始化initInstances方法实例化的PipelineOwner对象。
      //一个Flutter App全局只有一个PipelineOwner实例。
      container: renderView,// RenderView get renderView => _pipelineOwner.rootNode! as RenderView;
      debugShortDescription: '[root]',
      //4、我们平时写的dart Widget app
      child: rootWidget,
    ).attachToRenderTree(buildOwner!, rootElement as RenderObjectToWidgetElement<RenderBox>?);
    if (isBootstrapFrame) {
      //6、首帧主动更新一下，匹配条件的情况下内部本质是调用SchedulerBinding的scheduleFrame()方法。
      //进而本质调用了window.scheduleFrame()方法。
      SchedulerBinding.instance.ensureVisualUpdate();
    }
  }

  /// Whether the [rootElement] has been initialized.
  ///
  /// This will be false until [runApp] is called (or [WidgetTester.pumpWidget]
  /// is called in the context of a [TestWidgetsFlutterBinding]).
  bool get isRootWidgetAttached => _rootElement != null;

  @override
  Future<void> performReassemble() {
    assert(() {
      WidgetInspectorService.instance.performReassemble();
      return true;
    }());

    if (rootElement != null) {
      buildOwner!.reassemble(rootElement!, BindingBase.debugReassembleConfig);
    }
    return super.performReassemble();
  }

  /// Computes the locale the current platform would resolve to.
  ///
  /// This method is meant to be used as part of a
  /// [WidgetsApp.localeListResolutionCallback]. Since this method may return
  /// null, a Flutter/dart algorithm should still be provided as a fallback in
  /// case a native resolved locale cannot be determined or if the native
  /// resolved locale is undesirable.
  ///
  /// This method may return a null [Locale] if the platform does not support
  /// native locale resolution, or if the resolution failed.
  ///
  /// The first `supportedLocale` is treated as the default locale and will be returned
  /// if no better match is found.
  ///
  /// Android and iOS are currently supported.
  ///
  /// On Android, the algorithm described in
  /// https://developer.android.com/guide/topics/resources/multilingual-support
  /// is used to determine the resolved locale. Depending on the android version
  /// of the device, either the modern (>= API 24) or legacy (< API 24) algorithm
  /// will be used.
  ///
  /// On iOS, the result of `preferredLocalizationsFromArray` method of `NSBundle`
  /// is returned. See:
  /// https://developer.apple.com/documentation/foundation/nsbundle/1417249-preferredlocalizationsfromarray?language=objc
  /// for details on the used method.
  ///
  /// iOS treats script code as necessary for a match, so a user preferred locale of
  /// `zh_Hans_CN` will not resolve to a supported locale of `zh_CN`.
  ///
  /// Since implementation may vary by platform and has potential to be heavy,
  /// it is recommended to cache the results of this method if the value is
  /// used multiple times.
  ///
  /// Second-best (and n-best) matching locales should be obtained by calling this
  /// method again with the matched locale of the first call omitted from
  /// `supportedLocales`.
  Locale? computePlatformResolvedLocale(List<Locale> supportedLocales) {
    return platformDispatcher.computePlatformResolvedLocale(supportedLocales);
  }
}

/// Inflate the given widget and attach it to the screen.
///
/// The widget is given constraints during layout that force it to fill the
/// entire screen. If you wish to align your widget to one side of the screen
/// (e.g., the top), consider using the [Align] widget. If you wish to center
/// your widget, you can also use the [Center] widget.
///
/// Calling [runApp] again will detach the previous root widget from the screen
/// and attach the given widget in its place. The new widget tree is compared
/// against the previous widget tree and any differences are applied to the
/// underlying render tree, similar to what happens when a [StatefulWidget]
/// rebuilds after calling [State.setState].
///
/// Initializes the binding using [WidgetsFlutterBinding] if necessary.
///
/// See also:
///
///  * [WidgetsBinding.attachRootWidget], which creates the root widget for the
///    widget hierarchy.
///  * [RenderObjectToWidgetAdapter.attachToRenderTree], which creates the root
///    element for the element hierarchy.
///  * [WidgetsBinding.handleBeginFrame], which pumps the widget pipeline to
///    ensure the widget, element, and render trees are all built.
void runApp(Widget app) {
  //TODO: 确保初始化，获取了全局单例 WidgetsBinding
  final WidgetsBinding binding = WidgetsFlutterBinding.ensureInitialized();
  assert(binding.debugCheckZone('runApp'));
  //TODO: 绑定根节点创建核心三棵树
  binding.scheduleAttachRootWidget(binding.wrapWithDefaultView(app));
  //TODO: 绘制热身帧--调用后会立即执行一次绘制（不用等待 VSYNC 信号到来）。
  binding.scheduleWarmUpFrame();
}

String _debugDumpAppString() {
  const String mode = kDebugMode ? 'DEBUG MODE' : kReleaseMode ? 'RELEASE MODE' : 'PROFILE MODE';
  final StringBuffer buffer = StringBuffer();
  buffer.writeln('${WidgetsBinding.instance.runtimeType} - $mode');
  if (WidgetsBinding.instance.rootElement != null) {
    buffer.writeln(WidgetsBinding.instance.rootElement!.toStringDeep());
  } else {
    buffer.writeln('<no tree currently mounted>');
  }
  return buffer.toString();
}

/// Print a string representation of the currently running app.
void debugDumpApp() {
  debugPrint(_debugDumpAppString());
}

/// A bridge from a [RenderObject] to an [Element] tree.
///
/// The given container is the [RenderObject] that the [Element] tree should be
/// inserted into. It must be a [RenderObject] that implements the
/// [RenderObjectWithChildMixin] protocol. The type argument `T` is the kind of
/// [RenderObject] that the container expects as its child.
///
/// Used by [runApp] to bootstrap applications.
/// RenderObjectToWidgetAdapter-->RenderObjectWidget-->Widget()
class RenderObjectToWidgetAdapter<T extends RenderObject> extends RenderObjectWidget {
  /// Creates a bridge from a [RenderObject] to an [Element] tree.
  ///
  /// Used by [WidgetsBinding] to attach the root widget to the [RenderView].
  RenderObjectToWidgetAdapter({
    this.child,//rootWidget
    required this.container,//RenderView get renderView => _pipelineOwner.rootNode! as RenderView;
    this.debugShortDescription,
  }) : super(key: GlobalObjectKey(container));

  /// The widget below this widget in the tree.
  ///
  /// {@macro flutter.widgets.ProxyWidget.child}
  /// 我们编写dart的runApp函数参数中传递的Flutter应用Widget树根
  final Widget? child;

  /// The [RenderObject] that is the parent of the [Element] created by this widget.
  /// 继承自RenderObject，来自PipelineOwner对象的rootNode属性，一个Flutter App全局只有一个PipelineOwner实例。
  final RenderObjectWithChildMixin<T> container;

  /// A short description of this widget used by debugging aids.
  final String? debugShortDescription;

  ///5、重写Widget的createElement实现，构建了一个RenderObjectToWidgetElement实例，它继承于Element。
  /// Element树的根结点是RenderObjectToWidgetElement。
  @override
  RenderObjectToWidgetElement<T> createElement() => RenderObjectToWidgetElement<T>(this);
  //6、重写Widget的createRenderObject实现，container本质是一个RenderView。
  //RenderObject树的根结点是RenderView。
  @override
  RenderObjectWithChildMixin<T> createRenderObject(BuildContext context) => container;

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) { }

  /// Inflate this widget and actually set the resulting [RenderObject] as the
  /// child of [container].
  ///
  /// If `element` is null, this function will create a new element. Otherwise,
  /// the given element will have an update scheduled to switch to this widget.
  ///
  /// Used by [runApp] to bootstrap applications.
  ///
  //  7、上面代码片段中RenderObjectToWidgetAdapter实例创建后调用
  //  owner来自 WidgetsBinding 初始化时实例化的 BuildOwner 实例，element 值就是自己。
  //  该方法创建根Element(RenderObjectToWidgetElement)，并将Element与Widget进行关联，即创建 WidgetTree 对应的 ElementTree 。
  //  如果Element已经创建过则将根Element中关联的Widget设为新的(即_newWidget)。
  //  可以看见Element只会创建一次，后面都是直接复用的。
  RenderObjectToWidgetElement<T> attachToRenderTree(BuildOwner owner, [ RenderObjectToWidgetElement<T>? element ]) {
    //最初的 element 是 null
    //返回的 RenderObjectToWidgetElement 才是 element 树的根节点
    if (element == null) {
      //在lockState里面代码执行过程中禁止调用setState方法
      owner.lockState(() {
        //创建一个Element实例，即调用本段代码片段中步骤5的方法。
        //调用RenderObjectToWidgetAdapter的createElement方法构建了一个RenderObjectToWidgetElement实例，继承RootRenderObjectElement，又继续继承RenderObjectElement，接着继承Element。
        element = createElement();//创建了Element的根节点
        assert(element != null);
        //11、给根Element的owner属性赋值为WidgetsBinding初始化时实例化的BuildOwner实例。
        element!.assignOwner(owner);
      });
      owner.buildScope(element!, () {
        //12、重点！mount里面RenderObject
        element!.mount(null, null);//在挂载的时候创建了renderObject 的根节点
      });
    } else {
      //13、更新widget树时_newWidget赋值为新的，然后element数根标记为markNeedsBuild
      element._newWidget = this;
      element.markNeedsBuild();//====>>接下来的这部分和 setState 的源码逻辑一致
    }
    return element!;
  }

  @override
  String toStringShort() => debugShortDescription ?? super.toStringShort();
}

/// The root of the element tree that is hosted by a [RenderObject].
///
/// This element class is the instantiation of a [RenderObjectToWidgetAdapter]
/// widget. It can be used only as the root of an [Element] tree (it cannot be
/// mounted into another [Element]; it's parent must be null).
///
/// In typical usage, it will be instantiated for a [RenderObjectToWidgetAdapter]
/// whose container is the [RenderView] that connects to the Flutter engine. In
/// this usage, it is normally instantiated by the bootstrapping logic in the
/// [WidgetsFlutterBinding] singleton created by [runApp].
class RenderObjectToWidgetElement<T extends RenderObject> extends RenderObjectElement with RootElementMixin {
  /// Creates an element that is hosted by a [RenderObject].
  ///
  /// The [RenderObject] created by this element is not automatically set as a
  /// child of the hosting [RenderObject]. To actually attach this element to
  /// the render tree, call [RenderObjectToWidgetAdapter.attachToRenderTree].
  RenderObjectToWidgetElement(RenderObjectToWidgetAdapter<T> super.widget);

  Element? _child;

  static const Object _rootChildSlot = Object();

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_child != null) {
      visitor(_child!);
    }
  }

  @override
  void forgetChild(Element child) {
    assert(child == _child);
    _child = null;
    super.forgetChild(child);
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    assert(parent == null);
    super.mount(parent, newSlot);
    _rebuild();
    assert(_child != null);
  }

  @override
  void update(RenderObjectToWidgetAdapter<T> newWidget) {
    super.update(newWidget);
    assert(widget == newWidget);
    _rebuild();
  }

  // When we are assigned a new widget, we store it here
  // until we are ready to update to it.
  Widget? _newWidget;

  @override
  void performRebuild() {
    if (_newWidget != null) {
      // _newWidget can be null if, for instance, we were rebuilt
      // due to a reassemble.
      final Widget newWidget = _newWidget!;
      _newWidget = null;
      update(newWidget as RenderObjectToWidgetAdapter<T>);
    }
    super.performRebuild();
    assert(_newWidget == null);
  }

  @pragma('vm:notify-debugger-on-exception')
  void _rebuild() {
    try {
      _child = updateChild(_child, (widget as RenderObjectToWidgetAdapter<T>).child, _rootChildSlot);
    } catch (exception, stack) {
      final FlutterErrorDetails details = FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'widgets library',
        context: ErrorDescription('attaching to the render tree'),
      );
      FlutterError.reportError(details);
      final Widget error = ErrorWidget.builder(details);
      _child = updateChild(null, error, _rootChildSlot);
    }
  }

  @override
  RenderObjectWithChildMixin<T> get renderObject => super.renderObject as RenderObjectWithChildMixin<T>;

  @override
  void insertRenderObjectChild(RenderObject child, Object? slot) {
    assert(slot == _rootChildSlot);
    assert(renderObject.debugValidateChild(child));
    renderObject.child = child as T;
  }

  @override
  void moveRenderObjectChild(RenderObject child, Object? oldSlot, Object? newSlot) {
    assert(false);
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    assert(renderObject.child == child);
    renderObject.child = null;
  }
}

/// A concrete binding for applications based on the Widgets framework.
///
/// This is the glue that binds the framework to the Flutter engine.
///
/// When using the widgets framework, this binding, or one that
/// implements the same interfaces, must be used. The following
/// mixins are used to implement this binding:
///
/// * [GestureBinding], which implements the basics of hit testing.[Flutter 手势事件绑定，处理屏幕事件分发及事件回调处理]
/// * [SchedulerBinding], which introduces the concepts of frames.[Flutter 绘制调度器相关绑定类，debug 编译模式时统计绘制流程时长等操作。]
/// * [ServicesBinding], which provides access to the plugin subsystem.[Flutter 系统平台消息监听绑定类。即 Platform 与 Flutter 层通信相关服务，同时注册监听了应用的生命周期回调。]
/// * [PaintingBinding], which enables decoding images.[Flutter 绘制预热缓存等绑定类。]
/// * [SemanticsBinding], which supports accessibility.[语义树和 Flutter 引擎之间的粘合剂绑定类。]
/// * [RendererBinding], which handles the render tree.[渲染树和 Flutter 引擎之间的粘合剂绑定类，内部重点是持有了渲染树的根节点。]
/// * [WidgetsBinding], which handles the widget tree.[Widget 树和 Flutter 引擎之间的粘合剂绑定类。]
/// WidgetsFlutterBinding 实例及初始化: 继承自 BindingBase with了N多个 xxxBinding,在 BindingBase 的构造器进行 initInstances，同时 各个
/// xxxBinding 一并执行了 initInstances
class WidgetsFlutterBinding extends BindingBase with
    GestureBinding, SchedulerBinding, ServicesBinding,
    PaintingBinding, SemanticsBinding, RendererBinding, WidgetsBinding {
  /// Returns an instance of the binding that implements
  /// [WidgetsBinding]. If no binding has yet been initialized, the
  /// [WidgetsFlutterBinding] class is used to create and initialize
  /// one.
  ///
  /// You only need to call this method if you need the binding to be
  /// initialized before calling [runApp].
  ///
  /// In the `flutter_test` framework, [testWidgets] initializes the
  /// binding instance to a [TestWidgetsFlutterBinding], not a
  /// [WidgetsFlutterBinding]. See
  /// [TestWidgetsFlutterBinding.ensureInitialized].
  /// WidgetsFlutterBinding 就是将 Widget 架构和 Flutter Engine 连接的核心桥梁，也是整个 Flutter 的应用层核心。
  /// 通过 ensureInitialized() 方法我们可以得到一个  全局  单例  的 WidgetsFlutterBinding 实例，且 mixin 的一堆 XxxBinding 也被实例化。
  static WidgetsBinding ensureInitialized() {
    if (WidgetsBinding._instance == null) {
      //构造器执行
      WidgetsFlutterBinding();
    }
    return WidgetsBinding.instance;
  }
}
