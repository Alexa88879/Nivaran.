// lib/screens/report/camera_capture_screen.dart
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:developer' as developer;
import 'report_details_screen.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  int _selectedCameraIdx = 0;
  bool _isCameraInitialized = false;
  bool _isPermissionGranted = false;
  String _initializationError = "";

  // To ensure dispose is only called once or handled correctly
  bool _isDisposing = false;
  
  // Add these new variables for retry mechanism
  int _initRetryCount = 0;
  static const int _maxInitRetries = 3;
  static const Duration _initTimeout = Duration(seconds: 10);
  bool _isInitializing = false;

  FlashMode _currentFlashMode = FlashMode.off;
  final List<FlashMode> _availableFlashModes = [
    FlashMode.off,
    FlashMode.auto,
    FlashMode.always,
  ];

  @override
  void initState() {
    super.initState();
    developer.log('CameraCaptureScreen: initState', name: 'CameraCaptureScreen');
    WidgetsBinding.instance.addObserver(this);
    _requestPermissionAndInitializeCamera();
  }

  Future<void> _disposeController() async {
    if (_cameraController != null) {
      developer.log('CameraCaptureScreen: Attempting to dispose controller.', name: 'CameraCaptureScreen');
      try {
        if (_cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }
        await _cameraController!.dispose();
        developer.log('CameraCaptureScreen: Controller disposed.', name: 'CameraCaptureScreen');
      } catch (e, s) {
        developer.log('CameraCaptureScreen: Error disposing controller: $e', 
                     name: 'CameraCaptureScreen', error: e, stackTrace: s);
      } finally {
        if (mounted) {
          setState(() {
            _cameraController = null;
          });
        } else {
          _cameraController = null;
        }
      }
    }
  }


  // Add this flag to track permission requests
  // Add this flag at the top of your _CameraCaptureScreenState class
  bool _isRequestingPermission = false;
  
  // Update your permission request method
  Future<void> _requestPermissionAndInitializeCamera() async {
    // Prevent multiple simultaneous permission requests
    if (_isRequestingPermission) {
      developer.log('CameraCaptureScreen: Permission request already in progress.', name: 'CameraCaptureScreen');
      return;
    }
    
    try {
      _isRequestingPermission = true;
      developer.log('CameraCaptureScreen: Requesting camera permission...', name: 'CameraCaptureScreen');
      if (!mounted) return; // Ensure widget is still mounted
      
      // First check if permission is already granted
      final cameraStatus = await Permission.camera.status;
      if (cameraStatus.isGranted) {
        developer.log('CameraCaptureScreen: Camera permission already granted.', name: 'CameraCaptureScreen');
        if (mounted) {
          setState(() {
            _isPermissionGranted = true;
            _initializationError = "";
          });
          await _initializeCamera();
        }
        return;
      }
      
      // Request permission if not already granted
      final requestStatus = await Permission.camera.request();
      
      if (!mounted) return;

      if (requestStatus.isGranted) {
        developer.log('CameraCaptureScreen: Camera permission granted.', name: 'CameraCaptureScreen');
        setState(() {
          _isPermissionGranted = true;
          _initializationError = "";
        });
        await _initializeCamera();
      } else {
        developer.log('CameraCaptureScreen: Camera permission denied.', name: 'CameraCaptureScreen');
        setState(() {
          _isPermissionGranted = false;
          _isCameraInitialized = false;
          _initializationError = 'Camera permission denied. Please grant permission in settings.';
        });
        if (requestStatus.isPermanentlyDenied && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is permanently denied. Please enable it in app settings.'),
              action: SnackBarAction(label: 'Open Settings', onPressed: openAppSettings),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingPermission = false;
        });
      } else {
        _isRequestingPermission = false;
      }
    }
  }

  Future<void> _initializeCamera() async {
    developer.log('CameraCaptureScreen: Initializing camera...', name: 'CameraCaptureScreen');
    if (!_isPermissionGranted || !mounted) {
      developer.log('CameraCaptureScreen: Cannot initialize camera, permission not granted or not mounted.', name: 'CameraCaptureScreen');
      if (mounted) {
        setState(() {
           _initializationError = "Camera permission not granted.";
           _isCameraInitialized = false;
        });
      }
      return;
    }
    if (_isDisposing) {
      developer.log('CameraCaptureScreen: Attempted to initialize camera while disposing.', name: 'CameraCaptureScreen');
      return;
    }
    
    // Prevent multiple simultaneous initialization attempts
    if (_isInitializing) {
      developer.log('CameraCaptureScreen: Camera initialization already in progress.', name: 'CameraCaptureScreen');
      return;
    }
    
    setState(() {
      _isInitializing = true;
      _initializationError = "";
    });

    try {
      developer.log('CameraCaptureScreen: Fetching available cameras...', name: 'CameraCaptureScreen');
      _cameras = await availableCameras();
      if (!mounted) return;

      if (_cameras != null && _cameras!.isNotEmpty) {
        developer.log('CameraCaptureScreen: ${_cameras!.length} cameras found.', name: 'CameraCaptureScreen');
        int backCameraIdx = _cameras!.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
        _selectedCameraIdx = (backCameraIdx != -1) ? backCameraIdx : 0;
        
        developer.log('CameraCaptureScreen: Selected camera index: $_selectedCameraIdx', name: 'CameraCaptureScreen');
        await _onNewCameraSelected(_cameras![_selectedCameraIdx]);
      } else {
        developer.log('CameraCaptureScreen: No cameras available.', name: 'CameraCaptureScreen');
        if (mounted) {
            setState(() {
              _isCameraInitialized = false;
              _initializationError = 'No cameras available on this device.';
              _isInitializing = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No cameras found on this device.')),
            );
         }
      }
    } catch (e, s) {
      developer.log('CameraCaptureScreen: Error during camera list fetching or initial selection: $e', name: 'CameraCaptureScreen', error: e, stackTrace: s);
      if(mounted) {
        setState(() {
          _isCameraInitialized = false;
          _initializationError = 'Error finding cameras: ${e.toString()}';
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _onNewCameraSelected(CameraDescription cameraDescription) async {
    developer.log('CameraCaptureScreen: Setting up new camera: ${cameraDescription.name}', name: 'CameraCaptureScreen');
    if (!mounted || _isDisposing) return;

    if (_cameraController != null) {
      developer.log('CameraCaptureScreen: Disposing previous camera controller in _onNewCameraSelected.', name: 'CameraCaptureScreen');
      await _disposeController(); // Use the new centralized dispose method
    }

    _cameraController = CameraController(
      cameraDescription,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    _cameraController!.addListener(() {
      if (mounted && _cameraController != null && _cameraController!.value.hasError) { // Check mounted
        developer.log('CameraCaptureScreen: Camera Controller Error: ${_cameraController!.value.errorDescription}', name: 'CameraCaptureScreen');
      }
    });

    try {
      developer.log('CameraCaptureScreen: Initializing new camera controller...', name: 'CameraCaptureScreen');
      
      // Add timeout to camera initialization
      bool initSuccess = false;
      await Future.any([
        _cameraController!.initialize().then((_) {
          initSuccess = true;
        }),
        Future.delayed(_initTimeout).then((_) {
          if (!initSuccess) {
            throw CameraException('timeout', 'Camera initialization timed out after ${_initTimeout.inSeconds} seconds');
          }
        })
      ]);
      
      developer.log('CameraCaptureScreen: Camera controller initialized successfully. Aspect Ratio: ${_cameraController!.value.aspectRatio}', name: 'CameraCaptureScreen');
      if(mounted && _cameraController != null) { 
        await _cameraController!.setFlashMode(_currentFlashMode);
      }
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _initializationError = "";
          _isInitializing = false;
          _initRetryCount = 0; // Reset retry count on success
        });
      }
    } on CameraException catch (e,s) {
      developer.log('CameraCaptureScreen: CameraException during _onNewCameraSelected: ${e.code} - ${e.description}', name: 'CameraCaptureScreen', error: e, stackTrace: s);
      _showCameraException(e); // This already checks mounted
      
      // Handle "busy" errors with retry mechanism
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _initializationError = 'Failed to initialize camera: ${e.description}';
          _isInitializing = false;
        });
        
        // Implement retry for camera busy errors
        if ((e.code == 'CameraAccessDenied' || 
             e.code == 'camera_error' || 
             e.description?.contains('busy') == true) && 
            _initRetryCount < _maxInitRetries) {
          _initRetryCount++;
          developer.log('CameraCaptureScreen: Retrying camera initialization (attempt $_initRetryCount of $_maxInitRetries)', 
                       name: 'CameraCaptureScreen');
          
          // Add delay before retry
          Future.delayed(Duration(milliseconds: 800 * _initRetryCount), () {
            if (mounted && !_isDisposing) {
              _onNewCameraSelected(cameraDescription);
            }
          });
        }
      }
    } catch (e,s) {
      developer.log('CameraCaptureScreen: Generic error during _onNewCameraSelected: $e', name: 'CameraCaptureScreen', error: e, stackTrace:s);
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _initializationError = 'An unexpected error occurred: ${e.toString()}';
          _isInitializing = false;
        });
      }
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return; // Check if widget is still mounted
    developer.log('CameraCaptureScreen: AppLifecycleState changed to $state', name: 'CameraCaptureScreen');
    
    final CameraController? currentCameraController = _cameraController; // Use a local variable

    if (state == AppLifecycleState.inactive) {
      developer.log('CameraCaptureScreen: App inactive.', name: 'CameraCaptureScreen');
      // Release camera resources when app goes to background
      _disposeController();
    } else if (state == AppLifecycleState.resumed) {
      developer.log('CameraCaptureScreen: App resumed.', name: 'CameraCaptureScreen');
      // Add delay before reinitializing to avoid resource contention
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted || _isDisposing) return;
        
        if (currentCameraController == null || !currentCameraController.value.isInitialized) {
          developer.log('CameraCaptureScreen: Controller not ready on resume, attempting re-init.', name: 'CameraCaptureScreen');
          if (_isPermissionGranted) {
            _initializeCamera();
          } else {
            _requestPermissionAndInitializeCamera();
          }
        } else {
          developer.log('CameraCaptureScreen: Controller was already initialized on resume.', name: 'CameraCaptureScreen');
          // Optionally re-apply flash mode if needed
          currentCameraController.setFlashMode(_currentFlashMode).catchError((e){
              _showCameraException(e is CameraException ? e : CameraException("FlashErrorOnResume", e.toString()));
          });
        }
      });
    }
  }

  void _showCameraException(dynamic e) {
    String errorText;
    if (e is CameraException) {
      errorText = 'Camera Error: ${e.code}\n${e.description}';
    } else {
      errorText = 'An unknown camera error occurred: ${e.toString()}';
    }
    developer.log(errorText, name: 'CameraCaptureScreen._showCameraException', error: e);

    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e is CameraException ? (e.description ?? e.code) : e.toString())),
      );
       setState(() {
          _initializationError = e is CameraException ? (e.description ?? e.code) : e.toString();
          _isCameraInitialized = false;
       });
    }
  }

  // Example for taking a picture
  Future<void> _onTakePictureButtonPressed() async {
    developer.log('CameraCaptureScreen: Take picture button pressed.', name: 'CameraCaptureScreen');
    if (!_isCameraControllerAvailable() || _cameraController!.value.isTakingPicture) {
      developer.log(
        'CameraCaptureScreen: Cannot take picture. Controller available: ${_isCameraControllerAvailable()}, IsTakingPicture: ${_cameraController?.value.isTakingPicture}',
        name: 'CameraCaptureScreen'
      );
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera not ready or currently busy.')),
        );
      }
      return;
    }
    try {
      developer.log('CameraCaptureScreen: Taking picture...', name: 'CameraCaptureScreen');
      final XFile imageFile = await _cameraController!.takePicture();
      developer.log('CameraCaptureScreen: Picture taken: ${imageFile.path}', name: 'CameraCaptureScreen');
      
      if (mounted) {
        // IMPORTANT: Pause the camera preview before navigating away
        // This might help with resource contention when ReportDetailsScreen is pushed.
        if (_cameraController!.value.isPreviewPaused == false) {
             await _cameraController!.pausePreview();
             developer.log('CameraCaptureScreen: Camera preview paused.', name: 'CameraCaptureScreen');
        }
        if (!mounted) return;
        final result = await Navigator.push(context,MaterialPageRoute(
            builder: (context) => ReportDetailsScreen(imagePath: imageFile.path),
          ),
        );

        developer.log('CameraCaptureScreen: Returned from ReportDetailsScreen with result: $result', name: 'CameraCaptureScreen');
        
        if (!mounted) return; // Check mounted again after await

        if (result == true) { // Issue was submitted successfully
          // CameraCaptureScreen itself should be popped by ReportDetailsScreen's new navigation logic.
          // If ReportDetailsScreen navigates with pushNamedAndRemoveUntil, this screen is already gone.
          // If ReportDetailsScreen just pops itself, then this screen needs to pop.
          // Based on previous logic: ReportDetailsScreen pops, then CameraCaptureScreen pops.
          // Let's assume ReportDetailsScreen now handles navigating away from the whole flow.
          // So, if result is true, we might not need to do anything here if ReportDetailsScreen cleared the stack.
          // However, if ReportDetailsScreen ONLY pops itself, then this screen should pop.
          // Let's use the new navigation where ReportDetailsScreen navigates away fully.
        } else { // Closed ReportDetailsScreen without submitting or an error occurred there
           developer.log('CameraCaptureScreen: ReportDetailsScreen returned false or null. Resuming preview.', name: 'CameraCaptureScreen');
           // Ensure camera is resumed or re-initialized if needed
           if (_cameraController != null && _cameraController!.value.isInitialized) {
              if (_cameraController!.value.isPreviewPaused) {
                await _cameraController!.resumePreview();
                developer.log('CameraCaptureScreen: Camera preview resumed.', name: 'CameraCaptureScreen');
              }
              await _cameraController!.setFlashMode(_currentFlashMode).catchError((e){
                  _showCameraException(e is CameraException ? e : CameraException("FlashErrorPostDetails", e.toString()));
              });
           } else if (_isPermissionGranted) {
              _initializeCamera(); // Re-initialize if it became uninitialized
           }
        }
      }
    } on CameraException catch (e) {
      developer.log('CameraCaptureScreen: CameraException during takePicture: ${e.code}', name: 'CameraCaptureScreen', error: e);
      _showCameraException(e);
    } catch (e) {
      developer.log('CameraCaptureScreen: Generic error during takePicture: $e', name: 'CameraCaptureScreen', error: e);
       if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error taking picture: ${e.toString()}')),
        );
      }
    }
  }

  // Update flash mode method
  Future<void> _onFlashModeButtonPressed() async {
    if (!_isCameraControllerAvailable()) return;
    
    int nextModeIndex = (_availableFlashModes.indexOf(_currentFlashMode) + 1) % _availableFlashModes.length;
    FlashMode nextFlashMode = _availableFlashModes[nextModeIndex];

    try {
      await _cameraController!.setFlashMode(nextFlashMode);
      if(mounted) {
        setState(() {
          _currentFlashMode = nextFlashMode;
        });
      }
    } on CameraException catch (e) {
      _showCameraException(e);
    }
  }

  IconData _getFlashIcon(FlashMode mode) {
    switch (mode) {
      case FlashMode.off: return Icons.flash_off;
      case FlashMode.auto: return Icons.flash_auto;
      case FlashMode.always: return Icons.flash_on;
      case FlashMode.torch: return Icons.highlight;
    }
  }

  // Modify your dispose method to ensure proper cleanup
  @override
  Future<void> dispose() async {
    developer.log('CameraCaptureScreen: dispose() called.', name: 'CameraCaptureScreen');
    _isDisposing = true;
    WidgetsBinding.instance.removeObserver(this);
    await _disposeController(); // Use the centralized async dispose method
    super.dispose();
    developer.log('CameraCaptureScreen: dispose() finished.', name: 'CameraCaptureScreen');
  }
  
  // Add this safety method to check controller state before using it
  bool _isCameraControllerAvailable() {
    return _cameraController != null && 
           !_isDisposing && 
           mounted &&
           _cameraController!.value.isInitialized;
  }

  @override
  Widget build(BuildContext context) {
    developer.log(
        'CameraCaptureScreen: Build method called. IsCameraInitialized: $_isCameraInitialized, IsPermissionGranted: $_isPermissionGranted, InitError: $_initializationError, Controller: ${_cameraController != null}, Controller Initialized: ${_cameraController?.value.isInitialized}',
        name: 'CameraCaptureScreen');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report New Issue'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      backgroundColor: Colors.black,
      body: Builder(
        builder: (BuildContext scaffoldContext) {
          if (!_isPermissionGranted) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.no_photography, size: 80, color: Colors.white54),
                    const SizedBox(height: 20),
                    Text(
                      _initializationError.isNotEmpty ? _initializationError : 'Camera permission is required to report issues.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _requestPermissionAndInitializeCamera,
                      child: const Text('Grant Permission'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!_isCameraInitialized || _cameraController == null || !_cameraController!.value.isInitialized) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 20),
                      Text(
                        _initializationError.isNotEmpty ? 'Error: $_initializationError' : 'Initializing Camera...',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                       if (_initializationError.isNotEmpty) ...[
                         const SizedBox(height: 20),
                         ElevatedButton(
                           onPressed: _requestPermissionAndInitializeCamera,
                           child: const Text('Try Again'),
                         )
                       ]
                    ]),
              ),
            );
          }
          // Camera is initialized
          return Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12.0),
                  child: Container(
                    margin: const EdgeInsets.all(0), // Can add padding here if needed around preview
                    color: Colors.black,
                    child: OverflowBox( // Allows the child to overflow and then be clipped by FittedBox/parent
                        maxWidth: double.infinity,
                        maxHeight: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _cameraController!.value.previewSize!.height, // For portrait, preview size is often landscape
                            height: _cameraController!.value.previewSize!.width,
                            child: CameraPreview(_cameraController!),
                          ),
                        ),
                      ),
                  ),
                ),
              ),
              _buildControls(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 20.0),
      color: Colors.black.withAlpha(180),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          IconButton(
            icon: Icon(_getFlashIcon(_currentFlashMode), color: Colors.white, size: 28),
            onPressed: _onFlashModeButtonPressed,
            tooltip: 'Flash Mode: ${_currentFlashMode.toString().split('.').last}',
          ),
          GestureDetector(
            onTap: _onTakePictureButtonPressed,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.grey.shade400, width: 3)
              ),
              child: const Icon(Icons.camera_alt, color: Colors.black, size: 35),
            ),
          ),
          (_cameras != null && _cameras!.length > 1) 
          ? IconButton(
              icon: const Icon(Icons.switch_camera, color: Colors.white, size: 28),
              onPressed: () {
                if (_cameras != null && _cameras!.isNotEmpty && _cameraController != null && _cameraController!.value.isInitialized) {
                  _selectedCameraIdx = (_selectedCameraIdx + 1) % _cameras!.length;
                   developer.log("Switching to camera index: $_selectedCameraIdx", name: "CameraCaptureScreen");
                  _onNewCameraSelected(_cameras![_selectedCameraIdx]);
                }
              },
              tooltip: 'Switch Camera',
            )
          : SizedBox(width: 48),
        ],
      ),
    );
  }
}