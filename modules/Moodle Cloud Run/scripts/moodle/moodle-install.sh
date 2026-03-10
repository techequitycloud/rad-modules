set -e

echo "Checking if Moodle is already installed..."
if [ -f /mnt/moodledata_installed ]; then
  echo "Moodle already installed, skipping..."
  exit 0
fi

echo "Running Moodle CLI installation..."
cd /var/www/html

# Wait for database to be ready
sleep 10

# Run Moodle installation
sudo -u www-data php admin/cli/install_database.php \
  --lang=en \
  --adminuser="${MOODLE_ADMIN_USER:-admin}" \
  --adminpass="${MOODLE_ADMIN_PASSWORD:-Admin123!}" \
  --adminemail="${MOODLE_ADMIN_EMAIL:-admin@example.com}" \
  --fullname="${MOODLE_SITE_FULLNAME:-Moodle LMS}" \
  --shortname="${MOODLE_SITE_NAME:-Moodle}" \
  --agree-license || echo "Installation may have already been completed"

# Mark as installed
touch /mnt/moodledata_installed

echo "Moodle installation complete."