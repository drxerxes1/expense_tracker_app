# Offline Support for Org Wallet

This document explains how the offline functionality has been implemented in the Org Wallet expense tracking app.

## Overview

The app now supports full offline functionality using an offline-first architecture. Users can:
- View and manage expenses without internet connection
- Add new transactions and expenses offline
- Sync data automatically when connection is restored
- Continue working seamlessly when going online/offline

## Architecture

### Local Storage
- **SQLite Database**: Using Drift (formerly Moor) for local data persistence
- **Offline-First**: All operations work on local data first
- **Sync Queue**: Pending changes are queued for sync when online

### Key Components

#### 1. Database Layer (`lib/database/`)
- `app_database.dart`: Main database class with Drift
- `tables.dart`: Database table definitions
- Generated files: `app_database.g.dart` (auto-generated)

#### 2. Services Layer (`lib/services/`)
- `offline_data_service.dart`: CRUD operations for local storage
- `sync_service.dart`: Handles online/offline synchronization
- `connectivity_service.dart`: Monitors network connectivity
- `transaction_service.dart`: Updated for offline-first approach

#### 3. UI Components (`lib/widgets/`)
- `offline_indicator.dart`: Shows connection and sync status
- `sync_status_widget.dart`: Displays pending sync items

## Database Schema

### Tables
- **Organizations**: Organization data
- **Users**: User account information
- **Officers**: Organization membership and roles
- **Transactions**: Financial transaction records
- **Categories**: Expense/fund categories
- **Expenses**: Expense records
- **AuditTrails**: Action history logs

### Sync Fields
Each table includes:
- `isSynced`: Boolean flag indicating if data is synced with Firebase
- Timestamps for tracking creation and updates

## How It Works

### 1. Offline Operations
```dart
// Adding a transaction offline
final transaction = AppTransaction(
  id: uuid.v4(),
  orgId: orgId,
  amount: 100.0,
  categoryId: categoryId,
  note: 'Office supplies',
  addedBy: userId,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);

// Save to local storage (works offline)
await offlineService.saveTransaction(transaction);
```

### 2. Online Sync
```dart
// When connection is restored, sync automatically
if (connectivityService.isOnline) {
  await syncService.forceSync();
}
```

### 3. Data Flow
1. **User Action** → Save to local database
2. **If Online** → Also save to Firebase
3. **If Offline** → Queue for later sync
4. **Connection Restored** → Sync pending changes

## Usage Examples

### Adding a Transaction
```dart
// Works both online and offline
final transactionService = TransactionService();
await transactionService.addTransaction(transaction);
```

### Viewing Data
```dart
// Always reads from local storage
final transactions = await transactionService.watchTransactions(orgId);
```

### Checking Sync Status
```dart
final syncStatus = await syncService.getSyncStatus();
print('Pending transactions: ${syncStatus['pendingTransactions']}');
```

## UI Indicators

### Connection Status
- **Green WiFi Icon**: Online and connected
- **Red WiFi Off Icon**: Offline mode
- **Blue Sync Icon**: Currently syncing

### Sync Status
- **"Syncing..."**: Data is being synchronized
- **"Synced"**: All data is up to date
- **"Pending Sync"**: Changes waiting to sync

## Configuration

### Dependencies Added
```yaml
dependencies:
  drift: ^2.14.1
  sqlite3_flutter_libs: ^0.5.0
  connectivity_plus: ^5.0.2

dev_dependencies:
  build_runner: ^2.4.7
  drift_dev: ^2.14.1
```

### Database Generation
```bash
# Generate database files
dart run build_runner build
```

## Benefits

### For Users
- **Uninterrupted Work**: Continue working without internet
- **Fast Performance**: Local data access is instant
- **Reliable Sync**: Data syncs automatically when possible
- **No Data Loss**: All changes are saved locally first

### For Developers
- **Offline-First Architecture**: Robust and reliable
- **Automatic Sync**: No manual sync management needed
- **Conflict Resolution**: Handles sync conflicts gracefully
- **Scalable**: Works with any amount of data

## Testing Offline Mode

### Simulate Offline
1. Turn off WiFi/mobile data
2. Add transactions and expenses
3. Verify data is saved locally
4. Turn connection back on
5. Check that data syncs automatically

### Demo Screen
Use the `OfflineDemoScreen` to test offline functionality:
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const OfflineDemoScreen(),
  ),
);
```

## Troubleshooting

### Common Issues

1. **Database not initializing**
   - Ensure `OfflineDataService.initialize()` is called
   - Check that build_runner generated files exist

2. **Sync not working**
   - Verify Firebase configuration
   - Check network connectivity
   - Review sync service logs

3. **Data not persisting**
   - Ensure proper database setup
   - Check file permissions
   - Verify SQLite installation

### Debug Information
```dart
// Check sync status
final status = await syncService.getSyncStatus();
print('Sync status: $status');

// Check connectivity
final isOnline = connectivityService.isOnline;
print('Online: $isOnline');
```

## Future Enhancements

- **Conflict Resolution**: Handle simultaneous edits
- **Selective Sync**: Choose what data to sync
- **Background Sync**: Sync in background when app is closed
- **Data Compression**: Optimize sync performance
- **Offline Analytics**: Track offline usage patterns

## Migration from Online-Only

The offline functionality is backward compatible. Existing Firebase data will be synced to local storage when the app first runs with offline support enabled.

No data migration is required - the app will automatically:
1. Download existing data from Firebase
2. Store it locally
3. Continue with offline-first operations
4. Sync changes back to Firebase

This ensures a seamless transition to offline-capable functionality.
