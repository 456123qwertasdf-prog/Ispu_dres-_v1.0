# LSPU DRES - Black Box Testing Questionnaire
## Complete System Testing for All Roles and Dashboards

**Document Version:** 1.0  
**Date:** December 2, 2025  
**Purpose:** Comprehensive black box testing to verify functionality, usability, and security across all user roles

---

## Table of Contents
1. [Testing Instructions](#testing-instructions)
2. [Citizen Role Testing](#1-citizen-role-testing)
3. [Responder Role Testing](#2-responder-role-testing)
4. [Admin Role Testing](#3-admin-role-testing)
5. [Super User Role Testing](#4-super-user-role-testing)
6. [LSM Admin Role Testing](#5-lsm-admin-role-testing)
7. [Cross-Platform Testing](#6-cross-platform-testing)
8. [Security & Access Control Testing](#7-security--access-control-testing)

---

## Testing Instructions

### How to Use This Questionnaire
- **Test Environment**: Use a test/staging environment, not production
- **Test Data**: Use sample/dummy data for all tests
- **Pass Criteria**: ✅ Feature works as expected | ❌ Feature fails or has issues | ⚠️ Partial functionality
- **Documentation**: Note any bugs, errors, or unexpected behavior
- **Browser Testing**: Test on Chrome, Firefox, Edge, and Safari
- **Mobile Testing**: Test on Android and iOS devices

### Tester Information
- **Tester Name**: ___________________________
- **Date of Testing**: ___________________________
- **Environment**: ☐ Staging ☐ Production ☐ Local Development
- **Browser/Device**: ___________________________

---

## 1. CITIZEN ROLE TESTING

### 1.1 Authentication & Login
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 1.1.1 | Open login page | Login page loads with all elements visible | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.1.2 | Login with valid citizen credentials | Successfully logged in and redirected to home | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.1.3 | Login with invalid credentials | Error message displayed, login fails | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.1.4 | Password reset functionality | Reset email sent, password can be changed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.1.5 | Logout functionality | Successfully logged out and redirected to login | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 1.2 Home Dashboard (Mobile App)
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 1.2.1 | View home screen | Home dashboard displays with quick actions | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.2.2 | View weather outlook | Current weather data displays correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.2.3 | View emergency banner (if active) | Emergency alert banner displays prominently | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.2.4 | User profile displays correctly | Username, email, and role shown correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.2.5 | Bottom navigation works | All navigation tabs functional | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 1.3 Emergency Reporting
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 1.3.1 | Access emergency report screen | Opens report form successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.3.2 | Select emergency type | Dropdown shows all emergency types | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.3.3 | Capture/upload photo | Camera works and image uploads | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.3.4 | Auto-detect location | GPS captures current location accurately | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.3.5 | Manually select location on map | Map displays and location can be selected | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.3.6 | Add description (optional) | Text field accepts input | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.3.7 | Submit report without photo | Form validation error shown | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.3.8 | Submit complete report | Report submitted successfully with confirmation | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.3.9 | View success message | Confirmation message displayed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 1.4 My Reports
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 1.4.1 | View all submitted reports | List of user's reports displayed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.4.2 | View report details | Full report information shown | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.4.3 | View report status | Current status (pending/assigned/resolved) shown | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.4.4 | View report images | Images load and display correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.4.5 | View report location on map | Map shows report location accurately | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.4.6 | Filter reports by status | Filter works correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.4.7 | Cannot access other users' reports | Only own reports visible | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 1.5 Learning Modules
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 1.5.1 | View learning modules list | All available modules displayed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.5.2 | Open a learning module | Module content loads correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.5.3 | Navigate through module pages | Pagination/navigation works | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.5.4 | View images in modules | All images load correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.5.5 | Complete module | Completion tracked correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.5.6 | Take quiz (if available) | Quiz loads and can be completed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.5.7 | View quiz results | Score displayed correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 1.6 Safety Tips
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 1.6.1 | View safety tips list | Tips categorized and displayed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.6.2 | Open safety tip details | Full tip content shown | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.6.3 | Search safety tips | Search functionality works | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.6.4 | View images/illustrations | Visual aids display correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 1.7 Map View
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 1.7.1 | Open map simulation | Map loads with default view | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.7.2 | View evacuation centers | Markers displayed on map | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.7.3 | View emergency reports on map | Report markers shown | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.7.4 | Zoom in/out on map | Map zoom controls work | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.7.5 | Click on map markers | Info popup displays details | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.7.6 | View current location | User location shown on map | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 1.8 Notifications
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 1.8.1 | View announcements list | All announcements displayed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.8.2 | Open announcement details | Full announcement shown | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.8.3 | Receive push notifications | Notifications received when published | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.8.4 | Emergency alert sound plays | Alert sound triggers for emergencies | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.8.5 | Mark notification as read | Read status updates | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 1.9 Profile Management
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 1.9.1 | View profile information | All profile data displayed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.9.2 | Edit profile (name, phone) | Changes saved successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.9.3 | Change password | Password updated successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 1.9.4 | Update profile picture (if available) | Image uploads and displays | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

---

## 2. RESPONDER ROLE TESTING

### 2.1 Authentication & Dashboard Access
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 2.1.1 | Login with responder credentials | Logged in, redirected to responder dashboard | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.1.2 | View responder dashboard | Statistics and assigned reports shown | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.1.3 | Dashboard displays role correctly | "Emergency Responder" role shown | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.1.4 | Cannot access admin features | Admin pages return access denied | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.1.5 | Cannot access citizen-only features | Appropriate access restrictions in place | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 2.2 Dashboard Statistics
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 2.2.1 | View assigned reports count | Correct number displayed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.2.2 | View completed assignments count | Accurate count shown | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.2.3 | View pending assignments | Pending cases displayed correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.2.4 | Statistics update in real-time | Data refreshes automatically | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 2.3 My Assignments
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 2.3.1 | View all assigned reports | List shows only assigned reports | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.3.2 | View assignment details | Full report information displayed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.3.3 | View reporter information | Reporter contact details shown | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.3.4 | View report location | Location shown on map | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.3.5 | View report images | All images load correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.3.6 | Accept assignment | Status changes to "in progress" | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.3.7 | Add response notes | Notes saved successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.3.8 | Update assignment status | Status updated in system | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.3.9 | Mark assignment as completed | Moves to completed list | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.3.10 | Filter assignments by status | Filter works correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.3.11 | Sort assignments by date/priority | Sorting functions properly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 2.4 Map View (Responder)
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 2.4.1 | View responder map | Map displays with all assigned incidents | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.4.2 | View route to incident | Navigation route displayed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.4.3 | View nearest evacuation centers | Centers marked on map | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.4.4 | Click incident marker | Incident details popup shown | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.4.5 | View only own assignments | Cannot see unassigned reports | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 2.5 Availability Status
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 2.5.1 | Toggle availability status | Status changes to available/unavailable | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.5.2 | Status reflected in system | Admin sees updated availability | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.5.3 | Unavailable responders not assigned | No new assignments when unavailable | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 2.6 Mobile App - Responder Features
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 2.6.1 | Access responder dashboard in app | Dashboard loads successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.6.2 | Receive assignment notifications | Push notifications work | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.6.3 | Accept assignment via app | Can accept from mobile | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.6.4 | Update status via app | Status updates sync | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 2.6.5 | View assignments offline | Cached data accessible | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

---

## 3. ADMIN ROLE TESTING

### 3.1 Authentication & Dashboard Access
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 3.1.1 | Login with admin credentials | Successfully logged in to admin dashboard | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.1.2 | View admin dashboard | All admin features accessible | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.1.3 | Dashboard displays admin role | "Administrator" role shown | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.1.4 | All navigation items visible | Full sidebar menu displayed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 3.2 Dashboard Statistics
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 3.2.1 | View active cases count | Correct number displayed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.2.2 | View total users count | Accurate user count shown | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.2.3 | View total responders count | Correct responder count | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.2.4 | View resolved cases count | Accurate resolved count | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.2.5 | System status indicator | Shows online/offline status | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.2.6 | Statistics auto-refresh | Data updates in real-time | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 3.3 Reports Management
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 3.3.1 | View all reports list | All emergency reports displayed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.3.2 | Filter reports by status | Filter works (pending/assigned/resolved) | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.3.3 | Filter by emergency type | Type filter functions correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.3.4 | Filter by date range | Date filter works properly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.3.5 | Search reports | Search functionality works | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.3.6 | View report details | Full report information shown | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.3.7 | View report images | Images load correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.3.8 | View report location on map | Map shows accurate location | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.3.9 | Assign report to responder | Assignment created successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.3.10 | Reassign report | Reassignment works correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.3.11 | Change report priority | Priority updated in system | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.3.12 | Add admin notes to report | Notes saved successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.3.13 | Edit report details | Changes saved correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.3.14 | Mark report as resolved | Status changes to resolved | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.3.15 | Delete report | Report deleted with confirmation | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.3.16 | Archive report | Report moved to archive | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.3.17 | Export reports to CSV/PDF | Export function works | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 3.4 Announcements Management
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 3.4.1 | View announcements list | All announcements displayed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.4.2 | Create new announcement | Form opens successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.4.3 | Add announcement title | Title saved correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.4.4 | Add announcement content | Content saved correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.4.5 | Upload announcement image | Image uploads successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.4.6 | Set announcement priority | Priority (normal/high/critical) set | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.4.7 | Publish announcement | Published and visible to users | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.4.8 | Save as draft | Saved but not published | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.4.9 | Edit existing announcement | Changes saved successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.4.10 | Delete announcement | Deleted with confirmation | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.4.11 | Push notifications sent | Users receive notification | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.4.12 | View announcement analytics | View counts shown correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 3.5 Early Warning Dashboard
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 3.5.1 | View weather dashboard | Current weather data displayed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.5.2 | View weather forecast | 7-day forecast shown | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.5.3 | View weather alerts | Active warnings displayed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.5.4 | Create custom weather alert | Alert created successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.5.5 | Set alert severity level | Severity (low/medium/high) set | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.5.6 | Publish weather alert | Alert sent to all users | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.5.7 | View historical weather data | Past data accessible | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.5.8 | Weather data auto-updates | Data refreshes automatically | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.5.9 | Rain volume displayed correctly | Accurate rainfall data | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.5.10 | Temperature displayed correctly | Accurate temperature data | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 3.6 Map View (Admin)
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 3.6.1 | View admin map | Map displays with all reports | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.6.2 | View all emergency markers | All active reports shown | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.6.3 | View evacuation centers | Centers marked on map | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.6.4 | View responder locations | Responders shown on map | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.6.5 | Filter map by emergency type | Filter works correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.6.6 | Filter by date | Date filter functions | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.6.7 | Click marker for details | Popup shows full information | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.6.8 | Assign from map | Can assign responder from popup | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.6.9 | View heat map | Density visualization works | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.6.10 | Map clustering works | Markers cluster appropriately | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 3.7 Evacuation Guide Management
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 3.7.1 | View evacuation centers list | All centers displayed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.7.2 | Add new evacuation center | Form opens successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.7.3 | Add center name and location | Information saved correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.7.4 | Add center capacity | Capacity saved correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.7.5 | Add contact information | Contacts saved correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.7.6 | Add facilities list | Facilities saved correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.7.7 | Upload center images | Images upload successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.7.8 | Set location on map | Coordinates set correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.7.9 | Edit evacuation center | Changes saved successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.7.10 | Delete evacuation center | Deleted with confirmation | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.7.11 | Mark center as active/inactive | Status updated correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.7.12 | Update occupancy status | Current occupancy tracked | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 3.8 Analytics
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 3.8.1 | View analytics dashboard | All charts and graphs displayed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.8.2 | View reports by type chart | Chart displays correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.8.3 | View reports by location | Geographic distribution shown | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.8.4 | View reports trend over time | Timeline chart works | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.8.5 | View responder performance | Statistics accurate | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.8.6 | View response time metrics | Average times calculated correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.8.7 | Filter analytics by date range | Date filters work | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.8.8 | Export analytics report | Export to PDF/CSV works | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.8.9 | View user engagement metrics | User statistics shown | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.8.10 | View classification analytics | AI classification metrics displayed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 3.9 User Management
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 3.9.1 | View all users list | All users displayed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.9.2 | Search users | Search functionality works | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.9.3 | Filter users by role | Role filter works | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.9.4 | View user details | Full user information shown | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.9.5 | Create new user | User created successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.9.6 | Assign user role | Role assigned correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.9.7 | Edit user information | Changes saved successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.9.8 | Reset user password | Password reset email sent | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.9.9 | Deactivate user account | Account deactivated, user cannot login | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.9.10 | Reactivate user account | Account reactivated successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.9.11 | Delete user account | Deleted with confirmation | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.9.12 | Send credentials via email | Email sent with login details | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.9.13 | View user activity log | Activity history displayed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 3.10 Archive Management
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 3.10.1 | View archived reports | All archived reports listed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.10.2 | Search archived reports | Search works correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.10.3 | Filter archived reports | Filters function properly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.10.4 | View archived report details | Full details accessible | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.10.5 | Restore archived report | Report restored to active | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.10.6 | Permanently delete archived report | Deleted with confirmation | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 3.10.7 | Export archived data | Export function works | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

---

## 4. SUPER USER ROLE TESTING

### 4.1 Authentication & Full Access
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 4.1.1 | Login with super user credentials | Logged in with full access | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 4.1.2 | Access all admin features | All admin features accessible | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 4.1.3 | Access super user dashboard | Super user dashboard loads | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 4.1.4 | Role displayed as "Super User" | Correct role shown in UI | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 4.2 System Configuration
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 4.2.1 | Access system settings | Settings page accessible | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 4.2.2 | Configure email settings | SMTP settings can be updated | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 4.2.3 | Configure OneSignal settings | Push notification settings updated | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 4.2.4 | Configure weather API | API key updated successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 4.2.5 | Configure system coordinates | LSPU coordinates updated | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 4.2.6 | Test configuration changes | Changes take effect immediately | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 4.3 Advanced User Management
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 4.3.1 | Create admin users | Admin users created successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 4.3.2 | Promote user to super user | Role upgraded successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 4.3.3 | Demote super user to admin | Role downgraded successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 4.3.4 | Bulk user operations | Bulk actions work correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 4.3.5 | View all user roles | Complete role list accessible | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 4.4 Advanced Analytics & Reporting
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 4.4.1 | Access advanced analytics | Extended analytics available | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 4.4.2 | View system performance metrics | Performance data displayed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 4.4.3 | View audit logs | Complete audit trail accessible | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 4.4.4 | Generate custom reports | Custom report builder works | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 4.4.5 | Export complete database | Full export function works | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 4.5 Database Management
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 4.5.1 | Access database console | Supabase dashboard accessible | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 4.5.2 | Run SQL queries | Can execute custom queries | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 4.5.3 | View database tables | All tables accessible | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 4.5.4 | Modify RLS policies | Security policies can be updated | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 4.5.5 | Database backup | Backup functionality works | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 4.6 Mobile App - Super User Features
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 4.6.1 | Access super user dashboard in app | Dashboard loads successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 4.6.2 | View all reports in app | Access to all reports | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 4.6.3 | Manage announcements | Create/edit/delete announcements | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 4.6.4 | View all responders | Responder list accessible | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 4.6.5 | Assign reports from app | Assignment function works | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

---

## 5. LSM ADMIN ROLE TESTING

### 5.1 Learning Modules Management
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 5.1.1 | Access LSM admin dashboard | Dashboard loads successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 5.1.2 | View all learning modules | Complete module list displayed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 5.1.3 | Create new learning module | Module creation form opens | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 5.1.4 | Add module title and description | Information saved correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 5.1.5 | Add module content | Content editor works | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 5.1.6 | Upload module images | Images upload successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 5.1.7 | Add module pages | Multiple pages can be added | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 5.1.8 | Reorder module pages | Drag-and-drop reordering works | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 5.1.9 | Preview module | Preview displays correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 5.1.10 | Publish module | Module published and visible to users | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 5.1.11 | Edit existing module | Changes saved successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 5.1.12 | Delete module | Deleted with confirmation | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 5.1.13 | Duplicate module | Copy created successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 5.2 Quiz Management
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 5.2.1 | Create quiz for module | Quiz creation form opens | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 5.2.2 | Add quiz questions | Questions added successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 5.2.3 | Add multiple choice options | Options saved correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 5.2.4 | Set correct answers | Correct answers marked | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 5.2.5 | Add question explanations | Explanations saved | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 5.2.6 | Set passing score | Score threshold configured | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 5.2.7 | Preview quiz | Quiz preview works | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 5.2.8 | Edit quiz | Changes saved successfully | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 5.2.9 | Delete quiz | Deleted with confirmation | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 5.3 Module Analytics
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 5.3.1 | View module completion rates | Statistics displayed correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 5.3.2 | View quiz performance | Average scores shown | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 5.3.3 | View user engagement | Time spent data available | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 5.3.4 | Export module reports | Export function works | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 5.3.5 | View individual user progress | User-specific data accessible | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

---

## 6. CROSS-PLATFORM TESTING

### 6.1 Web Application - Browser Compatibility
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 6.1.1 | Test on Google Chrome | All features work correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | Version: ____ |
| 6.1.2 | Test on Mozilla Firefox | All features work correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | Version: ____ |
| 6.1.3 | Test on Microsoft Edge | All features work correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | Version: ____ |
| 6.1.4 | Test on Safari (macOS) | All features work correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | Version: ____ |
| 6.1.5 | Test on mobile browsers | Responsive design works | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 6.2 Mobile Application - Device Testing
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 6.2.1 | Test on Android phone | App functions correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | Device: _____ |
| 6.2.2 | Test on Android tablet | App functions correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | Device: _____ |
| 6.2.3 | Test on iPhone | App functions correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | Device: _____ |
| 6.2.4 | Test on iPad | App functions correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | Device: _____ |
| 6.2.5 | Test on different screen sizes | UI adapts correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 6.2.6 | Test on different Android versions | Compatible across versions | ☐ ✅ ☐ ❌ ☐ ⚠️ | Versions tested: _____ |
| 6.2.7 | Test on different iOS versions | Compatible across versions | ☐ ✅ ☐ ❌ ☐ ⚠️ | Versions tested: _____ |

### 6.3 Responsive Design
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 6.3.1 | Desktop view (1920x1080) | Layout displays correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 6.3.2 | Laptop view (1366x768) | Layout adapts properly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 6.3.3 | Tablet view (768x1024) | Layout responsive | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 6.3.4 | Mobile view (375x667) | Layout mobile-friendly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 6.3.5 | Orientation change | Adapts to portrait/landscape | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 6.4 Offline Functionality
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 6.4.1 | Mobile app offline access | Cached data accessible | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 6.4.2 | Create report offline | Queued for submission | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 6.4.3 | Sync when back online | Data syncs automatically | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 6.4.4 | View saved modules offline | Modules accessible | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 6.4.5 | PWA functionality | Web app works offline | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

---

## 7. SECURITY & ACCESS CONTROL TESTING

### 7.1 Authentication Security
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 7.1.1 | SQL injection in login | Protected against SQL injection | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 7.1.2 | XSS attack in login | Protected against XSS | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 7.1.3 | Brute force protection | Account locked after failed attempts | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 7.1.4 | Session timeout | Sessions expire appropriately | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 7.1.5 | Password strength requirements | Weak passwords rejected | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 7.1.6 | Secure password reset | Reset tokens expire properly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 7.2 Role-Based Access Control (RBAC)
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 7.2.1 | Citizen cannot access admin pages | Access denied/redirected | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 7.2.2 | Citizen cannot access responder pages | Access denied/redirected | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 7.2.3 | Responder cannot access admin features | Access denied | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 7.2.4 | Admin cannot access super user features | Access restricted appropriately | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 7.2.5 | Direct URL access blocked | Cannot bypass via URL manipulation | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 7.2.6 | API endpoint protection | Unauthorized API calls blocked | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 7.3 Data Privacy & RLS (Row Level Security)
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 7.3.1 | Citizens can only see own reports | RLS prevents viewing others' data | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 7.3.2 | Responders see only assigned reports | RLS limits data access | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 7.3.3 | Users cannot modify others' data | Write operations restricted | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 7.3.4 | Soft-deleted data not visible | Deleted records hidden | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 7.3.5 | Personal information protected | Sensitive data encrypted | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 7.4 File Upload Security
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 7.4.1 | Upload malicious file | File rejected | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 7.4.2 | Upload oversized file | File size limit enforced | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 7.4.3 | Upload wrong file type | Only allowed types accepted | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 7.4.4 | File name sanitization | Special characters handled | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 7.4.5 | Uploaded file storage | Files stored securely | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 7.5 API Security
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 7.5.1 | API key required | Requests without key rejected | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 7.5.2 | Rate limiting enforced | Excessive requests blocked | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 7.5.3 | CORS configured correctly | Only allowed origins accepted | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 7.5.4 | API versioning works | Version control maintained | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 7.5.5 | Error messages safe | No sensitive data in errors | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

---

## 8. PERFORMANCE TESTING

### 8.1 Load Time Performance
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 8.1.1 | Login page load time | Loads in < 3 seconds | ☐ ✅ ☐ ❌ ☐ ⚠️ | Actual: _____ |
| 8.1.2 | Dashboard load time | Loads in < 5 seconds | ☐ ✅ ☐ ❌ ☐ ⚠️ | Actual: _____ |
| 8.1.3 | Map page load time | Loads in < 7 seconds | ☐ ✅ ☐ ❌ ☐ ⚠️ | Actual: _____ |
| 8.1.4 | Report submission time | Submits in < 5 seconds | ☐ ✅ ☐ ❌ ☐ ⚠️ | Actual: _____ |
| 8.1.5 | Image upload time | Uploads in < 10 seconds | ☐ ✅ ☐ ❌ ☐ ⚠️ | Actual: _____ |

### 8.2 Stress Testing
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 8.2.1 | 100+ concurrent users | System remains responsive | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 8.2.2 | Large dataset loading | Pagination handles large data | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 8.2.3 | Multiple simultaneous uploads | All uploads process correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 8.2.4 | Real-time updates with many users | Updates propagate correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

---

## 9. INTEGRATION TESTING

### 9.1 Supabase Integration
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 9.1.1 | Database connection stable | No connection drops | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 9.1.2 | Real-time subscriptions work | Data updates in real-time | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 9.1.3 | Storage bucket operations | Files upload/download correctly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 9.1.4 | Authentication flows | Auth works seamlessly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 9.2 OneSignal Notification Integration
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 9.2.1 | Push notifications delivered | Users receive notifications | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 9.2.2 | Notification sound plays | Custom sound works | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 9.2.3 | Click notification opens app | Deep linking works | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 9.2.4 | Multiple device support | Notifications on all devices | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 9.3 Weather API Integration
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 9.3.1 | Weather data fetched correctly | Accurate data displayed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 9.3.2 | Weather updates automatically | Data refreshes periodically | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 9.3.3 | Weather alerts generated | Alerts created when thresholds met | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 9.3.4 | API failure handling | Graceful degradation on error | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 9.4 Email Integration
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 9.4.1 | Welcome emails sent | New users receive email | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 9.4.2 | Password reset emails sent | Reset emails delivered | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 9.4.3 | Credential emails sent | Login details emailed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 9.4.4 | Email formatting correct | HTML emails display properly | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

---

## 10. USABILITY TESTING

### 10.1 User Interface
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 10.1.1 | UI is intuitive | Users can navigate without help | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 10.1.2 | Consistent design language | UI elements consistent throughout | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 10.1.3 | Clear call-to-action buttons | Actions obvious and clickable | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 10.1.4 | Proper color contrast | Text readable on all backgrounds | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 10.1.5 | Appropriate font sizes | Text legible on all devices | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 10.2 User Experience
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 10.2.1 | Form validation helpful | Clear error messages | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 10.2.2 | Loading indicators present | Users know when system is working | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 10.2.3 | Success messages clear | Confirmations displayed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 10.2.4 | Error messages helpful | Errors explain what went wrong | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 10.2.5 | Confirmation dialogs | Destructive actions confirmed | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

### 10.3 Accessibility
| # | Test Case | Expected Result | Status | Notes |
|---|-----------|-----------------|--------|-------|
| 10.3.1 | Keyboard navigation works | All features accessible via keyboard | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 10.3.2 | Screen reader compatible | Proper ARIA labels present | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 10.3.3 | Focus indicators visible | Clear focus states | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 10.3.4 | Color not only indicator | Icons/text accompany colors | ☐ ✅ ☐ ❌ ☐ ⚠️ | |
| 10.3.5 | Alt text for images | Images have descriptive alt text | ☐ ✅ ☐ ❌ ☐ ⚠️ | |

---

## TESTING SUMMARY

### Overall Results

**Total Test Cases**: _____  
**Passed**: _____ (✅)  
**Failed**: _____ (❌)  
**Partial**: _____ (⚠️)  
**Not Tested**: _____  

**Pass Rate**: _____% 

### Critical Issues Found

| Issue # | Description | Severity | Role Affected | Status |
|---------|-------------|----------|---------------|--------|
| 1 | | ☐ Critical ☐ High ☐ Medium ☐ Low | | ☐ Open ☐ Fixed |
| 2 | | ☐ Critical ☐ High ☐ Medium ☐ Low | | ☐ Open ☐ Fixed |
| 3 | | ☐ Critical ☐ High ☐ Medium ☐ Low | | ☐ Open ☐ Fixed |

### Recommendations

1. 
2. 
3. 

### Sign-off

**Tester Signature**: _____________________________  
**Date**: _____________________________  
**Approved By**: _____________________________  
**Date**: _____________________________  

---

## Notes & Additional Comments

_Use this space for any additional observations, suggestions, or comments about the system._

---

**End of Black Box Testing Questionnaire**

