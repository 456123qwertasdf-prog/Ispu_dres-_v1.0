# Add OneSignal REST API Key to Supabase - Quick Setup

## 🎯 Direct Link to Supabase Secrets

**Click this link to go directly to your Supabase Secrets page:**
👉 https://supabase.com/dashboard/project/hmolyqzbvxxliemclrld/settings/functions

Then click the **"Secrets"** tab at the top.

---

## 📝 Step-by-Step Instructions

### Step 1: Open Supabase Secrets Page
1. Go to: https://supabase.com/dashboard/project/hmolyqzbvxxliemclrld/settings/functions
2. Click the **"Secrets"** tab (at the top of the page)

### Step 2: Add OneSignal REST API Key
1. Click **"Add new secret"** button
2. **Name**: `ONESIGNAL_REST_API_KEY`
3. **Value**: `jirjmqx3xegumyrxf4ni4vemh`
4. Click **"Save"**

### Step 3: Add OneSignal App ID (Optional - already in code)
1. Click **"Add new secret"** button again
2. **Name**: `ONESIGNAL_APP_ID`
3. **Value**: `8d6aa625-a650-47ac-b9ba-00a247840952`
4. Click **"Save"**

---

## ✅ Verification

After adding the secrets, you should see:
- ✅ `ONESIGNAL_REST_API_KEY` in your secrets list
- ✅ `ONESIGNAL_APP_ID` in your secrets list (optional)

---

## 🧪 Test It

1. Create an emergency announcement in your app
2. Check Supabase Edge Function logs:
   - Go to: https://supabase.com/dashboard/project/hmolyqzbvxxliemclrld/functions
   - Click on `onesignal-send` function
   - Check the logs to see if notifications are being sent

---

## 🔗 Quick Links

- **Supabase Secrets**: https://supabase.com/dashboard/project/hmolyqzbvxxliemclrld/settings/functions
- **Edge Functions**: https://supabase.com/dashboard/project/hmolyqzbvxxliemclrld/functions
- **OneSignal Dashboard**: https://dashboard.onesignal.com/apps/8d6aa625-a650-47ac-b9ba-00a247840952

---

## 📋 Summary

**Your OneSignal Configuration:**
- **App ID**: `8d6aa625-a650-47ac-b9ba-00a247840952`
- **REST API Key**: `jirjmqx3xegumyrxf4ni4vemh`

**Supabase Secrets to Add:**
1. `ONESIGNAL_REST_API_KEY` = `jirjmqx3xegumyrxf4ni4vemh`
2. `ONESIGNAL_APP_ID` = `8d6aa625-a650-47ac-b9ba-00a247840952` (optional)

---

That's it! Once you add these secrets, your OneSignal push notifications will work! 🎉

