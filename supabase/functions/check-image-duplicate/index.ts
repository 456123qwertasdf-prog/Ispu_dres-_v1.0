import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { computeImageHash } from "../_shared/imageHash.ts";
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
    const body = await req.json();
    const { imageBuffer, imageHash, fileName } = body;

    let hash: string;

    // Compute hash if not provided
    if (imageHash) {
      hash = imageHash;
    } else if (imageBuffer) {
      // Convert base64 to ArrayBuffer if needed
      let buffer: ArrayBuffer;
      if (typeof imageBuffer === 'string') {
        // Base64 encoded
        const binaryString = atob(imageBuffer);
        const bytes = new Uint8Array(binaryString.length);
        for (let i = 0; i < binaryString.length; i++) {
          bytes[i] = binaryString.charCodeAt(i);
        }
        buffer = bytes.buffer;
      } else {
        // Already ArrayBuffer (from FormData)
        buffer = imageBuffer;
      }
      hash = await computeImageHash(buffer);
    } else {
      return new Response(
        JSON.stringify({ error: "Either imageBuffer or imageHash must be provided" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Check if hash exists in database
    const { data: existingImage, error: lookupError } = await supabase
      .from("image_deduplication")
      .select("image_path, storage_bucket, reference_count")
      .eq("image_hash", hash)
      .single();

    if (lookupError && lookupError.code !== 'PGRST116') {
      // PGRST116 = not found, which is fine
      throw new Error(`Database lookup error: ${lookupError.message}`);
    }

    if (existingImage) {
      // Duplicate found - return existing path
      return new Response(
        JSON.stringify({
          isDuplicate: true,
          imageHash: hash,
          existingPath: existingImage.image_path,
          storageBucket: existingImage.storage_bucket,
          referenceCount: existingImage.reference_count,
          message: "Duplicate image found - reusing existing image"
        }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // No duplicate - return hash for storage
    return new Response(
      JSON.stringify({
        isDuplicate: false,
        imageHash: hash,
        message: "New unique image - proceed with upload"
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error: any) {
    console.error("Error checking image duplicate:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Failed to check image duplicate" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

