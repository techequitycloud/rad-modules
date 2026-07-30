#!/bin/bash
for dir in modules/Bank_GKE modules/MC_Bank_GKE; do
  find $dir -name "*.tf" -exec sed -i -e '1s|^\s*// |# |g' -e '1s|^\s*//|#|g' {} +
done
