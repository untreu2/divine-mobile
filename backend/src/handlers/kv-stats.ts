// ABOUTME: KV store statistics handler to count records and analyze vine data
// ABOUTME: Provides insights into stored vine IDs, filenames, and other metadata

/**
 * Get statistics about KV store contents
 */
export async function handleKVStats(
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

    const stats = {
      totalRecords: 0,
      recordTypes: {
        vineIds: 0,
        filenames: 0,
        sha256Hashes: 0,
        videoMetadata: 0,
        vineUrls: 0,
        other: 0
      },
      uniqueVineIds: new Set<string>(),
      sampleRecords: {
        vineIds: [] as any[],
        filenames: [] as any[],
        other: [] as any[]
      }
    };

    let cursor: string | undefined;
    const BATCH_SIZE = 1000;
    const MAX_ITERATIONS = 100; // Safety limit
    let iterations = 0;

    console.log('[KV Stats] Starting KV statistics collection...');

    // Iterate through all KV records
    for (let i = 0; i < MAX_ITERATIONS; i++) {
      iterations++;
      console.log(`[KV Stats] Iteration ${i + 1}, cursor: ${cursor || 'none'}`);
      
      const listResult = await env.METADATA_CACHE.list({
        limit: BATCH_SIZE,
        cursor
      });

      console.log(`[KV Stats] Retrieved ${listResult.keys.length} keys, list_complete: ${listResult.list_complete}`);

      for (const key of listResult.keys) {
        stats.totalRecords++;

        // Categorize by key prefix
        if (key.name.startsWith('vine_id:')) {
          stats.recordTypes.vineIds++;
          const vineId = key.name.substring(8);
          stats.uniqueVineIds.add(vineId);
          
          // Sample first few vine_id records
          if (stats.sampleRecords.vineIds.length < 5) {
            try {
              const value = await env.METADATA_CACHE.get(key.name, 'json');
              stats.sampleRecords.vineIds.push({
                key: key.name,
                vineId,
                value
              });
            } catch (e) {
              console.error(`[KV Stats] Error reading ${key.name}:`, e);
            }
          }
        } else if (key.name.startsWith('filename:')) {
          stats.recordTypes.filenames++;
          
          // Sample first few filename records
          if (stats.sampleRecords.filenames.length < 5) {
            try {
              const value = await env.METADATA_CACHE.get(key.name, 'json');
              stats.sampleRecords.filenames.push({
                key: key.name,
                filename: key.name.substring(9),
                value
              });
            } catch (e) {
              console.error(`[KV Stats] Error reading ${key.name}:`, e);
            }
          }
        } else if (key.name.startsWith('sha256:')) {
          stats.recordTypes.sha256Hashes++;
        } else if (key.name.startsWith('video:')) {
          stats.recordTypes.videoMetadata++;
        } else if (key.name.startsWith('vine_url:')) {
          stats.recordTypes.vineUrls++;
        } else {
          stats.recordTypes.other++;
          // Sample some "other" records to see what they are
          if (stats.sampleRecords.other.length < 5) {
            try {
              const value = await env.METADATA_CACHE.get(key.name);
              stats.sampleRecords.other.push({
                key: key.name,
                value: typeof value === 'string' ? value.substring(0, 100) : value
              });
            } catch (e) {
              console.error(`[KV Stats] Error reading ${key.name}:`, e);
            }
          }
        }
      }

      cursor = listResult.cursor;
      
      // If no more records, break
      if (listResult.list_complete || !cursor || listResult.keys.length === 0) {
        console.log('[KV Stats] Reached end of records');
        break;
      }
    }

    console.log(`[KV Stats] Total iterations: ${iterations}`);
    console.log(`[KV Stats] Total records found: ${stats.totalRecords}`);

    // Extract unique vines from filenames  
    const uniqueVinesFromFilenames = new Set<string>();
    for (const record of stats.sampleRecords.filenames) {
      const filename = record.filename;
      // Extract the file ID (16 hex chars) from filename
      const match = filename.match(/^([a-fA-F0-9]{16})/);
      if (match) {
        uniqueVinesFromFilenames.add(match[1]);
      }
    }

    const response = {
      summary: {
        totalRecords: stats.totalRecords,
        uniqueVineIds: stats.uniqueVineIds.size,
        uniqueFilenameIds: uniqueVinesFromFilenames.size,
        estimatedTotalVines: Math.max(stats.uniqueVineIds.size, uniqueVinesFromFilenames.size),
        iterationsRun: iterations
      },
      breakdown: stats.recordTypes,
      samples: stats.sampleRecords,
      analysis: {
        hasVideoFiles: stats.recordTypes.filenames > 0,
        hasThumbnails: stats.sampleRecords.filenames.some(f => f.filename.includes('_thumb')),
        kvNamespaceEmpty: stats.totalRecords === 0
      },
      debug: {
        namespaceId: '45b500d029d24315bb447a066fe9e9df',
        environment: env.ENVIRONMENT || 'unknown'
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
    console.error('KV stats error:', error);
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

export function handleKVStatsOptions(): Response {
  return new Response(null, {
    status: 200,
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type'
    }
  });
}