# make_subdomains.sh - Usage

Generate candidate subdomains from wordlists for reconnaissance. Supports single-prefix (p1.domain) and two-prefix (p1.p2.domain) generation, flexible flags, and direct stdout output for piping into other tools.

## Requirements
awk, sed, sort, mktemp

## Synopsis
```
make_subdomains.sh -w WORDLIST -d DOMAIN \
  [--depth 1|2|both] [-W WORDLIST2] [-o OUTPUT] [--stdout] [-h] [-v]
```
## Flags
Flag	Required	Description
```
-w, --wordlist PATH		First wordlist (prefix1). One prefix per line.
-d, --domain DOMAIN		Base domain, e.g., example.com or testing.internal.example.com.
-W, --wordlist2 PATH		Second wordlist (prefix2). Defaults to --wordlist if omitted.
--depth {1|2|both}		Generation depth; default 1.
-o, --out PATH		Output file path; default ./subdomains.txt. Ignored if --stdout is set.
--stdout		Print results to STDOUT (no file, no footer). Mutually exclusive with -o/--out.
-h, --help		Show help and exit.
-v, --version		Print version and exit.
```
## Behavior & Data Cleaning

1. Trims whitespace, strips CRLFs, lowercases prefixes.

2. Skips blank lines and lines starting with #.

3. Collapses accidental .. into ..

4. Deduplicates output.

5. Creates output directory if it doesn’t exist.

6. If --stdout is present, no file is created and no summary footer is printed.

## Examples

1) Single-prefix list (depth 1) → file
```./make_subdomains.sh \
  -w /opt/wordlists/subdomains.txt \
  -d testing.internal.ackme-corp.net \
  --depth 1
# → writes ./subdomains.txt
```

2) Two-prefix list (depth 2) using the same list for both prefixes
```./make_subdomains.sh \
  -w /opt/wordlists/subdomains.txt \
  -d testing.internal.ackme-corp.net \
  --depth 2 \
  -o results/two_prefixes.txt
```
3) Two-prefix list with different wordlists
```./make_subdomains.sh \
  -w /opt/wordlists/prefixes.txt \
  -W /opt/wordlists/services.txt \
  -d ackme-corp.net \
  --depth 2 \
  -o out/ackme_two_prefixes.txt
```
4) Both depths combined (deduped) → stdout (pipe to a probe)
```./make_subdomains.sh \
  -w subdomains.txt \
  -d ackme-corp.net \
  --depth both \
  --stdout | dnsx -silent
```
5) Generate on the fly with process substitution
```./make_subdomains.sh \
  -w <(printf "www\napi\ncdn\n") \
  -d example.com \
  --depth 1 \
  --stdout
```
## Exit Codes

0 - Success

1 - I/O error (unreadable wordlist, unwritable output, etc.)

2 - Usage error (missing/invalid flags, unknown options, --stdout with --out, etc.)

3 - File size exceeded (use `ulimit -f unlimited` to temporarily create files that can exceed the restricted file size)

## Notes

1. Intended for wordlists with one token per line.

2. Works well piped into massdns, dnsx, httpx, etc.

3. Version: 3.1.0

Tip: For very large wordlists, consider pre-filtering or sharding to manage runtime and memory (e.g., generate --depth 1 first to quickly find live hosts, then expand to --depth 2 on the hits).
