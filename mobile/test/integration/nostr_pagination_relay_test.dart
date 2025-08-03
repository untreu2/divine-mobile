// ABOUTME: Test real pagination requests against relay3.openvine.co
// ABOUTME: Debug exactly what happens with 'until' parameter for historical events

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

void main() async {
  print('🔍 Testing pagination against relay3.openvine.co...\n');
  
  WebSocket? socket;
  final List<Map<String, dynamic>> receivedEvents = [];
  
  try {
    // Connect to relay3.openvine.co
    print('1. Connecting to wss://relay3.openvine.co...');
    socket = await WebSocket.connect('wss://relay3.openvine.co');
    print('✅ Connected!\n');
    
    // Listen for messages
    socket.listen((message) {
      final data = jsonDecode(message);
      print('📨 Received: ${data[0]} ${data.length > 1 ? data[1] : ""}');
      
      if (data[0] == 'EVENT') {
        final event = data[2];
        receivedEvents.add(event);
        final timestamp = event['created_at'];
        final eventId = (event['id'] as String).substring(0, 8);
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
        print('   📺 Event $eventId created: $date');
      } else if (data[0] == 'EOSE') {
        print('   ⏹️ End of stored events\n');
      } else if (data[0] == 'NOTICE') {
        print('   📢 Notice: ${data[1]}');
      }
    });
    
    // Step 1: Get initial batch of recent events
    print('2. Getting initial 10 recent events...');
    final req1 = jsonEncode([
      'REQ',
      'initial_test',
      {
        'kinds': [22],
        'limit': 10
      }
    ]);
    socket.add(req1);
    print('   📤 Sent: $req1\n');
    
    // Wait for initial events
    await Future.delayed(Duration(seconds: 3));
    
    if (receivedEvents.isEmpty) {
      print('❌ No events received! Relay might be empty or not responding.');
      return;
    }
    
    // Sort events by timestamp to find oldest
    receivedEvents.sort((a, b) => (a['created_at'] as int).compareTo(b['created_at'] as int));
    final oldestEvent = receivedEvents.first;
    final oldestTimestamp = oldestEvent['created_at'] as int;
    final oldestDate = DateTime.fromMillisecondsSinceEpoch(oldestTimestamp * 1000);
    final oldestId = (oldestEvent['id'] as String).substring(0, 8);
    
    print('📊 Initial batch stats:');
    print('   Total events: ${receivedEvents.length}');
    print('   Oldest event: $oldestId at $oldestDate (timestamp: $oldestTimestamp)\n');
    
    // Step 2: Try to get older events using 'until'
    print('3. Requesting events OLDER than $oldestDate using until=${oldestTimestamp - 1}...');
    
    // Clear previous subscription
    socket.add(jsonEncode(['CLOSE', 'initial_test']));
    await Future.delayed(Duration(milliseconds: 100));
    
    final untilTimestamp = oldestTimestamp - 1;
    final req2 = jsonEncode([
      'REQ', 
      'pagination_test',
      {
        'kinds': [22],
        'until': untilTimestamp,
        'limit': 10
      }
    ]);
    
    socket.add(req2);
    print('   📤 Sent: $req2\n');
    
    // Wait for pagination results
    final int eventCountBefore = receivedEvents.length;
    await Future.delayed(Duration(seconds: 5));
    final int eventCountAfter = receivedEvents.length;
    final int newEvents = eventCountAfter - eventCountBefore;
    
    print('📊 Pagination results:');
    print('   Events before pagination: $eventCountBefore');
    print('   Events after pagination: $eventCountAfter');
    print('   New events loaded: $newEvents');
    
    if (newEvents > 0) {
      print('✅ SUCCESS: Pagination worked! Got $newEvents older events');
      
      // Show details of new events
      final newEventsList = receivedEvents.skip(eventCountBefore).toList();
      for (final event in newEventsList) {
        final timestamp = event['created_at'] as int;
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
        final eventId = (event['id'] as String).substring(0, 8);
        print('   📺 New event $eventId: $date');
      }
    } else {
      print('❌ PROBLEM: No older events found!');
      print('   This could mean:');
      print('   - No older events exist on the relay');
      print('   - The "until" parameter is not working correctly');
      print('   - There is a bug in our pagination logic');
    }
    
    // Step 3: Test edge case - what if we ask for WAY older events?
    print('\n4. Testing edge case: requesting events from 30 days ago...');
    final thirtyDaysAgo = DateTime.now().subtract(Duration(days: 30)).millisecondsSinceEpoch ~/ 1000;
    
    socket.add(jsonEncode(['CLOSE', 'pagination_test']));
    await Future.delayed(Duration(milliseconds: 100));
    
    final req3 = jsonEncode([
      'REQ',
      'old_test', 
      {
        'kinds': [22],
        'until': thirtyDaysAgo,
        'limit': 5
      }
    ]);
    
    socket.add(req3);
    print('   📤 Sent: $req3');
    
    await Future.delayed(Duration(seconds: 3));
    print('   Done with old events test\n');
    
  } catch (e) {
    print('❌ Error: $e');
  } finally {
    socket?.close();
    print('🔌 Connection closed');
  }
}