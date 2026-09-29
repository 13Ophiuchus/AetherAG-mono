
#!/usr/bin/env bash
set -uo pipefail

echo "================================================================"
echo "1. PATH resolution order for 'swift'"
echo "================================================================"
which -a swift
echo ""
type -a swift

echo ""
echo "================================================================"
echo "2. Check for shell functions/aliases named 'swift'"
echo "================================================================"
declare -f swift 2>/dev/null && echo "-> Found a shell FUNCTION named swift (see above)" || echo "-> No shell function named swift"
alias swift 2>/dev/null && echo "-> Found an ALIAS named swift" || echo "-> No alias named swift"

echo ""
echo "================================================================"
echo "3. Check for version manager shims (swiftenv / asdf / mise)"
echo "================================================================"
for tool in swiftenv asdf mise; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "-> Found $tool at $(command -v $tool)"
  fi
done
echo "PATH entries containing 'swiftenv', 'asdf', or 'mise':"
echo "$PATH" | tr ':' '\n' | grep -Ei 'swiftenv|asdf|mise' || echo "  (none found)"

echo ""
echo "================================================================"
echo "4. Search for .swift-version pin files (cwd up to \$HOME)"
echo "================================================================"
dir="$PWD"
while [ "$dir" != "$HOME" ] && [ "$dir" != "/" ]; do
  if [ -f "$dir/.swift-version" ]; then
    echo "-> FOUND: $dir/.swift-version -> $(cat "$dir/.swift-version")"
  fi
  dir=$(dirname "$dir")
done
[ -f "$HOME/.swift-version" ] && echo "-> FOUND: $HOME/.swift-version -> $(cat "$HOME/.swift-version")"

echo ""
echo "================================================================"
echo "5. Check shell profiles for TOOLCHAINS= or swift shims"
echo "================================================================"
for f in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.bash_profile" "$HOME/.bashrc"; do
  if [ -f "$f" ]; then
    matches=$(grep -nEi 'TOOLCHAINS=|swiftenv|asdf|mise|swift[[:space:]]*\\(\\)|alias swift' "$f")
    if [ -n "$matches" ]; then
      echo "-> $f:"
      echo "$matches"
    fi
  fi
done

echo ""
echo "================================================================"
echo "6. Check current project for a local toolchain/version pin"
echo "================================================================"
[ -f "Package.swift" ] && echo "Package.swift first line:" && head -1 Package.swift
[ -f ".xcode-toolchain" ] && echo ".xcode-toolchain contents:" && cat .xcode-toolchain
find . -maxdepth 2 -name "*.xctoolchain" 2>/dev/null

echo ""
echo "================================================================"
echo "7. Direct binary check (bypasses PATH/shims entirely)"
echo "================================================================"
XCODE_SWIFT="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
if [ -x "$XCODE_SWIFT" ]; then
  "$XCODE_SWIFT" --version
else
  echo "-> Not found at expected path"
fi

echo ""
echo "================================================================"
echo "DONE - review sections 2-6 for anything that intercepted 'swift'"
echo "before it reached XcodeDefault.xctoolchain in section 1/7."
echo "================================================================"
