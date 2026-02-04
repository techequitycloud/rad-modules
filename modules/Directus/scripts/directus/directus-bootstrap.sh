set -e
echo "Waiting for database to be ready..."
sleep 10

echo "Bootstrapping Directus..."
npx directus bootstrap

echo "Bootstrap complete."