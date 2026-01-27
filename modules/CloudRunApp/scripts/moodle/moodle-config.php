<?php
unset($CFG);  // Ignore this line
global $CFG;  // This is necessary here for PHPUnit execution
$CFG = new stdClass();

// Handle Health Checks
$http_user_agent = isset($_SERVER['HTTP_USER_AGENT']) ? $_SERVER['HTTP_USER_AGENT'] : '';
if (strstr($http_user_agent, "GoogleHC")) {
    echo "ok";
    die;
}

$CFG->slasharguments = 1;
$CFG->getremoteaddrconf = 1;
$CFG->allowthemechangeonurl = true;

// Database Configuration
$CFG->dbtype    = getenv('MOODLE_DB_TYPE') ?: 'pgsql';
$CFG->dblibrary = 'native';
$CFG->dbhost    = getenv('MOODLE_DB_HOST') ?: getenv('DB_HOST');
$CFG->dbname    = getenv('MOODLE_DB_NAME') ?: getenv('DB_NAME');
$CFG->dbuser    = getenv('MOODLE_DB_USER') ?: getenv('DB_USER');
$CFG->dbpass    = getenv('MOODLE_DB_PASSWORD') ?: getenv('DB_PASSWORD');
$CFG->prefix    = 'mdl_';

$CFG->dboptions = array(
    'dbpersist' => false,
    'dbsocket'  => false,
    'dbport'    => getenv('MOODLE_DB_PORT') ?: getenv('DB_PORT'),
    'dbhandlesoptions' => false,
);

// Site Configuration
$CFG->wwwroot   = getenv('APP_URL');
$CFG->dataroot  = '/mnt';
$CFG->directorypermissions = 02770;
$CFG->admin = 'admin';

// Proxy Configuration
$CFG->reverseproxy = getenv('MOODLE_REVERSE_PROXY') === 'true';
$CFG->sslproxy = true;

// Cron Configuration
if (getenv('MOODLE_CRON_PASSWORD')) {
    $CFG->cronclionly = 0;
    $CFG->cron_password = getenv('MOODLE_CRON_PASSWORD');
}

// Redis Configuration
$redis_host = getenv('MOODLE_REDIS_HOST');
if ($redis_host) {
    // Session handling
    $CFG->session_handler_class = '\core\session\redis';
    $CFG->session_redis_host = $redis_host;
    $CFG->session_redis_port = 6379;
    $CFG->session_redis_database = 0;
    $CFG->session_redis_prefix = 'moodle_sess_';
    $CFG->session_redis_acquire_lock_timeout = 120;
    $CFG->session_redis_lock_expire = 7200;

    // Application Cache (MUC)
    // Note: This requires the Moodle site to be installed and the config to be active
    // We define stores here, but usually these are configured in MUC configuration.
    // Defining $CFG->muc_stores allows overriding.
    $CFG->muc_stores = array(
        'redis' => array(
            'name' => 'redis',
            'class' => 'cachestore_redis',
            'configuration' => array(
                'server' => $redis_host,
                'prefix' => 'moodle_muc_',
            ),
            'lock' => 'cachelock_file_default',
        ),
    );
}

// SMTP Configuration
if (getenv('MOODLE_SMTP_HOST')) {
    $CFG->smtphosts = getenv('MOODLE_SMTP_HOST') . ':' . (getenv('MOODLE_SMTP_PORT') ?: '25');
    $CFG->smtpuser = getenv('MOODLE_SMTP_USER');
    $CFG->smtppass = getenv('MOODLE_SMTP_PASSWORD');
    $CFG->smtpsecure = getenv('MOODLE_SMTP_SECURE') ?: '';
    $CFG->smtpauthtype = getenv('MOODLE_SMTP_AUTH') ?: 'LOGIN';
    // Force SMTP as the mailer
    $CFG->mailer = 'smtp';
}

require_once(dirname(__FILE__) . '/lib/setup.php'); // Do not edit
