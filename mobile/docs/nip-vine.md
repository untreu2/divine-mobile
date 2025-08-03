# NIP-32222

## Addressable Short Looping Video Events

`draft` `optional`

This specification defines addressable short looping video events for Vine-style content that can be updated after publication.

### Abstract

Kind `32222` events represent short-form looping videos with editable metadata. Unlike regular video events (NIP-71), these are addressable events that can be updated while maintaining the same identifier. They are specifically designed for short, continuously looping video content similar to the former Vine platform.

### Motivation

Short looping videos need different treatment than regular video content:
- Metadata corrections (descriptions, titles, tags) without republishing
- Preservation of imported content IDs from legacy platforms
- Optimized for quick-loading, auto-looping playback
- Support for platform migration tracking

### Event Format

Kind `32222` uses the addressable event range (30000-39999), requiring a `d` tag as a unique identifier.

```json
{
  "kind": 32222,
  "content": "<summary / description of video>",
  "tags": [
    ["d", "<unique-identifier>"],
    ["title", "<title of video>"],
    ["imeta", 
      "url https://example.com/video.mp4",
      "m video/mp4",
      "dim 480x480",
      "blurhash eVF$^OI:${M{%LRjWBoLoLaeR*",
      "image https://example.com/thumb.jpg",
      "x 3093509d1e0bc604ff60cb9286f4cd7c781553bc8991937befaacfdc28ec5cdc"
    ]
    // ... additional tags
  ]
}
```

### Required Tags

- `d` - Unique identifier for this video (user-chosen string)
- `title` - Title of the video
- `imeta` - Video metadata including:
  - At least one image URL for thumbnail
  - `blurhash` property for preview while loading
  - Standard NIP-92 properties (url, m, dim, x, etc.)

### Optional Tags

All optional tags from NIP-71 are supported:
- `published_at` - Original publication timestamp
- `duration` - Video duration in seconds
- `alt` - Accessibility description
- `content-warning` - NSFW/content warnings
- `t` - Hashtags
- `p` - Participants
- `r` - Reference links

Additional tags for imported content:
- `origin` - Track original platform and ID

### Video Data Structure

Videos must use `imeta` tags following NIP-92:

```json
["imeta",
  "url https://video.host/abc123.mp4",
  "m video/mp4",
  "dim 480x480",
  "blurhash eVF$^OI:${M{%LRjWBoLoLaeR*",
  "image https://video.host/abc123-thumb.jpg",
  "fallback https://backup.host/abc123.mp4",
  "x e1d4f808dae475ed32fb23ce52ef8ac82e3cc760702fca10d62d382d2da3697d"
]
```

Multiple `imeta` tags may be included for different resolutions/formats.

### Origin Tracking

For imported content from other platforms:

```json
["origin", "<platform>", "<external-id>", "<original-url>", "<optional-metadata>"]
```

Examples:
```json
["origin", "vine", "hBFP5LFKUOU", "https://vine.co/v/hBFP5LFKUOU"]
["origin", "tiktok", "7158430687982759173", "https://www.tiktok.com/@user/video/7158430687982759173"]
```

### Client Implementation

1. **Playback**: Videos should auto-loop continuously
2. **Preview**: Display blurhash while loading
3. **Updates**: Handle replaceable event updates appropriately
4. **Import**: Use original platform IDs as `d` tag when importing

### Example: Complete Event

```json
{
  "id": "<event-id>",
  "pubkey": "<32-bytes hex>",
  "created_at": 1698789234,
  "kind": 32222,
  "content": "Check out this perfect loop! 🔄",
  "tags": [
    ["d", "hBFP5LFKUOU"],
    ["title", "Perfect soup stirring loop"],
    ["published_at", "1698789234"],
    ["duration", "6"],
    ["alt", "A pot of soup being stirred in a perfect seamless loop"],
    
    ["imeta",
      "url https://videos.host/hBFP5LFKUOU.mp4",
      "m video/mp4",
      "dim 480x480",
      "blurhash eNH_0EI:${M{%LRjWBaeoLofR*",
      "image https://videos.host/hBFP5LFKUOU-thumb.jpg",
      "x 6b4ae19e4eb38db31e672b389eda28c0285b77c547879d0d26f51c3f2894836e"
    ],
    
    ["origin", "vine", "hBFP5LFKUOU", "https://vine.co/v/hBFP5LFKUOU"],
    ["t", "perfectloops"],
    ["t", "satisfying"]
  ],
  "sig": "<signature>"
}
```

### Referencing 

To reference an addressable short looping video:
```json
["a", "32222:<pubkey>:<d-tag-value>", "<relay-url>"]
```