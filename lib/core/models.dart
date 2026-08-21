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
  });

  final int id;
  final String name;
  final String mobile;
  final String role;

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    id: _parseInt(json['id']),
    name: json['name']?.toString() ?? 'User',
    mobile: json['mobile']?.toString() ?? '',
    role: json['role'] is Map
        ? ((json['role'] as Map)['name']?.toString() ?? 'operator')
        : (json['role']?.toString() ?? 'operator'),
  );
}

class BrickTypeModel {
  const BrickTypeModel({
    required this.id,
    required this.name,
    required this.code,
    required this.currentStock,
    required this.reorderLevel,
  });

  final int id;
  final String name;
  final String code;
  final int currentStock;
  final int reorderLevel;

  factory BrickTypeModel.fromJson(Map<String, dynamic> json) => BrickTypeModel(
    id: _parseInt(json['id']),
    name: json['name']?.toString() ?? 'Brick',
    code: json['code']?.toString() ?? '',
    currentStock: _parseInt(json['current_stock']),
    reorderLevel: _parseInt(json['reorder_level']),
  );
}

class MachineModel {
  const MachineModel({
    required this.id,
    required this.name,
    required this.code,
  });

  final int id;
  final String name;
  final String code;

  factory MachineModel.fromJson(Map<String, dynamic> json) => MachineModel(
    id: _parseInt(json['id']),
    name: json['name']?.toString() ?? 'Machine',
    code: json['code']?.toString() ?? '',
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
    this.remarks,
  });

  final int id;
  final String date;
  final String material;
  final String unit;
  final String type;
  final double quantity;
  final String? remarks;

  bool get isOut => type == 'out';

  factory InventoryTransactionModel.fromJson(Map<String, dynamic> json) {
    final material = json['raw_material'] as Map?;
    return InventoryTransactionModel(
      id: _parseInt(json['id']),
      date: json['transaction_date']?.toString() ?? '',
      material: material?['name']?.toString() ?? 'Material',
      unit: material?['unit']?.toString() ?? 'unit',
      type: json['type']?.toString() ?? '',
      quantity: _parseDouble(json['quantity']),
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
    this.remarks,
  });

  final int id;
  final String date;
  final int machineId;
  final int brickTypeId;
  final String machine;
  final String product;
  final int quantity;
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
        remarks: json['remarks']?.toString(),
      );
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
    this.driver,
    this.freightAmount,
    this.freightPaid = false,
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
  final String? driver;
  final double? freightAmount;
  final bool freightPaid;

  factory DispatchRecord.fromJson(Map<String, dynamic> json) => DispatchRecord(
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
    driver: (json['driver'] as Map?)?['name']?.toString(),
    freightAmount: json['freight_amount'] != null
        ? _parseDouble(json['freight_amount'])
        : null,
    freightPaid: json['freight_paid'] as bool? ?? false,
  );
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
