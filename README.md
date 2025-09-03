# Expense Tracker App

A comprehensive expense tracking application built with Flutter and Firebase, designed for organizations to manage and track expenses with role-based access control and audit trails.

## Features

### 🔐 Authentication & User Management
- **User Registration**: Create new accounts (Organization Presidents only)
- **User Login**: Secure authentication with Firebase Auth
- **Role-Based Access Control**: Different permissions for different user roles

### 🏢 Organization Management
- **Create Organizations**: Presidents can create new organizations
- **QR Code Invites**: Generate QR codes for officer invitations
- **Member Management**: Approve/deny officer requests
- **Role Assignment**: Assign different roles (President, Treasurer, Secretary, Auditor, Moderator, Member)

### 💰 Expense Management
- **Add Expenses**: Record new expenses with categories and notes
- **Edit Expenses**: Modify existing expenses with audit trail tracking
- **Expense Categories**: Food, Transportation, Utilities, Entertainment, Healthcare, Education, Shopping, Other
- **Search & Filter**: Find expenses by date, category, or search terms

### 📊 Analytics & Reporting
- **Dashboard**: Visual summaries with charts and metrics
- **Category Analysis**: Pie charts showing expense distribution
- **Monthly Trends**: Line charts for spending patterns over time
- **Summary Statistics**: Total, average, and category counts
- **Top Expenses**: List of highest expense items

### 🔍 Audit Trail
- **Complete Tracking**: All expense actions are logged
- **Edit Reasons**: Users must provide reasons for expense modifications
- **Action History**: View all changes with timestamps and user information
- **Compliance**: Maintain transparency and accountability

### 📱 User Interface
- **Modern Design**: Material Design 3 with light/dark theme support
- **Responsive Layout**: Works on all screen sizes
- **Intuitive Navigation**: Bottom navigation with clear sections
- **Real-time Updates**: Live data synchronization with Firebase

## User Roles & Permissions

### Organization President
- ✅ Create and manage organizations
- ✅ Generate QR codes for officer invites
- ✅ Approve/deny officer requests
- ✅ Full access to all features
- ✅ Export reports and manage settings

### Officers (Treasurer, Secretary, Auditor, Moderator)
- ✅ View organization information
- ✅ Add and edit expenses
- ✅ View reports and analytics
- ✅ Access audit logs
- ❌ Cannot create organizations
- ❌ Cannot approve new members

### Members
- ✅ View organization information
- ✅ Add expenses (if approved)
- ✅ View reports (limited access)
- ❌ Cannot edit expenses
- ❌ Cannot access administrative features

## Technical Architecture

### Frontend
- **Framework**: Flutter 3.8+
- **State Management**: Provider pattern
- **UI Components**: Material Design 3
- **Charts**: FL Chart library
- **QR Code**: QR Flutter for generation, QR Code Scanner for reading

### Backend
- **Database**: Firebase Firestore
- **Authentication**: Firebase Auth
- **Storage**: Firebase Storage (for future receipt uploads)
- **Real-time**: Firestore streams for live updates

### Data Models
- **Organizations**: Company/group information
- **Users**: User account details
- **Officers**: Organization membership and roles
- **Expenses**: Financial transaction records
- **Audit Trail**: Complete action history

## Getting Started

### Prerequisites
- Flutter SDK 3.8.1 or higher
- Dart SDK 3.8.1 or higher
- Firebase project setup
- Android Studio / VS Code

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/expense_tracker_app.git
   cd expense_tracker_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a new Firebase project
   - Enable Authentication (Email/Password)
   - Enable Firestore Database
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place them in the appropriate platform directories

4. **Configure Firebase**
   - Update Firebase configuration in your project
   - Set up Firestore security rules
   - Configure authentication methods

5. **Run the app**
   ```bash
   flutter run
   ```

### Firebase Configuration

#### Firestore Security Rules
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Organization members can read org data
    match /organizations/{orgId} {
      allow read: if request.auth != null && 
        exists(/databases/$(database)/documents/officers/{userId: request.auth.uid, orgId: orgId});
    }
    
    // Officers can read/write officer data for their org
    match /officers/{officerId} {
      allow read, write: if request.auth != null && 
        resource.data.orgId == get(/databases/$(database)/documents/officers/{userId: request.auth.uid}).data.orgId;
    }
    
    // Expenses: members can read/write for their org
    match /expenses/{expenseId} {
      allow read, write: if request.auth != null && 
        resource.data.orgId == get(/databases/$(database)/documents/officers/{userId: request.auth.uid}).data.orgId;
    }
    
    // Audit trail: members can read for their org
    match /auditTrail/{auditId} {
      allow read: if request.auth != null && 
        exists(/databases/$(database)/documents/expenses/{expenseId: resource.data.expenseId}) &&
        get(/databases/$(database)/documents/expenses/{expenseId: resource.data.expenseId}).data.orgId == 
        get(/databases/$(database)/documents/officers/{userId: request.auth.uid}).data.orgId;
    }
  }
}
```

## Usage Guide

### For Organization Presidents

1. **Create Account**: Sign up as a new user
2. **Create Organization**: Set up your organization with name, description, and department
3. **Generate QR Codes**: Create QR codes for different officer roles
4. **Invite Officers**: Share QR codes with team members
5. **Approve Requests**: Review and approve officer applications
6. **Manage Organization**: Monitor expenses, generate reports, and manage settings

### For Officers

1. **Join Organization**: Scan QR code provided by president
2. **Wait for Approval**: President will review and approve your request
3. **Start Tracking**: Add expenses and view reports once approved
4. **Maintain Records**: Keep accurate expense records with proper categorization

### Adding Expenses

1. Navigate to the Transactions tab
2. Tap the + button in the app bar
3. Enter amount, select category, and add notes
4. Submit the expense
5. View in the transactions list

### Viewing Reports

1. Navigate to the Reports tab
2. Select time period (This Month, Last Month, This Year, All Time)
3. View summary cards, charts, and top expenses
4. Analyze spending patterns and category distribution

### Audit Trail

1. Navigate to the Logs tab
2. View all expense-related activities
3. Filter by action type (Created, Edited, Deleted, Approved, Denied)
4. Track changes with timestamps and user information

## Future Enhancements

### Planned Features
- **Receipt Upload**: Photo/document attachment for expenses
- **Budget Management**: Set and track spending limits
- **Export Functionality**: PDF/CSV report generation
- **Push Notifications**: Expense approval alerts
- **Multi-Currency Support**: International expense tracking
- **Advanced Analytics**: Machine learning insights
- **Mobile Receipt Scanning**: OCR for automatic data extraction

### Technical Improvements
- **Offline Support**: Local data caching
- **Performance Optimization**: Lazy loading and pagination
- **Testing**: Unit and integration tests
- **CI/CD**: Automated build and deployment
- **Monitoring**: Crash reporting and analytics

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For support and questions:
- Create an issue in the GitHub repository
- Contact the development team
- Check the documentation and FAQ

## Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend services
- FL Chart for beautiful data visualization
- QR Flutter for QR code functionality
- Material Design team for design guidelines

---

**Note**: This app is designed for organizational use and includes comprehensive audit trails for compliance and transparency. All expense modifications are tracked and require justification.
