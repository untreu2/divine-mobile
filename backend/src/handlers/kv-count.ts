// ABOUTME: Simple KV store record counter
// ABOUTME: Counts total records and by prefix efficiently

/**
 * Count KV store records efficiently
 */
export async function handleKVCount(
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

    // Count total records
    let totalRecords = 0;
    let cursor: string | undefined;
    const BATCH_SIZE = 1000;
    let iterations = 0;

    while (iterations < 1000) { // Safety limit
      const listResult = await env.METADATA_CACHE.list({
        limit: BATCH_SIZE,
        cursor
      });

      totalRecords += listResult.keys.length;
      iterations++;
      
      cursor = listResult.cursor;

      if (listResult.list_complete || !cursor) {
        break;
      }
    }

    // Count specific prefixes
    const prefixCounts: Record<string, number> = {};
    const prefixes = ['vine_id:', 'filename:', 'sha256:'];
    
    for (const prefix of prefixes) {
      let count = 0;
      cursor = undefined;
      iterations = 0;
      
      while (iterations < 100) {
        const listResult = await env.METADATA_CACHE.list({
          prefix,
          limit: BATCH_SIZE,
          cursor
        });

        count += listResult.keys.length;
        iterations++;
        
        cursor = listResult.cursor;

        if (listResult.list_complete || !cursor) {
          break;
        }
      }
      
      prefixCounts[prefix] = count;
    }

    // Estimate unique vines
    const estimatedVines = Math.floor(prefixCounts['filename:'] / 2); // Each vine has .mp4 and _thumb.jpg

    const response = {
      totalRecords,
      prefixCounts,
      analysis: {
        estimatedUniqueVines: estimatedVines,
        averageFilesPerVine: prefixCounts['filename:'] > 0 ? prefixCounts['filename:'] / estimatedVines : 0
      }
    };

    return new Response(JSON.stringify(response, null, 2), {
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Cache-Control': 'public, max-age=300' // Cache for 5 minutes
      }
    });

  } catch (error) {
    console.error('KV count error:', error);
    return new Response(JSON.stringify({
      error: 'Failed to count KV records',
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

export function handleKVCountOptions(): Response {
  return new Response(null, {
    status: 200,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type'
    }
  });
}