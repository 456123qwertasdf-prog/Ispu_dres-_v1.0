-- Seed HTML tutorial for "Reporting an Emergency" module
-- Migration: 20251031_seed_reporting_emergency_content.sql

UPDATE public.learning_modules
SET content_html = $$
  <div style="padding:16px; line-height:1.6;">
    <h2 style="margin:0 0 8px 0;">Reporting an Emergency</h2>
    <p style="margin:0 0 12px 0; color:#374151;">A short tutorial to practice how the LMS works.</p>

    <h3 style="margin:16px 0 6px 0;">1) Take or Upload a Photo</h3>
    <ul style="margin:0 0 12px 18px; color:#374151;">
      <li>Open the <strong>Emergency Report</strong> form on the dashboard.</li>
      <li>Tap <strong>Emergency Photo</strong> and capture or choose an image of the incident.</li>
      <li>Make sure the image is clear and relevant (e.g., fire, flood, accident).</li>
    </ul>

    <h3 style="margin:16px 0 6px 0;">2) Add Essential Details</h3>
    <ul style="margin:0 0 12px 18px; color:#374151;">
      <li>In <strong>Additional Details</strong>, describe what happened (what/where/when).</li>
      <li>Examples: "Fire at Building 3 lab", "Flooded road near Gate 2".</li>
      <li>Keep it short, factual, and focused on safety-critical info.</li>
    </ul>

    <h3 style="margin:16px 0 6px 0;">3) Get Your Location</h3>
    <ul style="margin:0 0 12px 18px; color:#374151;">
      <li>Click <strong>Get Location</strong>. Allow location permissions if prompted.</li>
      <li>Verify that the detected address matches where the incident is.</li>
      <li>If needed, add specific landmarks in the details field.</li>
    </ul>

    <h3 style="margin:16px 0 6px 0;">4) Submit the Report</h3>
    <ul style="margin:0 0 12px 18px; color:#374151;">
      <li>Press <strong>Submit Emergency Report</strong>.</li>
      <li>The system uploads your photo, saves your details, and triggers AI analysis.</li>
      <li>Admins review and assign responders; you’ll see status updates in <strong>My Reports</strong>.</li>
    </ul>

    <h3 style="margin:16px 0 6px 0;">Practice Task</h3>
    <ol style="margin:0 0 12px 18px; color:#374151;">
      <li>Open the dashboard’s <strong>Emergency Report</strong> form.</li>
      <li>Attach any sample photo from your device (e.g., a non-sensitive image).</li>
      <li>Write a one‑sentence description and click <strong>Get Location</strong>.</li>
      <li>Submit the report to see how statuses change in <strong>My Reports</strong>.</li>
    </ol>

    <div style="margin-top:16px;padding:10px;border-left:4px solid #3b82f6;background:#eff6ff;border-radius:8px;">
      <div style="font-weight:600; margin-bottom:6px;">Tip</div>
      <div style="color:#374151;">If you’re just testing, clearly label the description as <strong>Test Report</strong> so admins can identify it.</div>
    </div>

    <div style="margin-top:16px;padding:10px;border-left:4px solid #10b981;background:#ecfdf5;border-radius:8px;">
      <div style="font-weight:600; margin-bottom:6px;">Mark this module complete</div>
      <div style="color:#065f46;">After reading, close this viewer and click <strong>Mark Completed</strong> on this module.</div>
    </div>
  </div>
$$
WHERE title = 'Reporting an Emergency' AND active = true;


