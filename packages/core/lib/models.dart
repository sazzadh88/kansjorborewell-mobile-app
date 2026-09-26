int _parseInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value) ?? (double.tryParse(value)?.toInt() ?? fallback);
  }
  return fallback;
}

double _parseDouble(dynamic value, [double fallback = 0.0]) {
  if (value == null) return fallback;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value) ?? fallback;
  }
  return fallback;
}

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.mobile,
    required this.role,
    this.permissions = const {},
  });

  final int id;
  final String name;
  final String mobile;
  final String role;
  final Set<String> permissions;

  bool get isAdmin => role == 'admin';

  bool hasPermission(String permission) =>
      isAdmin || permissions.contains(permission);

  factory UserModel.fromJson(
    Map<String, dynamic> json, {
    List<dynamic> permissions = const [],
  }) => UserModel(
    id: _parseInt(json['id']),
    name: json['name']?.toString() ?? 'User',
    mobile: json['mobile']?.toString() ?? '',
    role: json['role'] is Map
        ? ((json['role'] as Map)['name']?.toString() ?? 'operator')
        : (json['role']?.toString() ?? 'operator'),
    permissions: permissions.map((item) => item.toString()).toSet(),
  );
}

class PermissionModel {
  const PermissionModel({
    required this.id,
    required this.name,
    required this.label,
    required this.group,
  });

  final int id;
  final String name;
  final String label;
  final String group;

  factory PermissionModel.fromJson(Map<String, dynamic> json) =>
      PermissionModel(
        id: _parseInt(json['id']),
        name: json['name']?.toString() ?? '',
        label: json['label']?.toString() ?? json['name']?.toString() ?? '',
        group: json['group']?.toString() ?? 'General',
      );
}

class RoleModel {
  const RoleModel({
    required this.id,
    required this.name,
    required this.permissions,
    this.usersCount = 0,
  });

  final int id;
  final String name;
  final Set<String> permissions;
  final int usersCount;

  factory RoleModel.fromJson(Map<String, dynamic> json) => RoleModel(
    id: _parseInt(json['id']),
    name: json['name']?.toString() ?? '',
    permissions: ((json['permissions'] as List?) ?? const [])
        .map((item) => (item is Map ? item['name'] : item)?.toString() ?? '')
        .toSet(),
    usersCount: _parseInt(json['users_count']),
  );
}

class BrickTypeModel {
  const BrickTypeModel({
    required this.id,
    required this.name,
    required this.code,
    required this.currentStock,
    required this.reorderLevel,
    required this.isPaver,
    this.size,
  });

  final int id;
  final String name;
  final String code;
  final int currentStock;
  final int reorderLevel;
  final bool isPaver;
  final String? size;

  factory BrickTypeModel.fromJson(Map<String, dynamic> json) => BrickTypeModel(
    id: _parseInt(json['id']),
    name: json['name']?.toString() ?? 'Brick',
    code: json['code']?.toString() ?? '',
    currentStock: _parseInt(json['current_stock']),
    reorderLevel: _parseInt(json['reorder_level']),
    isPaver: json['is_paver'] as bool? ?? false,
    size: json['size']?.toString(),
  );
}

class DesignModel {
  const DesignModel({
    required this.id,
    required this.name,
    required this.size,
    required this.colors,
    required this.isActive,
  });

  final int id;
  final String name;
  final String size;
  final List<String> colors;
  final bool isActive;

  String get label => '$name ($size)';

  factory DesignModel.fromJson(Map<String, dynamic> json) => DesignModel(
    id: _parseInt(json['id']),
    name: json['name']?.toString() ?? 'Design',
    size: json['size']?.toString() ?? '',
    colors: ((json['colors'] as List?) ?? const []).map((c) => c.toString()).toList(),
    isActive: json['is_active'] as bool? ?? true,
  );
}

class MachineModel {
  const MachineModel({
    required this.id,
    required this.name,
    required this.code,
    required this.isActive,
  });

  final int id;
  final String name;
  final String code;
  final bool isActive;

  factory MachineModel.fromJson(Map<String, dynamic> json) => MachineModel(
    id: _parseInt(json['id']),
    name: json['name']?.toString() ?? 'Machine',
    code: json['code']?.toString() ?? '',
    isActive: json['is_active'] as bool? ?? true,
  );
}

class RawMaterialModel {
  const RawMaterialModel({
    required this.id,
    required this.name,
    required this.unit,
    required this.currentStock,
    required this.reorderLevel,
    required this.isActive,
  });

  final int id;
  final String name;
  final String unit;
  final double currentStock;
  final double reorderLevel;
  final bool isActive;

  bool get isLowStock => currentStock <= reorderLevel;

  factory RawMaterialModel.fromJson(Map<String, dynamic> json) =>
      RawMaterialModel(
        id: _parseInt(json['id']),
        name: json['name']?.toString() ?? 'Material',
        unit: json['unit']?.toString() ?? 'unit',
        currentStock: _parseDouble(json['current_stock']),
        reorderLevel: _parseDouble(json['reorder_level']),
        isActive: json['is_active'] as bool? ?? true,
      );
}

class InventoryTransactionModel {
  const InventoryTransactionModel({
    required this.id,
    required this.date,
    required this.material,
    required this.unit,
    required this.type,
    required this.quantity,
    this.createdAt,
    this.remarks,
  });

  final int id;
  final String date;
  final String material;
  final String unit;
  final String type;
  final double quantity;
  final String? createdAt;
  final String? remarks;

  bool get isOut => type == 'out';

  /// Returns formatted human-readable date & time (e.g., "21 Aug 2026, 03:24 PM")
  String get formattedDateTime {
    final raw = (createdAt != null && createdAt!.isNotEmpty) ? createdAt! : date;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return date;
    final local = parsed.isUtc ? parsed.toLocal() : parsed;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month - 1];
    final year = local.year;
    
    // Format 12-hour time with AM/PM if time information exists
    final hasTime = raw.contains('T') || raw.contains(':');
    if (!hasTime) {
      return '$day $month $year';
    }
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$day $month $year, ${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  factory InventoryTransactionModel.fromJson(Map<String, dynamic> json) {
    final material = json['raw_material'] as Map?;
    return InventoryTransactionModel(
      id: _parseInt(json['id']),
      date: json['transaction_date']?.toString() ?? '',
      material: material?['name']?.toString() ?? 'Material',
      unit: material?['unit']?.toString() ?? 'unit',
      type: json['type']?.toString() ?? '',
      quantity: _parseDouble(json['quantity']),
      createdAt: json['created_at']?.toString(),
      remarks: json['remarks']?.toString(),
    );
  }
}

class PaginatedInventory {
  const PaginatedInventory({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<InventoryTransactionModel> items;
  final int currentPage;
  final int lastPage;
  final int total;
}

class ProductionRecord {
  const ProductionRecord({
    required this.id,
    required this.date,
    required this.machineId,
    required this.brickTypeId,
    required this.machine,
    required this.product,
    required this.quantity,
    this.designId,
    this.design,
    this.remarks,
  });

  final int id;
  final String date;
  final int machineId;
  final int brickTypeId;
  final String machine;
  final String product;
  final int quantity;
  final int? designId;
  final String? design;
  final String? remarks;

  factory ProductionRecord.fromJson(Map<String, dynamic> json) =>
      ProductionRecord(
        id: _parseInt(json['id']),
        date: json['production_date']?.toString() ?? '',
        machineId: _parseInt((json['machine'] as Map?)?['id']),
        brickTypeId: _parseInt((json['brick_type'] as Map?)?['id']),
        machine: (json['machine'] as Map?)?['name']?.toString() ?? 'Machine',
        product: (json['brick_type'] as Map?)?['name']?.toString() ?? 'Product',
        quantity: _parseInt(json['quantity_produced']),
        designId: json['design'] != null
            ? _parseInt((json['design'] as Map?)?['id'])
            : null,
        design: (json['design'] as Map?)?['name']?.toString(),
        remarks: json['remarks']?.toString(),
      );
}

class DispatchItemModel {
  const DispatchItemModel({
    required this.brickTypeId,
    required this.product,
    required this.quantity,
    this.designId,
    this.design,
    this.currentStock,
  });

  final int brickTypeId;
  final String product;
  final int quantity;
  final int? designId;
  final String? design;
  final int? currentStock;

  factory DispatchItemModel.fromJson(Map<String, dynamic> json) {
    final brick = json['brick_type'] as Map?;
    return DispatchItemModel(
      brickTypeId: _parseInt(json['brick_type_id'] ?? brick?['id']),
      product: brick?['name']?.toString() ?? 'Product',
      quantity: _parseInt(json['quantity']),
      designId: json['design_id'] != null
          ? _parseInt(json['design_id'])
          : ((json['design'] as Map?)?['id'] != null
                ? _parseInt((json['design'] as Map?)?['id'])
                : null),
      design: (json['design'] as Map?)?['name']?.toString(),
      currentStock: brick?['current_stock'] != null
          ? _parseInt(brick?['current_stock'])
          : null,
    );
  }
}

class DispatchRecord {
  const DispatchRecord({
    required this.id,
    required this.date,
    required this.brickTypeId,
    required this.partyId,
    required this.vehicleId,
    required this.driverId,
    required this.product,
    required this.party,
    required this.vehicle,
    required this.quantity,
    this.items = const [],
    this.designId,
    this.design,
    this.driver,
    this.freightAmount,
    this.allocPaid = 0,
    this.paymentStatus = 'due',
    this.paidAmount = 0,
    this.paymentMode,
    this.gstRate = 18,
    this.remarks,
  });

  final int id;
  final String date;
  final int brickTypeId;
  final int partyId;
  final int vehicleId;
  final int? driverId;
  final String product;
  final String party;
  final String vehicle;
  final int quantity;
  final int? designId;
  final String? design;
  final String? driver;
  final double? freightAmount;
  final double allocPaid;
  final String paymentStatus;
  final double paidAmount;
  final String? paymentMode;
  final double gstRate;
  final String? remarks;

  final List<DispatchItemModel> items;

  int get totalQuantity =>
      items.isEmpty ? quantity : items.fold(0, (s, i) => s + i.quantity);

  String get itemsSummary => items.isEmpty
      ? '$product × $quantity'
      : items.map((i) => '${i.product} × ${i.quantity}').join(', ');

  double get dueAmount => (freightAmount ?? 0) - paidAmount;
  bool get isPaid => paymentStatus == 'paid';

  /// Allocation-aware status: receipts (incl. collected on delivery) count.
  String get collectionStatus {
    final freight = freightAmount ?? 0;
    if (allocPaid >= freight) return 'paid';
    if (allocPaid > 0) return 'partial';
    return 'due';
  }

  bool get isFullyPaid => collectionStatus == 'paid';

  factory DispatchRecord.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    return DispatchRecord(
    id: _parseInt(json['id']),
    date: json['dispatch_date']?.toString() ?? '',
    brickTypeId: _parseInt((json['brick_type'] as Map?)?['id']),
    partyId: _parseInt((json['party'] as Map?)?['id']),
    vehicleId: _parseInt((json['vehicle'] as Map?)?['id']),
    driverId: json['driver_id'] != null
        ? _parseInt(json['driver_id'])
        : ((json['driver'] as Map?)?['id'] != null
              ? _parseInt((json['driver'] as Map?)?['id'])
              : null),
    product: (json['brick_type'] as Map?)?['name']?.toString() ?? 'Product',
    party: (json['party'] as Map?)?['name']?.toString() ?? 'Party',
    vehicle:
        (json['vehicle'] as Map?)?['registration_number']?.toString() ??
        'Vehicle',
    quantity: _parseInt(json['quantity_loaded']),
    designId: json['design'] != null
        ? _parseInt((json['design'] as Map?)?['id'])
        : null,
    items: rawItems
        .map((e) => DispatchItemModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    design: (json['design'] as Map?)?['name']?.toString(),
    driver: (json['driver'] as Map?)?['name']?.toString(),
    freightAmount: json['freight_amount'] != null
        ? _parseDouble(json['freight_amount'])
        : null,
    allocPaid: _parseDouble(json['alloc_paid'] ?? json['paid_amount']),
    paymentStatus: json['payment_status']?.toString() ?? 'due',
    paidAmount: _parseDouble(json['paid_amount']),
    paymentMode: json['payment_mode']?.toString(),
    gstRate: _parseDouble(json['gst_rate'], 18),
    remarks: json['remarks']?.toString(),
  );
  }
}

class PaginatedProduction {
  const PaginatedProduction({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<ProductionRecord> items;
  final int currentPage;
  final int lastPage;
  final int total;
}

class PaginatedDispatch {
  const PaginatedDispatch({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<DispatchRecord> items;
  final int currentPage;
  final int lastPage;
  final int total;
}

class DashboardSummary {
  const DashboardSummary({
    required this.date,
    required this.productionQty,
    required this.saleQty,
    required this.brickTypes,
  });

  final String date;
  final int productionQty;
  final int saleQty;
  final List<BrickTypeModel> brickTypes;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) =>
      DashboardSummary(
        date: json['date']?.toString() ?? '',
        productionQty: _parseInt(json['production_qty']),
        saleQty: _parseInt(json['sale_qty']),
        brickTypes: ((json['brick_types'] as List?) ?? const [])
            .map(
              (item) => BrickTypeModel.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .toList(),
      );
}

class GstReport {
  const GstReport({
    required this.from,
    required this.to,
    required this.rows,
    required this.taxableAmount,
    required this.gstAmount,
    required this.totalAmount,
  });

  final String from;
  final String to;
  final List<GstRow> rows;
  final double taxableAmount;
  final double gstAmount;
  final double totalAmount;

  factory GstReport.fromJson(Map<String, dynamic> json) {
    final totals = Map<String, dynamic>.from(json['totals'] as Map? ?? {});
    return GstReport(
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      rows: ((json['rows'] as List?) ?? const [])
          .map((item) => GstRow.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      taxableAmount: _parseDouble(totals['taxable_amount']),
      gstAmount: _parseDouble(totals['gst_amount']),
      totalAmount: _parseDouble(totals['total_amount']),
    );
  }
}

class GstRow {
  const GstRow({
    required this.partyId,
    required this.party,
    required this.taxableAmount,
    required this.gstRate,
    required this.gstAmount,
    required this.totalAmount,
    required this.dispatches,
  });

  final int partyId;
  final String party;
  final double taxableAmount;
  final double gstRate;
  final double gstAmount;
  final double totalAmount;
  final int dispatches;

  factory GstRow.fromJson(Map<String, dynamic> json) => GstRow(
    partyId: _parseInt(json['party_id']),
    party: json['party']?.toString() ?? 'Unknown',
    taxableAmount: _parseDouble(json['taxable_amount']),
    gstRate: _parseDouble(json['gst_rate']),
    gstAmount: _parseDouble(json['gst_amount']),
    totalAmount: _parseDouble(json['total_amount']),
    dispatches: _parseInt(json['dispatches']),
  );
}

class DispatchDues {
  const DispatchDues({
    required this.parties,
    required this.freightAmount,
    required this.paidAmount,
    required this.dueAmount,
    this.openingDue = 0,
  });

  final List<DispatchDueRow> parties;
  final double freightAmount;
  final double paidAmount;
  final double dueAmount;
  final double openingDue;

  factory DispatchDues.fromJson(Map<String, dynamic> json) {
    final totals = Map<String, dynamic>.from(json['totals'] as Map? ?? {});
    return DispatchDues(
      parties: ((json['parties'] as List?) ?? const [])
          .map((item) => DispatchDueRow.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      freightAmount: _parseDouble(totals['freight_amount']),
      paidAmount: _parseDouble(totals['paid_amount']),
      dueAmount: _parseDouble(totals['due_amount']),
      openingDue: _parseDouble(totals['opening_due']),
    );
  }
}

class DispatchDueRow {
  const DispatchDueRow({
    required this.partyId,
    required this.party,
    required this.freightAmount,
    required this.paidAmount,
    required this.dueAmount,
    required this.dispatches,
    this.openingDue = 0,
  });

  final int partyId;
  final String party;
  final double freightAmount;
  final double paidAmount;
  final double dueAmount;
  final int dispatches;
  final double openingDue;

  factory DispatchDueRow.fromJson(Map<String, dynamic> json) => DispatchDueRow(
    partyId: _parseInt(json['party_id']),
    party: json['party']?.toString() ?? 'Unknown',
    freightAmount: _parseDouble(json['freight_amount']),
    paidAmount: _parseDouble(json['paid_amount']),
    dueAmount: _parseDouble(json['due_amount']),
    dispatches: _parseInt(json['dispatches']),
    openingDue: _parseDouble(json['opening_due']),
  );
}

class StrikingGroupRecord {
  const StrikingGroupRecord({
    required this.id,
    required this.date,
    required this.groupName,
    required this.brickTypeId,
    required this.product,
    required this.quantity,
    this.remarks,
    this.createdAt,
  });

  final int id;
  final String date;
  final String groupName;
  final int brickTypeId;
  final String product;
  final int quantity;
  final String? remarks;
  final String? createdAt;

  String get formattedDateTime {
    final raw = (createdAt != null && createdAt!.isNotEmpty) ? createdAt! : date;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return date;
    final local = parsed.isUtc ? parsed.toLocal() : parsed;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month - 1];
    final year = local.year;
    
    final hasTime = raw.contains('T') || raw.contains(':');
    if (!hasTime) {
      return '$day $month $year';
    }
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$day $month $year, ${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  factory StrikingGroupRecord.fromJson(Map<String, dynamic> json) =>
      StrikingGroupRecord(
        id: _parseInt(json['id']),
        date: json['entry_date']?.toString() ?? '',
        groupName: json['group_name']?.toString() ?? '',
        brickTypeId: _parseInt(
          (json['brick_type'] as Map?)?['id'] ?? json['brick_type_id'],
        ),
        product:
            (json['brick_type'] as Map?)?['name']?.toString() ?? 'Product',
        quantity: _parseInt(json['quantity']),
        remarks: json['remarks']?.toString(),
        createdAt: json['created_at']?.toString(),
      );
}

class LoadingGroupRecord {
  const LoadingGroupRecord({
    required this.id,
    required this.date,
    required this.groupName,
    required this.brickTypeId,
    required this.product,
    required this.quantity,
    this.remarks,
    this.createdAt,
  });

  final int id;
  final String date;
  final String groupName;
  final int brickTypeId;
  final String product;
  final int quantity;
  final String? remarks;
  final String? createdAt;

  String get formattedDateTime {
    final raw = (createdAt != null && createdAt!.isNotEmpty) ? createdAt! : date;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return date;
    final local = parsed.isUtc ? parsed.toLocal() : parsed;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month - 1];
    final year = local.year;
    
    final hasTime = raw.contains('T') || raw.contains(':');
    if (!hasTime) {
      return '$day $month $year';
    }
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$day $month $year, ${hour.toString().padLeft(2, '0')}:$minute $period';
  }

  factory LoadingGroupRecord.fromJson(Map<String, dynamic> json) =>
      LoadingGroupRecord(
        id: _parseInt(json['id']),
        date: json['entry_date']?.toString() ?? '',
        groupName: json['group_name']?.toString() ?? '',
        brickTypeId: _parseInt(
          (json['brick_type'] as Map?)?['id'] ?? json['brick_type_id'],
        ),
        product:
            (json['brick_type'] as Map?)?['name']?.toString() ?? 'Product',
        quantity: _parseInt(json['quantity']),
        remarks: json['remarks']?.toString(),
        createdAt: json['created_at']?.toString(),
      );
}

class PaginatedStrikingGroups {
  const PaginatedStrikingGroups({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<StrikingGroupRecord> items;
  final int currentPage;
  final int lastPage;
  final int total;
}

class PaginatedLoadingGroups {
  const PaginatedLoadingGroups({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<LoadingGroupRecord> items;
  final int currentPage;
  final int lastPage;
  final int total;
}

double _attendanceNum(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int _attendanceInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

class AttendanceOverview {
  const AttendanceOverview({
    required this.totalPresent,
    required this.totalAbsent,
    required this.otHours,
    required this.otMinutes,
    required this.otTotalHours,
    required this.otDisplay,
    required this.totalOtAmount,
    required this.totalAdvance,
    required this.halfDayTotal,
    required this.ppTotal,
    required this.pHalfTotal,
    required this.balanceAmount,
  });

  factory AttendanceOverview.fromJson(Map<String, dynamic> json) =>
      AttendanceOverview(
        totalPresent: _attendanceNum(json['total_present']),
        totalAbsent: _attendanceNum(json['total_absent']),
        otHours: _attendanceInt(json['ot_hours']),
        otMinutes: _attendanceInt(json['ot_minutes']),
        otTotalHours: _attendanceNum(json['ot_total_hours']),
        otDisplay: json['ot_display']?.toString() ?? '',
        totalOtAmount: _attendanceNum(json['total_ot_amount']),
        totalAdvance: _attendanceNum(json['total_advance']),
        halfDayTotal: _attendanceInt(json['half_day_total']),
        ppTotal: _attendanceInt(json['pp_total']),
        pHalfTotal: _attendanceInt(json['p_half_total']),
        balanceAmount: _attendanceNum(json['balance_amount']),
      );

  final double totalPresent;
  final double totalAbsent;
  final int otHours;
  final int otMinutes;
  final double otTotalHours;
  final String otDisplay;
  final double totalOtAmount;
  final double totalAdvance;
  final int halfDayTotal;
  final int ppTotal;
  final int pHalfTotal;
  final double balanceAmount;
}

class AttendanceDay {
  const AttendanceDay({
    required this.date,
    required this.day,
    required this.weekday,
    this.status,
    required this.otHours,
    required this.otMinutes,
    required this.otRate,
    required this.otAmount,
    required this.advanceAmount,
    this.advanceMode,
    this.note,
  });

  factory AttendanceDay.fromJson(Map<String, dynamic> json) => AttendanceDay(
        date: json['date']?.toString() ?? '',
        day: json['day']?.toString() ?? '',
        weekday: json['weekday']?.toString() ?? '',
        status: json['status']?.toString(),
        otHours: _attendanceInt(json['ot_hours']),
        otMinutes: _attendanceInt(json['ot_minutes']),
        otRate: _attendanceNum(json['ot_rate']),
        otAmount: _attendanceNum(json['ot_amount']),
        advanceAmount: _attendanceNum(json['advance_amount']),
        advanceMode: json['advance_mode']?.toString(),
        note: json['note']?.toString(),
      );

  final String date;
  final String day;
  final String weekday;
  final String? status;
  final int otHours;
  final int otMinutes;
  final double otRate;
  final double otAmount;
  final double advanceAmount;
  final String? advanceMode;
  final String? note;

  bool get hasEntry =>
      status != null ||
      advanceAmount > 0 ||
      (note != null && note!.isNotEmpty);
}

class MonthlyAttendance {
  const MonthlyAttendance({
    required this.userId,
    required this.userName,
    required this.userMobile,
    required this.month,
    required this.monthLabel,
    required this.overview,
    required this.days,
  });

  factory MonthlyAttendance.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? const {};
    return MonthlyAttendance(
      userId: _attendanceInt(user['id']),
      userName: user['name']?.toString() ?? '',
      userMobile: user['mobile']?.toString() ?? '',
      month: json['month']?.toString() ?? '',
      monthLabel: json['month_label']?.toString() ?? '',
      overview: AttendanceOverview.fromJson(
        json['overview'] as Map<String, dynamic>? ?? const {},
      ),
      days: ((json['days'] as List?) ?? const [])
          .map((d) => AttendanceDay.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }

  final int userId;
  final String userName;
  final String userMobile;
  final String month;
  final String monthLabel;
  final AttendanceOverview overview;
  final List<AttendanceDay> days;
}
