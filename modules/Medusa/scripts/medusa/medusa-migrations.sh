set -e
echo "Running Medusa migrations..."
npx medusa migrations run
echo "Migrations complete."