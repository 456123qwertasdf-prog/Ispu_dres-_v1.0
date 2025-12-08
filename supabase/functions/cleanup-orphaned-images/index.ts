import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
// deno-types-ignore
declare const Deno: any;

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

const supabase = createClient(SUPABASE_URL, SERVICE_KEY, {
  auth: { persistSession: false },
});

Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 200, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ error: "Method not allowed" }),
      { status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  try {
    // Get all orphaned images (reference_count = 0)
    const { data: orphanedImages, error: fetchError } = await supabase
      .rpc("get_orphaned_images");

    if (fetchError) {
      throw new Error(`Failed to get orphaned images: ${fetchError.message}`);
    }

    if (!orphanedImages || orphanedImages.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          deleted: 0,
          message: "No orphaned images to clean up"
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    let deletedCount = 0;
    let failedCount = 0;
    const errors: string[] = [];

    // Delete each orphaned image from storage
    for (const image of orphanedImages) {
      try {
        // Extract path from full URL if needed
        let imagePath = image.image_path;
        if (imagePath.includes('/storage/v1/object/public/')) {
          imagePath = imagePath.split('/storage/v1/object/public/')[1];
        }

        // Remove bucket prefix if present
        if (imagePath.startsWith(`${image.storage_bucket}/`)) {
          imagePath = imagePath.replace(`${image.storage_bucket}/`, '');
        }

        // Delete from storage
        const { error: deleteError } = await supabase.storage
          .from(image.storage_bucket || 'reports-images')
          .remove([imagePath]);

        if (deleteError) {
          console.error(`Failed to delete ${imagePath}:`, deleteError);
          failedCount++;
          errors.push(`${imagePath}: ${deleteError.message}`);
          continue;
        }

        // Delete from deduplication table
        const { error: dbDeleteError } = await supabase
          .from("image_deduplication")
          .delete()
          .eq("id", image.id);

        if (dbDeleteError) {
          console.error(`Failed to remove deduplication record for ${image.id}:`, dbDeleteError);
          errors.push(`DB record ${image.id}: ${dbDeleteError.message}`);
        } else {
          deletedCount++;
        }

      } catch (error: any) {
        console.error(`Error deleting image ${image.image_path}:`, error);
        failedCount++;
        errors.push(`${image.image_path}: ${error.message}`);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        deleted: deletedCount,
        failed: failedCount,
        total: orphanedImages.length,
        errors: errors.length > 0 ? errors : undefined,
        message: `Cleaned up ${deletedCount} orphaned images`
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error: any) {
    console.error("Error cleaning up orphaned images:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Failed to clean up orphaned images" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

