const ffmpeg = require("fluent-ffmpeg");
const path = require("path");
const fs = require("fs");
const os = require("os");
const { saveToLocal } = require("./localStorage");

// ─────────────────────────────────────────────────────────────────────────────
// Quality presets
// ─────────────────────────────────────────────────────────────────────────────
const VIDEO_QUALITIES = {
  // These define the *maximum* dimensions for each quality level.
  // The actual output resolution will maintain the aspect ratio.
  low: { max_dim: 640, bitrate: "500k", audioBitrate: "64k" }, // Max dimension (width or height) is 640px
  medium: { max_dim: 1280, bitrate: "1500k", audioBitrate: "128k" }, // Max dimension is 1280px
  high: { max_dim: 1920, bitrate: "3000k", audioBitrate: "192k" }, // Max dimension is 1920px
};

function safeName(filename) {
  const ext = require('path').extname(filename).toLowerCase() || '.mp4';
  // Keep only ASCII letters, numbers, dash, underscore, dot
  const base = require('path')
    .basename(filename, ext)
    .replace(/[^\x00-\x7F]/g, '')      // strip non-ASCII (Arabic etc.)
    .replace(/[^a-zA-Z0-9\-_.]/g, '_') // replace remaining unsafe chars
    .replace(/_{2,}/g, '_')             // collapse multiple underscores
    .replace(/^_+|_+$/g, '')           // trim leading/trailing underscores
    || 'video';                         // fallback if everything stripped
  return base + ext;
}
 

// ─────────────────────────────────────────────────────────────────────────────
// Get video metadata including rotation
// ─────────────────────────────────────────────────────────────────────────────
function getVideoMetadata(filePath) {
  return new Promise((resolve, reject) => {
    ffmpeg.ffprobe(filePath, (err, data) => {
      if (err) return reject(err);
      const vs = data.streams.find((s) => s.codec_type === "video");
      const as = data.streams.find((s) => s.codec_type === "audio");

      // ── Detect rotation from every possible location ──
      let rotation = 0;
      if (vs) {
        // 1. tags.rotate (most common for mobile videos)
        if (vs.tags?.rotate) {
          rotation = parseInt(vs.tags.rotate, 10);
        }
        // 2. side_data_list display matrix
        else if (vs.side_data_list) {
          const dm = vs.side_data_list.find(
            (sd) => sd.side_data_type === "Display Matrix"
          );
          if (dm?.rotation != null) {
            rotation = parseInt(dm.rotation, 10);
          }
        }
      }

      resolve({
        rotation,
        width: vs?.width || 0,
        height: vs?.height || 0,
        duration: data.format.duration,
        videoCodec: vs?.codec_name,
        audioCodec: as?.codec_name,
        size: data.format.size,
        originalResolution: `${vs?.width || 0}x${vs?.height || 0}`,
        originalDuration: data.format.duration,
        originalCodec: vs?.codec_name,
      });
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Build the correct vf filter string for a given rotation + target dimensions
//
// This function now dynamically calculates scaling to maintain aspect ratio
// without forcing a specific output resolution if the aspect ratios differ.
// It prioritizes fitting the video within the target dimensions while preserving
// the original aspect ratio, and then pads if necessary.
// ─────────────────────────────────────────────────────────────────────────────
function buildVideoFilter(rotation, originalWidth, originalHeight, maxDimension) {
  const filters = [];
  let effectiveWidth  = originalWidth;
  let effectiveHeight = originalHeight;
 
  // Step 1 – rotation
  if (rotation === 90 || rotation === -270) {
    filters.push('transpose=1');
    effectiveWidth  = originalHeight;
    effectiveHeight = originalWidth;
  } else if (rotation === -90 || rotation === 270) {
    filters.push('transpose=2');
    effectiveWidth  = originalHeight;
    effectiveHeight = originalWidth;
  } else if (rotation === 180 || rotation === -180) {
    filters.push('hflip,vflip');
  }
 
  // Step 2 – scale (NO extra quotes around min() — they break on some ffmpeg builds)
  if (effectiveWidth > maxDimension || effectiveHeight > maxDimension) {
    if (effectiveWidth >= effectiveHeight) {
      // landscape: limit width
      filters.push(`scale=min(${maxDimension}\\,iw):-2`);
    } else {
      // portrait: limit height
      filters.push(`scale=-2:min(${maxDimension}\\,ih)`);
    }
  } else {
    filters.push('scale=iw:ih');
  }
 
  // Step 3 – pixel format
  filters.push('format=yuv420p');
 
  return filters.join(',');
}

// ─────────────────────────────────────────────────────────────────────────────
// Generate thumbnail (returns Buffer)
// ─────────────────────────────────────────────────────────────────────────────
async function generateThumbnail(videoPath) {
  const ffmpeg = require('fluent-ffmpeg');
  const path   = require('path');
  const fs     = require('fs');
  const os     = require('os');
  const crypto = require('crypto');
 
  // Use a guaranteed-safe path (no original filename involved)
  const tmpDir  = os.tmpdir();
  const tmpName = `squad_thumb_${crypto.randomBytes(8).toString('hex')}.jpg`;
  const tmpPath = path.join(tmpDir, tmpName);
 
  const tryExtract = (timemark) =>
    new Promise((resolve, reject) => {
      ffmpeg(videoPath)
        .screenshots({
          count: 1,
          timemarks: [timemark],
          filename: tmpName,
          folder: tmpDir,
        })
        .on('end', () => {
          try {
            if (!fs.existsSync(tmpPath)) return reject(new Error('Thumbnail file missing'));
            const buffer = fs.readFileSync(tmpPath);
            try { fs.unlinkSync(tmpPath); } catch (_) {}
            resolve(buffer);
          } catch (e) {
            reject(e);
          }
        })
        .on('error', reject);
    });
 
  // Try 1s → 0s → ffmpeg seek approach
  try {
    return await tryExtract('1');
  } catch (_) {
    try {
      return await tryExtract('0');
    } catch (err2) {
      throw new Error(`generateThumbnail failed: ${err2.message}`);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Process video: compress to 3 quality levels with correct orientation
// ─────────────────────────────────────────────────────────────────────────────
async function processAndUploadVideo(videoPath, originalFilename, folder = 'posts/media') {
  const ffmpeg      = require('fluent-ffmpeg');
  const path        = require('path');
  const fs          = require('fs');
  const os          = require('os');
  const { saveToLocal } = require('./localStorage');
 
  // ── 0. Validate input ────────────────────────────────────────────────────
  if (!videoPath) throw new Error('processAndUploadVideo: videoPath is required');
  if (!fs.existsSync(videoPath)) throw new Error(`processAndUploadVideo: file not found at ${videoPath}`);
 
  const VIDEO_QUALITIES = {
    low:    { max_dim: 640,  bitrate: '500k',  audioBitrate: '64k'  },
    medium: { max_dim: 1280, bitrate: '1500k', audioBitrate: '128k' },
    high:   { max_dim: 1920, bitrate: '3000k', audioBitrate: '192k' },
  };
 
  // ── 1. Build safe base name ───────────────────────────────────────────────
  const safe   = safeName(originalFilename || 'video.mp4');
  const ext    = path.extname(safe).toLowerCase();
  const base   = path.basename(safe, ext);
  const unique = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
  const tempDir = path.join(os.tmpdir(), `squad-video-${unique}`);
 
  console.log(`[VideoProcessor] Start: originalFilename="${originalFilename}" → safe="${safe}"`);
 
  try {
    if (!fs.existsSync(tempDir)) fs.mkdirSync(tempDir, { recursive: true });
 
    // ── 2. Read metadata ──────────────────────────────────────────────────
    let meta;
    try {
      meta = await getVideoMetadata(videoPath);
      console.log(`[VideoProcessor] Metadata: ${meta.width}x${meta.height} rotation=${meta.rotation}`);
    } catch (metaErr) {
      throw new Error(`[VideoProcessor] getVideoMetadata failed: ${metaErr.message}`);
    }
 
    // ── 3. Thumbnail ──────────────────────────────────────────────────────
    let thumbUrl = null;
    try {
      const thumbBuf = await generateThumbnail(videoPath);
      const safeBuf  = Buffer.isBuffer(thumbBuf) ? thumbBuf : Buffer.from(thumbBuf);
      thumbUrl = saveToLocal(safeBuf, `${folder}/thumbnails/${base}-${unique}.jpg`);
      console.log(`[VideoProcessor] Thumbnail saved: ${thumbUrl}`);
    } catch (thumbErr) {
      // Non-fatal — a missing thumbnail is acceptable
      console.warn(`[VideoProcessor] Thumbnail failed (non-fatal): ${thumbErr.message}`);
    }
 
    const result = {
      thumbnail: thumbUrl,
      qualities: {},
      metadata: {
        originalDuration: meta.duration,
        originalCodec:    meta.videoCodec,
        originalResolution: `${meta.width}x${meta.height}`,
        originalSize:     meta.size,
        processedAt:      new Date().toISOString(),
      },
    };
 
    // ── 4. Compress each quality — isolated try/catch per quality ─────────
    for (const [qName, q] of Object.entries(VIDEO_QUALITIES)) {
      // Use ONLY safe ASCII in output path — this is what caused error 234
      const outPath = path.join(tempDir, `${base}-${qName}${ext === '.mp4' ? '.mp4' : '.mp4'}`);
 
      let vf;
      try {
        vf = buildVideoFilter(meta.rotation, meta.width, meta.height, q.max_dim);
      } catch (filterErr) {
        console.error(`[VideoProcessor] buildVideoFilter failed for ${qName}: ${filterErr.message}`);
        result.qualities[qName] = { url: null, error: filterErr.message };
        continue;
      }
 
      console.log(`[VideoProcessor] Processing ${qName}: vf="${vf}" → ${outPath}`);
 
      try {
        await new Promise((resolve, reject) => {
          ffmpeg(videoPath)
            .videoCodec('libx264')
            .audioCodec('aac')
            .outputOptions([
              '-preset veryfast',
              '-crf 28',
              '-movflags +faststart',
              '-pix_fmt yuv420p',
              '-metadata:s:v rotate=0',
              '-map_metadata -1',
              '-map_metadata:s:a 0:s:a',
            ])
            .videoFilters(vf)
            .videoBitrate(q.bitrate)
            .audioBitrate(q.audioBitrate)
            .audioChannels(2)
            .audioFrequency(44100)
            .format('mp4')
            .on('progress', (p) => {
              if (p.percent) process.stdout.write(`\r  [${qName}] ${Math.round(p.percent)}%`);
            })
            .on('end', () => {
              process.stdout.write('\n');
              resolve();
            })
            .on('error', (err) => {
              process.stdout.write('\n');
              reject(new Error(`ffmpeg ${qName} error: ${err.message}`));
            })
            .save(outPath);  // <-- outPath is now guaranteed ASCII
        });
 
        // Verify output file exists and has content
        if (!fs.existsSync(outPath)) {
          throw new Error(`Output file missing after ffmpeg: ${outPath}`);
        }
        const stat = fs.statSync(outPath);
        if (stat.size === 0) {
          throw new Error(`Output file is empty: ${outPath}`);
        }
 
        const buf = fs.readFileSync(outPath);
        const url = saveToLocal(buf, `${folder}/videos/${qName}/${base}-${unique}.mp4`);
 
        // Get output metadata (non-fatal if it fails)
        let outputMeta = { width: 0, height: 0 };
        try {
          outputMeta = await getVideoMetadata(outPath);
        } catch (_) {}
 
        result.qualities[qName] = {
          url,
          resolution: `${outputMeta.width}x${outputMeta.height}`,
          size: buf.length,
          bitrate: q.bitrate,
        };
 
        console.log(`[VideoProcessor] ✅ ${qName}: ${(buf.length / 1024 / 1024).toFixed(1)}MB → ${url}`);
 
        // Clean up quality file immediately to save disk
        try { fs.unlinkSync(outPath); } catch (_) {}
 
      } catch (qErr) {
        console.error(`[VideoProcessor] ❌ ${qName} failed: ${qErr.message}`);
        result.qualities[qName] = { url: null, error: qErr.message };
        // Continue to next quality — don't abort everything
      }
    }
 
    // ── 5. Verify at least one quality succeeded ──────────────────────────
    const successCount = Object.values(result.qualities).filter(q => q.url).length;
    if (successCount === 0) {
      throw new Error('[VideoProcessor] All quality levels failed. Check ffmpeg logs above.');
    }
 
    console.log(`[VideoProcessor] Done: ${successCount}/3 qualities succeeded`);
    return result;
 
  } finally {
    // Always clean up temp dir
    try {
      fs.rmSync(tempDir, { recursive: true, force: true });
      console.log(`[VideoProcessor] Temp dir cleaned: ${tempDir}`);
    } catch (cleanErr) {
      console.warn(`[VideoProcessor] Temp dir cleanup failed: ${cleanErr.message}`);
    }
  }
}
 
// Export — replace the existing module.exports in your videoProcessor.js
module.exports = {
  processAndUploadVideo,
  getVideoMetadata,   // keep your existing getVideoMetadata unchanged
  generateThumbnail,
  buildVideoFilter,
  safeName,
  VIDEO_QUALITIES: {
    low:    { max_dim: 640,  bitrate: '500k',  audioBitrate: '64k'  },
    medium: { max_dim: 1280, bitrate: '1500k', audioBitrate: '128k' },
    high:   { max_dim: 1920, bitrate: '3000k', audioBitrate: '192k' },
  },
};
 
module.exports = {
  processAndUploadVideo,
  getVideoMetadata,
  generateThumbnail,
  VIDEO_QUALITIES,
};