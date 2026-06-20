for module in modules/*; do
  if [ -d "$module" ]; then
    for file in "$module"/*.tf; do
      if [ -f "$file" ]; then
        sed -i 's/^\/\*\*/#/' "$file"
        sed -i 's/^ \*\//#/' "$file"
        sed -i 's/^ \*/#/' "$file"
      fi
    done
  fi
done
