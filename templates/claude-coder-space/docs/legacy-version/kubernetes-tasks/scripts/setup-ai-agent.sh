#!/bin/bash
# AI Agent Setup Script
# This script sets up a basic AI coding assistant in the workspace

set -e

echo "🤖 Setting up AI Agent..."

# Install Claude Code if not present
if ! command -v claude &> /dev/null; then
    echo "📦 Installing Claude Code..."
    npm install -g @anthropic-ai/claude-code
fi

# Set up environment
export ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
export CLAUDE_CODE_WORKDIR="/home/coder/projects"

# Create a simple AI chat interface
cat > /tmp/ai-chat-server.js << 'EOF'
const express = require('express');
const { exec } = require('child_process');
const app = express();

app.use(express.json());

app.get('/', (req, res) => {
    res.send(`
    <!DOCTYPE html>
    <html>
    <head>
        <title>AI Assistant</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .chat { border: 1px solid #ccc; padding: 10px; height: 400px; overflow-y: auto; }
            .input { width: 100%; padding: 10px; margin-top: 10px; }
            button { padding: 10px 20px; margin-top: 10px; }
        </style>
    </head>
    <body>
        <h1>🤖 AI Coding Assistant</h1>
        <div class="chat" id="chat"></div>
        <input type="text" class="input" id="prompt" placeholder="Ask me to help with your code...">
        <button onclick="sendPrompt()">Send</button>

        <script>
            function sendPrompt() {
                const prompt = document.getElementById('prompt').value;
                if (!prompt.trim()) return;

                const chat = document.getElementById('chat');
                chat.innerHTML += '<p><strong>You:</strong> ' + prompt + '</p>';

                // For now, just echo back (replace with actual AI integration)
                setTimeout(() => {
                    chat.innerHTML += '<p><strong>AI:</strong> I understand you want help with: ' + prompt + '. Please run `claude` in your terminal for full AI assistance.</p>';
                    chat.scrollTop = chat.scrollHeight;
                }, 500);

                document.getElementById('prompt').value = '';
            }

            document.getElementById('prompt').addEventListener('keypress', function(e) {
                if (e.key === 'Enter') sendPrompt();
            });
        </script>
    </body>
    </html>
    `);
});

app.listen(3001, () => {
    console.log('AI Chat interface running on http://localhost:3001');
});
EOF

# Install dependencies and start the chat interface
if ! command -v node &> /dev/null; then
    echo "📦 Installing Node.js..."
    # Node should be available in the universal image
fi

npm install express
node /tmp/ai-chat-server.js &

echo "✅ AI Agent setup complete!"
echo "🌐 AI Chat interface: http://localhost:3001"
echo "💻 Run 'claude' in terminal for full AI coding assistance"