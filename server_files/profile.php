<?php
include 'xtras/config.php';

// Get user ID parameter
$userId = isset($_GET['user_id']) ? (int)$_GET['user_id'] : 0;

try {
    if ($userId <= 0) {
        echo json_encode(array(
            'success' => false,
            'error' => 'Invalid user ID'
        ));
        exit;
    }
    
    // SQL query to get user profile data
    $sql = "SELECT
        Users.id,
        Users.Fullname,
        COUNT(Items.id) AS items_count
    FROM
        Users
    LEFT JOIN Items
        ON Items.uid = Users.uid
    WHERE Users.id = $userId
        AND (Items.Visibility = 'Public' OR Items.Visibility IS NULL)
    GROUP BY Users.id, Users.Fullname";

    $result = $conn->query($sql);
    
    if ($result->num_rows > 0) {
        $row = $result->fetch_assoc();
        
        $profile = array(
            'id' => $row['id'],
            'name' => $row['Fullname'],
            'avatar' => "https://globee.b-cdn.net/users/" . $row['id'] . "/avatar.jpg",
            'itemsCount' => (int)$row['items_count']
        );
        
        echo json_encode(array(
            'success' => true,
            'data' => $profile
        ));
        
    } else {
        echo json_encode(array(
            'success' => false,
            'error' => 'User not found'
        ));
    }
    
} catch (Exception $e) {
    echo json_encode(array(
        'success' => false,
        'error' => 'Profile error: ' . $e->getMessage()
    ));
}

$conn->close();
?>
