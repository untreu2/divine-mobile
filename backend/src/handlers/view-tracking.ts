// ABOUTME: Minimal view tracking handler - increments counters without user data
// ABOUTME: Foundation for future opt-in personalization features

import type { ViewData, ViewRequest, AnalyticsEnv, CreatorData } from '../types/analytics';

export async function handleViewTracking(
  request: Request,
  env: AnalyticsEnv
): Promise<Response> {
  try {
    // Parse request body
    const body = await request.json() as ViewRequest;
    const { 
      eventId, 
      userId,
      source = 'web', 
      creatorPubkey, 
      hashtags, 
      title,
      eventType = 'view_start',
      watchDurationMs,
      totalDurationMs,
      watchDuration, // Alternative field name
      totalDuration, // Alternative field name
      completionRate,
      loopCount,
      completedVideo,
      timestamp 
    } = body;
    
    // Handle both field name formats
    const actualWatchDuration = watchDurationMs ?? watchDuration ?? 0;
    const actualTotalDuration = totalDurationMs ?? totalDuration ?? 0;

    // Validate event ID (64 char hex string)
    if (!eventId || !/^[a-f0-9]{64}$/i.test(eventId)) {
      return new Response(
        JSON.stringify({ error: 'Invalid event ID' }),
        { status: 400, headers: { 'Content-Type': 'application/json' } }
      );
    }

    // NO RATE LIMITING - We want to track ALL usage of our app!

    // Batch KV operations for better performance
    const viewKey = `views:${eventId}`;
    const userViewKey = userId && eventType === 'view_start' ? `user-view:${eventId}:${userId}` : null;
    
    // Parallel fetch of required data
    const [currentData, hasUserViewed] = await Promise.all([
      env.ANALYTICS_KV.get<ViewData>(viewKey, 'json'),
      userViewKey ? env.ANALYTICS_KV.get(userViewKey) : Promise.resolve(null)
    ]);
    
    // Track unique viewers
    let uniqueViewers = currentData?.uniqueViewers || 0;
    let isNewViewer = false;
    
    if (userId && eventType === 'view_start' && !hasUserViewed) {
      // New unique viewer
      isNewViewer = true;
      uniqueViewers += 1;
    }
    
    // Handle different event types
    let newCount = currentData?.count || 0;
    if (eventType === 'view_start') {
      newCount += 1; // Only increment count for new views
    }
    
    const now = Date.now();
    
    // Calculate enhanced engagement metrics
    const newTotalWatchTime = (currentData?.totalWatchTimeMs || 0) + actualWatchDuration;
    const newLoopCount = (currentData?.loopCount || 0) + (loopCount || 0);
    const newCompletedViews = (currentData?.completedViews || 0) + (completedVideo ? 1 : 0);
    const newPauseCount = (currentData?.pauseCount || 0) + (eventType === 'pause' ? 1 : 0);
    const newSkipCount = (currentData?.skipCount || 0) + (eventType === 'skip' ? 1 : 0);
    
    // Preserve existing metadata or use new
    const viewData: ViewData = {
      count: newCount,
      uniqueViewers: uniqueViewers,
      lastUpdate: now,
      hashtags: hashtags || currentData?.hashtags || [],
      creatorPubkey: creatorPubkey || currentData?.creatorPubkey,
      title: title || currentData?.title,
      // Enhanced engagement metrics
      totalWatchTimeMs: newTotalWatchTime,
      completionRate: completionRate || currentData?.completionRate,
      loopCount: newLoopCount,
      completedViews: newCompletedViews,
      pauseCount: newPauseCount,
      skipCount: newSkipCount,
      averageWatchTimeMs: newCount > 0 ? Math.round(newTotalWatchTime / newCount) : 0,
    };

    // Batch all write operations for better performance
    const writeOperations: Promise<void>[] = [];
    
    // 1. Store updated view data
    writeOperations.push(
      env.ANALYTICS_KV.put(viewKey, JSON.stringify(viewData))
    );
    
    // 2. Mark user as having viewed (if new viewer)
    if (userViewKey && isNewViewer) {
      writeOperations.push(
        env.ANALYTICS_KV.put(userViewKey, '1', {
          expirationTtl: 60 * 60 * 24 * 365 // Keep for 1 year
        })
      );
    }
    
    // 3. Track hourly buckets (async, no need to wait for current value)
    const hourBucket = new Date(now).toISOString().slice(0, 13); // YYYY-MM-DDTHH
    const hourKey = `hour:${hourBucket}:${eventId}`;
    // Use atomic increment approach - get current value in background
    writeOperations.push(
      (async () => {
        const hourData = await env.ANALYTICS_KV.get<number>(hourKey);
        await env.ANALYTICS_KV.put(hourKey, String((hourData || 0) + 1), {
          expirationTtl: 60 * 60 * 24 * 31 // Keep hourly data for 31 days
        });
      })()
    );
    
    // Execute core operations in parallel
    await Promise.all(writeOperations);
    
    // Track hashtag and creator metrics asynchronously (don't block response)
    if (hashtags && hashtags.length > 0) {
      // Don't await - run in background
      trackHashtagViews(env, eventId, hashtags).catch(e => 
        console.error('Background hashtag tracking failed:', e)
      );
    }

    if (creatorPubkey && /^[a-f0-9]{64}$/i.test(creatorPubkey)) {
      // Don't await - run in background
      updateCreatorMetrics(env, creatorPubkey, eventId).catch(e =>
        console.error('Background creator metrics failed:', e)
      );
    }

    // Log to console for debugging
    console.log(`${eventType} recorded: ${eventId} from ${source}, total views: ${newCount}, unique viewers: ${uniqueViewers}${isNewViewer ? ' (new viewer)' : ''}`);

    // Return success response
    return new Response(
      JSON.stringify({
        success: true,
        eventId,
        views: newCount,
        // Future: could return personalized recommendations if user opts in
      }),
      {
        status: 200,
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache',
          'Access-Control-Allow-Origin': '*'
        }
      }
    );

  } catch (error) {
    console.error('View tracking error:', error);
    return new Response(
      JSON.stringify({ error: 'Failed to track view' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
}


// Track views for each hashtag
async function trackHashtagViews(env: AnalyticsEnv, eventId: string, hashtags: string[]): Promise<void> {
  try {
    for (const hashtag of hashtags) {
      // Normalize hashtag (lowercase, remove # if present)
      const normalizedTag = hashtag.toLowerCase().replace(/^#/, '');
      
      // Track this video is associated with this hashtag
      const hashtagVideoKey = `hashtag-video:${normalizedTag}:${eventId}`;
      const exists = await env.ANALYTICS_KV.get(hashtagVideoKey);
      if (!exists) {
        await env.ANALYTICS_KV.put(hashtagVideoKey, '1', {
          expirationTtl: 60 * 60 * 24 * 30 // 30 days
        });
      }
      
      // Increment hashtag view counter
      const hashtagViewKey = `hashtag-views:${normalizedTag}`;
      const currentViews = await env.ANALYTICS_KV.get<number>(hashtagViewKey);
      await env.ANALYTICS_KV.put(hashtagViewKey, String((currentViews || 0) + 1));
    }
  } catch (error) {
    console.error('Failed to track hashtag views:', error);
    // Don't fail the whole request if hashtag tracking fails
  }
}

// Update creator metrics when their video gets a view
async function updateCreatorMetrics(env: AnalyticsEnv, creatorPubkey: string, eventId: string): Promise<void> {
  try {
    const creatorKey = `creator:${creatorPubkey}`;
    const currentData = await env.ANALYTICS_KV.get<CreatorData>(creatorKey, 'json');
    
    // Track unique videos this creator has had views on
    const videoSetKey = `creator-videos:${creatorPubkey}`;
    const existingVideos = await env.ANALYTICS_KV.get(videoSetKey);
    let videoIds: string[] = existingVideos ? JSON.parse(existingVideos) : [];
    
    // Add this video if not already tracked
    const isNewVideo = !videoIds.includes(eventId);
    if (isNewVideo) {
      videoIds.push(eventId);
      await env.ANALYTICS_KV.put(videoSetKey, JSON.stringify(videoIds));
    }
    
    // Update creator metrics
    const creatorData: CreatorData = {
      totalViews: (currentData?.totalViews || 0) + 1,
      videoCount: videoIds.length,
      lastUpdate: Date.now()
    };
    
    await env.ANALYTICS_KV.put(creatorKey, JSON.stringify(creatorData));
    
    console.log(`Creator metrics updated: ${creatorPubkey.substring(0, 8)}... - ${creatorData.totalViews} total views, ${creatorData.videoCount} videos`);
  } catch (error) {
    console.error('Failed to update creator metrics:', error);
    // Don't fail the whole request if creator tracking fails
  }
}