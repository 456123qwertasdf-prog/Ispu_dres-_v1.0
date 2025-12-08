// deno-types-ignore
declare const Deno: any;

export type AzureImageAnalysis = {
  raw: any;
  caption: { text: string; confidence: number } | null;
  tags: Array<{ name: string; confidence: number }>;
  objects: Array<{ object: string; confidence: number; boundingBox: { x: number; y: number; w: number; h: number } }>;
  peopleCount: number;
  faces: Array<{ age: number | null; gender: string | null; confidence: number | null; boundingBox: { x: number; y: number; w: number; h: number } }>;
  ocr: Array<{ text: string; confidence: number; boundingBox: { x: number; y: number; w: number; h: number } }>;
  denseCaptions: Array<{ text: string; confidence: number; boundingBox: { x: number; y: number; w: number; h: number } }>;
  adult: { isAdultContent: boolean | null; score: number | null; isMedical: boolean | null; medicalScore: number | null };
  width: number | null;
  height: number | null;
};

export async function analyzeImageWithAzure(imageBytes: ArrayBuffer): Promise<AzureImageAnalysis> {
  const endpoint = Deno.env.get("AZURE_VISION_ENDPOINT") || Deno.env.get("AZURE_VISION_API_ENDPOINT") || "";
  const key = Deno.env.get("AZURE_VISION_KEY") || Deno.env.get("AZURE_VISION_API_KEY") || "";

  if (!endpoint || !key) {
    throw new Error("Missing Azure Vision credentials: set AZURE_VISION_ENDPOINT and AZURE_VISION_KEY");
  }

  // Use only v4-supported features for 2023-10-01
  const features = [
    "Caption",
    "Tags",
    "Objects",
    "Read",
    "DenseCaptions"
  ].join(",");

  const url = `${endpoint}/computervision/imageanalysis:analyze?api-version=2023-10-01&features=${encodeURIComponent(features)}&language=en`;

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Ocp-Apim-Subscription-Key": key,
      "Content-Type": "application/octet-stream"
    },
    body: imageBytes
  });

  if (!res.ok) {
    const txt = await res.text().catch(() => "");
    throw new Error(`Azure analyze failed: ${res.status} ${res.statusText} ${txt}`);
  }

  const raw = await res.json();

  // Normalize outputs
  const captionText = raw?.captionResult?.text ?? null;
  const captionConf = raw?.captionResult?.confidence ?? null;

  const tags = (raw?.tagsResult?.values ?? []).map((t: any) => ({ name: t.name, confidence: t.confidence })) as Array<{ name: string; confidence: number }>;

  const objects = (raw?.objectsResult?.values ?? []).map((o: any) => {
    const bb = o?.boundingBox ?? { x: 0, y: 0, w: 0, h: 0 };
    const name = (o?.tags?.[0]?.name ?? o?.name ?? "object");
    return { object: name, confidence: o?.confidence ?? 0, boundingBox: { x: bb.x ?? 0, y: bb.y ?? 0, w: bb.w ?? 0, h: bb.h ?? 0 } };
  });

  const peopleCount = (raw?.peopleResult?.values ?? []).length || 0;

  const faces = (raw?.facesResult?.values ?? []).map((f: any) => {
    const bb = f?.boundingBox ?? { x: 0, y: 0, w: 0, h: 0 };
    return { age: f?.age ?? null, gender: f?.gender ?? null, confidence: f?.confidence ?? null, boundingBox: { x: bb.x ?? 0, y: bb.y ?? 0, w: bb.w ?? 0, h: bb.h ?? 0 } };
  });

  const readBlocks = raw?.readResult?.blocks ?? [];
  const ocr: Array<{ text: string; confidence: number; boundingBox: { x: number; y: number; w: number; h: number } }> = [];
  for (const block of readBlocks) {
    for (const line of (block?.lines ?? [])) {
      const bb = line?.boundingPolygon ?? [];
      // Convert polygon to bounding box roughly
      const xs = bb.filter((p: any) => p?.x != null).map((p: any) => p.x);
      const ys = bb.filter((p: any) => p?.y != null).map((p: any) => p.y);
      const minX = xs.length ? Math.min(...xs) : 0;
      const minY = ys.length ? Math.min(...ys) : 0;
      const maxX = xs.length ? Math.max(...xs) : 0;
      const maxY = ys.length ? Math.max(...ys) : 0;
      ocr.push({ text: line?.text ?? "", confidence: line?.confidence ?? 0, boundingBox: { x: minX, y: minY, w: Math.max(0, maxX - minX), h: Math.max(0, maxY - minY) } });
    }
  }

  const denseCaptions = (raw?.denseCaptionsResult?.values ?? []).map((d: any) => {
    const bb = d?.boundingBox ?? { x: 0, y: 0, w: 0, h: 0 };
    return { text: d?.text ?? "", confidence: d?.confidence ?? 0, boundingBox: { x: bb.x ?? 0, y: bb.y ?? 0, w: bb.w ?? 0, h: bb.h ?? 0 } };
  });

  const adult = {
    isAdultContent: raw?.adultResult?.isAdultContent ?? null,
    score: raw?.adultResult?.adultScore ?? null,
    isMedical: raw?.adultResult?.isMedical ?? null,
    medicalScore: raw?.adultResult?.medicalScore ?? null
  };

  const width = raw?.metadata?.width ?? null;
  const height = raw?.metadata?.height ?? null;

  return {
    raw,
    caption: captionText ? { text: captionText, confidence: captionConf ?? 0 } : null,
    tags,
    objects,
    peopleCount,
    faces,
    ocr,
    denseCaptions,
    adult,
    width,
    height
  };
}

export function scoreImageQuality(analysis: AzureImageAnalysis): number {
  // Heuristic quality score from signals available
  const signals: number[] = [];
  // Caption confidence
  if (analysis.caption) signals.push(Math.min(1, Math.max(0, analysis.caption.confidence)));
  // Average tag confidence
  if (analysis.tags.length) signals.push(Math.min(1, Math.max(0, analysis.tags.reduce((a, b) => a + b.confidence, 0) / analysis.tags.length)));
  // Object detection presence
  if (analysis.objects.length) signals.push(Math.min(1, Math.max(0, analysis.objects.reduce((a, b) => a + b.confidence, 0) / analysis.objects.length)));
  // OCR presence (lines with confidence)
  if (analysis.ocr.length) signals.push(Math.min(1, Math.max(0, analysis.ocr.reduce((a, b) => a + (b.confidence ?? 0), 0) / analysis.ocr.length)));
  // Dense caption confidence
  if (analysis.denseCaptions.length) signals.push(Math.min(1, Math.max(0, analysis.denseCaptions.reduce((a, b) => a + (b.confidence ?? 0), 0) / analysis.denseCaptions.length)));

  if (!signals.length) return 0.3; // default low
  const avg = signals.reduce((a, b) => a + b, 0) / signals.length;
  // Clamp
  return Math.min(1, Math.max(0, avg));
}

export function normalizeBoundingBox(bb: { x: number; y: number; w: number; h: number }, width: number | null, height: number | null) {
  if (!width || !height || width <= 0 || height <= 0) return { x: 0, y: 0, w: 0, h: 0 };
  return { x: bb.x / width, y: bb.y / height, w: bb.w / width, h: bb.h / height };
}

