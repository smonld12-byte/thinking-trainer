#!/bin/bash
cd "$(dirname "$0")"

echo "🧠 思维训练启动中…"
echo ""

# Kill any existing server on port 8765
lsof -ti:8765 | xargs kill -9 2>/dev/null

# Start Python server in background
python3 -m http.server 8765 &
SERVER_PID=$!

# Wait for server to be ready
sleep 1

# Open browser
open "http://localhost:8765/thinking-trainer.html"

echo "✅ 已在浏览器中打开"
echo "💡 关闭此窗口不会影响使用"
echo "   训练完回来按 Ctrl+C 停止服务器"
echo ""

# Wait for user to press Ctrl+C
trap "kill $SERVER_PID 2>/dev/null; echo '👋 服务器已停止'" EXIT
wait $SERVER_PID
