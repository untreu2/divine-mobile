// ABOUTME: Service for generating and managing video thumbnails on-demand
// ABOUTME: Handles lazy thumbnail generation, storage in R2, and caching

import { R2UrlSigner } from './r2-url-signer.js';
import { logger } from '../utils/logger.js';

export interface ThumbnailOptions {
  size?: 'small' | 'medium' | 'large';
  timestamp?: number; // Seconds into video
  format?: 'jpg' | 'webp';
}

export interface ThumbnailMetadata {
  videoId: string;
  size: string;
  timestamp: number;
  format: string;
  r2Key: string;
  generatedAt: number;
  streamThumbnailUrl?: string;
}

export interface ThumbnailSizes {
  small: { width: 320, height: 180 };
  medium: { width: 640, height: 360 };
  large: { width: 1280, height: 720 };
}

export class ThumbnailService {
  private readonly r2Bucket: R2Bucket;
  private readonly kvStore: KVNamespace;
  private readonly urlSigner: R2UrlSigner;
  private readonly sizes: ThumbnailSizes = {
    small: { width: 320, height: 180 },
    medium: { width: 640, height: 360 },
    large: { width: 1280, height: 720 }
  };

  constructor(env: Env) {
    this.r2Bucket = env.MEDIA_BUCKET;
    this.kvStore = env.METADATA_CACHE;
    this.urlSigner = new R2UrlSigner(env);
  }

  /**
   * Get or generate a thumbnail for a video
   */
  async getThumbnail(videoId: string, options: ThumbnailOptions = {}): Promise<Response> {
    const startTime = Date.now();
    const { size = 'medium', timestamp = 1, format = 'jpg' } = options;


    try {
      // Check if this is a Nostr event ID (64 char hex) and resolve to fileId
      let actualVideoId = videoId;
      
      if (/^[a-f0-9]{64}$/i.test(videoId)) {
        const eventMapping = await this.kvStore.get<{ fileId: string, videoUrl?: string }>(`event:${videoId}`, 'json');
        
        if (eventMapping?.fileId) {
          actualVideoId = eventMapping.fileId;
        }
      }

      // Check if thumbnail already exists in KV cache
      const cacheKey = this.getCacheKey(actualVideoId, size, timestamp, format);
      const cachedMetadata = await this.kvStore.get<ThumbnailMetadata>(cacheKey, 'json');

      if (cachedMetadata) {
        // Get thumbnail from R2
        const thumbnailObject = await this.r2Bucket.get(cachedMetadata.r2Key);
        if (thumbnailObject) {
          return new Response(thumbnailObject.body, {
            headers: {
              'Content-Type': `image/${format}`,
              'Cache-Control': 'public, max-age=31536000', // 1 year
              'X-Thumbnail-Cached': 'true'
            }
          });
        }
      }

      // Generate new thumbnail
      const thumbnail = await this.generateThumbnail(actualVideoId, size, timestamp, format);
      return thumbnail;
    } catch (error) {
      logger.error('Failed to get thumbnail:', error);
      // Return placeholder image
      return this.getPlaceholderImage();
    }
  }

  /**
   * Generate a new thumbnail from video
   */
  private async generateThumbnail(
    videoId: string, 
    size: 'small' | 'medium' | 'large',
    timestamp: number,
    format: 'jpg' | 'webp'
  ): Promise<Response> {
    // First, try to get video metadata from v1:video pattern (Stream uploads)
    const videoMetadata = await this.kvStore.get(`v1:video:${videoId}`, 'json');
    
    if (videoMetadata) {
      // Check if video was processed by Cloudflare Stream
      if (videoMetadata.stream?.uid) {
        // Use Stream's thumbnail generation API
        return this.generateFromStream(videoId, videoMetadata.stream, size, timestamp, format);
      } else if (videoMetadata.directUpload?.r2Key || videoMetadata.r2Key) {
        // Direct R2 upload - we'll need to handle this differently
        // For now, return a placeholder as we can't process video in Workers
        logger.warn(`Cannot generate thumbnail for direct R2 upload: ${videoId}`);
        return this.getPlaceholderImage();
      }
    }

    // If no v1:video metadata found, check if this is a vine_id lookup
    // Try to find existing thumbnail file for this video
    const existingThumbnail = await this.findExistingThumbnail(videoId);
    if (existingThumbnail) {
      return existingThumbnail;
    }

    // Check if videoId might be a Nostr event ID that needs resolving
    if (/^[a-f0-9]{64}$/i.test(videoId)) {
      const eventMapping = await this.kvStore.get(`event:${videoId}`, 'json');      
      if (eventMapping?.fileId) {
        // Try again with the resolved fileId
        return this.generateThumbnail(eventMapping.fileId, size, timestamp, format);
      }
    }

    logger.warn(`No video metadata or thumbnail found for: ${videoId}`);
    return this.getPlaceholderImage();
  }

  /**
   * Find existing thumbnail file for a video
   */
  private async findExistingThumbnail(videoId: string): Promise<Response | null> {
    try {
      // Try to find vine_id that matches this videoId
      let vineId: string | null = null;
      
      // Check if this is already a vine ID (11 characters, alphanumeric)
      if (videoId.length === 11 && /^[a-zA-Z0-9]+$/.test(videoId)) {
        vineId = videoId;
      } else {
        // Try to extract vine ID from filename-like videoId
        const vineIdMatch = videoId.match(/([a-zA-Z0-9]{11})/);
        if (vineIdMatch) {
          vineId = vineIdMatch[1];
        }
      }
      
      if (vineId) {
        // Look for thumbnail file in vine_id mapping
        const vineMapping = await this.kvStore.get(`vine_id:${vineId}`, 'json');
        
        if (vineMapping && vineMapping.originalFilename?.includes('_thumb')) {
          // Found thumbnail file, serve it from R2
          const r2Key = `uploads/${vineMapping.fileId}.jpg`;
          let thumbnailObject = await this.r2Bucket.get(r2Key);
          
          // If not found with .jpg, try without extension since fileId might already include it
          if (!thumbnailObject) {
            const altR2Key = `uploads/${vineMapping.fileId}`;
            thumbnailObject = await this.r2Bucket.get(altR2Key);
          }
          
          if (thumbnailObject) {
            // Detect content type from object or filename
            const contentType = thumbnailObject.httpMetadata?.contentType || 
                              (vineMapping.originalFilename?.endsWith('.jpg') || vineMapping.originalFilename?.endsWith('.jpeg') ? 'image/jpeg' : 'image/png');
            
            return new Response(thumbnailObject.body, {
              headers: {
                'Content-Type': contentType,
                'Cache-Control': 'public, max-age=31536000', // 1 year
                'X-Thumbnail-Source': 'existing-file',
                'X-Vine-ID': vineId
              }
            });
          }
        }
      }
      
      return null;
    } catch (error) {
      logger.error('Error finding existing thumbnail:', error);
      return null;
    }
  }

  /**
   * Generate thumbnail using Cloudflare Stream API
   */
  private async generateFromStream(
    videoId: string,
    streamData: any,
    size: 'small' | 'medium' | 'large',
    timestamp: number,
    format: 'jpg' | 'webp'
  ): Promise<Response> {
    const { width, height } = this.sizes[size];
    
    // Cloudflare Stream provides thumbnails via their public URL
    // No authentication needed for public thumbnails
    const baseUrl = streamData.thumbnailUrl || streamData.thumbnail || streamData.preview;
    if (!baseUrl) {
      throw new Error('No thumbnail URL available from Stream');
    }
    
    // Stream thumbnail URLs already include the video ID and are parameterized
    // Example: https://customer-xxx.cloudflarestream.com/{uid}/thumbnails/thumbnail.jpg
    const url = new URL(baseUrl);
    
    // Add size and time parameters
    url.searchParams.set('time', `${timestamp}s`);
    url.searchParams.set('width', width.toString());
    url.searchParams.set('height', height.toString());
    
    // Remove any existing format parameter and set our desired format
    url.searchParams.delete('format');
    if (format === 'webp') {
      // Change the extension in the pathname
      url.pathname = url.pathname.replace(/\.jpg$/, '.webp');
    }
    
    // Fetch thumbnail from Stream
    const response = await fetch(url.toString());

    if (!response.ok) {
      throw new Error(`Stream thumbnail generation failed: ${response.status}`);
    }

    const thumbnailBuffer = await response.arrayBuffer();

    // Store in R2 for future use
    const r2Key = this.getR2Key(videoId, size, timestamp, format);
    await this.r2Bucket.put(r2Key, thumbnailBuffer, {
      httpMetadata: {
        contentType: `image/${format}`
      },
      customMetadata: {
        videoId,
        size,
        timestamp: timestamp.toString(),
        generatedAt: Date.now().toString()
      }
    });

    // Cache metadata in KV
    const metadata: ThumbnailMetadata = {
      videoId,
      size,
      timestamp,
      format,
      r2Key,
      generatedAt: Date.now(),
      streamThumbnailUrl: url.toString()
    };

    const cacheKey = this.getCacheKey(videoId, size, timestamp, format);
    await this.kvStore.put(cacheKey, JSON.stringify(metadata), {
      expirationTtl: 60 * 60 * 24 * 30 // 30 days
    });

    return new Response(thumbnailBuffer, {
      headers: {
        'Content-Type': `image/${format}`,
        'Cache-Control': 'public, max-age=31536000',
        'X-Thumbnail-Generated': 'true'
      }
    });
  }

  /**
   * Upload a custom thumbnail
   */
  async uploadCustomThumbnail(
    videoId: string,
    thumbnailData: ArrayBuffer,
    format: 'jpg' | 'webp' = 'jpg'
  ): Promise<string> {
    const r2Key = this.getR2Key(videoId, 'custom', 0, format);
    
    await this.r2Bucket.put(r2Key, thumbnailData, {
      httpMetadata: {
        contentType: `image/${format}`
      },
      customMetadata: {
        videoId,
        type: 'custom',
        uploadedAt: Date.now().toString()
      }
    });

    // Generate signed URL for the thumbnail
    const signedUrl = await this.urlSigner.signUrl(r2Key, 60 * 60 * 24 * 365); // 1 year

    // Update video metadata to include custom thumbnail
    const videoMetadata = await this.kvStore.get(`v1:video:${videoId}`, 'json');
    if (videoMetadata) {
      videoMetadata.customThumbnailUrl = signedUrl;
      await this.kvStore.put(`v1:video:${videoId}`, JSON.stringify(videoMetadata));
    }

    return signedUrl;
  }

  /**
   * List available thumbnails for a video
   */
  async listThumbnails(videoId: string): Promise<ThumbnailMetadata[]> {
    const prefix = `thumbnail:${videoId}:`;
    const list = await this.kvStore.list({ prefix });
    
    const thumbnails: ThumbnailMetadata[] = [];
    for (const key of list.keys) {
      const metadata = await this.kvStore.get<ThumbnailMetadata>(key.name, 'json');
      if (metadata) {
        thumbnails.push(metadata);
      }
    }

    return thumbnails;
  }

  /**
   * Delete all thumbnails for a video
   */
  async deleteThumbnails(videoId: string): Promise<void> {
    // List all thumbnails
    const thumbnails = await this.listThumbnails(videoId);

    // Delete from R2
    for (const thumbnail of thumbnails) {
      await this.r2Bucket.delete(thumbnail.r2Key);
    }

    // Delete from KV
    const prefix = `thumbnail:${videoId}:`;
    const list = await this.kvStore.list({ prefix });
    for (const key of list.keys) {
      await this.kvStore.delete(key.name);
    }
  }

  /**
   * Get cache key for thumbnail metadata
   */
  private getCacheKey(videoId: string, size: string, timestamp: number, format: string): string {
    return `thumbnail:${videoId}:${size}:${timestamp}:${format}`;
  }

  /**
   * Get R2 object key for thumbnail
   */
  private getR2Key(videoId: string, size: string, timestamp: number, format: string): string {
    return `thumbnails/${videoId}/${size}_t${timestamp}.${format}`;
  }

  /**
   * Get a placeholder image when thumbnail generation fails
   */
  private getPlaceholderImage(): Response {
    // Simple SVG placeholder
    const svg = `
      <svg width="640" height="360" xmlns="http://www.w3.org/2000/svg">
        <rect width="640" height="360" fill="#1a1a1a"/>
        <text x="320" y="180" font-family="Arial" font-size="24" fill="#666" text-anchor="middle" dy=".3em">
          Video Thumbnail
        </text>
      </svg>
    `;

    return new Response(svg, {
      headers: {
        'Content-Type': 'image/svg+xml',
        'Cache-Control': 'public, max-age=3600' // 1 hour
      }
    });
  }
}