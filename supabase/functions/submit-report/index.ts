import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { corsHeaders } from '../_shared/cors.ts'
import { computeImageHash } from '../_shared/imageHash.ts'

// Submissions: rate limit and validation constants
const MAX_REPORTS_PER_HOUR = 10
const RATE_LIMIT_WINDOW_HOURS = 1
const MAX_IMAGE_SIZE_BYTES = 5 * 1024 * 1024   // 5MB
const MIN_DESCRIPTION_LENGTH = 10
const MAX_DESCRIPTION_LENGTH = 1000
const ALLOWED_IMAGE_TYPES = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp']

/** Thrown for invalid input; handler returns 400 */
class ValidationError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'ValidationError'
  }
}

/** Thrown when rate limit exceeded; handler returns 429 */
class RateLimitError extends Error {
  constructor(message: string, public readonly retryAfterSeconds?: number) {
    super(message)
    this.name = 'RateLimitError'
  }
}

interface ReportSubmission {
  image: File
  reporter_id?: string
  user_id?: string
  phone?: string
  lat: number
  lng: number
  description: string
  timestamp: string
}

interface ReportData {
  reporter_uid?: string
  reporter_name?: string
  message: string
  location: {
    lat: number
    lng: number
    address?: string
  }
  image_path: string
  type?: string
  confidence?: number
  status: string
  lifecycle_status: string
  created_at: string
  ai_labels?: any
  ai_timestamp?: string
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Initialize Supabase client with proper configuration
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    
    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY environment variables')
    }
    
    const supabaseClient = createClient(supabaseUrl, supabaseServiceKey, {
      auth: { persistSession: false },
    })

    // Parse multipart form data
    const formData = await req.formData()
    const reportData = await parseReportSubmission(formData)

    console.log('Incoming report submission', {
      hasImage: !!reportData.image,
      imageSize: reportData.image?.size,
      imageType: reportData.image?.type,
      descriptionLength: reportData.description?.length,
      lat: reportData.lat,
      lng: reportData.lng
    })

    // Validate required fields
    validateReportSubmission(reportData)

    // Check for duplicate image and upload to storage (with deduplication)
    const { imagePath, imageHash, isDuplicate } = await uploadImageToStorageWithDeduplication(
      supabaseClient,
      reportData.image
    )
    console.log('Image upload result', {
      imagePath,
      imageHash,
      isDuplicate
    })

    // Get or create reporter
    const reporterInfo = await getOrCreateReporter(supabaseClient, reportData)

    // Rate limit: max N reports per hour per reporter
    await checkRateLimit(supabaseClient, reporterInfo.uid)

    // Prepare report data for database
    const reportRecord: ReportData = {
      reporter_uid: reporterInfo.uid,
      reporter_name: reporterInfo.name,
      message: reportData.description,
      location: {
        lat: reportData.lat,
        lng: reportData.lng
      },
      image_path: imagePath,
      image_hash: imageHash,
      status: 'pending',
      lifecycle_status: 'pending',
      created_at: reportData.timestamp || new Date().toISOString()
    }

    // Insert report into database - explicitly select image_path to ensure it's returned
    const { data: insertedReport, error: insertError } = await supabaseClient
      .from('reports')
      .insert(reportRecord)
      .select('id, image_path, status, lifecycle_status, created_at, reporter_uid, reporter_name, message, location')
      .single()

    if (insertError) {
      throw new Error(`Failed to insert report: ${insertError.message}`)
    }

    // Ensure image_path is set (use the one we inserted if not in response)
    const finalImagePath = insertedReport.image_path || imagePath
    if (!finalImagePath) {
      console.warn('Warning: Report inserted but image_path is missing', {
        insertedReport,
        dedupImagePath: imagePath
      })
    } else {
      console.log('Final image path confirmed', finalImagePath)
    }

    if (!insertedReport.image_path) {
      console.log('Inserted report payload missing image_path even after insert', {
        insertedReport,
        dedupImagePath: imagePath
      })
    }

    // If image is a duplicate, try to reuse existing classification
    if (isDuplicate) {
      const classificationCopied = await copyExistingClassification(supabaseClient, imageHash, insertedReport.id)
      
      if (classificationCopied) {
        console.log(`✅ Reused classification from previous report with same image hash`)
      } else {
        // No existing classification found, trigger new one
        console.log('Duplicate image but no classification found, triggering new analysis')
        triggerImageClassification(supabaseClient, insertedReport.id, finalImagePath)
          .catch(err => console.warn('Background classification error (non-critical):', err))
      }
    } else {
      // New unique image - trigger classification
      console.log('New unique image, triggering AI classification')
      triggerImageClassification(supabaseClient, insertedReport.id, finalImagePath)
        .catch(err => console.warn('Background classification error (non-critical):', err))
    }

    // Emit real-time event for new report
    await emitReportCreatedEvent(supabaseClient, insertedReport)

    // Log successful submission
    await logAuditEvent(supabaseClient, {
      entity_type: 'report',
      entity_id: insertedReport.id,
      action: 'created',
      user_id: reporterInfo.uid,
      details: {
        location: reportData.lat + ',' + reportData.lng,
        has_image: true,
        description_length: reportData.description.length
      }
    })

    return new Response(
      JSON.stringify({
        success: true,
        report_id: insertedReport.id,
        message: 'Report submitted successfully',
        image_path: imagePath
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 201
      }
    )

  } catch (error) {
    const err = error instanceof Error ? error : new Error(String(error))
    console.error('Error in submit-report function:', err)

    const body = { success: false, error: err.message || 'Internal server error' }
    let status = 500
    const headers: Record<string, string> = { ...corsHeaders, 'Content-Type': 'application/json' }

    if (err.name === 'ValidationError') {
      status = 400
    } else if (err.name === 'RateLimitError') {
      status = 429
      const retryAfter = (err as RateLimitError).retryAfterSeconds
      if (retryAfter != null) headers['Retry-After'] = String(retryAfter)
    }

    return new Response(JSON.stringify(body), { headers, status })
  }
})

/**
 * Parse multipart form data into structured report submission
 */
async function parseReportSubmission(formData: FormData): Promise<ReportSubmission> {
  const image = formData.get('image') as File
  const reporter_id = formData.get('reporter_id') as string
  const user_id = formData.get('user_id') as string
  const phone = formData.get('phone') as string
  const lat = parseFloat(formData.get('lat') as string)
  const lng = parseFloat(formData.get('lng') as string)
  const description = formData.get('description') as string
  const timestamp = formData.get('timestamp') as string

  if (!image) {
    throw new ValidationError('Image file is required')
  }

  const trimmedDesc = typeof description === 'string' ? description.trim() : ''
  if (!trimmedDesc) {
    throw new ValidationError('Description is required')
  }

  if (isNaN(lat) || isNaN(lng)) {
    throw new ValidationError('Valid latitude and longitude are required')
  }

  if (!reporter_id && !phone && !user_id) {
    throw new ValidationError('Either reporter_id, user_id, or phone is required')
  }

  return {
    image,
    reporter_id: reporter_id || undefined,
    user_id: user_id || undefined,
    phone: phone || undefined,
    lat,
    lng,
    description: sanitizeDescription(trimmedDesc),
    timestamp: timestamp || new Date().toISOString()
  }
}

/**
 * Sanitize description: normalize whitespace, strip control characters
 */
function sanitizeDescription(input: string): string {
  return input
    .replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '')
    .replace(/\s+/g, ' ')
    .trim()
}

/**
 * Validate report submission data (throws ValidationError on failure)
 */
function validateReportSubmission(data: ReportSubmission): void {
  if (!data.image || data.image.size === 0) {
    throw new ValidationError('Image file is required and cannot be empty')
  }

  if (data.image.size > MAX_IMAGE_SIZE_BYTES) {
    throw new ValidationError(`Image must be under ${MAX_IMAGE_SIZE_BYTES / (1024 * 1024)}MB`)
  }

  const type = (data.image.type || '').toLowerCase()
  if (!ALLOWED_IMAGE_TYPES.includes(type)) {
    throw new ValidationError('Image must be JPEG, PNG, or WebP')
  }

  if (data.lat < -90 || data.lat > 90) {
    throw new ValidationError('Latitude must be between -90 and 90')
  }
  if (data.lng < -180 || data.lng > 180) {
    throw new ValidationError('Longitude must be between -180 and 180')
  }

  if (data.description.length < MIN_DESCRIPTION_LENGTH) {
    throw new ValidationError(`Description must be at least ${MIN_DESCRIPTION_LENGTH} characters`)
  }
  if (data.description.length > MAX_DESCRIPTION_LENGTH) {
    throw new ValidationError(`Description must be at most ${MAX_DESCRIPTION_LENGTH} characters`)
  }
}

/**
 * Enforce rate limit: max MAX_REPORTS_PER_HOUR reports per reporter in the last window.
 * Uses reporter_uid on reports table. Throws RateLimitError if over limit.
 */
async function checkRateLimit(supabaseClient: any, reporterUid: string): Promise<void> {
  const since = new Date(Date.now() - RATE_LIMIT_WINDOW_HOURS * 60 * 60 * 1000).toISOString()

  const { count, error } = await supabaseClient
    .from('reports')
    .select('id', { count: 'exact', head: true })
    .eq('reporter_uid', reporterUid)
    .gte('created_at', since)

  if (error) {
    console.warn('Rate limit check failed:', error.message)
    return
  }

  const n = typeof count === 'number' ? count : 0
  if (n >= MAX_REPORTS_PER_HOUR) {
    const retryAfterSeconds = 3600
    throw new RateLimitError(
      `Too many reports. Maximum ${MAX_REPORTS_PER_HOUR} per ${RATE_LIMIT_WINDOW_HOURS} hour(s). Try again later.`,
      retryAfterSeconds
    )
  }
}

/**
 * Upload image to Supabase Storage with deduplication
 */
async function uploadImageToStorageWithDeduplication(
  supabaseClient: any,
  image: File
): Promise<{ imagePath: string; imageHash: string; isDuplicate: boolean }> {
  // Compute image hash
  const arrayBuffer = await image.arrayBuffer()
  const imageHash = await computeImageHash(arrayBuffer)

  // Check if image already exists (deduplication table)
  let existingRecord: {
    id: string
    image_path: string | null
    reference_count: number | null
  } | null = null

  const { data: dedupRecord, error: dedupError } = await supabaseClient
    .from('image_deduplication')
    .select('id, image_path, reference_count')
    .eq('image_hash', imageHash)
    .maybeSingle()

  if (dedupError && dedupError.code !== 'PGRST116') {
    console.warn('Deduplication lookup failed:', dedupError.message)
  } else if (dedupRecord) {
    existingRecord = dedupRecord
  }

  // If we already have an image path stored, reuse it
  if (existingRecord && existingRecord.image_path) {
    console.log('Deduplication hit, reusing existing image', {
      imageHash,
      imagePath: existingRecord.image_path,
      referenceCount: existingRecord.reference_count
    })

    await supabaseClient
      .from('image_deduplication')
      .update({
        reference_count: (existingRecord.reference_count ?? 1) + 1,
        last_accessed_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('id', existingRecord.id)

    return {
      imagePath: existingRecord.image_path,
      imageHash,
      isDuplicate: true
    }
  }

  // No duplicate found or function doesn't exist - upload new image
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
  const fileName = `reports/${timestamp}-${crypto.randomUUID()}.${getFileExtension(image.name)}`
  
  console.log(`Attempting to upload to bucket: reports-images, file: ${fileName}, size: ${image.size} bytes`)
  
  const { data, error } = await supabaseClient.storage
    .from('reports-images')
    .upload(fileName, image, {
      contentType: image.type,
      upsert: false
    })

  if (error) {
    console.error('Storage upload error details:', {
      message: error.message,
      statusCode: error.statusCode,
      error: error.error,
      bucket: 'reports-images',
      fileName: fileName
    })
    throw new Error(`Failed to upload image: ${error.message || error.error || 'Unknown error'}`)
  }
  
  console.log('Image uploaded successfully:', data)

  // Register or update deduplication record with the real image path
  try {
    if (existingRecord) {
      // Record existed but had no path; update it now
      await supabaseClient
        .from('image_deduplication')
        .update({
          image_path: fileName,
          storage_bucket: 'reports-images',
          file_size: image.size,
          reference_count: (existingRecord.reference_count ?? 0) + 1,
          first_reported_at: new Date().toISOString(),
          last_accessed_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        })
        .eq('id', existingRecord.id)
    } else {
      await supabaseClient
        .from('image_deduplication')
        .insert({
          image_hash: imageHash,
          image_path: fileName,
          storage_bucket: 'reports-images',
          file_size: image.size,
          reference_count: 1,
          first_reported_at: new Date().toISOString(),
          last_accessed_at: new Date().toISOString(),
          updated_at: new Date().toISOString()
        })
    }
  } catch (err) {
    console.warn('Failed to register/update image hash:', err)
  }

  return {
    imagePath: fileName,
    imageHash: imageHash,
    isDuplicate: false
  }
}

/**
 * Get file extension from filename
 */
function getFileExtension(filename: string): string {
  return filename.split('.').pop()?.toLowerCase() || 'jpg'
}

/**
 * Get or create reporter record
 */
async function getOrCreateReporter(
  supabaseClient: any,
  data: ReportSubmission
): Promise<{ uid: string; name: string }> {
  // If Supabase auth user ID provided, try to find reporter linked to that user
  if (data.user_id) {
    const { data: reporterByUser, error: userLookupError } = await supabaseClient
      .from('reporter')
      .select('id, name, user_id, phone')
      .eq('user_id', data.user_id)
      .maybeSingle()

    if (userLookupError && userLookupError.code !== 'PGRST116') {
      throw new Error(`Failed to get reporter by user_id: ${userLookupError.message}`)
    }

    if (reporterByUser) {
      // Optionally update phone if newly provided
      if (data.phone && !reporterByUser.phone) {
        await supabaseClient
          .from('reporter')
          .update({ phone: data.phone })
          .eq('id', reporterByUser.id)
      }

      return {
        uid: data.user_id,
        name: reporterByUser.name
      }
    }
  }

  // If reporter_id is provided, get existing reporter
  if (data.reporter_id) {
    const { data: reporter, error } = await supabaseClient
      .from('reporter')
      .select('id, name, user_id')
      .eq('id', data.reporter_id)
      .single()

    if (error && error.code !== 'PGRST116') {
      throw new Error(`Failed to get reporter: ${error.message}`)
    }

    if (reporter) {
      return {
        uid: reporter.user_id || data.reporter_id,
        name: reporter.name
      }
    }
  }

  // If phone is provided, try to find existing reporter by phone
  if (data.phone) {
    const { data: reporter, error } = await supabaseClient
      .from('reporter')
      .select('id, name, user_id')
      .eq('phone', data.phone)
      .single()

    if (error && error.code !== 'PGRST116') {
      throw new Error(`Failed to get reporter by phone: ${error.message}`)
    }

    if (reporter) {
      return {
        uid: reporter.user_id || reporter.id,
        name: reporter.name
      }
    }
  }

  // Create new reporter record
  const reporterName = data.user_id
    ? 'Citizen Reporter'
    : data.phone
      ? `Reporter-${data.phone.slice(-4)}`
      : 'Anonymous'
  
  const { data: newReporter, error: createError } = await supabaseClient
    .from('reporter')
    .insert({
      name: reporterName,
      phone: data.phone || null,
      user_id: data.user_id || null,
      verified: false
    })
    .select()
    .single()

  if (createError) {
    throw new Error(`Failed to create reporter: ${createError.message}`)
  }

  return {
    uid: data.user_id || newReporter.id,
    name: newReporter.name
  }
}

/**
 * Copy classification from an existing report with the same image hash
 * Returns true if classification was copied, false if no suitable report found
 */
async function copyExistingClassification(
  supabaseClient: any,
  imageHash: string,
  newReportId: string
): Promise<boolean> {
  try {
    console.log('🔍 Looking for existing classification for image hash:', imageHash)
    
    // Find a report with the same image hash that has been classified
    const { data: existingReport, error: findError } = await supabaseClient
      .from('reports')
      .select('id, type, confidence, ai_labels, priority, severity, emergency_icon, response_time, status')
      .eq('image_hash', imageHash)
      .not('type', 'is', null)
      .not('status', 'eq', 'pending')
      .order('created_at', { ascending: false })
      .limit(1)
      .maybeSingle()
    
    if (findError) {
      console.warn('Error finding existing classification:', findError)
      return false
    }
    
    if (!existingReport || !existingReport.type) {
      console.log('No existing classification found for this image hash')
      return false
    }
    
    console.log('✅ Found existing classification:', {
      type: existingReport.type,
      confidence: existingReport.confidence,
      priority: existingReport.priority,
      severity: existingReport.severity
    })
    
    // Copy classification fields to new report
    const updateData: any = {
      type: existingReport.type,
      confidence: existingReport.confidence,
      ai_labels: existingReport.ai_labels,
      status: 'classified',
      lifecycle_status: 'classified',
      last_update: new Date().toISOString()
    }
    
    // Copy priority/severity if available
    if (existingReport.priority) updateData.priority = existingReport.priority
    if (existingReport.severity) updateData.severity = existingReport.severity
    if (existingReport.emergency_icon) updateData.emergency_icon = existingReport.emergency_icon
    if (existingReport.response_time) updateData.response_time = existingReport.response_time
    
    const { error: updateError } = await supabaseClient
      .from('reports')
      .update(updateData)
      .eq('id', newReportId)
    
    if (updateError) {
      console.error('Failed to copy classification:', updateError)
      return false
    }
    
    console.log(`✅ Successfully copied classification from existing report to new report ${newReportId}`)
    
    // If it's a critical/high priority report, still notify super users
    if (existingReport.priority <= 2 || existingReport.severity === 'CRITICAL' || existingReport.severity === 'HIGH') {
      console.log('🚨 Critical/High priority duplicate - notifying super users')
      await notifySuperUsersForCriticalReport(supabaseClient, newReportId, existingReport.type, existingReport.priority, existingReport.severity)
    }
    
    return true
  } catch (error) {
    console.error('Error in copyExistingClassification:', error)
    return false
  }
}

/**
 * Notify super users about critical reports
 */
async function notifySuperUsersForCriticalReport(
  supabaseClient: any,
  reportId: string,
  reportType: string,
  priority: number,
  severity: string
): Promise<void> {
  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    
    if (!supabaseUrl || !supabaseServiceKey) {
      console.warn('Supabase URL or Service Key not configured')
      return
    }

    const response = await fetch(`${supabaseUrl}/functions/v1/notify-superusers-critical-report`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${supabaseServiceKey}`
      },
      body: JSON.stringify({
        report_id: reportId,
        report_type: reportType,
        priority: priority,
        severity: severity
      })
    })

    if (!response.ok) {
      const errorText = await response.text()
      console.warn('Failed to notify super users:', response.status, errorText)
    } else {
      console.log('✅ Super users notified about critical duplicate report')
    }
  } catch (error) {
    console.warn('Failed to notify super users:', error)
  }
}

/**
 * Trigger image classification
 */
async function triggerImageClassification(
  supabaseClient: any,
  reportId: string,
  imagePath?: string
): Promise<void> {
  try {
    // Get Supabase URL from environment
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    
    if (!supabaseUrl || !supabaseServiceKey) {
      console.warn('Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY for classification')
      return
    }

    // Call the classify-image function via HTTP
    // Note: classify-image expects reportId and will fetch the report from DB
    // But we can also pass image_path if available to help with timing issues
    const classifyUrl = `${supabaseUrl}/functions/v1/classify-image`
    
    // classify-image only accepts reportId and fetches the report from DB
    // The imagePath parameter is just for logging/debugging
    const requestBody = { reportId: reportId }
    
    const response = await fetch(classifyUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${supabaseServiceKey}`
      },
      body: JSON.stringify(requestBody)
    })

    if (!response.ok) {
      const errorText = await response.text().catch(() => 'Unknown error')
      console.warn(`Failed to trigger classification: HTTP ${response.status} - ${errorText}`)
      // Don't throw error here as classification is not critical for submission
    } else {
      console.log(`Classification triggered successfully for report ${reportId}`)
    }
  } catch (error) {
    // Log but don't throw - classification failure shouldn't block report submission
    console.warn('Error triggering classification (non-critical):', error instanceof Error ? error.message : String(error))
    // Continue execution even if classification fails
  }
}

/**
 * Emit real-time event for new report
 */
async function emitReportCreatedEvent(
  supabaseClient: any,
  report: any
): Promise<void> {
  try {
    const payload = {
      id: report.id,
      status: report.status,
      lifecycle_status: report.lifecycle_status,
      type: report.type,
      lat: report.location?.lat,
      lng: report.location?.lng,
      message: report.message,
      reporter_name: report.reporter_name,
      created_at: report.created_at,
      confidence: report.ai_confidence,
      has_image: !!report.image_path
    }

    // Use realtime broadcast - simplified to avoid httpSend() payload issues
    // The httpSend() method may have different requirements, so we'll use the standard send() method
    // which will automatically fall back to REST API if needed (this is acceptable for non-critical events)
    try {
      const channel = supabaseClient.realtime.channel('public:reports')
      await channel.send({
        type: 'broadcast',
        event: 'report.created',
        payload: payload
      })
    } catch (realtimeError) {
      // Silently ignore realtime errors as they're non-critical
      console.log('Realtime broadcast skipped (non-critical)')
    }

    // Emit to admin channel
    try {
      const adminChannel = supabaseClient.realtime.channel('private:admin')
      const adminPayload = {
        ...payload,
        reporter_uid: report.reporter_uid
      }
      await adminChannel.send({
        type: 'broadcast',
        event: 'report.created',
        payload: adminPayload
      })
    } catch (adminRealtimeError) {
      // Silently ignore realtime errors as they're non-critical
      console.log('Admin realtime broadcast skipped (non-critical)')
    }

  } catch (error) {
    // Log but don't throw - real-time events are not critical for report submission
    console.warn('Failed to emit report created event (non-critical):', error instanceof Error ? error.message : String(error))
    // Don't throw error as real-time events are not critical
  }
}

/**
 * Log audit event
 */
async function logAuditEvent(
  supabaseClient: any,
  event: {
    entity_type: string
    entity_id: string
    action: string
    user_id?: string
    details?: any
  }
): Promise<void> {
  try {
    await supabaseClient
      .from('audit_log')
      .insert({
        entity_type: event.entity_type,
        entity_id: event.entity_id,
        action: event.action,
        user_id: event.user_id,
        details: event.details,
        created_at: new Date().toISOString()
      })
  } catch (error) {
    console.warn('Failed to log audit event:', error)
    // Don't throw error as audit logging is not critical
  }
} 
