// ABOUTME: Quick KV store statistics by checking specific prefixes
// ABOUTME: Faster alternative to full iteration for getting basic counts

/**
 * Get quick statistics about KV store by checking specific prefixes
 */
export async function handleKVQuickStats(
  request: Request,
  env: Env
): Promise<Response> {
  try {
    if (!env.METADATA_CACHE) {
      return new Response(JSON.stringify({
        error: 'METADATA_CACHE namespace not available'
      }), {
        status: 500,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' }
      });
    }

    const prefixes = ['vine_id:', 'filename:', 'sha256:', 'video:', 'vine_url:'];
    const counts: Record<string, number> = {};
    const samples: Record<string, any[]> = {};

    // Count records for each prefix
    for (const prefix of prefixes) {
      console.log(`[KV Quick Stats] Checking prefix: ${prefix}`);
      
      const listResult = await env.METADATA_CACHE.list({
        prefix,
        limit: 10 // Just get a small sample
      });

      counts[prefix] = 0;
      samples[prefix] = [];

      // Count total by checking if we need to paginate
      if (listResult.keys.length > 0) {
        // At least some records exist
        counts[prefix] = listResult.keys.length;
        
        // Get sample values
        for (const key of listResult.keys.slice(0, 3)) {
          try {
            const value = await env.METADATA_CACHE.get(key.name, 'json');
            samples[prefix].push({
              key: key.name,
              value
            });
          } catch (e) {
            // Try as text
            const textValue = await env.METADATA_CACHE.get(key.name);
            samples[prefix].push({
              key: key.name,
              value: textValue
            });
          }
        }

        // If there might be more, indicate it
        if (!listResult.list_complete) {
          counts[prefix] = `${counts[prefix]}+`;
        }
      }
    }

    // Also check for any records without common prefixes
    const allRecords = await env.METADATA_CACHE.list({ limit: 100 });
    const totalSample = allRecords.keys.length;

    const response = {
      prefixCounts: counts,
      samples,
      totalSampleSize: totalSample,
      hasMoreRecords: !allRecords.list_complete,
      debug: {
        namespaceId: '45b500d029d24315bb447a066fe9e9df',
        environment: env.ENVIRONMENT || 'unknown'
      }
    };

    return new Response(JSON.stringify(response, null, 2), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Cache-Control': 'public, max-age=60' // Cache for 1 minute
      }
    });

  } catch (error) {
    console.error('KV quick stats error:', error);
    return new Response(JSON.stringify({
      error: 'Failed to get KV statistics',
      message: error.message
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      }
    });
  }
}

export function handleKVQuickStatsOptions(): Response {
  return new Response(null, {
    status: 200,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type'
    }
  });
}