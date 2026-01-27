<?php
unset($CFG);  // Ignore this line
global $CFG;  // This is necessary here for PHPUnit execution
$CFG = new stdClass();
$http_user_agent = $_SERVER['HTTP_USER_AGENT'];
if (strstr($http_user_agent, "GoogleHC")) {
    echo "ok";
    die;
}
$CFG->slasharguments = 1; // Turning off slash arguments as a temp fix for "Exception - Call to undefined method HTML_QuickForm_Error::setValue()" error
$CFG->getremoteaddrconf = 1; // to avoid "Installation must be finished from the original IP address, sorry" error
$CFG->allowthemechangeonurl = true; // to allow theme change
$CFG->dbtype    = 'pgsql';      // 'pgsql', 'mariadb', 'mysqli', 'mssql', 'sqlsrv' or 'oci'
$CFG->dblibrary = 'native';     // 'native' only at the moment
$CFG->dbhost    = getenv('DB_HOST');  // eg 'localhost' or 'db.isp.com' or IP
$CFG->dbname    = getenv('DB_NAME');     // database name, eg moodle
$CFG->dbuser    = getenv('DB_USER');   // your database username
$CFG->dbpass    = getenv('DB_PASSWORD');   // your database password
$CFG->prefix    = 'mdl_';       // prefix to use for all table names

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
    'dbsocket'  => false,
    'dbport'    => getenv('DB_PORT'),
    'dbhandlesoptions' => false,
    'dbcollation' => 'utf8mb4_unicode_ci', 
);
$CFG->wwwroot   = getenv('APP_URL');
$CFG->dataroot  = '/mnt';
$CFG->directorypermissions = 02777;
$CFG->admin = 'admin';
$CFG->reverseproxy = false;
$CFG->sslproxy = true;

require_once(dirname(__FILE__) . '/lib/setup.php'); // Do not edit
