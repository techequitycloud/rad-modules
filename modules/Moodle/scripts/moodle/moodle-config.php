<?php
unset($CFG);
global $CFG;
$CFG = new stdClass();

// Handle Health Checks
$http_user_agent = isset($_SERVER['HTTP_USER_AGENT']) ? $_SERVER['HTTP_USER_AGENT'] : '';
if (strpos($http_user_agent, "GoogleHC") !== false || 
    strpos($http_user_agent, "kube-probe") !== false) {
    http_response_code(200);
    echo "ok";
    die();
}

// Database Configuration
$CFG->dbtype    = getenv('MOODLE_DB_TYPE') ?: 'pgsql';
$CFG->dblibrary = 'native';
$CFG->dbhost    = getenv('MOODLE_DB_HOST') ?: getenv('DB_HOST') ?: 'localhost';
$CFG->dbname    = getenv('MOODLE_DB_NAME') ?: getenv('DB_NAME') ?: 'moodle';
$CFG->dbuser    = getenv('MOODLE_DB_USER') ?: getenv('DB_USER') ?: 'moodle';
$CFG->dbpass    = getenv('MOODLE_DB_PASSWORD') ?: getenv('DB_PASSWORD') ?: '';
$CFG->prefix    = 'mdl_';

$CFG->dboptions = array(
    'dbpersist' => false,
    'dbsocket'  => false,
    'dbport'    => getenv('MOODLE_DB_PORT') ?: getenv('DB_PORT') ?: '5432',
    'dbhandlesoptions' => false,
    'dbcollation' => 'utf8mb4_unicode_ci',
);

// Site Configuration
$app_url = getenv('APP_URL') ?: getenv('MOODLE_URL') ?: 'http://localhost:8080';
$CFG->wwwroot   = rtrim($app_url, '/');
$CFG->dataroot  = '/mnt';
$CFG->directorypermissions = 02770;
$CFG->admin = 'admin';

// Performance settings
$CFG->slasharguments = 1;
$CFG->getremoteaddrconf = 1;
$CFG->allowthemechangeonurl = true;

// Proxy Configuration (Critical for Cloud Run)
$CFG->reverseproxy = (getenv('MOODLE_REVERSE_PROXY') === 'true');
$CFG->sslproxy = true;

// Force HTTPS if behind proxy
if (!empty($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    $_SERVER['HTTPS'] = 'on';
}

// Cron Configuration
$cron_password = getenv('MOODLE_CRON_PASSWORD');
if ($cron_password) {
    $CFG->cronclionly = 0;
    $CFG->cronremotepassword = $cron_password;
}

// Redis Configuration
$redis_host = getenv('MOODLE_REDIS_HOST');
if ($redis_host) {
    // Session handling
    $CFG->session_handler_class = '\core\session\redis';
    $CFG->session_redis_host = $redis_host;
    $CFG->session_redis_port = getenv('MOODLE_REDIS_PORT') ?: 6379;
    $CFG->session_redis_database = 0;
    $CFG->session_redis_prefix = 'moodle_sess_';
    $CFG->session_redis_acquire_lock_timeout = 120;
    $CFG->session_redis_lock_expire = 7200;
}

// SMTP Configuration
$smtp_host = getenv('MOODLE_SMTP_HOST');
if ($smtp_host) {
    $CFG->smtphosts = $smtp_host . ':' . (getenv('MOODLE_SMTP_PORT') ?: '25');
    $CFG->smtpuser = getenv('MOODLE_SMTP_USER') ?: '';
    $CFG->smtppass = getenv('MOODLE_SMTP_PASSWORD') ?: '';
    $CFG->smtpsecure = getenv('MOODLE_SMTP_SECURE') ?: '';
    $CFG->smtpauthtype = getenv('MOODLE_SMTP_AUTH') ?: 'LOGIN';
    $CFG->noreplyaddress = getenv('MOODLE_NOREPLY_ADDRESS') ?: 'noreply@example.com';
}

// Debugging (disable in production)
$debug_mode = getenv('MOODLE_DEBUG');
if ($debug_mode === 'true') {
    @error_reporting(E_ALL | E_STRICT);
    @ini_set('display_errors', '1');
    $CFG->debug = (E_ALL | E_STRICT);
    $CFG->debugdisplay = 1;
} else {
    @error_reporting(E_ALL & ~E_DEPRECATED & ~E_STRICT);
    @ini_set('display_errors', '0');
    $CFG->debug = 0;
    $CFG->debugdisplay = 0;
}

// Performance settings
$CFG->cachejs = true;
$CFG->yuicomboloading = true;

require_once(__DIR__ . '/lib/setup.php');
