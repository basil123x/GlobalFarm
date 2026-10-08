<?php
// Database configuration
$servername = "localhost"; // Change this to your server name
$username = "your_username"; // Change this to your database username
$password = "your_password"; // Change this to your database password
$dbname = "your_database_name"; // Change this to your database name

// Create connection
$conn = new mysqli($servername, $username, $password, $dbname);

// Check connection
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

// Set charset to utf8 for Arabic support
$conn->set_charset("utf8");

// CORS headers for Flutter app
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json; charset=UTF-8");

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    exit(0);
}
?>
