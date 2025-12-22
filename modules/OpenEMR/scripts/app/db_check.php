<?php
// Copyright 2025 Tech Equity Ltd
//
// DB Connection Check Script
//

// Ensure output is not buffered
ob_implicit_flush(true);

// Disable exception reporting for mysqli to handle errors manually
mysqli_report(MYSQLI_REPORT_OFF);

/**
 * Helper to get env variable or read from file if _FILE suffix exists
 */
function getenv_docker($env, $default = false) {
    $val = getenv($env);
    if ($val !== false) {
        return $val;
    }

    $file_env = getenv($env . '_FILE');
    if ($file_env !== false && file_exists($file_env)) {
        return trim(file_get_contents($file_env));
    }

    return $default;
}

// Get credentials supporting standard vars and Docker secrets
$host_raw = getenv_docker('MYSQL_HOST');
$socket = getenv_docker('MYSQL_SOCKET');
$user = getenv_docker('MYSQL_USER');

// Password fallback chain
$pass = getenv_docker('MYSQL_PASS');
if ($pass === false) {
    $pass = getenv_docker('MYSQL_PASSWORD');
}
if ($pass === false) {
    $pass = getenv_docker('MYSQL_ROOT_PASSWORD');
}

$port = getenv_docker('MYSQL_PORT', 3306);

if (!$user) {
    fwrite(STDERR, "MYSQL_USER (or MYSQL_USER_FILE) not set. Skipping DB check.\n");
    exit(0);
}

// Parse Host for Port (host:port)
if ($host_raw && strpos($host_raw, ':') !== false) {
    $parts = explode(':', $host_raw);
    $host = $parts[0];
    if (isset($parts[1]) && is_numeric($parts[1])) {
        $port = (int)$parts[1];
    }
} else {
    $host = $host_raw;
}

// Log configuration (masking password)
fwrite(STDERR, "Configuration: User=$user, Host=" . ($host ?: 'N/A') . ", Socket=" . ($socket ?: 'N/A') . ", Port=$port\n");

$max_attempts = 30;
$attempt = 1;

while ($attempt <= $max_attempts) {
    fwrite(STDERR, "Waiting for database... ($attempt/$max_attempts)\n");

    $mysqli = null;

    // Prioritize Socket if available, otherwise Host
    if ($socket) {
        $mysqli = @new mysqli(null, $user, $pass, '', 0, $socket);
    } elseif ($host) {
        $mysqli = @new mysqli($host, $user, $pass, '', $port);
    } else {
        fwrite(STDERR, "Neither MYSQL_HOST nor MYSQL_SOCKET set. Cannot connect.\n");
        exit(1);
    }

    if (!$mysqli->connect_error) {
        fwrite(STDERR, "Database connection successful!\n");
        $mysqli->close();
        exit(0);
    }

    fwrite(STDERR, "Connection failed: " . $mysqli->connect_error . "\n");
    sleep(2);
    $attempt++;
}

fwrite(STDERR, "Could not connect to database after $max_attempts attempts.\n");
exit(1);
?>
