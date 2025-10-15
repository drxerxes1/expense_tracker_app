import 'package:org_wallet/models/officer.dart';

/// Role-based permission system for the expense tracker app
class RolePermissions {
  /// Check if a role can access a specific drawer menu item
  static bool canAccessDrawerItem(OfficerRole role, String menuItem) {
    switch (menuItem) {
      case 'edit_organization':
        return _hasFullPrivileges(role);
      
      case 'manage_dues':
        return _hasFullPrivileges(role);
      
      case 'manage_members':
        return _hasFullPrivileges(role);
      
      case 'manage_categories':
        return _hasManagementAccess(role);
      
      case 'manage_collections':
        return _hasCollectionAccess(role);
      
      case 'invite_qr':
        return _hasFullPrivileges(role);
      
      case 'export_reports':
        return _hasManagementAccess(role); // Only officers and presidents can export reports
      
      case 'profile':
        return true; // All roles can access profile
      
      case 'join_qr':
        return true; // All roles can join via QR
      
      case 'switch_organization':
        return true; // All roles can switch organizations
      
      case 'logout':
        return true; // All roles can logout
      
      default:
        return false;
    }
  }

  /// Check if a role can perform a specific action
  static bool canPerformAction(OfficerRole role, String action) {
    switch (action) {
      case 'add_transaction':
        return _hasTransactionAccess(role);
      
      case 'edit_transaction':
        return _hasTransactionAccess(role);
      
      case 'delete_transaction':
        return _hasFullPrivileges(role);
      
      case 'manage_categories':
        return _hasManagementAccess(role);
      
      case 'manage_members':
        return _hasFullPrivileges(role);
      
      case 'manage_dues':
        return _hasFullPrivileges(role);
      
      case 'edit_organization':
        return _hasFullPrivileges(role);
      
      case 'invite_members':
        return _hasFullPrivileges(role);
      
      case 'approve_requests':
        return _hasFullPrivileges(role);
      
      case 'manage_collections':
        return _hasCollectionAccess(role);
      
      case 'view_reports':
        return true; // All roles can view reports
      
      case 'export_reports':
        return _hasManagementAccess(role); // Only officers and presidents can export reports
      
      default:
        return false;
    }
  }

  /// Check if role has full privileges (President/Moderator)
  static bool _hasFullPrivileges(OfficerRole role) {
    return role == OfficerRole.president || role == OfficerRole.moderator;
  }

  /// Check if role has management access (Treasurer/Secretary/Auditor/President/Moderator)
  static bool _hasManagementAccess(OfficerRole role) {
    return role == OfficerRole.treasurer ||
           role == OfficerRole.secretary ||
           role == OfficerRole.auditor ||
           role == OfficerRole.president ||
           role == OfficerRole.moderator;
  }

  /// Check if role has transaction access (Treasurer/Secretary/Auditor/President/Moderator)
  static bool _hasTransactionAccess(OfficerRole role) {
    return role == OfficerRole.treasurer ||
           role == OfficerRole.secretary ||
           role == OfficerRole.auditor ||
           role == OfficerRole.president ||
           role == OfficerRole.moderator;
  }

  /// Check if role has collection access (Officers only: Treasurer/Secretary/Auditor/President/Moderator)
  static bool _hasCollectionAccess(OfficerRole role) {
    // Only officers can manage collections, not regular members
    return role == OfficerRole.treasurer ||
           role == OfficerRole.secretary ||
           role == OfficerRole.auditor ||
           role == OfficerRole.president ||
           role == OfficerRole.moderator;
  }

  /// Get role display name with emoji
  static String getRoleDisplayName(OfficerRole role) {
    switch (role) {
      case OfficerRole.president:
        return '👑 President';
      case OfficerRole.treasurer:
        return '💰 Treasurer';
      case OfficerRole.secretary:
        return '📋 Secretary';
      case OfficerRole.auditor:
        return '🧾 Auditor';
      case OfficerRole.moderator:
        return '🛠️ Moderator';
      case OfficerRole.member:
        return '👤 Member';
    }
  }

  /// Get role description
  static String getRoleDescription(OfficerRole role) {
    switch (role) {
      case OfficerRole.president:
        return 'Full administrative access to all features';
      case OfficerRole.treasurer:
        return 'Can manage transactions, categories, and collections';
      case OfficerRole.secretary:
        return 'Can manage transactions, categories, and collections';
      case OfficerRole.auditor:
        return 'Can manage transactions, categories, and collections';
      case OfficerRole.moderator:
        return 'Full administrative access to all features';
      case OfficerRole.member:
        return 'View-only access to organization data';
    }
  }

  /// Get list of drawer menu items for a specific role
  static List<String> getDrawerMenuItems(OfficerRole role) {
    List<String> items = [];
    
    // Add role-specific items
    if (canAccessDrawerItem(role, 'edit_organization')) {
      items.add('edit_organization');
    }
    if (canAccessDrawerItem(role, 'manage_dues')) {
      items.add('manage_dues');
    }
    if (canAccessDrawerItem(role, 'manage_members')) {
      items.add('manage_members');
    }
    if (canAccessDrawerItem(role, 'manage_categories')) {
      items.add('manage_categories');
    }
    if (canAccessDrawerItem(role, 'manage_collections')) {
      items.add('manage_collections');
    }
    if (canAccessDrawerItem(role, 'invite_qr')) {
      items.add('invite_qr');
    }
    if (canAccessDrawerItem(role, 'export_reports')) {
      items.add('export_reports');
    }
    
    // Add divider
    items.add('divider');
    
    // Add common items
    items.addAll(['profile', 'join_qr', 'switch_organization', 'logout']);
    
    return items;
  }
}
