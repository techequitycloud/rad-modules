# Wordpress Module Technical Features

## Architecture
Deploying WordPress on a stateless container platform like **Cloud Run** requires decoupling the application code from its state. This module achieves this by externalizing the database (**Cloud SQL**) and the media library (**Cloud Storage** or **NFS**).

## Cloud Capabilities

### Stateless Design
- **Media**: Configured to use a Google Cloud Storage plugin (like *WP-Stateless*) or an NFS mount for `wp-content/uploads`. This ensures that when a user uploads an image, it is stored centrally and accessible by all scaled-out container instances.
- **Database**: Connects to Cloud SQL (MySQL).

### Deployment Automation
- **WP-CLI Integration**: The deployment often triggers `wp-cli` commands to install WordPress, set the site URL, and create the initial admin user automatically.
- **Secrets**: Database passwords and salts are managed via **Secret Manager** and injected as environment variables.

### Performance
- **Caching**: Can be configured to use Memorystore (Redis) for object caching (though this basic module focuses on DB/Storage separation).
- **CDN**: ready to sit behind a Global Load Balancer (Cloud CDN) for edge caching.

## Configuration & Enhancement
- **Custom Images**: Technical users can point the `application_version` or image source to a custom Docker image containing specific themes and plugins pre-installed (Immutable Infrastructure approach).
- **Database Tuning**: `mysql_tier` variable allows resizing the DB for high-traffic sites.
