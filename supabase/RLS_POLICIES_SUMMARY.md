# RLS Policies Summary

## Overview
Comprehensive Row Level Security (RLS) policies have been implemented for the emergency response system with role-based access control.

## Role Structure
- **`user`** (default): Regular users who can report incidents
- **`responder`**: Emergency responders who can be assigned to incidents
- **`admin`**: Administrators with full access to all data

## Tables with RLS Policies

### 1. Reports Table
- **Users**: Can create, read, and update their own reports
- **Responders**: Can read and update reports assigned to them
- **Admins**: Full access (create, read, update, delete)

### 2. Reporter Table
- **Users**: Can create, read, and update their own profile
- **Admins**: Full access to all reporter profiles

### 3. Responder Table
- **Responders**: Can read and update their own profile
- **Admins**: Full access (create, read, update, delete)

### 4. Assignment Table
- **Responders**: Can read and update their own assignments
- **Admins**: Full access (create, read, update, delete)

### 5. Audit Log Table
- **Users**: Can insert their own audit logs
- **Admins**: Can read all audit logs
- **Service Role**: Can insert audit logs for system operations

## Helper Functions Created

### `public.user_role()`
Returns the user role from JWT claims or defaults to 'user'

### `public.is_admin()`
Returns true if user has admin role

### `public.is_responder()`
Returns true if user has responder role

### `public.current_reporter_id()`
Returns the reporter ID for the current user

### `public.current_responder_id()`
Returns the responder ID for the current user

## Role Assignment Commands

Use the commands in `role_mapping_commands.sql` to assign roles to users:

```sql
-- Set default role for all users
UPDATE auth.users 
SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || '{"user_role": "user"}'::jsonb
WHERE raw_user_meta_data ->> 'user_role' IS NULL;

-- Grant responder role
UPDATE auth.users 
SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || '{"user_role": "responder"}'::jsonb
WHERE email = 'responder@example.com';

-- Grant admin role
UPDATE auth.users 
SET raw_user_meta_data = COALESCE(raw_user_meta_data, '{}'::jsonb) || '{"user_role": "admin"}'::jsonb
WHERE email = 'admin@example.com';
```

## Security Features

1. **Role-based Access**: Users can only access data appropriate to their role
2. **Ownership-based Access**: Users can only modify their own data
3. **Assignment-based Access**: Responders can only access reports assigned to them
4. **Admin Override**: Admins have full access to all data
5. **Audit Trail**: All actions are logged in the audit_log table

## Implementation Notes

- All policies use `SECURITY DEFINER` functions for consistent role checking
- Foreign key constraints ensure data integrity
- Indexes optimize query performance
- User ID columns link to Supabase auth.users table
- JWT claims are used for role determination
