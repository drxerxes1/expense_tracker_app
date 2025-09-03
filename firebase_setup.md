# Firebase Setup Guide for Expense Tracker App

## Prerequisites
- Google account
- Firebase project (free tier available)

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" or "Add project"
3. Enter a project name (e.g., "expense-tracker-app")
4. Choose whether to enable Google Analytics (optional)
5. Click "Create project"

## Step 2: Enable Authentication

1. In your Firebase project, go to "Authentication" in the left sidebar
2. Click "Get started"
3. Go to "Sign-in method" tab
4. Enable "Email/Password" provider
5. Click "Save"

## Step 3: Create Firestore Database

1. Go to "Firestore Database" in the left sidebar
2. Click "Create database"
3. Choose "Start in test mode" for development (you can secure it later)
4. Select a location close to your users
5. Click "Enable"

## Step 4: Configure Security Rules

1. In Firestore Database, go to "Rules" tab
2. Replace the default rules with the following:

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

3. Click "Publish"

## Step 5: Get Configuration Files

### For Android:
1. Go to "Project settings" (gear icon)
2. Scroll down to "Your apps" section
3. Click "Add app" and select Android
4. Enter your package name (e.g., `com.example.expense_tracker_app`)
5. Download `google-services.json`
6. Place it in `android/app/` directory

### For iOS:
1. In "Your apps" section, click "Add app" and select iOS
2. Enter your bundle ID (e.g., `com.example.expenseTrackerApp`)
3. Download `GoogleService-Info.plist`
4. Place it in `ios/Runner/` directory

### For Web:
1. In "Your apps" section, click "Add app" and select Web
2. Enter a nickname for your app
3. Copy the configuration object
4. Use it in your web configuration

## Step 6: Update Flutter Configuration

### Android (`android/app/build.gradle`):
Make sure you have the Google Services plugin:

```gradle
// Add to the bottom of the file
apply plugin: 'com.google.gms.google-services'
```

### Android (`android/build.gradle`):
Add the Google Services classpath:

```gradle
buildscript {
    dependencies {
        // Add this line
        classpath 'com.google.gms:google-services:4.3.15'
    }
}
```

## Step 7: Test Configuration

1. Run `flutter clean`
2. Run `flutter pub get`
3. Try running the app: `flutter run`

## Troubleshooting

### Common Issues:

1. **"No Firebase App" error**: Make sure you've added the configuration files
2. **Authentication errors**: Verify Email/Password is enabled in Firebase Console
3. **Permission denied**: Check your Firestore security rules
4. **Build errors**: Ensure all configuration files are in the correct locations

### Security Notes:

- The provided rules are for development. For production:
  - Add more restrictive rules
  - Enable Firebase App Check
  - Set up proper user validation
  - Consider implementing custom claims for roles

### Performance Tips:

- Use Firestore indexes for complex queries
- Implement pagination for large datasets
- Use offline persistence for better user experience
- Monitor usage in Firebase Console

## Next Steps

After Firebase is configured:

1. Test user registration and login
2. Create an organization
3. Generate QR codes for testing
4. Test expense creation and editing
5. Verify audit trail functionality

## Support

If you encounter issues:
1. Check Firebase Console for error logs
2. Verify your configuration files
3. Check Flutter and Firebase plugin versions
4. Consult Firebase documentation
5. Check the app's error handling and logging
