<?php
require_once('/var/www/localhost/htdocs/openemr/vendor/autoload.php');
// Set up default configuration settings using environment variables
$installSettings = array();
$installSettings['iuser']                    = getenv('OE_USER') ?: 'admin'; // Default to 'admin' if not set
$installSettings['iuname']                   = 'Administrator';
$installSettings['iuserpass']                = getenv('OE_PASS') ?: 'admin'; // Default to 'admin' if not set
$installSettings['igroup']                   = 'Default';
$installSettings['server']                   = getenv('MYSQL_HOST') ?: 'localhost'; // Default to 'localhost' if not set
$installSettings['loginhost']                = 'localhost'; // php/apache server
$installSettings['port']                     = getenv('MYSQL_PORT') ?: '3306'; // Default to '3306' if not set
$installSettings['root']                     = 'root';
$installSettings['rootpass']                 = getenv('MYSQL_ROOT_PASS') ?: ''; // Default to empty if not set
$installSettings['login']                    = getenv('MYSQL_USER') ?: 'openemr'; // Default to 'openemr' if not set
$installSettings['pass']                     = getenv('MYSQL_PASS') ?: 'openemr'; // Default to 'openemr' if not set
$installSettings['dbname']                   = getenv('MYSQL_DATABASE') ?: 'openemr'; // Default to 'openemr' if not set
$installSettings['collate']                  = 'utf8mb4_general_ci';
$installSettings['site']                     = 'default';
$installSettings['source_site_id']           = 'BLANK';
$installSettings['clone_database']           = 'BLANK';
$installSettings['no_root_db_access']        = 'BLANK';
$installSettings['development_translations'] = 'BLANK';
// Collect parameters(if exist) for installation configuration settings
for ($i=1; $i < count($argv); $i++) {
    $indexandvalue = explode("=", $argv[$i]);
    $index = $indexandvalue[0];
    $value = $indexandvalue[1] ?? '';
    $installSettings[$index] = $value;
}
// Convert BLANK settings to empty
$tempInstallSettings = array();
foreach ($installSettings as $setting => $value) {
    if ($value == "BLANK") {
        $value = '';
    }
    $tempInstallSettings[$setting] = $value;
}
$installSettings = $tempInstallSettings;
// Install and configure OpenEMR using the Installer class
$installer = new Installer($installSettings);
if (! $installer->quick_install()) {
  // Failed, report error
    throw new Exception("ERROR: " . $installer->error_message . "\n");
} else {
  // Successful
    echo $installer->debug_message . "\n";
}