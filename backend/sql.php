<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

// Database configuration
$servername = "localhost";
$username = "your_username";
$password = "your_password";
$dbname = "globee_db";

try {
    $pdo = new PDO("mysql:host=$servername;dbname=$dbname", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch(PDOException $e) {
    die(json_encode(['success' => false, 'error' => 'Connection failed: ' . $e->getMessage()]));
}

$action = $_POST['action'] ?? '';

switch($action) {
    case 'create_item':
        createItem($pdo);
        break;
    case 'update_item':
        updateItem($pdo);
        break;
    case 'follow_user':
        followUser($pdo);
        break;
    case 'get_items':
        getItems($pdo);
        break;
    default:
        echo json_encode(['success' => false, 'error' => 'Invalid action']);
}

function createItem($pdo) {
    try {
        $user_id = $_POST['user_id'] ?? '';
        
        if (empty($user_id)) {
            echo json_encode(['success' => false, 'error' => 'User ID is required']);
            return;
        }
        
        $stmt = $pdo->prepare("INSERT INTO Items (user_id, created_at) VALUES (?, NOW())");
        $stmt->execute([$user_id]);
        
        $item_id = $pdo->lastInsertId();
        
        echo json_encode([
            'success' => true, 
            'item_id' => $item_id,
            'message' => 'Item created successfully'
        ]);
        
    } catch(PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

function updateItem($pdo) {
    try {
        $item_id = $_POST['item_id'] ?? '';
        $name = $_POST['name'] ?? '';
        $description = $_POST['description'] ?? '';
        $category = $_POST['category'] ?? '';
        $price = $_POST['price'] ?? '';
        $qtt = $_POST['qtt'] ?? '';
        $visibility = $_POST['visibility'] ?? 'public';
        $comments = $_POST['comments'] ?? 'on';
        $media = $_POST['media'] ?? '';
        
        if (empty($item_id)) {
            echo json_encode(['success' => false, 'error' => 'Item ID is required']);
            return;
        }
        
        $stmt = $pdo->prepare("
            UPDATE Items 
            SET name = ?, description = ?, category = ?, price = ?, qtt = ?, 
                visibility = ?, comments = ?, media = ?, updated_at = NOW()
            WHERE id = ?
        ");
        
        $stmt->execute([
            $name, $description, $category, $price, $qtt, 
            $visibility, $comments, $media, $item_id
        ]);
        
        if ($stmt->rowCount() > 0) {
            echo json_encode([
                'success' => true, 
                'message' => 'Item updated successfully'
            ]);
        } else {
            echo json_encode([
                'success' => false, 
                'error' => 'Item not found or no changes made'
            ]);
        }
        
    } catch(PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

function followUser($pdo) {
    try {
        $buyer_id = $_POST['buyer_id'] ?? '';
        $user_id = $_POST['user_id'] ?? '';
        $user_token = $_POST['user_token'] ?? '';
        
        if (empty($buyer_id) || empty($user_id)) {
            echo json_encode(['success' => false, 'error' => 'Buyer ID and User ID are required']);
            return;
        }
        
        // Check if already following
        $checkStmt = $pdo->prepare("SELECT id FROM Followers WHERE buyer_id = ? AND user_id = ?");
        $checkStmt->execute([$buyer_id, $user_id]);
        
        if ($checkStmt->rowCount() > 0) {
            echo json_encode(['success' => false, 'error' => 'Already following this user']);
            return;
        }
        
        $stmt = $pdo->prepare("
            INSERT INTO Followers (buyer_id, user_id, user_token, created_at) 
            VALUES (?, ?, ?, NOW())
        ");
        
        $stmt->execute([$buyer_id, $user_id, $user_token]);
        
        echo json_encode([
            'success' => true, 
            'message' => 'Successfully followed user'
        ]);
        
    } catch(PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

function getItems($pdo) {
    try {
        $page = $_POST['page'] ?? 0;
        $limit = 10;
        $offset = $page * $limit;
        
        $stmt = $pdo->prepare("
            SELECT i.*, u.name as seller_name, u.avatar as seller_avatar 
            FROM Items i 
            LEFT JOIN Users u ON i.user_id = u.id 
            WHERE i.visibility = 'public' AND i.name IS NOT NULL 
            ORDER BY i.created_at DESC 
            LIMIT ? OFFSET ?
        ");
        
        $stmt->execute([$limit, $offset]);
        $items = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo json_encode([
            'success' => true, 
            'data' => $items
        ]);
        
    } catch(PDOException $e) {
        echo json_encode(['success' => false, 'error' => $e->getMessage()]);
    }
}

// Create tables if they don't exist
function createTables($pdo) {
    try {
        // Items table
        $pdo->exec("
            CREATE TABLE IF NOT EXISTS Items (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id VARCHAR(255) NOT NULL,
                name VARCHAR(255),
                description TEXT,
                category VARCHAR(255),
                price DECIMAL(10,2),
                qtt INT,
                visibility ENUM('public', 'private') DEFAULT 'public',
                comments ENUM('on', 'off') DEFAULT 'on',
                media TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
        ");
        
        // Followers table
        $pdo->exec("
            CREATE TABLE IF NOT EXISTS Followers (
                id INT AUTO_INCREMENT PRIMARY KEY,
                buyer_id VARCHAR(255) NOT NULL,
                user_id VARCHAR(255) NOT NULL,
                user_token VARCHAR(255),
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY unique_follow (buyer_id, user_id)
            )
        ");
        
        // Users table (if not exists)
        $pdo->exec("
            CREATE TABLE IF NOT EXISTS Users (
                id VARCHAR(255) PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                phone VARCHAR(20),
                avatar TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ");
        
    } catch(PDOException $e) {
        error_log("Error creating tables: " . $e->getMessage());
    }
}

// Initialize tables
createTables($pdo);
?>
