for file in modules/*/*.tf; do
  sed -i 's/\/\/ SECTION/# SECTION/g' "$file"
done
