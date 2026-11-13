#!/usr/bin/env bash
# scripts/replace_money_icons.sh
# Replace every dollar-sign icon in the app with a "KES" CurrencyIcon widget.
#
# Usage:
#   chmod +x scripts/replace_money_icons.sh
#   ./scripts/replace_money_icons.sh
#
# Safety:
#   - Backs up each modified file to <file>.bak
#   - Skips files that don't exist
#   - Adds the import only if missing
#   - Idempotent: re-running on already-converted files is a no-op

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$ROOT/lib"
WIDGET_FILE="$LIB/core/widgets/currency_icon.dart"

echo "▸ Root: $ROOT"

# ─── 1. Ensure the CurrencyIcon widget exists ───
mkdir -p "$(dirname "$WIDGET_FILE")"
if [[ ! -f "$WIDGET_FILE" ]]; then
  echo "▸ Creating $WIDGET_FILE"
  cat > "$WIDGET_FILE" <<'DART'
import 'package:flutter/material.dart';

/// Renders "KES" in the same visual footprint as a Material money icon.
class CurrencyIcon extends StatelessWidget {
  final double size;
  final Color color;
  final FontWeight weight;

  const CurrencyIcon({
    super.key,
    this.size = 22,
    this.color = Colors.white,
    this.weight = FontWeight.w800,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.4,
      height: size * 1.4,
      child: Center(
        child: Text(
          'KES',
          style: TextStyle(
            color: color,
            fontSize: size * 0.6,
            fontWeight: weight,
            letterSpacing: 0.5,
            height: 1,
          ),
        ),
      ),
    );
  }
}
DART
else
  echo "▸ CurrencyIcon already exists — skipping"
fi

# ─── 2. Files to update ───
FILES=(
  "$LIB/features/dashboard/dashboard_screen.dart"
  "$LIB/features/reports/reports_screen.dart"
  "$LIB/features/settings/expense_form_screen.dart"
  "$LIB/features/settings/expenses_screen.dart"
  "$LIB/features/sales/sales_screen.dart"
  "$LIB/features/inventory/adjust_stock_screen.dart"
)

# ─── 3. Icon replacement map (Perl regex, single-quoted) ───
# Each entry: "search_pattern|replacement"
REPLACEMENTS=(
  # Icon(Icons.attach_money, color: X) → CurrencyIcon(color: X)
  's/Icon\(\s*Icons\.attach_money\s*,\s*color:\s*([^,)]+)\s*\)/CurrencyIcon(color: $1)/g|'
  # Icon(Icons.money, color: X) → CurrencyIcon(color: X)
  's/Icon\(\s*Icons\.money\s*,\s*color:\s*([^,)]+)\s*\)/CurrencyIcon(color: $1)/g|'
  # prefixIcon: Icon(Icons.attach_money) → padded CurrencyIcon
  's/prefixIcon:\s*Icon\(\s*Icons\.attach_money\s*\)/prefixIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), child: CurrencyIcon(color: AppTheme.textLight, size: 16))/g|'
  's/prefixIcon:\s*Icon\(\s*Icons\.money\s*\)/prefixIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14), child: CurrencyIcon(color: AppTheme.textLight, size: 16))/g|'
  # Bare Icons.attach_money / Icons.money → CurrencyIcon widget (last resort)
  's/Icons\.attach_money/CurrencyIcon(color: AppTheme.primaryGreen, size: 20)/g|'
  's/Icons\.money/CurrencyIcon(color: AppTheme.primaryGreen, size: 20)/g|'
)

echo "▸ Updating files…"

for f in "${FILES[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "  ⚠ skip (missing): $f"
    continue
  fi

  echo "  • $f"

  # Backup once per run (don't clobber a previous backup on re-run)
  if [[ ! -f "$f.bak" ]]; then
    cp "$f" "$f.bak"
    echo "    · backed up → $(basename "$f").bak"
  fi

  # Apply each regex replacement
  for rule in "${REPLACEMENTS[@]}"; do
    perl -0pi -e "$rule" "$f"
  done

  # Ensure the import is present (only if the file now contains CurrencyIcon)
  if grep -q "CurrencyIcon" "$f" && ! grep -q "core/widgets/currency_icon.dart" "$f"; then
    # Compute the relative prefix based on the file's depth under lib/
    rel_depth=$(echo "$f" | sed "s|$LIB/||" | tr -cd '/' | wc -c)
    rel_prefix=""
    for ((i=0; i<rel_depth; i++)); do rel_prefix+="../"; done
    import_line="import '${rel_prefix}core/widgets/currency_icon.dart';"

    # Use Python to safely insert after the last import line
    python3 - "$f" "$import_line" <<'PY'
import sys

path, line = sys.argv[1], sys.argv[2]

with open(path, 'r', encoding='utf-8') as fh:
    lines = fh.readlines()

last_import = -1
for i, l in enumerate(lines):
    if l.startswith('import '):
        last_import = i

if last_import == -1:
    # No imports at all (very unlikely) — insert at top
    lines.insert(0, line + '\n')
else:
    lines.insert(last_import + 1, line + '\n')

with open(path, 'w', encoding='utf-8') as fh:
    fh.writelines(lines)

print(f"    + added import: {line}")
PY
  fi
done

echo
echo "✅ Done. Original files saved as *.bak"
echo
echo "Next steps:"
echo "  flutter analyze"
echo "  flutter run -d chrome"
echo
echo "Manual follow-ups (see previous message for full details):"
echo "  1. _buildMetricCard in reports_screen.dart: change 'IconData icon' → 'Widget iconWidget'"
echo "  2. _buildHeroCard in dashboard_screen.dart: change 'IconData icon' → 'Widget iconWidget'"
echo "  3. Non-money icons (Icons.trending_up, Icons.receipt_long) inside those cards:"
echo "     keep them, but wrap in 'const Icon(...)' since the signature now expects Widget."