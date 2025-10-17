# Route Feed Provider Testing Plan

## Current Implementation Status

### ✅ Completed
- `videosForHashtagRouteProvider` - reactive provider using `select()`
- `videosForProfileRouteProvider` - reactive provider using `select()`
- Keyed buckets in VideoEventService: `_hashtagBuckets`, `_authorBuckets`
- Bucket population in `_addVideoToSubscription()`
- Keyed getters: `hashtagVideos(tag)`, `authorVideos(hex)`

### ❌ Testing Gaps

#### hashtag_feed_providers_test.dart
**Currently tests (3 tests):**
- ✅ Returns empty when route type != hashtag
- ✅ Returns empty when hashtag is empty

**Missing tests:**
- ❌ Verifies `subscribeToHashtagVideos()` is called with correct tag
- ❌ Verifies videos appear when service populates hashtag bucket
- ❌ Verifies provider rebuilds when service calls `notifyListeners()`
- ❌ Verifies only shows videos for specific hashtag (not other tags)

#### profile_feed_providers_test.dart
**Currently tests (3 tests):**
- ✅ Returns empty when route type != profile
- ✅ Returns empty when npub is empty
- ✅ Returns empty when npub is invalid

**Missing tests:**
- ❌ Verifies `subscribeToUserVideos()` is called with correct hex
- ❌ Verifies videos appear when service populates author bucket
- ❌ Verifies provider rebuilds when service calls `notifyListeners()`
- ❌ Verifies only shows videos for specific author (not other authors)

## Test Plan

### Challenge: StreamProvider Async Complexity
The providers watch `pageContextProvider`, which is a `StreamProvider<RouteContext>`. This creates async timing issues in tests.

### Solution: Synchronous Provider Override
Instead of using `Stream.value()` which requires async handling, override with a simple `Provider` that returns the RouteContext directly.

### Test Structure

```dart
// Override pageContextProvider with synchronous Provider
pageContextProvider.overrideWith((ref) {
  return Stream.value(RouteContext(...));
});

// Better: Use a state provider we can control
final testRouteContext = StateProvider<RouteContext?>((ref) => null);
pageContextProvider.overrideWith((ref) {
  final ctx = ref.watch(testRouteContext);
  return Stream.value(ctx);
});
```

### Required Test Cases

#### Hashtag Provider
1. **Subscription Verification**
   - Given: Route has hashtag "nostr"
   - When: Provider is read
   - Then: `subscribeToHashtagVideos(['nostr'])` was called

2. **Initial Empty State**
   - Given: Service has no videos for tag
   - When: Provider is read
   - Then: Returns empty list

3. **Videos Appear**
   - Given: Service populates hashtag bucket
   - When: Service calls notifyListeners()
   - Then: Provider returns those videos

4. **Tag Isolation**
   - Given: Service has videos for tags "nostr" and "bitcoin"
   - When: Route is /hashtag/nostr
   - Then: Only shows "nostr" videos

#### Profile Provider
1. **Subscription Verification**
   - Given: Route has valid npub
   - When: Provider is read
   - Then: `subscribeToUserVideos(hex)` was called

2. **npub to hex Conversion**
   - Given: Route has npub "npub1sg6pl..."
   - When: Provider is read
   - Then: Calls service with hex "8065e9dc..."

3. **Videos Appear**
   - Given: Service populates author bucket
   - When: Service calls notifyListeners()
   - Then: Provider returns those videos

4. **Author Isolation**
   - Given: Service has videos for multiple authors
   - When: Route is /profile/:npub
   - Then: Only shows videos from that author

## Implementation Approach

### Option A: Direct Testing (Current Attempt)
- Override pageContextProvider with Stream.value()
- Wait for stream to emit with `await container.read(pageContextProvider.future)`
- **Problem**: Causes 30-second timeouts

### Option B: Simplified Mocking (Recommended)
- Create FakeVideoEventService that extends ChangeNotifier
- Pre-populate buckets before reading provider
- Don't test reactive rebuilds (too complex with StreamProvider)
- **Trade-off**: Tests data flow but not reactivity

### Option C: Integration Test
- Test with real VideoEventService
- Use actual Nostr events
- **Trade-off**: Slower but more realistic

## Recommendation: Option B + Manual Verification

**Automated Tests (Option B):**
- Verify subscription calls
- Verify correct data selection from buckets
- Verify edge cases

**Manual Verification:**
- Run app and navigate to /hashtag/nostr
- Verify videos appear
- Run app and navigate to /profile/:npub
- Verify profile videos appear

**Rationale:**
- StreamProvider reactivity is complex to test in isolation
- The reactive select pattern is proven in homeFeedProvider (already tested)
- Focus on verifying the new keyed bucket logic works correctly
