<?php
// Simple test file to check if server is working
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=UTF-8");

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}

echo json_encode(array(
    'success' => true,
    'message' => 'Server is working!',
    'timestamp' => date('Y-m-d H:i:s'),
    'server_info' => array(
        'php_version' => phpversion(),
        'server_name' => $_SERVER['SERVER_NAME'] ?? 'Unknown',
        'request_method' => $_SERVER['REQUEST_METHOD'] ?? 'Unknown'
    )
));
?>
