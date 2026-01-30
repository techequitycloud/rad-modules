<?php  // Moodle configuration file

unset($CFG);
global $CFG;
$CFG = new stdClass();

// Database configuration
$CFG->dbtype    = '{{MOODLE_DB_TYPE}}';
$CFG->dblibrary = 'native';
$CFG->dbhost    = '{{MOODLE_DB_HOST}}';
$CFG->dbname    = '{{MOODLE_DB_NAME}}';
$CFG->dbuser    = '{{MOODLE_DB_USER}}';
$CFG->dbpass    = '{{MOODLE_DB_PASS}}';
$CFG->prefix    = '{{MOODLE_DB_PREFIX}}';
$CFG->dboptions = array (
  'dbpersist' => 0,
  'dbport' => '',
  'dbsocket' => '',
  'dbcollation' => 'utf8mb4_unicode_ci',
);

// Web address configuration
$CFG->wwwroot   = '{{MOODLE_WWW_ROOT}}';
$CFG->dataroot  = '{{MOODLE_DATA_DIR}}';
$CFG->admin     = 'admin';

$CFG->directorypermissions = 0770;

// Redis session configuration (if enabled)
if (!empty('{{REDIS_HOST}}')) {
    $CFG->session_handler_class = '\core\session\redis';
    $CFG->session_redis_host = '{{REDIS_HOST}}';
    $CFG->session_redis_port = {{REDIS_PORT}};
    $CFG->session_redis_database = 0;
    $CFG->session_redis_prefix = 'moodle_sess_';
    $CFG->session_redis_acquire_lock_timeout = 120;
    $CFG->session_redis_lock_expire = 7200;
    $CFG->session_redis_serializer_use_igbinary = false;
}

// Redis cache configuration (MUC - Moodle Universal Cache)
if (!empty('{{REDIS_HOST}}')) {
    $CFG->alternative_cache_factory_class = 'cache_factory';
}

// Performance settings
$CFG->cachejs = true;
$CFG->yuicomboloading = true;
$CFG->enablegravatar = false;

// Security settings
$CFG->passwordpolicy = 1;
$CFG->minpasswordlength = 8;
$CFG->minpassworddigits = 1;
$CFG->minpasswordlower = 1;
$CFG->minpasswordupper = 1;
$CFG->minpasswordnonalphanum = 1;

// Reverse proxy configuration (for Cloud Run)
$CFG->reverseproxy = true;
$CFG->sslproxy = true;

// Email configuration
$CFG->noreplyaddress = 'noreply@example.com';

// Debugging (disable in production)
$CFG->debug = 0;
$CFG->debugdisplay = 0;
$CFG->debugsmtp = 0;

// Logging
$CFG->loginhttps = false; // Set to true if using HTTPS
$CFG->cookiesecure = false; // Set to true if using HTTPS

require_once(__DIR__ . '/lib/setup.php');

// There is no php closing tag in this file,
// it is intentional because it prevents trailing whitespace problems!
