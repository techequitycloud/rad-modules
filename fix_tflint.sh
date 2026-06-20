for file in modules/Migration_Center/*.tf; do
  # Replace block comments /** ... */ with # ...
  sed -i 's/^\/\*\*/#/' "$file"
  sed -i 's/^ \*\//#/' "$file"
  sed -i 's/^ \*/#/' "$file"
done
