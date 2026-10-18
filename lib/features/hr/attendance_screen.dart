import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/models/user_session.dart';
import '../../core/network/api_client.dart';

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

  bool _loadingLocation = false;
  bool _submittingCheckin = false;
  bool _loadingHistory = false;
  Position? _currentPosition;
  String _resolvedAddress = 'Tap "Refresh GPS" to detect your location';
  GeoBranchLocation _selectedBranch = UserSession.defaultBranches.first;
  bool _isFieldSiteMode = false;
  XFile? _selfieFile;

  List<Map<String, dynamic>> _recentCheckins = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _attendanceList = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _shiftRequests = <Map<String, dynamic>>[];
  List<String> _shiftTypes = <String>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
    _fetchLocation();
    _loadAttendanceAndShifts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  double? get _distanceMeters {
    if (_currentPosition == null) {
      return null;
    }
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _selectedBranch.latitude,
      _selectedBranch.longitude,
    );
  }

  bool get _isInsideGeofence {
    if (_isFieldSiteMode) {
      return _currentPosition != null;
    }
    final double? dist = _distanceMeters;
    if (dist == null) {
      return false;
    }
    return dist <= _selectedBranch.radiusMeters;
  }

  Future<void> _fetchLocation() async {
    setState(() {
      _loadingLocation = true;
    });
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable GPS.');
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission is required for Geo-fenced attendance.',
        );
      }

      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final String addr =
          'GPS (${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)})';

      if (mounted) {
        setState(() {
          _currentPosition = pos;
          _resolvedAddress = addr;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _resolvedAddress = ErpApiClient.formatErrorMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingLocation = false;
        });
      }
    }
  }

  Future<void> _captureSelfie() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 75,
        maxWidth: 960,
      );
      if (photo != null && mounted) {
        setState(() {
          _selfieFile = photo;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Camera error: ${ErpApiClient.formatErrorMessage(e)}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _loadAttendanceAndShifts() async {
    setState(() {
      _loadingHistory = true;
    });
    final UserSession? session = ErpApiClient.instance.session;
    final Map<String, dynamic> empFilter =
        (session != null && session.employeeId.isNotEmpty)
        ? <String, dynamic>{'employee': session.employeeId}
        : <String, dynamic>{};

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
            filters: empFilter,
            orderBy: 'time desc',
            limitPageLength: 20,
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
              'attendance_date',
              'status',
              'shift',
              'in_time',
              'out_time',
            ],
            filters: empFilter,
            orderBy: 'attendance_date desc',
            limitPageLength: 40,
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
              'employee_name',
              'shift_type',
              'from_date',
              'to_date',
              'status',
            ],
            filters: empFilter,
            limitPageLength: 25,
          );
      final List<Map<String, dynamic>> shiftTypeDocs = await ErpApiClient
          .instance
          .getList('Shift Type', fields: <String>['name'], limitPageLength: 20);
      if (mounted) {
        setState(() {
          _shiftRequests = shifts;
          _shiftTypes = shiftTypeDocs
              .map((Map<String, dynamic> e) => (e['name'] ?? '').toString())
              .where((String s) => s.isNotEmpty)
              .toList();
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
    final UserSession? session = ErpApiClient.instance.session;
    if (session == null) {
      return;
    }
    if (_currentPosition == null) {
      await _fetchLocation();
      if (_currentPosition == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Unable to acquire GPS coordinates. Enable GPS first.',
              ),
            ),
          );
        }
        return;
      }
    }

    if (!_isInsideGeofence) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Outside Geo-fence (${_distanceMeters?.toStringAsFixed(0)}m away from ${_selectedBranch.name}). Move closer or switch to Field/Site Mode.',
            ),
          ),
        );
      }
      return;
    }

    if (_selfieFile == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please capture a Selfie first to verify attendance.',
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _submittingCheckin = true;
    });

    try {
      final String nowStr = DateFormat('yyyy-MM-dd HH:mm:ss')
          .format(DateTime.now());
      final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      String uploadedSelfieUrl = '';
      if (_selfieFile != null) {
        uploadedSelfieUrl = await ErpApiClient.instance.uploadFile(
          filePath: _selfieFile!.path,
          fileName:
              'selfie_${logType}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      final String locationNote = _isFieldSiteMode
          ? 'Field Site ($_resolvedAddress)'
          : '${_selectedBranch.name} (${_distanceMeters?.toStringAsFixed(0)}m)';

      String createdDocName = '';
      String targetDocType = 'Employee Checkin';

      try {
        final Map<String, dynamic> checkinDoc = await ErpApiClient.instance
            .createDoc('Employee Checkin', <String, dynamic>{
              if (session.employeeId.isNotEmpty) 'employee': session.employeeId,
              'log_type': logType,
              'time': nowStr,
              'latitude': _currentPosition!.latitude,
              'longitude': _currentPosition!.longitude,
              'device_id': locationNote,
            });
        createdDocName = (checkinDoc['name'] ?? '').toString();
      } catch (_) {
        // Fallback directly to Attendance DocType if Employee Checkin is restricted or unconfigured
        targetDocType = 'Attendance';
        final Map<String, dynamic> attDoc = await ErpApiClient.instance
            .createDoc('Attendance', <String, dynamic>{
              if (session.employeeId.isNotEmpty) 'employee': session.employeeId,
              'attendance_date': todayStr,
              'status': 'Present',
              'company': session.company,
            });
        createdDocName = (attDoc['name'] ?? '').toString();
      }

      if (uploadedSelfieUrl.isNotEmpty && createdDocName.isNotEmpty) {
        try {
          await ErpApiClient.instance.uploadFile(
            filePath: _selfieFile!.path,
            fileName:
                'selfie_${logType}_${DateTime.now().millisecondsSinceEpoch}.jpg',
            doctype: targetDocType,
            docname: createdDocName,
          );
        } catch (_) {}
      }

      // If logType == 'IN', also ensure today's Attendance record exists in DIBL
      if (logType == 'IN' &&
          targetDocType == 'Employee Checkin' &&
          session.employeeId.isNotEmpty) {
        try {
          final List<Map<String, dynamic>> existingAtt = await ErpApiClient
              .instance
              .getList(
                'Attendance',
                filters: <String, dynamic>{
                  'employee': session.employeeId,
                  'attendance_date': todayStr,
                },
                limitPageLength: 1,
              );
          if (existingAtt.isEmpty) {
            await ErpApiClient.instance.createDoc(
              'Attendance',
              <String, dynamic>{
                'employee': session.employeeId,
                'attendance_date': todayStr,
                'status': 'Present',
                'company': session.company,
              },
            );
          }
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green.shade700,
            content: Text(
              'Check-$logType recorded with GPS & Selfie ($createdDocName)!',
            ),
          ),
        );
        setState(() {
          _selfieFile = null;
        });
      }
      await _loadAttendanceAndShifts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text(ErpApiClient.formatErrorMessage(e)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _submittingCheckin = false;
        });
      }
    }
  }

  Future<void> _showCreateShiftRequestDialog() async {
    final UserSession? session = ErpApiClient.instance.session;
    String selectedShift = _shiftTypes.isNotEmpty
        ? _shiftTypes.first
        : 'Day Shift';
    final TextEditingController shiftCtrl = TextEditingController(
      text: selectedShift,
    );
    DateTime fromDate = DateTime.now();
    DateTime toDate = DateTime.now().add(const Duration(days: 7));

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
                  const Text(
                    'New Shift Request',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (_shiftTypes.isNotEmpty)
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
                      onChanged: (String? v) {
                        if (v != null) {
                          setModalState(() {
                            selectedShift = v;
                            shiftCtrl.text = v;
                          });
                        }
                      },
                    )
                  else
                    TextField(
                      controller: shiftCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Shift Type Name',
                        border: OutlineInputBorder(),
                      ),
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
                  const SizedBox(height: 16),
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
                            'shift_type': shiftCtrl.text.trim(),
                            'from_date': DateFormat('yyyy-MM-dd')
                                .format(fromDate),
                            'to_date': DateFormat('yyyy-MM-dd').format(toDate),
                          },
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Shift Request submitted!'),
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

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('HR & Geo-Fenced Attendance'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const <Widget>[
            Tab(icon: Icon(Icons.pin_drop_rounded), text: 'Check-In / Selfie'),
            Tab(icon: Icon(Icons.calendar_month_rounded), text: 'Attendance'),
            Tab(icon: Icon(Icons.schedule_rounded), text: 'Shift Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: <Widget>[
          _buildGeofenceCheckinTab(colors),
          _buildAttendanceSheetTab(colors),
          _buildShiftRequestsTab(colors),
        ],
      ),
    );
  }

  Widget _buildGeofenceCheckinTab(ColorScheme colors) {
    final double? dist = _distanceMeters;
    final bool allowed = _isInsideGeofence;

    return RefreshIndicator(
      onRefresh: () async {
        await _fetchLocation();
        await _loadAttendanceAndShifts();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            elevation: 0,
            color: colors.primaryContainer.withValues(alpha: 0.45),
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
                      Icon(Icons.my_location_rounded, color: colors.primary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Geo-Fence & Location Verification',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh GPS',
                        onPressed: _loadingLocation ? null : _fetchLocation,
                        icon: _loadingLocation
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: const <ButtonSegment<bool>>[
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('Office / Branch Zone'),
                        icon: Icon(Icons.apartment_rounded),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Field / Project Site'),
                        icon: Icon(Icons.engineering_rounded),
                      ),
                    ],
                    selected: <bool>{_isFieldSiteMode},
                    onSelectionChanged: (Set<bool> s) {
                      setState(() {
                        _isFieldSiteMode = s.first;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (!_isFieldSiteMode)
                    DropdownButtonFormField<GeoBranchLocation>(
                      initialValue: _selectedBranch,
                      decoration: const InputDecoration(
                        labelText: 'Select Office / Branch Geo-Fence',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: UserSession.defaultBranches
                          .map(
                            (GeoBranchLocation b) =>
                                DropdownMenuItem<GeoBranchLocation>(
                                  value: b,
                                  child: Text(
                                    '${b.name} (${b.radiusMeters.toInt()}m)',
                                  ),
                                ),
                          )
                          .toList(),
                      onChanged: (GeoBranchLocation? val) {
                        if (val != null) {
                          setState(() => _selectedBranch = val);
                        }
                      },
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Icon(
                        allowed
                            ? Icons.check_circle_rounded
                            : Icons.warning_amber_rounded,
                        color: allowed ? Colors.green.shade700 : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _currentPosition == null
                              ? _resolvedAddress
                              : _isFieldSiteMode
                              ? 'Field Site Active: $_resolvedAddress'
                              : '${dist?.toStringAsFixed(0)}m from ${_selectedBranch.name} • $_resolvedAddress',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: colors.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'Step 2: Selfie Attendance Verification',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  if (_selfieFile != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(
                        File(_selfieFile!.path),
                        height: 190,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      height: 130,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.camera_front_rounded,
                            size: 40,
                            color: colors.primary,
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Take a live front-camera selfie to unlock Check-In/Out',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _captureSelfie,
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: Text(
                      _selfieFile == null
                          ? 'Capture Front Selfie'
                          : 'Retake Selfie Photo',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
          const Text(
            'Recent Check-In / Out Logs',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_recentCheckins.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No recent Employee Checkin logs found.'),
              ),
            )
          else
            ..._recentCheckins.map((Map<String, dynamic> c) {
              final String logType = (c['log_type'] ?? 'IN').toString();
              final bool isIn = logType == 'IN';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isIn
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    child: Icon(
                      isIn ? Icons.login_rounded : Icons.logout_rounded,
                      color: isIn ? Colors.green.shade700 : Colors.deepOrange,
                    ),
                  ),
                  title: Text(
                    '${c['employee_name'] ?? c['employee'] ?? 'Employee'} • $logType',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${c['time'] ?? ''}\n${c['device_id'] ?? ''}'),
                  isThreeLine: true,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildAttendanceSheetTab(ColorScheme colors) {
    if (_loadingHistory && _attendanceList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final int presentCount = _attendanceList
        .where((Map<String, dynamic> a) => a['status'] == 'Present')
        .length;
    final int leaveCount = _attendanceList
        .where((Map<String, dynamic> a) => a['status'] == 'On Leave')
        .length;
    final int absentCount = _attendanceList
        .where((Map<String, dynamic> a) => a['status'] == 'Absent')
        .length;

    return RefreshIndicator(
      onRefresh: _loadAttendanceAndShifts,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Row(
            children: <Widget>[
              _buildStatBadge('Present', presentCount.toString(), Colors.green),
              const SizedBox(width: 8),
              _buildStatBadge('On Leave', leaveCount.toString(), Colors.blue),
              const SizedBox(width: 8),
              _buildStatBadge('Absent', absentCount.toString(), Colors.red),
            ],
          ),
          const SizedBox(height: 14),
          ..._attendanceList.map((Map<String, dynamic> row) {
            final String status = (row['status'] ?? 'Present').toString();
            final Color badgeColor = status == 'Present'
                ? Colors.green
                : status == 'On Leave'
                ? Colors.blue
                : Colors.red;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: badgeColor.withValues(alpha: 0.15),
                  child: Icon(Icons.event_available_rounded, color: badgeColor),
                ),
                title: Text(
                  '${row['attendance_date'] ?? ''} — ${row['employee_name'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Doc: ${row['name']} ${row['shift'] != null ? '• Shift: ${row['shift']}' : ''}',
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
    );
  }

  Widget _buildShiftRequestsTab(ColorScheme colors) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateShiftRequestDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Shift Request'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAttendanceAndShifts,
        child: _shiftRequests.isEmpty
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: const <Widget>[
                  Center(
                    child: Text(
                      'No Shift Requests found. Tap "+ New Shift Request" to apply.',
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _shiftRequests.length,
                itemBuilder: (BuildContext context, int idx) {
                  final Map<String, dynamic> s = _shiftRequests[idx];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.schedule_send_rounded),
                      title: Text(
                        '${s['shift_type'] ?? 'Shift'} (${s['status'] ?? 'Draft'})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${s['from_date'] ?? ''} → ${s['to_date'] ?? ''} • ${s['employee_name'] ?? ''}',
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
