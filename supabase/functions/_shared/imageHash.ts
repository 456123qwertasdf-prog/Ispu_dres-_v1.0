// deno-types-ignore
declare const Deno: any;

/**
 * Compute SHA-256 hash of an image buffer for deduplication
 * @param imageBuffer - The image file as ArrayBuffer
 * @returns Promise resolving to hex-encoded SHA-256 hash string
 */
export async function computeImageHash(imageBuffer: ArrayBuffer): Promise<string> {
  // Use Web Crypto API for consistent hashing across platforms
  const hashBuffer = await crypto.subtle.digest('SHA-256', imageBuffer);
  
  // Convert ArrayBuffer to hex string
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  const hashHex = hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
  
  return hashHex;
}

/**
 * Compute hash from image file (for client-side usage)
 * @param file - File object from input
 * @returns Promise resolving to hex-encoded SHA-256 hash string
 */
export async function computeHashFromFile(file: File): Promise<string> {
  const arrayBuffer = await file.arrayBuffer();
  return computeImageHash(arrayBuffer);
}

/**
 * Verify if two image buffers are identical by comparing hashes
 * @param buffer1 - First image buffer
 * @param buffer2 - Second image buffer
 * @returns Promise resolving to true if images are identical
 */
export async function compareImageHashes(
  buffer1: ArrayBuffer,
  buffer2: ArrayBuffer
): Promise<boolean> {
  const hash1 = await computeImageHash(buffer1);
  const hash2 = await computeImageHash(buffer2);
  return hash1 === hash2;
}

