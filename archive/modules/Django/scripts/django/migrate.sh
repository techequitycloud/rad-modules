if [ -z "$DATABASE_URL" ] && [ -n "$DB_USER" ] && [ -n "$DB_NAME" ]; then
  export DATABASE_URL="postgres://$DB_USER:$DB_PASSWORD@$DB_HOST:${DB_PORT:-5432}/$DB_NAME"
fi
if [ -f manage.py ]; then
  python manage.py migrate
  python manage.py collectstatic --noinput --clear
else
  echo 'manage.py not found, skipping migration'
fi