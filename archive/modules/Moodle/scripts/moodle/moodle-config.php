<?php
unset($CFG);  // Ignore this line
global $CFG;  // This is necessary here for PHPUnit execution
$CFG = new stdClass();
$http_user_agent = $_SERVER['HTTP_USER_AGENT'] ?? '';
if (strstr($http_user_agent, "GoogleHC")) {
    echo "ok";
    die;
}
$CFG->slasharguments = 1; // Turning off slash arguments as a temp fix for "Exception - Call to undefined method HTML_QuickForm_Error::setValue()" error
$CFG->getremoteaddrconf = 1; // to avoid "Installation must be finished from the original IP address, sorry" error
$CFG->allowthemechangeonurl = true; // to allow theme change
$CFG->dbtype    = 'pgsql';      // 'pgsql', 'mariadb', 'mysqli', 'mssql', 'sqlsrv' or 'oci'
$CFG->dblibrary = 'native';     // 'native' only at the moment
$CFG->dbname    = getenv('DB_NAME');     // database name, eg moodle
$CFG->dbuser    = getenv('DB_USER');   // your database username
$CFG->dbpass    = getenv('DB_PASSWORD');   // your database password
$CFG->prefix    = 'mdl_';       // prefix to use for all table names

// Handle DB_HOST - if it starts with /, treat it as a socket path
$raw_db_host = getenv('DB_HOST');
if (strpos($raw_db_host, '/') === 0) {
    $CFG->dbhost = 'localhost';
    $dbsocket = $raw_db_host;
} else {
    $CFG->dbhost = $raw_db_host;
    $dbsocket = false;
}

/**
$CFG->debugdisplay = 1;
$CFG->debug = E_ALL ^ E_DEPRECATED;
$CFG->langstringcache = 0;
$CFG->cachetemplates = 0;
$CFG->cachejs = 0;
$CFG->perfdebug = 15;
$CFG->debugpageinfo = 1;
$CFG->debugsmtp = true;
*/

$CFG->dboptions = array(
    'dbpersist' => false,
    'dbsocket'  => $dbsocket,
    'dbport'    => getenv('DB_PORT'),
    'dbhandlesoptions' => false,
    'dbcollation' => '',
);
$CFG->wwwroot   = getenv('APP_URL');
$CFG->dataroot  = '/gcs/moodle-data';  // Updated to match GCS mount path
$CFG->directorypermissions = 02777;
$CFG->admin = 'admin';
$CFG->reverseproxy = false;
$CFG->sslproxy = true;

// Redis Session Handling and MUC
if (getenv('MOODLE_REDIS_ENABLED') === 'true') {
    $CFG->session_handler_class = '\core\session\redis';
    $CFG->session_redis_host = getenv('MOODLE_REDIS_HOST');
    $CFG->session_redis_port = getenv('MOODLE_REDIS_PORT');
    $CFG->session_redis_auth = getenv('MOODLE_REDIS_PASSWORD');
    $CFG->session_redis_database = 0;
    $CFG->session_redis_prefix = 'moodle_prod_sess_';
    $CFG->session_redis_acquire_lock_timeout = 120;
    $CFG->session_redis_lock_expire = 7200;

    // Note regarding Moodle Universal Cache (MUC):
    // Full MUC offloading typically requires defining stores in 'muc/config.php' or via the GUI.
    // However, enabling Redis for sessions significantly reduces I/O on the shared storage.
}

require_once(dirname(__FILE__) . '/lib/setup.php'); // Do not edit
