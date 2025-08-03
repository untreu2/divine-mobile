// ABOUTME: Debug script to check video metadata keys for thumbnails
// ABOUTME: Helps identify why thumbnail generation is failing

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const videoId = url.searchParams.get('videoId') || '1753764858668-00941579';
    
    const results: Record<string, any> = {};
    
    // Check different key patterns that might exist
    const keyPatterns = [
      `v1:video:${videoId}`,
      `video:${videoId}`,
      `${videoId}`,
      `file:${videoId}`,
      `metadata:${videoId}`
    ];
    
    for (const key of keyPatterns) {
      try {
        const value = await env.METADATA_CACHE.get(key, 'json');
        if (value) {
          results[key] = value;
        } else {
          results[key] = null;
        }
      } catch (e) {
        results[key] = `Error: ${e.message}`;
      }
    }
    
    // Also check vine_id mapping
    try {
      const vineMapping = await env.METADATA_CACHE.get('vine_id:00941579178', 'json');
      results['vine_id:00941579178'] = vineMapping;
    } catch (e) {
      results['vine_id:00941579178'] = `Error: ${e.message}`;
    }
    
    return new Response(JSON.stringify(results, null, 2), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  }
};