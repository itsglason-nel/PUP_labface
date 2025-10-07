#!/bin/bash

# LabFace Camera Test Script
# This script tests RTSP camera connectivity and provides diagnostic information

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CAM_IP=${CAM_IP:-"192.168.1.100"}
CAM_USER=${CAM_USER:-"admin"}
CAM_PASS=${CAM_PASS:-"password"}
CAM_PORT=${CAM_PORT:-"554"}

echo -e "${YELLOW}LabFace Camera Test Script${NC}"
echo "=================================="
echo ""

# Function to test network connectivity
test_network() {
    echo -e "${YELLOW}Testing network connectivity...${NC}"
    
    if ping -c 3 $CAM_IP > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Camera IP $CAM_IP is reachable${NC}"
    else
        echo -e "${RED}✗ Camera IP $CAM_IP is not reachable${NC}"
        echo "Please check:"
        echo "  - Camera is powered on"
        echo "  - Network connection"
        echo "  - IP address is correct"
        return 1
    fi
}

# Function to test RTSP port
test_rtsp_port() {
    echo -e "${YELLOW}Testing RTSP port...${NC}"
    
    if timeout 5 bash -c "</dev/tcp/$CAM_IP/$CAM_PORT" 2>/dev/null; then
        echo -e "${GREEN}✓ RTSP port $CAM_PORT is open${NC}"
    else
        echo -e "${RED}✗ RTSP port $CAM_PORT is not accessible${NC}"
        echo "Please check:"
        echo "  - Camera RTSP service is running"
        echo "  - Firewall settings"
        echo "  - Port number is correct"
        return 1
    fi
}

# Function to test RTSP stream with VLC
test_rtsp_stream() {
    echo -e "${YELLOW}Testing RTSP stream...${NC}"
    
    RTSP_URL="rtsp://$CAM_USER:$CAM_PASS@$CAM_IP:$CAM_PORT/cam/realmonitor?channel=1&subtype=1"
    
    echo "Testing stream: $RTSP_URL"
    
    # Test with VLC (if available)
    if command -v vlc >/dev/null 2>&1; then
        echo "Testing with VLC..."
        timeout 10 vlc --intf dummy --play-and-exit "$RTSP_URL" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ RTSP stream is working${NC}"
        else
            echo -e "${RED}✗ RTSP stream test failed${NC}"
            echo "Please check:"
            echo "  - Camera credentials"
            echo "  - RTSP URL format"
            echo "  - Camera settings"
        fi
    else
        echo -e "${YELLOW}VLC not found, skipping stream test${NC}"
        echo "Install VLC to test RTSP streams:"
        echo "  Ubuntu/Debian: sudo apt install vlc"
        echo "  macOS: brew install vlc"
        echo "  Windows: Download from https://www.videolan.org/"
    fi
}

# Function to test with FFmpeg
test_ffmpeg() {
    echo -e "${YELLOW}Testing with FFmpeg...${NC}"
    
    RTSP_URL="rtsp://$CAM_USER:$CAM_PASS@$CAM_IP:$CAM_PORT/cam/realmonitor?channel=1&subtype=1"
    
    if command -v ffmpeg >/dev/null 2>&1; then
        echo "Testing stream with FFmpeg..."
        timeout 10 ffmpeg -i "$RTSP_URL" -t 5 -f null - > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ FFmpeg can access RTSP stream${NC}"
        else
            echo -e "${RED}✗ FFmpeg stream test failed${NC}"
        fi
    else
        echo -e "${YELLOW}FFmpeg not found, skipping test${NC}"
    fi
}

# Function to test GStreamer
test_gstreamer() {
    echo -e "${YELLOW}Testing with GStreamer...${NC}"
    
    RTSP_URL="rtsp://$CAM_USER:$CAM_PASS@$CAM_IP:$CAM_PORT/cam/realmonitor?channel=1&subtype=1"
    
    if command -v gst-launch-1.0 >/dev/null 2>&1; then
        echo "Testing with GStreamer pipeline..."
        timeout 10 gst-launch-1.0 -v rtspsrc location="$RTSP_URL" protocols=udp latency=0 ! rtph264depay ! h264parse ! fakesink > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ GStreamer can access RTSP stream${NC}"
        else
            echo -e "${RED}✗ GStreamer stream test failed${NC}"
        fi
    else
        echo -e "${YELLOW}GStreamer not found, skipping test${NC}"
        echo "Install GStreamer:"
        echo "  Ubuntu/Debian: sudo apt install gstreamer1.0-tools gstreamer1.0-plugins-*"
        echo "  macOS: brew install gstreamer"
    fi
}

# Function to show recommended settings
show_recommendations() {
    echo ""
    echo -e "${YELLOW}Camera Configuration Recommendations:${NC}"
    echo "====================================="
    echo ""
    echo "1. Network Settings:"
    echo "   - Use wired connection for stability"
    echo "   - Assign static IP address"
    echo "   - Use dedicated VLAN for cameras"
    echo "   - Enable QoS for camera traffic"
    echo ""
    echo "2. Camera Settings:"
    echo "   - Resolution: 640x360 for detection"
    echo "   - Frame rate: 15-30 FPS"
    echo "   - GOP size: 30-60 frames"
    echo "   - Bitrate: 1-2 Mbps for substream"
    echo ""
    echo "3. RTSP Settings:"
    echo "   - Use substream (subtype=1) for detection"
    echo "   - Use main stream (subtype=0) for snapshots"
    echo "   - Enable UDP for lower latency"
    echo "   - Configure TCP fallback"
    echo ""
    echo "4. Security:"
    echo "   - Change default passwords"
    echo "   - Use VPN for remote access"
    echo "   - Enable HTTPS for web interface"
    echo "   - Regular firmware updates"
    echo ""
}

# Function to show GStreamer commands
show_gstreamer_commands() {
    echo ""
    echo -e "${YELLOW}GStreamer Commands for LabFace:${NC}"
    echo "=================================="
    echo ""
    echo "Channel 1 Main Stream:"
    echo "gst-launch-1.0 -v rtspsrc location=\"rtsp://$CAM_USER:$CAM_PASS@$CAM_IP:554/cam/realmonitor?channel=1&subtype=1\" \\"
    echo "  protocols=udp latency=0 ! rtph264depay ! h264parse ! avdec_h264 ! videoconvert ! \\"
    echo "  videoscale ! video/x-raw,width=640,height=360 ! appsink sync=false max-buffers=1 drop=true"
    echo ""
    echo "Channel 2 Main Stream:"
    echo "gst-launch-1.0 -v rtspsrc location=\"rtsp://$CAM_USER:$CAM_PASS@$CAM_IP:554/cam/realmonitor?channel=2&subtype=1\" \\"
    echo "  protocols=udp latency=0 ! rtph264depay ! h264parse ! avdec_h264 ! videoconvert ! \\"
    echo "  videoscale ! video/x-raw,width=640,height=360 ! appsink sync=false max-buffers=1 drop=true"
    echo ""
    echo "With Hardware Acceleration (NVIDIA):"
    echo "gst-launch-1.0 rtspsrc location=\"rtsp://$CAM_USER:$CAM_PASS@$CAM_IP:554/cam/realmonitor?channel=1&subtype=1\" \\"
    echo "  ! rtph264depay ! h264parse ! nvv4l2decoder ! videoconvert ! appsink"
    echo ""
    echo "With Hardware Acceleration (VAAPI):"
    echo "gst-launch-1.0 rtspsrc location=\"rtsp://$CAM_USER:$CAM_PASS@$CAM_IP:554/cam/realmonitor?channel=1&subtype=1\" \\"
    echo "  ! rtph264depay ! h264parse ! avdec_h264 ! videoconvert ! appsink"
    echo ""
}

# Main execution
main() {
    echo "Starting camera diagnostics..."
    echo ""
    
    # Test network connectivity
    if ! test_network; then
        echo -e "${RED}Network test failed. Please fix network issues before proceeding.${NC}"
        exit 1
    fi
    
    # Test RTSP port
    if ! test_rtsp_port; then
        echo -e "${RED}RTSP port test failed. Please check camera configuration.${NC}"
        exit 1
    fi
    
    # Test RTSP stream
    test_rtsp_stream
    
    # Test with FFmpeg
    test_ffmpeg
    
    # Test with GStreamer
    test_gstreamer
    
    # Show recommendations
    show_recommendations
    
    # Show GStreamer commands
    show_gstreamer_commands
    
    echo ""
    echo -e "${GREEN}Camera test completed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Update your .env file with the working camera settings"
    echo "2. Test the LabFace application"
    echo "3. Configure additional cameras as needed"
    echo ""
}

# Run main function
main "$@"
