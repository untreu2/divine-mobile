// ABOUTME: Handler for cleaning up analytics data for deleted/missing videos
// ABOUTME: Removes view counts for videos that haven't been accessed in a long time

import { AnalyticsEnv, ViewData } from '../types/analytics';

// Videos not viewed for 30 days are considered potentially deleted
const STALE_THRESHOLD_MS = 30 * 24 * 60 * 60 * 1000; // 30 days

export async function handleAnalyticsCleanup(
  request: Request,
  env: AnalyticsEnv
): Promise<Response> {
  try {
    const authHeader = request.headers.get('Authorization');
    const expectedToken = env.CLEANUP_AUTH_TOKEN || 'default-cleanup-token';
    
    // Basic auth check for cleanup endpoint
    if (authHeader !== `Bearer ${expectedToken}`) {
      return new Response('Unauthorized', { status: 401 });
    }

    const now = Date.now();
    let cleaned = 0;
    let checked = 0;
    const errors: string[] = [];

    // List all view entries
    const list = await env.ANALYTICS_KV.list({ prefix: 'views:', limit: 1000 });
    
    for (const key of list.keys) {
      checked++;
      try {
        const viewData = await env.ANALYTICS_KV.get<ViewData>(key.name, 'json');
        
        if (viewData) {
          const timeSinceLastView = now - viewData.lastUpdate;
          
          // Remove if not viewed in 30 days
          if (timeSinceLastView > STALE_THRESHOLD_MS) {
            await env.ANALYTICS_KV.delete(key.name);
            cleaned++;
            console.log(`Cleaned stale video analytics: ${key.name} (last viewed ${Math.floor(timeSinceLastView / (24 * 60 * 60 * 1000))} days ago)`);
          }
        }
      } catch (error) {
        errors.push(`Failed to process ${key.name}: ${error instanceof Error ? error.message : String(error)}`);
      }
    }

    // Also clear the trending cache to force recalculation
    await env.ANALYTICS_KV.delete('trending:videos');

    const response = {
      success: true,
      cleaned,
      checked,
      errors: errors.length > 0 ? errors : undefined,
      message: `Cleaned ${cleaned} stale video analytics out of ${checked} checked`
    };

    return new Response(JSON.stringify(response), {
      status: 200,
      headers: { 'Content-Type': 'application/json' }
    });

  } catch (error) {
    console.error('Analytics cleanup error:', error);
    return new Response(
      JSON.stringify({ error: 'Cleanup failed', details: error instanceof Error ? error.message : String(error) }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
}