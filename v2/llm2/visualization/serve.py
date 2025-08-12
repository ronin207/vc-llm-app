#!/usr/bin/env python3
"""
Simple HTTP server for viewing the LLM2 dataset visualization.
Run this script and open http://localhost:8000 in your browser.
"""

import http.server
import socketserver
import os
import sys

# Change to the llm2 directory to serve files correctly
os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

PORT = 8000

class MyHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Add CORS headers
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

try:
    with socketserver.TCPServer(("", PORT), MyHTTPRequestHandler) as httpd:
        print(f"🚀 Server started at http://localhost:{PORT}/visualization/")
        print(f"📁 Serving files from: {os.getcwd()}")
        print("\n✨ Open your browser and go to:")
        print(f"   http://localhost:{PORT}/visualization/index.html")
        print("\n⌨️  Press Ctrl+C to stop the server")
        httpd.serve_forever()
except KeyboardInterrupt:
    print("\n👋 Server stopped.")
    sys.exit(0)
except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)