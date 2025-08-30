# 🌐 Network Resilience Testing Guide - RandomVideoChat (5SEC)

## 📊 Network Adaptation Features Implemented

### 1. **Automatic Quality Adjustment**
- Real-time network monitoring using iOS Network framework
- Dynamic video resolution scaling (720p → 480p → 360p → 240p)
- Adaptive bitrate control (1200kbps → 800kbps → 400kbps → 200kbps)
- Frame rate optimization (30fps → 24fps → 15fps → 10fps)

### 2. **Network Type Detection**
- WiFi: High quality video (720p, 30fps, 1200kbps)
- 5G/LTE: Medium quality (480p, 24fps, 800kbps)
- Poor Network: Low quality (240p, 15fps, 200kbps)
- No Network: Audio-only fallback mode

### 3. **Connection Recovery**
- Automatic reconnection with exponential backoff
- Up to 5 retry attempts with increasing delays
- Graceful degradation during reconnection
- State preservation across disconnections

## 🧪 Testing Scenarios

### WiFi Testing
```bash
# Test on strong WiFi (>10 Mbps)
1. Start video call on WiFi
2. Verify 720p resolution
3. Monitor bitrate ~1200kbps
4. Check smooth 30fps playback
✅ Expected: High quality video, no interruptions
```

### 5G Testing
```bash
# Test on 5G network
1. Disable WiFi, use 5G
2. Start video call
3. Verify 480p resolution
4. Monitor adaptive bitrate
✅ Expected: Good quality, slight resolution reduction
```

### LTE Testing
```bash
# Test on LTE/4G network
1. Force LTE mode (disable 5G if available)
2. Start video call
3. Observe quality adjustment
4. Monitor bitrate ~800kbps
✅ Expected: Stable connection, medium quality
```

### Poor Network Simulation
```bash
# Using Network Link Conditioner (macOS)
1. Install Network Link Conditioner
2. Set profile: "3G" or "Edge"
3. Start video call
4. Verify auto-switch to 240p
5. Check audio-only fallback
✅ Expected: Maintains connection, reduces to audio if needed
```

### Network Switching Test
```bash
# Test seamless handover
1. Start call on WiFi
2. Disable WiFi (switches to cellular)
3. Monitor reconnection process
4. Re-enable WiFi
5. Verify quality improvement
✅ Expected: Brief reconnection, no call drop
```

### Packet Loss Testing
```bash
# Simulate packet loss
1. Use Network Link Conditioner
2. Set 5% packet loss
3. Start video call
4. Increase to 10% packet loss
5. Check quality degradation
✅ Expected: Automatic quality reduction, maintained connection
```

## 📱 iOS Network Link Conditioner Setup

### Installation
1. Download "Additional Tools for Xcode" from Apple Developer
2. Install "Network Link Conditioner.prefPane"
3. Open System Preferences → Network Link Conditioner

### Preset Profiles
- **100% Loss**: Complete network failure
- **3G**: ~780 Kbps bandwidth
- **DSL**: ~2 Mbps, 5ms delay
- **Edge**: ~240 Kbps bandwidth
- **High Latency DNS**: 3s DNS delay
- **LTE**: ~10 Mbps, 50ms delay
- **Very Bad Network**: 1% packet loss, 500ms delay
- **WiFi**: ~40 Mbps, 1ms delay

### Custom Profile for Testing
```
Profile: "Video Chat Stress Test"
- Downlink: 500 Kbps
- Uplink: 300 Kbps
- Delay: 200ms
- Packet Loss: 3%
```

## 🔍 Debug Console Output

Monitor these logs during testing:
```
📶 Network Status: Connected/Disconnected
📶 Connection Type: WiFi/Cellular/Unknown
📶 Video config updated: 800kbps, 24fps
📶 Local network quality - TX: 2, RX: 1
⚠️ Poor network detected - switching to audio only mode
🔌 Connection state: 3 (reconnecting)
🔄 Reconnection attempt...
```

## 📋 Test Checklist

### Basic Connectivity
- [ ] WiFi connection works
- [ ] 5G connection works
- [ ] LTE/4G connection works
- [ ] 3G fallback works
- [ ] Audio-only mode activates on poor network

### Quality Adaptation
- [ ] Resolution decreases on poor network
- [ ] Frame rate adjusts automatically
- [ ] Bitrate scales with bandwidth
- [ ] Smooth quality transitions

### Connection Recovery
- [ ] Recovers from brief disconnection (<5s)
- [ ] Handles network switching (WiFi↔Cellular)
- [ ] Maintains call during reconnection
- [ ] Resumes video after recovery

### Edge Cases
- [ ] Handles airplane mode toggle
- [ ] Recovers from background/foreground
- [ ] Manages VPN connection changes
- [ ] Handles network congestion

## 🎯 Performance Targets

| Network Type | Resolution | FPS | Bitrate | Latency |
|-------------|------------|-----|---------|---------|
| WiFi | 1280x720 | 30 | 1200kbps | <50ms |
| 5G | 640x480 | 24 | 800kbps | <100ms |
| LTE | 640x360 | 24 | 600kbps | <150ms |
| 3G | 320x240 | 15 | 300kbps | <300ms |
| Poor | Audio Only | - | 64kbps | <500ms |

## 🛠️ Troubleshooting

### Issue: Video freezes on network switch
**Solution**: Check reconnection logic, ensure proper state management

### Issue: Audio continues but video stops
**Solution**: Verify video stream re-subscription after reconnection

### Issue: Call drops on poor network
**Solution**: Implement more aggressive retry logic, extend timeout

### Issue: High CPU usage on poor network
**Solution**: Disable video encoding on very poor connections

## 📈 Monitoring Tools

### Xcode Instruments
- Network Activity
- Energy Impact
- CPU Usage
- Memory Allocations

### Charles Proxy
- Monitor API calls
- Check WebRTC signaling
- Measure bandwidth usage

### Agora Analytics
- Monitor through Agora Console
- Check call quality metrics
- Review error rates

## ✅ Production Readiness

Before deployment, ensure:
1. ✅ All network types tested
2. ✅ Graceful degradation verified
3. ✅ Recovery mechanisms working
4. ✅ User notifications for poor network
5. ✅ Analytics tracking network events
6. ✅ Error reporting configured
7. ✅ Fallback servers available
8. ✅ CDN configured for static assets