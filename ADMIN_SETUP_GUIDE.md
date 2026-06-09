# Admin Access Setup Guide

## ✅ What's Been Done
Your admin page is now integrated into the navigation! When a user has `isAdmin: true`, they will see an **Admin** tab in the bottom navigation bar that gives them access to the Admin Codes Page for managing subscription codes.

## 📱 How to Set Up the Admin User (0549234970)

### Option 1: Using Firebase Console (Easiest)

1. **Go to [Firebase Console](https://console.firebase.google.com/)**
   - Select your project: **Service-App**
   - Navigate to **Firestore Database** → **Collections**

2. **Create/Find the `users` collection**
   - If it doesn't exist, create it manually

3. **Create a New Document with Admin Data**
   - Click **Add Document**
   - Set the Document ID to a unique ID (e.g., `admin_0549234970` or any Firebase Auth UID)
   - Add the following fields:

```json
{
  "uid": "admin_0549234970",
  "name": "Admin",
  "email": "admin@akhdem-li.com",
  "phone": "0549234970",
  "role": "admin",
  "isAdmin": true,
  "photoUrl": "",
  "createdAt": Timestamp.now(),
  "address": "",
  "totalJobs": 0,
  "rating": 0.0,
  "serviceIds": [],
  "subscriptionActive": true,
  "chatIds": [],
  "wilaya": "",
  "commune": ""
}
```

### Option 2: Using Firebase Authentication + Firestore (More Secure)

1. **Create a Firebase Auth User**
   - Go to **Firebase Console** → **Authentication** → **Users**
   - Click **Add User**
   - Email: `admin@akhdem-li.com`
   - Password: `(set a strong password)`
   - Copy the generated **UID**

2. **Create the Firestore Document**
   - In **Firestore Database** → **Collections** → **users**
   - Create a new document with the UID from step 1
   - Add the fields as shown in Option 1 (use the UID from Firebase Auth)

### Option 3: Using Flutter App (After First Deploy)

Once the app is deployed:

1. **Create a regular user account** with phone number **0549234970**
2. **Go to Firestore Console** → Find the user document
3. **Edit the user document** and add:
   - `"role": "admin"`
   - `"isAdmin": true`

## 🔑 Admin Credentials

| Field | Value |
|-------|-------|
| Phone | 0549234970 |
| Email | admin@akhdem-li.com |
| Role | admin |
| Is Admin | true |

## 📍 How Admin Accesses the Page

1. **Login** with admin credentials
2. **Look at the bottom navigation** - you'll see a new **Admin** tab (shield icon 🛡️)
3. **Tap the Admin tab** to access the Admin Codes Page
4. **Generate subscription codes** and manage them from there

## 🔄 How the Admin Tab Works

- **For Regular Users**: No Admin tab appears (navigation shows 5 tabs)
- **For Admin Users**: An extra Admin tab appears (navigation shows 6 tabs)
- **The Admin Page** lets admins:
  - View all subscription codes
  - Generate new subscription codes
  - Copy codes to clipboard
  - See code usage status

## ⚠️ Important Notes

- The `isAdmin` flag is checked from the `UserModel` which reads from Firestore
- The admin tab **only appears if the user's role is "admin"** (line 119 in UserModel.dart)
- Make sure the phone number matches exactly: `0549234970`

## 🛠️ Testing

To test the setup:

1. Deploy the app
2. Login with admin credentials
3. Check if the Admin tab appears
4. If it doesn't appear, verify:
   - The Firestore document has `"isAdmin": true`
   - The Firestore document has `"role": "admin"`
   - The user is logged out and back in (to refresh the user data)

## 📞 Troubleshooting

**Admin tab doesn't appear?**
- ✓ Check Firestore for `isAdmin: true`
- ✓ Check Firestore for `role: "admin"`
- ✓ Log out and back in
- ✓ Check browser console for errors

**Can't login?**
- ✓ Make sure Firebase Auth user exists
- ✓ Check the email/password combination
- ✓ Verify the Firestore document has all required fields

---

**Last Updated**: 2026-06-09
**Status**: ✅ Admin Navigation Ready - Firestore Setup Pending
