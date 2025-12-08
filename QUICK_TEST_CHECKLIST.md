# LSPU DRES - Quick Test Checklist
## Priority-Based Testing Guide

**Purpose**: Quick testing checklist for critical functionality  
**Use Case**: Smoke testing, regression testing, pre-deployment verification

---

## 🔴 CRITICAL PRIORITY (Must Pass Before Deployment)

### Authentication & Security
- [ ] Users can login with correct credentials
- [ ] Users cannot login with wrong credentials  
- [ ] Session timeout works correctly
- [ ] Users can only access their role's features
- [ ] Citizen cannot access admin/responder pages
- [ ] Password reset functionality works

### Emergency Reporting (Core Feature)
- [ ] Citizens can create emergency reports
- [ ] Photo upload works
- [ ] Location detection works
- [ ] Report successfully saved to database
- [ ] Admin/Responder can see new reports immediately

### Assignment System
- [ ] Admin can assign reports to responders
- [ ] Responders receive assignment notifications
- [ ] Responders can accept assignments
- [ ] Responders can mark assignments as completed
- [ ] Status updates reflect in real-time

### Critical Notifications
- [ ] Emergency alerts trigger push notifications
- [ ] Alert sound plays for emergencies
- [ ] All users receive announcements
- [ ] Notifications are delivered to mobile app

---

## 🟡 HIGH PRIORITY (Should Work Properly)

### Dashboard Functionality
- [ ] Statistics display correctly for each role
- [ ] Real-time data updates work
- [ ] Map displays all markers correctly
- [ ] Weather data loads and displays

### Reports Management
- [ ] View all reports (Admin)
- [ ] Filter reports by status/type/date
- [ ] Search functionality works
- [ ] Edit report details
- [ ] Archive/delete reports

### User Management
- [ ] Create new users
- [ ] Assign roles correctly
- [ ] Send credentials via email
- [ ] Deactivate/activate users
- [ ] View user activity

### Learning Modules
- [ ] Modules display correctly
- [ ] Quiz functionality works
- [ ] Progress tracking works
- [ ] Completion status updates

### Weather & Early Warning
- [ ] Weather data fetches automatically
- [ ] Alerts generated for severe weather
- [ ] Admin can create custom alerts
- [ ] Weather dashboard displays correctly

---

## 🟢 MEDIUM PRIORITY (Important but Not Critical)

### Analytics & Reporting
- [ ] Charts and graphs display
- [ ] Export functionality works
- [ ] Classification analytics available
- [ ] Response time metrics accurate

### Evacuation Centers
- [ ] View evacuation centers on map
- [ ] Add/edit/delete centers
- [ ] Capacity tracking works
- [ ] Directions functionality

### Profile Management
- [ ] Users can edit their profile
- [ ] Change password works
- [ ] Profile picture upload
- [ ] Contact information updates

### Archive System
- [ ] Archive reports
- [ ] View archived data
- [ ] Restore from archive
- [ ] Search archived reports

---

## 🔵 LOW PRIORITY (Nice to Have)

### UI/UX Enhancements
- [ ] Animations work smoothly
- [ ] Hover effects display
- [ ] Color schemes consistent
- [ ] Icons display correctly

### Advanced Features
- [ ] Heat map visualization
- [ ] Advanced filtering
- [ ] Bulk operations
- [ ] Custom report templates

---

## 📱 MOBILE APP SMOKE TEST (15 minutes)

### Quick Mobile Test Flow:
1. **Login** ✓
   - [ ] App opens without crash
   - [ ] Login screen displays
   - [ ] Can login successfully

2. **Home Screen** ✓
   - [ ] Dashboard loads
   - [ ] Weather displays
   - [ ] Quick actions visible
   - [ ] Navigation works

3. **Emergency Report** ✓
   - [ ] Can access report screen
   - [ ] Camera works
   - [ ] Location detected
   - [ ] Submit works

4. **Notifications** ✓
   - [ ] Can view announcements
   - [ ] Push notifications received
   - [ ] Alert sounds play

5. **My Reports** ✓
   - [ ] Reports list displays
   - [ ] Can view details
   - [ ] Status shown correctly

---

## 💻 WEB APP SMOKE TEST (20 minutes)

### Admin Dashboard Quick Test:
1. **Login** (2 min) ✓
   - [ ] Login page loads
   - [ ] Admin login successful
   - [ ] Redirected to dashboard

2. **Dashboard** (3 min) ✓
   - [ ] Statistics display
   - [ ] All navigation items visible
   - [ ] System status shows

3. **Reports** (5 min) ✓
   - [ ] Reports list loads
   - [ ] Can view details
   - [ ] Can assign to responder
   - [ ] Filter works

4. **Announcements** (3 min) ✓
   - [ ] Create announcement
   - [ ] Publish announcement
   - [ ] Visible to users

5. **Map View** (3 min) ✓
   - [ ] Map loads
   - [ ] Markers display
   - [ ] Can click markers

6. **User Management** (4 min) ✓
   - [ ] View users
   - [ ] Create user
   - [ ] Assign role
   - [ ] Send credentials

### Responder Dashboard Quick Test:
1. **Login** (1 min) ✓
   - [ ] Responder login successful

2. **Dashboard** (2 min) ✓
   - [ ] Statistics display
   - [ ] Assignment count correct

3. **Assignments** (5 min) ✓
   - [ ] View assigned reports
   - [ ] Accept assignment
   - [ ] Update status
   - [ ] Mark complete

4. **Map View** (2 min) ✓
   - [ ] View incidents on map
   - [ ] Navigate to location

---

## 🔒 SECURITY QUICK CHECK (10 minutes)

### Access Control:
- [ ] **Test 1**: Login as Citizen → Try to access `/admin.html` → Should be blocked
- [ ] **Test 2**: Login as Responder → Try to access admin features → Should be blocked
- [ ] **Test 3**: Login as Citizen → Try to view another user's report → Should not see it
- [ ] **Test 4**: Logout → Try to access dashboard directly → Should redirect to login
- [ ] **Test 5**: Manipulate URL parameters → Should not expose unauthorized data

### Data Validation:
- [ ] **Test 6**: Submit report without required fields → Should show validation errors
- [ ] **Test 7**: Upload non-image file → Should be rejected
- [ ] **Test 8**: Upload oversized file → Should show size error
- [ ] **Test 9**: SQL injection in forms → Should be sanitized
- [ ] **Test 10**: XSS attempt in text fields → Should be escaped

---

## 🌐 CROSS-BROWSER QUICK TEST (10 minutes)

Test on 3 browsers (Chrome, Firefox, Edge):

**Per Browser (3 min each):**
1. [ ] Login works
2. [ ] Dashboard displays correctly
3. [ ] Create report works
4. [ ] Map displays
5. [ ] Notifications work

---

## 📊 PERFORMANCE QUICK CHECK (5 minutes)

- [ ] Login page loads in < 3 seconds
- [ ] Dashboard loads in < 5 seconds
- [ ] Map loads in < 7 seconds
- [ ] Image upload completes in < 10 seconds
- [ ] Report submission in < 5 seconds

**Use browser DevTools Network tab to measure**

---

## 🔄 REAL-TIME FEATURES TEST (5 minutes)

1. [ ] **Dual Browser Test**: 
   - Open admin dashboard in Browser A
   - Create report in Browser B
   - Verify report appears in Browser A without refresh

2. [ ] **Mobile + Web Test**:
   - Open admin on web
   - Create announcement
   - Verify mobile app receives notification

3. [ ] **Assignment Test**:
   - Admin assigns report
   - Responder receives notification immediately

---

## 🚨 EMERGENCY SCENARIO TEST (10 minutes)

**Simulate Real Emergency:**

1. **Citizen Reports Emergency** (2 min)
   - [ ] Open mobile app
   - [ ] Create fire emergency report
   - [ ] Upload photo
   - [ ] Submit successfully

2. **Admin Receives & Assigns** (3 min)
   - [ ] Admin sees report immediately
   - [ ] Admin assigns to responder
   - [ ] Priority set to high

3. **Responder Accepts** (2 min)
   - [ ] Responder receives notification
   - [ ] Opens assignment
   - [ ] Accepts assignment

4. **Status Updates** (2 min)
   - [ ] Responder updates status to "En Route"
   - [ ] Admin sees status change
   - [ ] Citizen sees status change

5. **Completion** (1 min)
   - [ ] Responder marks complete
   - [ ] Status updates for all parties
   - [ ] Report moves to resolved

---

## ✅ PRE-DEPLOYMENT CHECKLIST

Before going live, verify ALL these items:

### Configuration
- [ ] Supabase URL and keys configured
- [ ] OneSignal app ID configured
- [ ] Weather API key configured
- [ ] SMTP email settings configured
- [ ] Correct LSPU coordinates set
- [ ] All environment variables set

### Database
- [ ] All migrations run successfully
- [ ] RLS policies enabled
- [ ] Test users created for each role
- [ ] Sample data loaded (if needed)

### Security
- [ ] All passwords are strong
- [ ] API keys are not exposed in frontend
- [ ] HTTPS enabled
- [ ] CORS configured correctly
- [ ] Rate limiting enabled

### Functionality
- [ ] All critical tests passed
- [ ] All high priority tests passed
- [ ] Mobile app published to stores (or APK available)
- [ ] Web app deployed and accessible
- [ ] Email notifications working
- [ ] Push notifications working

### Documentation
- [ ] User manual available
- [ ] Admin guide available
- [ ] Setup guide complete
- [ ] Training materials ready

### Backup & Recovery
- [ ] Database backup configured
- [ ] Recovery procedures documented
- [ ] Contact information for support

---

## 📝 QUICK BUG REPORT TEMPLATE

**When you find an issue, document it:**

```
BUG #: _____
SEVERITY: ☐ Critical ☐ High ☐ Medium ☐ Low
ROLE: ☐ Citizen ☐ Responder ☐ Admin ☐ Super User

DESCRIPTION:
What happened: 

What should happen:

STEPS TO REPRODUCE:
1. 
2. 
3. 

BROWSER/DEVICE:

SCREENSHOT/VIDEO:
```

---

## 🎯 DAILY TESTING ROUTINE (5 minutes)

**Run this every day in production:**

1. [ ] Login as each role (Citizen, Responder, Admin)
2. [ ] Create one test emergency report
3. [ ] Assign it to responder
4. [ ] Mark as complete
5. [ ] Create one announcement
6. [ ] Check weather data is updating
7. [ ] Verify notifications are working
8. [ ] Check system status indicators
9. [ ] Review any error logs
10. [ ] Delete test data

---

## 📞 SUPPORT CONTACTS

**If Critical Issues Found:**

- **Technical Lead**: _________________________
- **Database Admin**: _________________________
- **System Admin**: _________________________
- **Emergency Contact**: _________________________

---

**Tester**: _____________________ **Date**: _____________________ **Version**: _____


