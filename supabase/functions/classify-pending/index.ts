// classify-pending/index.ts
import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "https://hmolyqzbvxxliemclrld.supabase.co";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imhtb2x5cXpidnh4bGllbWNscmxkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDI0Njk3MCwiZXhwIjoyMDc1ODIyOTcwfQ.496txRbAGuiOov76vxdwSDUHplBt1osOD2PyV0EE958";
const CLASSIFY_IMAGE_URL = Deno.env.get("CLASSIFY_IMAGE_URL") || 'https://hmolyqzbvxxliemclrld.supabase.co/functions/v1/classify-image';

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false },
});

Deno.serve(async (req) => {
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
    // Get pending reports that have image_path not null
    const { data: reports, error } = await supabase
      .from('reports')
      .select('id, image_path')
      .eq('status', 'pending')
      .not('image_path', 'is', null)
      .limit(200);

    if (error) {
      console.error('Error fetching pending reports', error);
      return new Response(JSON.stringify({ error: 'failed to fetch pending reports' }), {
        status: 500,
        headers: { 
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        }
      });
    }

    const results = [];
    for (const r of reports) {
      try {
        // mark as processing to avoid duplicates
        await supabase.from('reports').update({ status: 'processing' }).eq('id', r.id);
      } catch (e) {
        console.warn('Failed to set processing for', r.id, e);
      }

      try {
        const resp = await fetch(CLASSIFY_IMAGE_URL, {
          method: 'POST',
          headers: { 
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${SERVICE_KEY}`
          },
          body: JSON.stringify({ reportId: r.id })
        });

        if (!resp.ok) {
          const txt = await resp.text();
          results.push({ id: r.id, ok: false, status: resp.status, info: txt });
          // revert status to pending for manual retry
          await supabase.from('reports').update({ status: 'pending' }).eq('id', r.id);
        } else {
          results.push({ id: r.id, ok: true, status: resp.status });
        }
      } catch (err) {
        console.error('Error calling classify-image for', r.id, err);
        results.push({ id: r.id, ok: false, error: err.message });
        await supabase.from('reports').update({ status: 'pending' }).eq('id', r.id);
      }

      // small polite delay
      await new Promise(s => setTimeout(s, 300));
    }

    return new Response(JSON.stringify({ ok: true, count: results.length, results }), {
      status: 200,
      headers: { 
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      }
    });
  } catch (err) {
    console.error('classify-pending error', err);
    return new Response(JSON.stringify({ error: err.toString() }), {
      status: 500,
      headers: { 
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      }
    });
  }
});
