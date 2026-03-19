#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_NAME="Pokemon Notify"
APP_DIR="$HOME/.claude/$APP_NAME.app"
SPRITES_DIR="$APP_DIR/Contents/Resources/sprites"

echo "🔨 Building Pokemon Notify..."

# Create app bundle structure
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"
mkdir -p "$SPRITES_DIR/shiny"

# Compile Swift source
swiftc "$PROJECT_DIR/Sources/pokemon-notify.swift" \
  -o "$APP_DIR/Contents/MacOS/claude-notify" \
  -framework Cocoa -framework QuartzCore

# Copy Info.plist
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/"

# Generate pokeball cursor
echo "🎨 Generating pokeball cursor..."
python3 "$PROJECT_DIR/scripts/generate_pokeball.py"

# Download Pokemon data if not already present
if [ ! -f "$APP_DIR/Contents/Resources/pokemon_names.json" ]; then
  echo "📥 Downloading Pokemon names..."
  python3 "$PROJECT_DIR/scripts/download_data.py"
fi

# Download sprites if not already present
SPRITE_COUNT=$(ls "$SPRITES_DIR"/*.gif 2>/dev/null | wc -l | tr -d ' ')
if [ "$SPRITE_COUNT" -lt 649 ]; then
  echo "📥 Downloading 649 Pokemon sprites (this may take a minute)..."
  bash "$PROJECT_DIR/scripts/download_sprites.sh"
fi

# Code sign
codesign --force --deep --sign - "$APP_DIR"

echo ""
echo "✅ Pokemon Notify built successfully!"
echo "📍 Installed at: $APP_DIR"
echo ""
echo "Test it with:"
echo "  \"$APP_DIR/Contents/MacOS/claude-notify\" \"MyProject\" \"Test notification\""
echo ""
echo "To use with Claude Code, add this to ~/.claude/settings.json:"
echo '  "hooks": {'
echo '    "Notification": ['
echo '      {'
echo '        "matcher": "permission_prompt",'
echo '        "hooks": [{ "type": "command", "command": "\"'"$APP_DIR"'/Contents/MacOS/claude-notify\" \"$(basename $PWD)\" \"Needs permission\"" }]'
echo '      },'
echo '      {'
echo '        "matcher": "idle_prompt",'
echo '        "hooks": [{ "type": "command", "command": "\"'"$APP_DIR"'/Contents/MacOS/claude-notify\" \"$(basename $PWD)\" \"Waiting for input\"" }]'
echo '      }'
echo '    ]'
echo '  }'
