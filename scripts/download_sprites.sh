#!/bin/bash
# Download all 649 Pokemon sprites (normal + shiny) from PokeAPI
set -e

APP_DIR="$HOME/.claude/Pokemon Notify.app"
SPRITES_DIR="$APP_DIR/Contents/Resources/sprites"

mkdir -p "$SPRITES_DIR/shiny"

echo "Downloading normal sprites..."
for i in $(seq 1 649); do
  curl -sL "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/animated/$i.gif" \
    -o "$SPRITES_DIR/$i.gif" &
  if (( i % 30 == 0 )); then
    wait
    echo "  Normal: $i/649..."
  fi
done
wait

echo "Downloading shiny sprites..."
for i in $(seq 1 649); do
  curl -sL "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/animated/shiny/$i.gif" \
    -o "$SPRITES_DIR/shiny/$i.gif" &
  if (( i % 30 == 0 )); then
    wait
    echo "  Shiny: $i/649..."
  fi
done
wait

NORMAL_COUNT=$(ls "$SPRITES_DIR"/*.gif 2>/dev/null | wc -l | tr -d ' ')
SHINY_COUNT=$(ls "$SPRITES_DIR/shiny/"*.gif 2>/dev/null | wc -l | tr -d ' ')
echo "Done! $NORMAL_COUNT normal sprites, $SHINY_COUNT shiny sprites"
