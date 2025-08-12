# LLM2 Dataset Visualization

A simple web-based viewer for the LLM2 DCQL dataset.

## 🚀 Quick Start

1. Navigate to this directory:
   ```bash
   cd dataset/v2/llm2/visualization
   ```

2. Start the server:
   ```bash
   python3 serve.py
   ```

3. Open your browser and go to:
   ```
   http://localhost:8000/visualization/index.html
   ```

## 🎯 Features

- **Pattern Navigation**: Switch between all 4 pattern types
- **Train/Test Toggle**: View both training and test datasets
- **Example Browser**: Navigate through examples with Previous/Next buttons or arrow keys
- **Target VC Highlighting**: The target VC is highlighted in red
- **Natural Language Display**: Shows the natural language query prominently
- **Formatted VC Display**: VCs are displayed in an easy-to-read card format
- **DCQL Viewer**: Generated DCQL is displayed with syntax highlighting
- **Metadata View**: Shows pattern type, target index, and constraints

## ⌨️ Keyboard Shortcuts

- `←` Previous example
- `→` Next example

## 📱 Mobile Friendly

The viewer is responsive and works on mobile devices.

## 🛠️ Alternative Servers

If you prefer, you can use other HTTP servers:

```bash
# Python (built-in)
python3 -m http.server 8000

# Node.js (if http-server is installed)
npx http-server -p 8000

# PHP
php -S localhost:8000
```

Just make sure to run the server from the `llm2` directory (parent of `visualization`).