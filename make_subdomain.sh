#!/usr/bin/env bash
# make_subdomains.sh
# Generate subdomain candidates at depth 1, 2, or both.
#
# Depths:
#   1    => <prefix1>.<domain>
#   2    => <prefix1>.<prefix2>.<domain>
#   both => union of 1 and 2 (deduped)
#
# Examples:
#   ./make_subdomains.sh -w sub.txt -d example.com --depth 1
#   ./make_subdomains.sh -w sub1.txt -W sub2.txt -d example.com --depth 2 -o out.txt
#   ./make_subdomains.sh -w sub.txt -d example.com --depth both --stdout
#
# Notes:
# - With --stdout, output is printed to STDOUT and no summary/footer is printed.
# - If --stdout is given together with -o/--out, this script errors to avoid ambiguity.

set -euo pipefail
VERSION="3.1.0"

usage() {
  cat >&2 <<'EOF'
Usage:
  make_subdomains.sh -w WORDLIST -d DOMAIN [--depth 1|2|both] [-W WORDLIST2] [-o OUTPUT] [--stdout]

Required:
  -w, --wordlist PATH     First wordlist (prefix1)
  -d, --domain  DOMAIN    Base domain, e.g. example.com

Optional:
  -W, --wordlist2 PATH    Second wordlist (prefix2). Defaults to --wordlist.
  --depth {1|2|both}      Generation depth (default: 1)
  -o, --out PATH          Output file (default: ./subdomains.txt)
  --stdout                Print results to STDOUT instead of writing to a file
  -h, --help              Show help and exit
  -v, --version           Show version and exit
EOF
}

WORDLIST=""
WORDLIST2=""
DOMAIN=""
DEPTH="1"
OUT="subdomains.txt"
TO_STDOUT=false

# Parse flags
[[ $# -eq 0 ]] && { echo "Error: no arguments provided." >&2; usage; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--wordlist)   [[ $# -ge 2 ]] || { echo "Error: missing value for $1" >&2; exit 2; }; WORDLIST="$2"; shift 2;;
    -W|--wordlist2)  [[ $# -ge 2 ]] || { echo "Error: missing value for $1" >&2; exit 2; }; WORDLIST2="$2"; shift 2;;
    -d|--domain)     [[ $# -ge 2 ]] || { echo "Error: missing value for $1" >&2; exit 2; }; DOMAIN="$2"; shift 2;;
    --depth)         [[ $# -ge 2 ]] || { echo "Error: missing value for $1" >&2; exit 2; }; DEPTH="$2"; shift 2;;
    -o|--out)        [[ $# -ge 2 ]] || { echo "Error: missing value for $1" >&2; exit 2; }; OUT="$2"; shift 2;;
    --stdout)        TO_STDOUT=true; shift;;
    -h|--help)       usage; exit 0;;
    -v|--version)    echo "make_subdomains.sh v$VERSION"; exit 0;;
    --)              shift; break;;
    -*)              echo "Error: unknown option: $1" >&2; usage; exit 2;;
    *)               echo "Error: unexpected positional argument: $1" >&2; usage; exit 2;;
  esac
done

# Validate required args
[[ -z "${WORDLIST// }" ]] && { echo "Error: --wordlist is required." >&2; usage; exit 2; }
[[ -z "${DOMAIN// }"   ]] && { echo "Error: --domain is required."  >&2; usage; exit 2; }
[[ -z "${WORDLIST2// }" ]] && WORDLIST2="$WORDLIST"

case "$DEPTH" in
  1|2|both) : ;;
  *) echo "Error: --depth must be one of: 1, 2, both" >&2; usage; exit 2;;
esac

# --stdout and --out together? Error to avoid ambiguity.
if $TO_STDOUT && [[ -n "${OUT// }" && "$OUT" != "subdomains.txt" ]]; then
  echo "Error: --stdout and --out are mutually exclusive. Remove one." >&2
  exit 2
fi

# Validate readability (supports process substitution /dev/fd/*)
[[ -r "$WORDLIST"  ]] || { echo "Error: cannot read wordlist at '$WORDLIST'"   >&2; exit 1; }
[[ -r "$WORDLIST2" ]] || { echo "Error: cannot read wordlist2 at '$WORDLIST2'" >&2; exit 1; }

# Build sets into temp files
tmp1="$(mktemp)"; tmp2="$(mktemp)"
cleanup() { rm -f "$tmp1" "$tmp2"; }
trap cleanup EXIT

# Depth 1: <p1>.<domain>
if [[ "$DEPTH" == "1" || "$DEPTH" == "both" ]]; then
  awk -v d="$DOMAIN" '
    function clean(line) {
      sub(/\r$/, "", line); gsub(/^[[:space:]]+|[[:space:]]+$/, "", line);
      return tolower(line);
    }
    {
      l=clean($0); if (l=="" || l ~ /^#/) next;
      print l "." d;
    }
  ' "$WORDLIST" | sed 's/\.\././g' > "$tmp1"
fi

# Depth 2: <p1>.<p2>.<domain>
if [[ "$DEPTH" == "2" || "$DEPTH" == "both" ]]; then
  awk -v d="$DOMAIN" '
    function clean(line) {
      sub(/\r$/, "", line); gsub(/^[[:space:]]+|[[:space:]]+$/, "", line);
      return tolower(line);
    }
    FNR==1 { fileidx++ }
    fileidx==1 {
      l=clean($0); if (l=="" || l ~ /^#/) next;
      p1[n1++]=l; next
    }
    fileidx==2 {
      l=clean($0); if (l=="" || l ~ /^#/) next;
      for (i=0;i<n1;i++) print p1[i] "." l "." d;
    }
  ' "$WORDLIST" "$WORDLIST2" | sed 's/\.\././g' > "$tmp2"
fi

# Combine & dedupe
tmp_out="$(mktemp)"
cat "$tmp1" "$tmp2" 2>/dev/null | sort -u > "$tmp_out"

# Output route: stdout or file
if $TO_STDOUT; then
  # Pure list to STDOUT; no extra summary text
  cat "$tmp_out"
else
  OUTDIR="$(dirname -- "$OUT")"
  mkdir -p -- "$OUTDIR"
  : > "$OUT" 2>/dev/null || { echo "Error: cannot write to '$OUT'" >&2; exit 1; }
  mv "$tmp_out" "$OUT"
  echo "Wrote $(wc -l < "$OUT") subdomains to $OUT"
fi
