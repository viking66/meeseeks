#!/usr/bin/env bash
set -euo pipefail

TEMPLATE_DIR="@templateDir@"
PLACEHOLDER="rambutan"
PLACEHOLDER_CAP="Rambutan"

if [ $# -eq 0 ]; then
  read -rp "Project name (lowercase, e.g. myapp): " PROJECT_NAME
else
  PROJECT_NAME="$1"
fi

if [ -z "$PROJECT_NAME" ]; then
  echo "Error: project name is required"
  exit 1
fi

# Validate: lowercase, no spaces, valid Haskell package name
if ! echo "$PROJECT_NAME" | grep -qE '^[a-z][a-z0-9-]*$'; then
  echo "Error: project name must start with a lowercase letter and contain only lowercase letters, digits, and hyphens"
  exit 1
fi

# Derive module name: capitalize first letter, remove hyphens and capitalize following letters
# e.g. "my-app" -> "MyApp"
MODULE_NAME=$(echo "$PROJECT_NAME" | sed -E 's/(^|-)([a-z])/\U\2/g')

TARGET_DIR="$PROJECT_NAME"

if [ -d "$TARGET_DIR" ]; then
  echo "Error: directory '$TARGET_DIR' already exists"
  exit 1
fi

echo "Creating $PROJECT_NAME..."

# Copy template and make writable (Nix store files are read-only)
cp -r "$TEMPLATE_DIR" "$TARGET_DIR"
chmod -R u+w "$TARGET_DIR"

# Remove any .git if present
rm -rf "$TARGET_DIR/.git"

# Rename files and directories
mv "$TARGET_DIR/rambutan.cabal" "$TARGET_DIR/$PROJECT_NAME.cabal"
mv "$TARGET_DIR/src/Rambutan.hs" "$TARGET_DIR/src/$MODULE_NAME.hs"
mv "$TARGET_DIR/test/Rambutan/RambutanSpec.hs" "$TARGET_DIR/test/Rambutan/${MODULE_NAME}Spec.hs"
mv "$TARGET_DIR/test/Rambutan" "$TARGET_DIR/test/$MODULE_NAME"

# Replace placeholder in all files
find "$TARGET_DIR" -type f | while read -r file; do
  if file "$file" | grep -q text; then
    sed -i "s/$PLACEHOLDER_CAP/$MODULE_NAME/g" "$file"
    sed -i "s/$PLACEHOLDER/$PROJECT_NAME/g" "$file"
  fi
done

# Init git repo
cd "$TARGET_DIR"
git init -q
git add -A
git commit -q -m "Initial commit from meeseeks haskell template"

echo ""
echo "Done! Your project is ready:"
echo ""
echo "  cd $PROJECT_NAME"
echo "  nix develop"
echo "  just build"
echo "  just run"
