import 'dart:io';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:fimber_io/fimber_io.dart';

// init(mode: Mode) -> i32
typedef TimerInit = int Function(int);
typedef TimerInitFunc = Int32 Function(Int32);

// stop() -> i32
typedef TimerStop = int Function();
typedef TimerStopFunc = Int32 Function();

// start_env_logger()
typedef TimerStartEnvLogger = void Function();
typedef TimerStartEnvLoggerFunc = Void Function();

// type Callback = extern "C" fn(bool, u32, *const c_char, *const u64)
// register_callback(cb: Callback) -> i32
typedef Callback = void Function(bool, int, String, int?);
typedef TimerCallback = Void Function(Bool, Uint32, Pointer<Utf8>, Pointer<Uint64>);
typedef TimerRegisterCallback = int Function(Pointer<NativeFunction<TimerCallback>>);
typedef TimerRegisterCallbackFunc = Int32 Function(Pointer<NativeFunction<TimerCallback>>);

// add_filter(path: *const c_char, custom: *const u64) -> i32
typedef TimerAddFilter = int Function(Pointer<Utf8>, Pointer<Uint64>);
typedef TimerAddFilterFunc = Int32 Function(Pointer<Utf8>, Pointer<Uint64>);

// remove_filter(path: *const c_char) -> i32
typedef TimerRemoveFilter = int Function(Pointer<Utf8>);
typedef TimerRemoveFilterFunc = Int32 Function(Pointer<Utf8>);

// clear_filters() -> i32
typedef TimerClearFilters = int Function();
typedef TimerClearFiltersFunc = Int32 Function();

// check(path: *const c_char) -> i32
typedef TimerCheck = int Function(Pointer<Utf8>);
typedef TimerCheckFunc = Int32 Function(Pointer<Utf8>);

class Timer {
  static Timer setup() {
    assert(!_instance._set, "You already setup the Timer instance");
    _instance._init();
    return _instance;
  }

  bool _set = false;

  Timer._();
  static final Timer _instance = Timer._();

  static Timer get instance {
    assert(_instance._set, 'You must setup the Timer instance before calling Timer.instance');
    return _instance;
  }

  late final DynamicLibrary library;

  late final TimerInit _timer_init;
  late final TimerStop _timer_stop;
  late final TimerRegisterCallback _timer_register_callback;
  late final TimerAddFilter _timer_add_filter;
  late final TimerRemoveFilter _timer_remove_filter;
  late final TimerClearFilters _timer_clear_filters;
  late final TimerCheck _timer_check;

  late final NativeCallable<TimerCallback> _callback_listener;
  Callback? _dart_callback;

  void _init() {
    try {
      library = DynamicLibrary.open("time_app_backend-logless.dll");
    } on ArgumentError catch (e) {
      Fimber.e("Failed to load AppTimer library. Error: ${e.message}");
      exit(-100);
    }

    _timer_init = library.lookup<NativeFunction<TimerInitFunc>>("init").asFunction<TimerInit>();
    _timer_stop = library.lookup<NativeFunction<TimerStopFunc>>("stop").asFunction<TimerStop>();
    _timer_register_callback = library.lookup<NativeFunction<TimerRegisterCallbackFunc>>("register_callback").asFunction<TimerRegisterCallback>();
    _timer_add_filter = library.lookup<NativeFunction<TimerAddFilterFunc>>("add_filter").asFunction<TimerAddFilter>();
    _timer_remove_filter = library.lookup<NativeFunction<TimerRemoveFilterFunc>>("remove_filter").asFunction<TimerRemoveFilter>();
    _timer_clear_filters = library.lookup<NativeFunction<TimerClearFiltersFunc>>("clear_filters").asFunction<TimerClearFilters>();
    _timer_check = library.lookup<NativeFunction<TimerCheckFunc>>("check").asFunction<TimerCheck>();

    // Start Timer logger - Only uncomment for debugging with the correct library
    // final _timer_start_env_logger = library.lookup<NativeFunction<TimerStartEnvLoggerFunc>>("start_env_logger").asFunction<TimerStartEnvLogger>();
    // _timer_start_env_logger();

    // Register callback
    _callback_listener = NativeCallable<TimerCallback>.listener(this._callback);
    _timer_register_callback(_callback_listener.nativeFunction);

    // Initialize Timer in filtered mode
    final result = _timer_init(1);
    if (result != 0) {
      switch (result) {
        case -1:
          throw "Failed to start Timer query loop";
        case -2:
          throw "Failed to check if Timer is already initialized";
        case -3:
          throw "Timer already initialized";
        default:
          throw "Unknow error while trying to initialize Timer";
      }
    }

    _set = true;
  }

  void setCallback(Callback callbackFunction) {
    _dart_callback = callbackFunction;
  }

  void addFilter(String executablePath, int? customID) {
    final pathPointer = executablePath.toNativeUtf8();

    var customPointer = nullptr as Pointer<Uint64>;
    if (customID != null) {
      customPointer = calloc<Uint64>();
      customPointer.value = customID;
    }

    final result = _timer_add_filter(pathPointer, customPointer);
    if (result != 0) {
      switch (result) {
        case -1:
          throw "Invalid executable path string";
        case -2:
          throw "Executable path does not exist";
        case -3:
          throw "Provided executable path is invalid in this context";
        case -4:
          throw "Provided executable path does not point to a file";
        default:
          throw "Unknow error while trying to add a Timer filter";
      }
    }
  }

  void removeFilter(String executablePath) {
    final pathPointer = executablePath.toNativeUtf8();

    final result = _timer_remove_filter(pathPointer);
    if (result < 0) {
      switch (result) {
        case -1:
          throw "Invalid executable path string";
        case -2:
          throw "Executable path does not exist";
        case -3:
          throw "Provided executable path is invalid in this context";
        case -4:
          throw "Provided executable path does not point to a file";
        default:
          throw "Unknow error while trying to add a Timer filter";
      }
    }
  }

  void clearFilters() {
    _timer_clear_filters();
  }

  bool check(String executablePath) {
    final pathPointer = executablePath.toNativeUtf8();

    final result = _timer_check(pathPointer);
    if (result < 0) {
      switch (result) {
        case -1:
          throw "Invalid executable path string";
        case -2:
          throw "Executable path does not exist";
        case -3:
          throw "Provided executable path is invalid in this context";
        case -4:
          throw "Failed to check if process with given executable path exists";
        default:
          throw "Unknow error while trying to add a Timer filter";
      }
    }

    return result == 1;
  }

  void stop() {
    final result = _timer_stop();
    if (result != 0) {
      throw "Failed to stop Timer";
    }

    _callback_listener.close();
  }

  void _callback(bool is_starting, int process_id, Pointer<Utf8> process_name_raw, Pointer<Uint64> custom_raw) {
    final process_name = process_name_raw.toDartString();

    int? custom_id = null;
    if (custom_raw.address != nullptr.address) {
      custom_id = custom_raw.value;
    }

    if (_dart_callback != null) {
      _dart_callback!(is_starting, process_id, process_name, custom_id);
    }

    calloc.free(process_name_raw);
    calloc.free(custom_raw);
  }
}
