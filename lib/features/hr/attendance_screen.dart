import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/user_session.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/erp_doc_sheet.dart';
import '../../core/widgets/erp_search_bar.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();

  Position? _currentPosition;
  bool _loadingLocation = false;
  String? _locationError;

  XFile? _selfieFile;
  bool _submittingCheckin = false;

  // Geo-fence settings (persisted locally so HR/Manager or user can set office pin)
  double? _officeLat;
  double? _officeLng;
  double _geofenceRadiusMeters = 300;
  bool _enforceGeofence = false;

  List<Map<String, dynamic>> _recentCheckins = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _attendanceList = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _shiftRequests = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _employees = <Map<String, dynamic>>[];
  List<String> _shiftTypes = <String>['General Shift', 'Morning Shift'];
  bool _loadingHistory = false;

  // 1. Employee Attendance Tool state
  DateTime _toolDate = DateTime.now();
  String _toolDepartment = 'All Departments';
  String _toolStatus = 'Present';
  String _toolShift = '';
  bool _toolLateEntry = false;
  bool _toolEarlyExit = false;
  final Set<String> _selectedUnmarkedEmployees = <String>{};
  bool _markingBulkAttendance = false;

  // 2. Monthly Attendance Sheet state
  int _sheetYear = DateTime.now().year;
  int _sheetMonth = DateTime.now().month;
  String _sheetEmployeeFilter = 'All Employees';
  String _sheetSearchQuery = '';
  String _sheetStatusFilter = 'All';

  // Search state across Attendance tabs
  String _checkinQuery = '';
  String _checkinTypeFilter = 'All';
  String _toolEmployeeQuery = '';
  String _toolEmployeeFilter = 'All';
  String _shiftQuery = '';
  String _shiftStatusFilter = 'All';

  static const List<String> _attendanceStatuses = <String>[
    'Present',
    'Absent',
    'On Leave',
    'Half Day',
    'Work From Home',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    _loadGeofenceConfig();
    _acquireLocation();
    _loadAttendanceAndShifts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGeofenceConfig() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _officeLat = prefs.getDouble('geofence_lat');
      _officeLng = prefs.getDouble('geofence_lng');
      _geofenceRadiusMeters = prefs.getDouble('geofence_radius') ?? 300;
      _enforceGeofence = prefs.getBool('geofence_enforce') ?? false;
    });
  }

  Future<void> _saveGeofenceConfig({
    required double? lat,
    required double? lng,
    required double radius,
    required bool enforce,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (lat != null && lng != null) {
      await prefs.setDouble('geofence_lat', lat);
      await prefs.setDouble('geofence_lng', lng);
    } else {
      await prefs.remove('geofence_lat');
      await prefs.remove('geofence_lng');
    }
    await prefs.setDouble('geofence_radius', radius);
    await prefs.setBool('geofence_enforce', enforce);
    setState(() {
      _officeLat = lat;
      _officeLng = lng;
      _geofenceRadiusMeters = radius;
      _enforceGeofence = enforce;
    });
  }

  Future<void> _acquireLocation() async {
    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationError = 'GPS Location Services are disabled on this device.';
          _loadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _locationError =
              'Location permission denied. Enable GPS for Geo-Fenced Check-In.';
          _loadingLocation = false;
        });
        return;
      }

      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _loadingLocation = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = 'Could not fetch GPS coordinates: $e';
          _loadingLocation = false;
        });
      }
    }
  }

  double? get _distanceFromOfficeMeters {
    if (_currentPosition == null || _officeLat == null || _officeLng == null) {
      return null;
    }
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _officeLat!,
      _officeLng!,
    );
  }

  bool get _isInsideGeofence {
    if (!_enforceGeofence || _officeLat == null || _officeLng == null) {
      return true;
    }
    final double? dist = _distanceFromOfficeMeters;
    if (dist == null) {
      return false;
    }
    return dist <= _geofenceRadiusMeters;
  }

  Future<void> _captureSelfie() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 78,
        maxWidth: 1080,
      );
      if (photo != null && mounted) {
        setState(() {
          _selfieFile = photo;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Camera error: $e')));
      }
    }
  }

  Future<void> _loadAttendanceAndShifts() async {
    setState(() {
      _loadingHistory = true;
    });

    try {
      final List<Map<String, dynamic>> empList = await ErpApiClient.instance
          .getList(
            'Employee',
            fields: <String>[
              'name',
              'employee_name',
              'department',
              'designation',
              'branch',
              'status',
              'company',
            ],
            filters: <String, dynamic>{'status': 'Active'},
            orderBy: 'employee_name asc',
            limitPageLength: 200,
          );
      if (mounted && empList.isNotEmpty) {
        setState(() {
          _employees = empList;
        });
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> checkins = await ErpApiClient.instance
          .getList(
            'Employee Checkin',
            fields: <String>[
              'name',
              'employee',
              'employee_name',
              'log_type',
              'time',
              'device_id',
            ],
            limitPageLength: 30,
          );
      if (mounted) {
        setState(() {
          _recentCheckins = checkins;
        });
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> att = await ErpApiClient.instance
          .getList(
            'Attendance',
            fields: <String>[
              'name',
              'employee',
              'employee_name',
              'department',
              'attendance_date',
              'status',
              'shift',
              'late_entry',
              'early_exit',
            ],
            orderBy: 'attendance_date desc',
            limitPageLength: 300,
          );
      if (mounted) {
        setState(() {
          _attendanceList = att;
        });
      }
    } catch (_) {}

    try {
      final List<Map<String, dynamic>> shifts = await ErpApiClient.instance
          .getList(
            'Shift Request',
            fields: <String>[
              'name',
              'employee',
              'employee_name',
              'shift_type',
              'from_date',
              'to_date',
              'status',
            ],
            limitPageLength: 30,
          );
      final List<Map<String, dynamic>> shiftTypeDocs = await ErpApiClient
          .instance
          .getList('Shift Type', fields: <String>['name'], limitPageLength: 20);
      if (mounted) {
        setState(() {
          _shiftRequests = shifts;
          if (shiftTypeDocs.isNotEmpty) {
            _shiftTypes = shiftTypeDocs
                .map((Map<String, dynamic> s) => (s['name'] ?? '').toString())
                .where((String s) => s.isNotEmpty)
                .toList();
          }
        });
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _loadingHistory = false;
      });
    }
  }

  Future<void> _submitCheckInOrOut(String logType) async {
    if (_enforceGeofence && !_isInsideGeofence) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            'Outside Geo-Fence! You are ${_distanceFromOfficeMeters?.toStringAsFixed(0) ?? '?'}m away (max ${_geofenceRadiusMeters.toStringAsFixed(0)}m).',
          ),
        ),
      );
      return;
    }

    setState(() {
      _submittingCheckin = true;
    });

    try {
      final UserSession? session = ErpApiClient.instance.session;
      final String nowStr = DateFormat('yyyy-MM-dd HH:mm:ss')
          .format(DateTime.now());
      final double lat = _currentPosition?.latitude ?? 0.0;
      final double lng = _currentPosition?.longitude ?? 0.0;

      String? selfieUrl;
      if (_selfieFile != null) {
        selfieUrl = await ErpApiClient.instance.uploadFile(
          filePath: _selfieFile!.path,
          fileName:
              'selfie_${logType}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      Map<String, dynamic>? createdDoc;
      try {
        createdDoc = await ErpApiClient.instance.createDoc(
          'Employee Checkin',
          <String, dynamic>{
            if (session != null && session.employeeId.isNotEmpty)
              'employee': session.employeeId,
            'log_type': logType,
            'time': nowStr,
            'latitude': lat,
            'longitude': lng,
            'device_id':
                '${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)} (Mobile)',
            if (selfieUrl != null && selfieUrl.isNotEmpty)
              'custom_selfie': selfieUrl,
          },
        );
      } catch (_) {
        // Fallback: if Employee Checkin has restricted permissions on this server,
        // create or update today's Attendance record directly.
        final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        createdDoc = await ErpApiClient.instance.createDoc(
          'Attendance',
          <String, dynamic>{
            if (session != null && session.employeeId.isNotEmpty)
              'employee': session.employeeId,
            if (session != null) 'company': session.company,
            'attendance_date': todayStr,
            'status': 'Present',
          },
        );
      }

      if (_selfieFile != null &&
          createdDoc['name'] != null &&
          (selfieUrl == null || selfieUrl.isEmpty)) {
        try {
          await ErpApiClient.instance.uploadFile(
            filePath: _selfieFile!.path,
            fileName: 'selfie_${createdDoc['name']}.jpg',
            doctype: 'Employee Checkin',
            docname: createdDoc['name'].toString(),
          );
        } catch (_) {}
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text(
            'Successfully recorded $logType at $nowStr ${selfieUrl != null ? '(with Selfie)' : ''}!',
          ),
        ),
      );
      setState(() {
        _selfieFile = null;
      });
      await _loadAttendanceAndShifts();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(ErpApiClient.formatErrorMessage(e)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submittingCheckin = false;
        });
      }
    }
  }

  /// Marks attendance for one or more employees on `_toolDate` (Employee Attendance Tool).
  /// Tries ERPNext HRMS `mark_employee_attendance` first and falls back to creating
  /// submitted `Attendance` documents for universal compatibility.
  Future<void> _markAttendanceForEmployees(
    List<Map<String, dynamic>> targetEmployees,
    String status,
  ) async {
    if (targetEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one employee to mark attendance.'),
        ),
      );
      return;
    }

    setState(() {
      _markingBulkAttendance = true;
    });

    final UserSession? session = ErpApiClient.instance.session;
    final String dateStr = DateFormat('yyyy-MM-dd').format(_toolDate);
    int successCount = 0;
    String? lastError;

    // First try standard ERPNext HRMS bulk method if marking multiple employees
    bool bulkHandled = false;
    if (targetEmployees.length > 1) {
      try {
        final List<String> empNames = targetEmployees
            .map((Map<String, dynamic> e) => (e['name'] ?? '').toString())
            .where((String s) => s.isNotEmpty)
            .toList();
        await ErpApiClient.instance.callMethod(
          'hrms.hr.doctype.employee_attendance_tool.employee_attendance_tool.mark_employee_attendance',
          data: <String, dynamic>{
            'employee_list': empNames,
            'status': status,
            'date': dateStr,
            if (session != null) 'company': session.company,
            if (_toolShift.isNotEmpty) 'shift': _toolShift,
            'late_entry': _toolLateEntry ? 1 : 0,
            'early_exit': _toolEarlyExit ? 1 : 0,
          },
        );
        bulkHandled = true;
        successCount = empNames.length;
      } catch (_) {
        bulkHandled = false;
      }
    }

    if (!bulkHandled) {
      for (final Map<String, dynamic> emp in targetEmployees) {
        final String empId = (emp['name'] ?? '').toString();
        if (empId.isEmpty) {
          continue;
        }
        try {
          await ErpApiClient.instance.createDoc('Attendance', <String, dynamic>{
            'employee': empId,
            'employee_name': emp['employee_name'],
            'attendance_date': dateStr,
            'status': status,
            'company':
                emp['company'] ?? session?.company ?? 'Drip Irrigation BD Ltd',
            if ((emp['department'] ?? '').toString().isNotEmpty)
              'department': emp['department'],
            if (_toolShift.isNotEmpty) 'shift': _toolShift,
            'late_entry': _toolLateEntry ? 1 : 0,
            'early_exit': _toolEarlyExit ? 1 : 0,
            'docstatus': 1,
          });
          successCount++;
        } catch (e) {
          // Retry without docstatus=1 if user only has draft creation permission
          try {
            await ErpApiClient.instance.createDoc(
              'Attendance',
              <String, dynamic>{
                'employee': empId,
                'employee_name': emp['employee_name'],
                'attendance_date': dateStr,
                'status': status,
                'company':
                    emp['company'] ??
                    session?.company ??
                    'Drip Irrigation BD Ltd',
                if (_toolShift.isNotEmpty) 'shift': _toolShift,
                'late_entry': _toolLateEntry ? 1 : 0,
                'early_exit': _toolEarlyExit ? 1 : 0,
              },
            );
            successCount++;
          } catch (innerErr) {
            lastError = ErpApiClient.formatErrorMessage(innerErr);
          }
        }
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _markingBulkAttendance = false;
      _selectedUnmarkedEmployees.clear();
    });

    if (successCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green.shade700,
          content: Text(
            'Marked $successCount employee(s) as "$status" for $dateStr!',
          ),
        ),
      );
      await _loadAttendanceAndShifts();
    } else if (lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(lastError),
        ),
      );
    }
  }

  Future<void> _showCreateShiftRequestDialog() async {
    final UserSession? session = ErpApiClient.instance.session;
    String selectedShift = _shiftTypes.first;
    DateTime fromDate = DateTime.now();
    DateTime toDate = DateTime.now().add(const Duration(days: 6));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text(
                        'New Shift Request',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ErpDocSheet.showCreate(
                            this.context,
                            doctype: 'Shift Request',
                            onCreated: _loadAttendanceAndShifts,
                          );
                        },
                        icon: const Icon(Icons.tune_rounded, size: 16),
                        label: const Text('All ERP Fields'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedShift,
                    decoration: const InputDecoration(
                      labelText: 'Shift Type',
                      border: OutlineInputBorder(),
                    ),
                    items: _shiftTypes
                        .map(
                          (String s) => DropdownMenuItem<String>(
                            value: s,
                            child: Text(s),
                          ),
                        )
                        .toList(),
                    onChanged: (String? val) {
                      if (val != null) {
                        setModalState(() => selectedShift = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            'From: ${DateFormat('yyyy-MM-dd').format(fromDate)}',
                          ),
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: fromDate,
                              firstDate: DateTime(2024),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setModalState(() => fromDate = picked);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.event, size: 16),
                          label: Text(
                            'To: ${DateFormat('yyyy-MM-dd').format(toDate)}',
                          ),
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: toDate,
                              firstDate: fromDate,
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setModalState(() => toDate = picked);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Submit Shift Request'),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await ErpApiClient.instance.createDoc(
                          'Shift Request',
                          <String, dynamic>{
                            if (session != null &&
                                session.employeeId.isNotEmpty)
                              'employee': session.employeeId,
                            if (session != null) 'company': session.company,
                            'shift_type': selectedShift,
                            'from_date': DateFormat('yyyy-MM-dd')
                                .format(fromDate),
                            'to_date': DateFormat('yyyy-MM-dd').format(toDate),
                          },
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Shift Request created!'),
                            ),
                          );
                        }
                        await _loadAttendanceAndShifts();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(ErpApiClient.formatErrorMessage(e)),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showGeofenceConfigDialog() async {
    double radius = _geofenceRadiusMeters;
    bool enforce = _enforceGeofence;
    double? lat = _officeLat;
    double? lng = _officeLng;

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Geo-Fence Settings'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enforce Office Geo-Fence'),
                    subtitle: const Text(
                      'Require user to be within radius to Check-In',
                    ),
                    value: enforce,
                    onChanged: (bool val) {
                      setDialogState(() => enforce = val);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lat != null && lng != null
                        ? 'Office Pin: ${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}'
                        : 'Office Pin: Not Set',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.my_location, size: 18),
                    label: const Text('Set Current GPS as Office Pin'),
                    onPressed: _currentPosition == null
                        ? null
                        : () {
                            setDialogState(() {
                              lat = _currentPosition!.latitude;
                              lng = _currentPosition!.longitude;
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  Text('Allowed Radius: ${radius.toStringAsFixed(0)} meters'),
                  Slider(
                    value: radius,
                    min: 50,
                    max: 2000,
                    divisions: 39,
                    label: '${radius.toStringAsFixed(0)}m',
                    onChanged: (double v) {
                      setDialogState(() => radius = v);
                    },
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    await _saveGeofenceConfig(
                      lat: lat,
                      lng: lng,
                      radius: radius,
                      enforce: enforce,
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> get _effectiveEmployees {
    if (_employees.isNotEmpty) {
      return _employees;
    }
    final UserSession? session = ErpApiClient.instance.session;
    return <Map<String, dynamic>>[
      <String, dynamic>{
        'name': session?.employeeId.isNotEmpty == true
            ? session!.employeeId
            : 'HR-EMP-00001',
        'employee_name': session?.employeeName.isNotEmpty == true
            ? session!.employeeName
            : (session?.fullName ?? 'Current Employee'),
        'department': session?.department ?? 'Operations - DIBL',
        'designation': session?.designation ?? 'Employee',
        'company': session?.company ?? 'Drip Irrigation BD Ltd',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('HR & Attendance Operations'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Geo-Fence Configuration',
            icon: const Icon(Icons.radar_rounded),
            onPressed: _showGeofenceConfigDialog,
          ),
          IconButton(
            tooltip: 'Refresh Data',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              _acquireLocation();
              _loadAttendanceAndShifts();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const <Widget>[
            Tab(
              icon: Icon(Icons.camera_front_rounded),
              text: 'Check-In / Selfie',
            ),
            Tab(icon: Icon(Icons.fact_check_rounded), text: 'Attendance Tool'),
            Tab(
              icon: Icon(Icons.calendar_month_rounded),
              text: 'Monthly Sheet',
            ),
            Tab(
              icon: Icon(Icons.schedule_send_rounded),
              text: 'Shift Requests',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _buildCheckinTab(colors),
          _buildEmployeeAttendanceToolTab(colors),
          _buildMonthlyAttendanceSheetTab(colors),
          _buildShiftRequestsTab(colors),
        ],
      ),
    );
  }

  Widget _buildCheckinTab(ColorScheme colors) {
    final double? dist = _distanceFromOfficeMeters;
    final bool inside = _isInsideGeofence;

    final List<Map<String, dynamic>> filteredCheckins = _recentCheckins.where((
      Map<String, dynamic> row,
    ) {
      return ErpSearchBar.matchesFilter(
            row,
            _checkinTypeFilter,
            field: 'log_type',
          ) &&
          ErpSearchBar.matchesQuery(row, _checkinQuery);
    }).toList();

    return Column(
      children: <Widget>[
        ErpSearchBar(
          hintText:
              'Search Check-In / Out Logs (employee, time, device, IN/OUT)...',
          query: _checkinQuery,
          onQueryChanged: (String v) => setState(() => _checkinQuery = v),
          onServerSearch: () => ErpDocSheet.showServerSearchDialog(
            context,
            doctype: 'Employee Checkin',
            initialQuery: _checkinQuery,
            onSaved: _loadAttendanceAndShifts,
          ),
          filters: const <String>['All', 'IN', 'OUT'],
          selectedFilter: _checkinTypeFilter,
          onFilterChanged: (String f) => setState(() => _checkinTypeFilter = f),
          resultCount: filteredCheckins.length,
          totalCount: _recentCheckins.length,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await _acquireLocation();
              await _loadAttendanceAndShifts();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                // Geo-fence & GPS Banner Card
                Card(
                  elevation: 0,
                  color: inside
                      ? colors.primaryContainer.withValues(alpha: 0.45)
                      : colors.errorContainer.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              inside
                                  ? Icons.verified_user_rounded
                                  : Icons.warning_amber_rounded,
                              color: inside ? colors.primary : colors.error,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _enforceGeofence
                                    ? (inside
                                          ? 'Inside Office Geo-Fence'
                                          : 'Outside Office Geo-Fence')
                                    : 'GPS Location Ready (Flexible Field Mode)',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (_loadingLocation)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_locationError != null)
                          Text(
                            _locationError!,
                            style: TextStyle(color: colors.error, fontSize: 13),
                          )
                        else if (_currentPosition != null)
                          Text(
                            'Lat: ${_currentPosition!.latitude.toStringAsFixed(5)}  •  Lng: ${_currentPosition!.longitude.toStringAsFixed(5)}'
                            '${dist != null ? '\nDistance from Office Pin: ${dist.toStringAsFixed(0)}m (Max ${_geofenceRadiusMeters.toStringAsFixed(0)}m)' : ''}',
                            style: const TextStyle(fontSize: 13),
                          )
                        else
                          const Text(
                            'Fetching high-accuracy GPS coordinates...',
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Selfie Attendance Card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Text(
                              'Selfie Verification',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _captureSelfie,
                              icon: const Icon(
                                Icons.camera_alt_rounded,
                                size: 18,
                              ),
                              label: Text(
                                _selfieFile == null
                                    ? 'Take Selfie'
                                    : 'Retake Selfie',
                              ),
                            ),
                          ],
                        ),
                        if (_selfieFile != null) ...<Widget>[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.file(
                              File(_selfieFile!.path),
                              height: 190,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ] else
                          Container(
                            height: 110,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHighest.withValues(
                                alpha: 0.45,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: _captureSelfie,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Icon(Icons.face_retouching_natural, size: 36),
                                  SizedBox(height: 6),
                                  Text(
                                    'Tap to capture live selfie for attendance',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.green.shade700,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: _submittingCheckin
                                    ? null
                                    : () => _submitCheckInOrOut('IN'),
                                icon: const Icon(Icons.login_rounded),
                                label: const Text('CHECK IN'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.deepOrange.shade700,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                onPressed: _submittingCheckin
                                    ? null
                                    : () => _submitCheckInOrOut('OUT'),
                                icon: const Icon(Icons.logout_rounded),
                                label: const Text('CHECK OUT'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Recent Check-In / Out Logs (${filteredCheckins.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => ErpDocSheet.showCreate(
                        context,
                        doctype: 'Employee Checkin',
                        onCreated: _loadAttendanceAndShifts,
                      ),
                      icon: const Icon(Icons.add_circle_outline, size: 16),
                      label: const Text('+ Manual Log'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (filteredCheckins.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No matching Employee Checkin logs found.'),
                    ),
                  )
                else
                  ...filteredCheckins.map((Map<String, dynamic> c) {
                    final String docName = (c['name'] ?? '').toString();
                    final String logType = (c['log_type'] ?? 'IN').toString();
                    final bool isIn = logType == 'IN';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: docName.isEmpty
                            ? null
                            : () => ErpDocSheet.showViewAndEdit(
                                context,
                                doctype: 'Employee Checkin',
                                docname: docName,
                                onSaved: _loadAttendanceAndShifts,
                              ),
                        leading: CircleAvatar(
                          backgroundColor: isIn
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.orange.withValues(alpha: 0.15),
                          child: Icon(
                            isIn ? Icons.login_rounded : Icons.logout_rounded,
                            color: isIn
                                ? Colors.green.shade700
                                : Colors.deepOrange,
                          ),
                        ),
                        title: Text(
                          '${c['employee_name'] ?? c['employee'] ?? 'Employee'} • $logType',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${c['time'] ?? ''}\n${c['device_id'] ?? ''}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.edit_note_rounded, size: 20),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// #1. Employee Attendance Tool Tab
  Widget _buildEmployeeAttendanceToolTab(ColorScheme colors) {
    final UserSession? session = ErpApiClient.instance.session;
    final String selectedDateStr = DateFormat('yyyy-MM-dd').format(_toolDate);
    final List<Map<String, dynamic>> allEmps = _effectiveEmployees;

    // Build Department filter options
    final Set<String> deptSet = <String>{'All Departments'};
    if (session != null) {
      deptSet.addAll(session.departments);
    }
    for (final Map<String, dynamic> e in allEmps) {
      final String d = (e['department'] ?? '').toString();
      if (d.isNotEmpty) {
        deptSet.add(d);
      }
    }
    final List<String> deptOptions = deptSet.toList();
    if (!deptOptions.contains(_toolDepartment)) {
      _toolDepartment = 'All Departments';
    }

    // Filter employees by department & search query
    final List<Map<String, dynamic>> deptEmployees = allEmps.where((
      Map<String, dynamic> e,
    ) {
      if (_toolDepartment != 'All Departments' &&
          (e['department'] ?? '').toString() != _toolDepartment) {
        return false;
      }
      return ErpSearchBar.matchesQuery(e, _toolEmployeeQuery);
    }).toList();

    // Find attendance records already marked for selectedDateStr
    final Map<String, Map<String, dynamic>> markedByEmpId =
        <String, Map<String, dynamic>>{};
    for (final Map<String, dynamic> att in _attendanceList) {
      if ((att['attendance_date'] ?? '').toString() == selectedDateStr) {
        final String empId = (att['employee'] ?? '').toString();
        final String empName = (att['employee_name'] ?? '').toString();
        if (empId.isNotEmpty) {
          markedByEmpId[empId] = att;
        } else if (empName.isNotEmpty) {
          markedByEmpId[empName] = att;
        }
      }
    }

    final List<Map<String, dynamic>> unmarkedEmployees =
        <Map<String, dynamic>>[];
    final List<Map<String, dynamic>> markedEmployees = <Map<String, dynamic>>[];

    for (final Map<String, dynamic> emp in deptEmployees) {
      final String empId = (emp['name'] ?? '').toString();
      final String empName = (emp['employee_name'] ?? '').toString();
      if (markedByEmpId.containsKey(empId) ||
          markedByEmpId.containsKey(empName)) {
        final Map<String, dynamic> attRecord =
            markedByEmpId[empId] ?? markedByEmpId[empName]!;
        markedEmployees.add(<String, dynamic>{...emp, 'att': attRecord});
      } else {
        unmarkedEmployees.add(emp);
      }
    }

    return Column(
      children: <Widget>[
        ErpSearchBar(
          hintText:
              'Search Employees in Attendance Tool (name, ID, department)...',
          query: _toolEmployeeQuery,
          onQueryChanged: (String v) => setState(() => _toolEmployeeQuery = v),
          onServerSearch: () => ErpDocSheet.showServerSearchDialog(
            context,
            doctype: 'Employee',
            initialQuery: _toolEmployeeQuery,
            onSaved: _loadAttendanceAndShifts,
          ),
          filters: const <String>['All', 'Unmarked', 'Marked'],
          selectedFilter: _toolEmployeeFilter,
          onFilterChanged: (String f) =>
              setState(() => _toolEmployeeFilter = f),
          resultCount: deptEmployees.length,
          totalCount: allEmps.length,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadAttendanceAndShifts,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    OutlinedButton.icon(
                      icon: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 16,
                      ),
                      label: const Text('+ New Employee'),
                      onPressed: () => ErpDocSheet.showCreate(
                        context,
                        doctype: 'Employee',
                        onCreated: _loadAttendanceAndShifts,
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.add_task_rounded, size: 16),
                      label: const Text('+ New Attendance'),
                      onPressed: () => ErpDocSheet.showCreate(
                        context,
                        doctype: 'Attendance',
                        onCreated: _loadAttendanceAndShifts,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Attendance Tool Control Header Card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.fact_check_rounded,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Employee Attendance Tool',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(selectedDateStr),
                              onPressed: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: _toolDate,
                                  firstDate: DateTime(2023),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  setState(() {
                                    _toolDate = picked;
                                    _selectedUnmarkedEmployees.clear();
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _toolDepartment,
                          decoration: const InputDecoration(
                            labelText: 'Department / Branch Filter',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: deptOptions
                              .map(
                                (String d) => DropdownMenuItem<String>(
                                  value: d,
                                  child: Text(d),
                                ),
                              )
                              .toList(),
                          onChanged: (String? v) {
                            if (v != null) {
                              setState(() {
                                _toolDepartment = v;
                                _selectedUnmarkedEmployees.clear();
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _toolStatus,
                                decoration: const InputDecoration(
                                  labelText: 'Mark Status As',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: _attendanceStatuses
                                    .map(
                                      (String s) => DropdownMenuItem<String>(
                                        value: s,
                                        child: Text(s),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (String? v) {
                                  if (v != null) {
                                    setState(() => _toolStatus = v);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _toolShift,
                                decoration: const InputDecoration(
                                  labelText: 'Shift (Optional)',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: <DropdownMenuItem<String>>[
                                  const DropdownMenuItem<String>(
                                    value: '',
                                    child: Text('Default Shift'),
                                  ),
                                  ..._shiftTypes.map(
                                    (String s) => DropdownMenuItem<String>(
                                      value: s,
                                      child: Text(s),
                                    ),
                                  ),
                                ],
                                onChanged: (String? v) {
                                  setState(() => _toolShift = v ?? '');
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: const Text('Late Entry'),
                                value: _toolLateEntry,
                                onChanged: (bool? v) =>
                                    setState(() => _toolLateEntry = v ?? false),
                              ),
                            ),
                            Expanded(
                              child: CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: const Text('Early Exit'),
                                value: _toolEarlyExit,
                                onChanged: (bool? v) =>
                                    setState(() => _toolEarlyExit = v ?? false),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        FilledButton.icon(
                          onPressed:
                              _markingBulkAttendance ||
                                  _selectedUnmarkedEmployees.isEmpty
                              ? null
                              : () {
                                  final List<Map<String, dynamic>>
                                  chosen = unmarkedEmployees
                                      .where(
                                        (Map<String, dynamic> e) =>
                                            _selectedUnmarkedEmployees.contains(
                                              (e['name'] ?? '').toString(),
                                            ),
                                      )
                                      .toList();
                                  _markAttendanceForEmployees(
                                    chosen,
                                    _toolStatus,
                                  );
                                },
                          icon: _markingBulkAttendance
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.done_all_rounded),
                          label: Text(
                            _markingBulkAttendance
                                ? 'Marking Attendance...'
                                : 'Mark ${_selectedUnmarkedEmployees.length} Selected as $_toolStatus',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Unmarked Employees Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      'Unmarked Employees (${unmarkedEmployees.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (unmarkedEmployees.isNotEmpty)
                      TextButton.icon(
                        icon: Icon(
                          _selectedUnmarkedEmployees.length ==
                                  unmarkedEmployees.length
                              ? Icons.deselect_rounded
                              : Icons.select_all_rounded,
                          size: 18,
                        ),
                        label: Text(
                          _selectedUnmarkedEmployees.length ==
                                  unmarkedEmployees.length
                              ? 'Deselect All'
                              : 'Select All',
                        ),
                        onPressed: () {
                          setState(() {
                            if (_selectedUnmarkedEmployees.length ==
                                unmarkedEmployees.length) {
                              _selectedUnmarkedEmployees.clear();
                            } else {
                              _selectedUnmarkedEmployees.addAll(
                                unmarkedEmployees.map(
                                  (Map<String, dynamic> e) =>
                                      (e['name'] ?? '').toString(),
                                ),
                              );
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                if (unmarkedEmployees.isEmpty)
                  Card(
                    color: Colors.green.withValues(alpha: 0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: <Widget>[
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'All employees in $_toolDepartment are marked for $selectedDateStr!',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...unmarkedEmployees.map((Map<String, dynamic> emp) {
                    final String empId = (emp['name'] ?? '').toString();
                    final bool isSelected = _selectedUnmarkedEmployees.contains(
                      empId,
                    );
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        child: Column(
                          children: <Widget>[
                            CheckboxListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              value: isSelected,
                              onChanged: (bool? checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedUnmarkedEmployees.add(empId);
                                  } else {
                                    _selectedUnmarkedEmployees.remove(empId);
                                  }
                                });
                              },
                              title: Text(
                                '${emp['employee_name'] ?? empId}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '$empId • ${emp['department'] ?? 'No Dept'}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              secondary: IconButton(
                                tooltip: 'View / Edit Employee Profile',
                                icon: const Icon(
                                  Icons.edit_note_rounded,
                                  size: 20,
                                ),
                                onPressed: () => ErpDocSheet.showViewAndEdit(
                                  context,
                                  doctype: 'Employee',
                                  docname: empId,
                                  onSaved: _loadAttendanceAndShifts,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 12,
                                right: 8,
                                bottom: 4,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: <Widget>[
                                  const Text(
                                    'Quick 1-Tap:',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _buildQuickMarkChip(
                                    emp,
                                    'Present',
                                    'P',
                                    Colors.green,
                                  ),
                                  const SizedBox(width: 6),
                                  _buildQuickMarkChip(
                                    emp,
                                    'Absent',
                                    'A',
                                    Colors.red,
                                  ),
                                  const SizedBox(width: 6),
                                  _buildQuickMarkChip(
                                    emp,
                                    'On Leave',
                                    'L',
                                    Colors.blue,
                                  ),
                                  const SizedBox(width: 6),
                                  _buildQuickMarkChip(
                                    emp,
                                    'Half Day',
                                    'HD',
                                    Colors.orange,
                                  ),
                                  const SizedBox(width: 6),
                                  _buildQuickMarkChip(
                                    emp,
                                    'Work From Home',
                                    'WFH',
                                    Colors.teal,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 18),
                Text(
                  'Marked on $selectedDateStr (${markedEmployees.length})',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (markedEmployees.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No attendance marked yet for this date.'),
                    ),
                  )
                else
                  ...markedEmployees.map((Map<String, dynamic> item) {
                    final Map<String, dynamic> att =
                        item['att'] as Map<String, dynamic>;
                    final String attDocName = (att['name'] ?? '').toString();
                    final String status = (att['status'] ?? 'Present')
                        .toString();
                    final Color badgeColor = _statusColor(status);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: attDocName.isEmpty
                            ? null
                            : () => ErpDocSheet.showViewAndEdit(
                                context,
                                doctype: 'Attendance',
                                docname: attDocName,
                                onSaved: _loadAttendanceAndShifts,
                              ),
                        leading: CircleAvatar(
                          backgroundColor: badgeColor.withValues(alpha: 0.15),
                          child: Text(
                            _statusShortCode(status),
                            style: TextStyle(
                              color: badgeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(
                          '${item['employee_name'] ?? att['employee_name'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${item['name']} • ${item['department'] ?? att['department'] ?? ''}',
                        ),
                        trailing: Chip(
                          label: Text(
                            status,
                            style: TextStyle(
                              color: badgeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickMarkChip(
    Map<String, dynamic> emp,
    String status,
    String shortLabel,
    Color color,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: _markingBulkAttendance
          ? null
          : () => _markAttendanceForEmployees(<Map<String, dynamic>>[
              emp,
            ], status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          shortLabel,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  /// #2. Monthly Attendance Sheet Tab
  Widget _buildMonthlyAttendanceSheetTab(ColorScheme colors) {
    if (_loadingHistory && _attendanceList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final int daysInMonth = DateUtils.getDaysInMonth(_sheetYear, _sheetMonth);
    final String monthPrefix =
        '$_sheetYear-${_sheetMonth.toString().padLeft(2, '0')}';

    // Build Employee Filter options
    final List<Map<String, dynamic>> allEmps = _effectiveEmployees;
    final List<String> empFilterOptions = <String>[
      'All Employees',
      ...allEmps.map(
        (Map<String, dynamic> e) =>
            '${e['name']} - ${e['employee_name'] ?? e['name']}',
      ),
    ];
    if (!empFilterOptions.contains(_sheetEmployeeFilter)) {
      _sheetEmployeeFilter = 'All Employees';
    }

    final String? selectedEmpId = _sheetEmployeeFilter == 'All Employees'
        ? null
        : _sheetEmployeeFilter.split(' - ').first;

    // Filter attendance list for selected month, employee, status & search query
    final List<Map<String, dynamic>> monthRecords = _attendanceList.where((
      Map<String, dynamic> a,
    ) {
      final String d = (a['attendance_date'] ?? '').toString();
      if (!d.startsWith(monthPrefix)) {
        return false;
      }
      if (selectedEmpId != null && selectedEmpId.isNotEmpty) {
        final String recEmp = (a['employee'] ?? '').toString();
        final String recName = (a['employee_name'] ?? '').toString();
        if (recEmp != selectedEmpId &&
            !_sheetEmployeeFilter.contains(recName)) {
          return false;
        }
      }
      return ErpSearchBar.matchesFilter(a, _sheetStatusFilter) &&
          ErpSearchBar.matchesQuery(a, _sheetSearchQuery);
    }).toList();

    final int presentCount = monthRecords
        .where((Map<String, dynamic> a) => a['status'] == 'Present')
        .length;
    final int leaveCount = monthRecords
        .where((Map<String, dynamic> a) => a['status'] == 'On Leave')
        .length;
    final int absentCount = monthRecords
        .where((Map<String, dynamic> a) => a['status'] == 'Absent')
        .length;
    final int halfDayCount = monthRecords
        .where(
          (Map<String, dynamic> a) =>
              a['status'] == 'Half Day' || a['status'] == 'Work From Home',
        )
        .length;

    // Group monthly records by Employee for the Monthly Attendance Matrix
    final List<Map<String, dynamic>> matrixEmployees =
        (selectedEmpId == null
                ? allEmps
                : allEmps
                      .where(
                        (Map<String, dynamic> e) => e['name'] == selectedEmpId,
                      )
                      .toList())
            .where(
              (Map<String, dynamic> e) =>
                  ErpSearchBar.matchesQuery(e, _sheetSearchQuery),
            )
            .toList();

    return Column(
      children: <Widget>[
        ErpSearchBar(
          hintText:
              'Search Monthly Attendance (employee, date, shift, status)...',
          query: _sheetSearchQuery,
          onQueryChanged: (String v) => setState(() => _sheetSearchQuery = v),
          onServerSearch: () => ErpDocSheet.showServerSearchDialog(
            context,
            doctype: 'Attendance',
            initialQuery: _sheetSearchQuery,
            onSaved: _loadAttendanceAndShifts,
          ),
          filters: const <String>[
            'All',
            'Present',
            'Absent',
            'On Leave',
            'Half Day',
            'Work From Home',
          ],
          selectedFilter: _sheetStatusFilter,
          onFilterChanged: (String f) => setState(() => _sheetStatusFilter = f),
          resultCount: monthRecords.length,
          totalCount: _attendanceList.length,
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadAttendanceAndShifts,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                // Month, Year & Employee Selector Card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Text(
                          'Monthly Attendance Sheet Filter',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: _sheetMonth,
                                decoration: const InputDecoration(
                                  labelText: 'Month',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: List<DropdownMenuItem<int>>.generate(
                                  12,
                                  (int i) {
                                    final int m = i + 1;
                                    final String mName = DateFormat('MMMM')
                                        .format(DateTime(2026, m));
                                    return DropdownMenuItem<int>(
                                      value: m,
                                      child: Text(mName),
                                    );
                                  },
                                ),
                                onChanged: (int? v) {
                                  if (v != null) {
                                    setState(() => _sheetMonth = v);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                initialValue: _sheetYear,
                                decoration: const InputDecoration(
                                  labelText: 'Year',
                                  border: OutlineInputBorder(),
                                  isDense: true,
                                ),
                                items: <int>[2024, 2025, 2026, 2027]
                                    .map(
                                      (int y) => DropdownMenuItem<int>(
                                        value: y,
                                        child: Text(y.toString()),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (int? v) {
                                  if (v != null) {
                                    setState(() => _sheetYear = v);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: _sheetEmployeeFilter,
                          decoration: const InputDecoration(
                            labelText: 'Employee',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: empFilterOptions
                              .map(
                                (String s) => DropdownMenuItem<String>(
                                  value: s,
                                  child: Text(
                                    s,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (String? v) {
                            if (v != null) {
                              setState(() => _sheetEmployeeFilter = v);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Summary KPI Badges
                Row(
                  children: <Widget>[
                    _buildStatBadge(
                      'Present',
                      presentCount.toString(),
                      Colors.green,
                    ),
                    const SizedBox(width: 8),
                    _buildStatBadge(
                      'On Leave',
                      leaveCount.toString(),
                      Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    _buildStatBadge(
                      'Absent',
                      absentCount.toString(),
                      Colors.red,
                    ),
                    const SizedBox(width: 8),
                    _buildStatBadge(
                      'HD / WFH',
                      halfDayCount.toString(),
                      Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Employee Day-by-Day Attendance Matrix Cards
                const Text(
                  'Employee Monthly Attendance Matrix (Days 1–31)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...matrixEmployees.map((Map<String, dynamic> emp) {
                  final String empId = (emp['name'] ?? '').toString();
                  final String empName = (emp['employee_name'] ?? empId)
                      .toString();

                  final Map<int, String> statusByDay = <int, String>{};
                  int empP = 0;
                  int empA = 0;
                  int empL = 0;
                  int empHD = 0;

                  for (final Map<String, dynamic> att in monthRecords) {
                    final String recEmp = (att['employee'] ?? '').toString();
                    final String recName = (att['employee_name'] ?? '')
                        .toString();
                    if (recEmp == empId || recName == empName) {
                      final String dateStr = (att['attendance_date'] ?? '')
                          .toString();
                      final List<String> parts = dateStr.split('-');
                      if (parts.length == 3) {
                        final int? day = int.tryParse(parts[2]);
                        final String st = (att['status'] ?? 'Present')
                            .toString();
                        if (day != null) {
                          statusByDay[day] = st;
                        }
                        if (st == 'Present') {
                          empP++;
                        } else if (st == 'Absent') {
                          empA++;
                        } else if (st == 'On Leave') {
                          empL++;
                        } else {
                          empHD++;
                        }
                      }
                    }
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Expanded(
                                child: InkWell(
                                  onTap: () => ErpDocSheet.showViewAndEdit(
                                    context,
                                    doctype: 'Employee',
                                    docname: empId,
                                    onSaved: _loadAttendanceAndShifts,
                                  ),
                                  child: Text(
                                    '$empName ($empId)',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                'P:$empP  L:$empL  A:$empA  HD:$empHD',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: List<Widget>.generate(daysInMonth, (
                              int idx,
                            ) {
                              final int dayNum = idx + 1;
                              final String? st = statusByDay[dayNum];
                              final Color c = st != null
                                  ? _statusColor(st)
                                  : Colors.grey;
                              final String code = st != null
                                  ? _statusShortCode(st)
                                  : '-';
                              return Container(
                                width: 34,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: st != null
                                      ? c.withValues(alpha: 0.15)
                                      : Colors.grey.withValues(alpha: 0.07),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: st != null
                                        ? c.withValues(alpha: 0.45)
                                        : Colors.grey.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Column(
                                  children: <Widget>[
                                    Text(
                                      dayNum.toString().padLeft(2, '0'),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      code,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: st != null ? c : Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 8),
                const Text(
                  'Daily Attendance Logs',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (monthRecords.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No attendance logs found for the selected month. Use the "Attendance Tool" tab to mark daily attendance.',
                      ),
                    ),
                  )
                else
                  ...monthRecords.map((Map<String, dynamic> row) {
                    final String docName = (row['name'] ?? '').toString();
                    final String status = (row['status'] ?? 'Present')
                        .toString();
                    final Color badgeColor = _statusColor(status);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: docName.isEmpty
                            ? null
                            : () => ErpDocSheet.showViewAndEdit(
                                context,
                                doctype: 'Attendance',
                                docname: docName,
                                onSaved: _loadAttendanceAndShifts,
                              ),
                        leading: CircleAvatar(
                          backgroundColor: badgeColor.withValues(alpha: 0.15),
                          child: Icon(
                            Icons.event_available_rounded,
                            color: badgeColor,
                          ),
                        ),
                        title: Text(
                          '${row['attendance_date'] ?? ''} — ${row['employee_name'] ?? row['employee'] ?? ''}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          'Doc: $docName ${row['shift'] != null ? '• Shift: ${row['shift']}' : ''}',
                        ),
                        trailing: Chip(
                          label: Text(
                            status,
                            style: TextStyle(
                              color: badgeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Present':
        return Colors.green;
      case 'On Leave':
        return Colors.blue;
      case 'Half Day':
        return Colors.orange;
      case 'Work From Home':
        return Colors.teal;
      case 'Absent':
      default:
        return Colors.red;
    }
  }

  String _statusShortCode(String status) {
    switch (status) {
      case 'Present':
        return 'P';
      case 'On Leave':
        return 'L';
      case 'Half Day':
        return 'HD';
      case 'Work From Home':
        return 'WFH';
      case 'Absent':
      default:
        return 'A';
    }
  }

  Widget _buildShiftRequestsTab(ColorScheme colors) {
    final List<Map<String, dynamic>> filteredShifts = _shiftRequests.where((
      Map<String, dynamic> row,
    ) {
      return ErpSearchBar.matchesFilter(row, _shiftStatusFilter) &&
          ErpSearchBar.matchesQuery(row, _shiftQuery);
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateShiftRequestDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Shift Request'),
      ),
      body: Column(
        children: <Widget>[
          ErpSearchBar(
            hintText: 'Search Shift Requests (employee, shift type, dates, status)...',
            query: _shiftQuery,
            onQueryChanged: (String v) => setState(() => _shiftQuery = v),
            onServerSearch: () => ErpDocSheet.showServerSearchDialog(
              context,
              doctype: 'Shift Request',
              initialQuery: _shiftQuery,
              onSaved: _loadAttendanceAndShifts,
            ),
            filters: const <String>[
              'All',
              'Draft',
              'Approved',
              'Rejected',
              'Cancelled',
            ],
            selectedFilter: _shiftStatusFilter,
            onFilterChanged: (String f) =>
                setState(() => _shiftStatusFilter = f),
            resultCount: filteredShifts.length,
            totalCount: _shiftRequests.length,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAttendanceAndShifts,
              child: filteredShifts.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: const <Widget>[
                        Center(
                          child: Text(
                            'No matching Shift Requests found. Tap "+ New Shift Request" to apply.',
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                      itemCount: filteredShifts.length,
                      itemBuilder: (BuildContext context, int idx) {
                        final Map<String, dynamic> s = filteredShifts[idx];
                        final String docName = (s['name'] ?? '').toString();
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            onTap: docName.isEmpty
                                ? null
                                : () => ErpDocSheet.showViewAndEdit(
                                    context,
                                    doctype: 'Shift Request',
                                    docname: docName,
                                    onSaved: _loadAttendanceAndShifts,
                                  ),
                            leading: const Icon(Icons.schedule_send_rounded),
                            title: Text(
                              '${s['shift_type'] ?? 'Shift'} (${s['status'] ?? 'Draft'})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${s['from_date'] ?? ''} → ${s['to_date'] ?? ''} • ${s['employee_name'] ?? ''}',
                            ),
                            trailing: const Icon(
                              Icons.edit_note_rounded,
                              size: 20,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: <Widget>[
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
