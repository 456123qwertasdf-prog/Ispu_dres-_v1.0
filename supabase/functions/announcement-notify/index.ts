import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "https://hmolyqzbvxxliemclrld.supabase.co";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhtb2x5cXpidnh4bGllbWNscmxkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDI0Njk3MCwiZXhwIjoyMDc1ODIyOTcwfQ.496txRbAGuiOov76vxdwSDUHplBt1osOD2PyV0EE958";

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false },
});

interface AnnouncementData {
  id: string;
  title: string;
  message: string;
  type: string;
  priority: string;
  target_audience: string;
  created_by: string;
  expires_at?: string;
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 200,
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
        "Access-Control-Allow-Methods": "POST, GET, OPTIONS, PUT, DELETE",
      },
    });
  }

  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "POST only" }), { 
        status: 405, 
        headers: { 
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        } 
      });
    }

    const { announcementId } = await req.json();
    
    if (!announcementId) {
      return new Response(JSON.stringify({ error: "announcementId required" }), { 
        status: 400, 
        headers: { 
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        } 
      });
    }

    // Get the announcement details
    const { data: announcement, error: fetchError } = await supabase
      .from("announcements")
      .select("*")
      .eq("id", announcementId)
      .single();

    if (fetchError) {
      throw new Error("Failed to fetch announcement: " + JSON.stringify(fetchError));
    }

    if (!announcement) {
      return new Response(JSON.stringify({ error: "Announcement not found" }), { 
        status: 404, 
        headers: { 
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        } 
      });
    }

    // Get all users based on target audience
    let targetUsers = [];
    
    if (announcement.target_audience === 'all') {
      // Get all authenticated users
      const { data: users, error: usersError } = await supabase
        .from("user_profiles")
        .select("user_id, role");
      
      if (usersError) {
        console.warn("Could not fetch all users:", usersError);
        // Fallback: try to get users from auth.users
        const { data: authUsers, error: authError } = await supabase.auth.admin.listUsers();
        if (!authError && authUsers?.users) {
          targetUsers = authUsers.users.map(user => ({
            user_id: user.id,
            role: user.user_metadata?.role || 'citizen'
          }));
        }
      } else {
        targetUsers = users || [];
      }
    } else {
      // Get users by specific role
      // Handle role mapping: 'responders' -> 'responder', 'citizens' -> 'citizen', etc.
      let targetRole = announcement.target_audience;
      
      // Map plural forms to singular role values
      const roleMapping: Record<string, string> = {
        'responders': 'responder',
        'citizens': 'citizen',
        'students': 'student', // if needed
        'faculty': 'faculty', // if needed
        'staff': 'staff' // if needed
      };
      
      // If mapping exists, use mapped role, otherwise use target_audience as-is
      const mappedRole = roleMapping[targetRole.toLowerCase()] || targetRole.toLowerCase();
      
      const { data: users, error: usersError } = await supabase
        .from("user_profiles")
        .select("user_id, role")
        .eq("role", mappedRole);
      
      if (usersError) {
        console.warn("Could not fetch users by role:", usersError);
      } else {
        targetUsers = users || [];
      }
    }

    // Create notifications for each target user
    const notifications = targetUsers.map(user => ({
      target_type: 'reporter', // Default to reporter for all users
      target_id: user.user_id,
      type: 'announcement',
      title: `📢 ${announcement.title}`,
      message: announcement.message,
      payload: {
        announcement_id: announcement.id,
        announcement_type: announcement.type,
        priority: announcement.priority,
        created_at: announcement.created_at
      },
      is_read: false
    }));

    if (notifications.length > 0) {
      const { error: insertError } = await supabase
        .from("notifications")
        .insert(notifications);

      if (insertError) {
        console.error("Failed to create notifications:", insertError);
        // Don't fail the request, just log the error
      } else {
        console.log(`✅ Created ${notifications.length} notifications for announcement ${announcementId}`);
      }
    }

    // Send push notifications if available (web push)
    try {
      await sendPushNotifications(announcement, targetUsers);
    } catch (pushError) {
      console.warn("Push notifications failed:", pushError);
      // Don't fail the request if push notifications fail
    }

    // Send OneSignal notifications (mobile push)
    try {
      const userIds = targetUsers.map(user => user.user_id);
      const oneSignalResponse = await fetch(`${SUPABASE_URL}/functions/v1/onesignal-send`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${SERVICE_KEY}`
        },
        body: JSON.stringify({
          announcementId: announcement.id,
          targetUserIds: userIds
        })
      });
      
      if (oneSignalResponse.ok) {
        const oneSignalResult = await oneSignalResponse.json();
        console.log(`✅ OneSignal notifications sent: ${oneSignalResult.sent || 0} devices`);
      } else {
        console.warn('OneSignal notification failed:', oneSignalResponse.status);
      }
    } catch (onesignalError) {
      console.warn("OneSignal notification failed:", onesignalError);
      // Don't fail the request if OneSignal fails
    }

    return new Response(JSON.stringify({ 
      success: true, 
      notifications_created: notifications.length,
      message: `Announcement notifications sent to ${notifications.length} users`
    }), { 
      status: 200, 
      headers: { 
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      } 
    });

  } catch (error) {
    console.error("Announcement notification error:", error);
    return new Response(JSON.stringify({ 
      error: error.message || "Internal server error" 
    }), { 
      status: 500, 
      headers: { 
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      } 
    });
  }
});

// Send push notifications to users
async function sendPushNotifications(announcement: AnnouncementData, targetUsers: any[]) {
  try {
    // Get push subscriptions for target users
    const userIds = targetUsers.map(user => user.user_id);
    
    // Try to fetch web push subscriptions (optional - for web notifications)
    // This table may not exist if only mobile push is used, so we ignore errors
    const { data: subscriptions, error: subError } = await supabase
      .from("push_subscriptions")
      .select("*")
      .in("user_id", userIds);

    if (subError) {
      // Silently ignore - this is expected if only mobile push (OneSignal) is used
      // The error is harmless and doesn't affect OneSignal mobile notifications
      return;
    }

    if (!subscriptions || subscriptions.length === 0) {
      console.log("No push subscriptions found for target users");
      return;
    }

    // Send push notifications
    const pushPromises = subscriptions.map(async (subscription) => {
      try {
        const payload = {
          title: `📢 ${announcement.title}`,
          body: announcement.message,
          icon: "/images/icon-192.png",
          badge: "/images/icon-192.png",
          data: {
            announcement_id: announcement.id,
            type: announcement.type,
            priority: announcement.priority,
            url: "/user.html"
          },
          actions: [
            {
              action: "view",
              title: "View Details"
            },
            {
              action: "dismiss",
              title: "Dismiss"
            }
          ]
        };

        const response = await fetch(subscription.endpoint, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `key=${subscription.auth_key}`,
            "TTL": "86400" // 24 hours
          },
          body: JSON.stringify(payload)
        });

        if (!response.ok) {
          console.warn(`Push notification failed for user ${subscription.user_id}:`, response.status);
        } else {
          console.log(`✅ Push notification sent to user ${subscription.user_id}`);
        }
      } catch (error) {
        console.warn(`Push notification error for user ${subscription.user_id}:`, error);
      }
    });

    await Promise.allSettled(pushPromises);
    console.log(`📱 Push notifications sent to ${subscriptions.length} users`);

  } catch (error) {
    console.error("Push notification system error:", error);
    throw error;
  }
}
