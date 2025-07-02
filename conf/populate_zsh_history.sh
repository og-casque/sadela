#!/bin/bash

#set -euo pipefail

INPUT_FILE="commands.txt"
OUTPUT_FILE="zsh_history"
BASE_TS=171000000

> "$OUTPUT_FILE"  # Vide le fichier s'il existe

i=0
while IFS= read -r cmd || [[ -n "$cmd" ]]; do
  ts=$((BASE_TS + i))
  echo ": ${ts}:0;${cmd}" >> "$OUTPUT_FILE"
  ((i++))
done < "$INPUT_FILE"

echo "✅ Fichier $OUTPUT_FILE généré avec $(wc -l < "$OUTPUT_FILE") commandes."

