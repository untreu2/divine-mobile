// ABOUTME: Type definitions for minimal analytics system
// ABOUTME: Focused on content metrics, no user tracking

export interface ViewData {
  count: number;
  uniqueViewers?: number; // Count of unique user IDs
  lastUpdate: number; // timestamp
  hashtags?: string[]; // Hashtags associated with this video
  creatorPubkey?: string; // Creator's public key
  title?: string; // Video title for display
  // Enhanced engagement metrics
  totalWatchTimeMs?: number; // Total accumulated watch time
  completionRate?: number; // Average completion rate
  loopCount?: number; // Total loops/replays
  completedViews?: number; // Views that watched to completion
  pauseCount?: number; // Number of times paused
  skipCount?: number; // Number of times skipped
  averageWatchTimeMs?: number; // Average watch time per view
  // Future: could add hourly buckets for trend calculation
}

export interface TrendingVideo {
  eventId: string;
  views: number;
  score: number; // calculated trending score
  title?: string; // optional metadata
  hashtags?: string[]; // optional for future hashtag trending
}

export interface TrendingData {
  videos: TrendingVideo[];
  updatedAt: number;
  // Future: could add hashtags, categories, etc.
}

export interface ViewRequest {
  eventId: string;
  userId?: string; // User's Nostr public key for unique viewer tracking
  source?: 'web' | 'mobile' | 'api';
  creatorPubkey?: string; // Optional: track creator metrics
  hashtags?: string[]; // Video hashtags for trending calculation
  title?: string; // Video title
  // Enhanced engagement tracking
  eventType?: 'view_start' | 'view_end' | 'loop' | 'pause' | 'resume' | 'skip';
  watchDurationMs?: number; // How long they actually watched
  totalDurationMs?: number; // Total video length
  watchDuration?: number; // Alternative field name (ms)
  totalDuration?: number; // Alternative field name (ms)
  completionRate?: number; // Percentage watched (0.0 - 1.0)
  loopCount?: number; // Number of times they replayed/looped
  completedVideo?: boolean; // Whether they watched to the end
  timestamp?: string; // ISO timestamp of the event
}

export interface CreatorData {
  totalViews: number;
  videoCount: number;
  lastUpdate: number;
  // Future: could add follower count, engagement metrics
}

export interface TrendingCreator {
  pubkey: string;
  displayName?: string;
  totalViews: number;
  videoCount: number;
  score: number; // calculated trending score
  avgViewsPerVideo: number;
}

export interface AnalyticsEnv {
  ANALYTICS_KV: KVNamespace;
  ANALYTICS_DB?: D1Database; // Optional until we set it up
  ENVIRONMENT: string;
  TRENDING_UPDATE_INTERVAL: string;
  MIN_VIEWS_FOR_TRENDING: string;
  CLEANUP_AUTH_TOKEN?: string;
}

// Time window analytics
export interface TimeWindowStats {
  eventId: string;
  views1h: number;
  views6h: number;
  views24h: number;
  views7d: number;
  views30d: number;
  velocityScore: number;
}

// Hashtag trending data
export interface HashtagTrending {
  hashtag: string;
  timeframe: '1h' | '6h' | '24h' | '7d' | '30d';
  videoCount: number;
  totalViews: number;
  topVideos: TrendingVideo[];
}