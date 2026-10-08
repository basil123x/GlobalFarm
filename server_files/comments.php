<?php
include 'xtras/config.php';

$db = isset($conx) ? $conx : (isset($conn) ? $conn : null);
if ($db === null) {
    echo json_encode(array(
        'success' => false,
        'error' => 'Database connection not initialized',
    ));
    exit;
}

$itemId = isset($_GET['item_id']) ? (int)$_GET['item_id'] : 0;

function commentsJsonError($db, $message) {
    $detail = ($db && $db->error) ? $db->error : $message;
    error_log('comments.php error: ' . $detail);
    echo json_encode(array(
        'success' => false,
        'error' => $detail,
    ));
    exit;
}

// Handle POST request for adding comments
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $input = json_decode(file_get_contents('php://input'), true);
    $comment = isset($input['comment']) ? trim($input['comment']) : '';
    $userId = isset($input['user_id']) ? trim((string)$input['user_id']) : '';

    if (empty($comment) || $userId === '' || $itemId <= 0) {
        echo json_encode(array(
            'success' => false,
            'error' => 'Invalid comment data',
        ));
        exit;
    }

    $comment = $db->real_escape_string($comment);
    $userId = $db->real_escape_string($userId);
    $sql = "INSERT INTO Comments (item_id, user_id, comment, created_at)
            VALUES ($itemId, '$userId', '$comment', UTC_TIMESTAMP())";

    if ($db->query($sql) === TRUE) {
        echo json_encode(array(
            'success' => true,
            'message' => 'Comment added successfully',
        ));
    } else {
        commentsJsonError($db, 'Failed to add comment');
    }

    $db->close();
    exit;
}

// Handle GET request for fetching comments
if ($itemId <= 0) {
    echo json_encode(array(
        'success' => false,
        'error' => 'Invalid item ID',
    ));
    exit;
}

$sql = "SELECT
    Comments.id,
    Comments.user_id,
    Users.uid,
    Users.Fullname,
    Users.store_id,
    Comments.`comment`,
    Comments.created_at
FROM Comments
LEFT JOIN Users ON Users.uid = Comments.user_id
WHERE Comments.item_id = $itemId
ORDER BY Comments.created_at DESC";

$result = $db->query($sql);

if ($result === false) {
    commentsJsonError($db, 'Failed to load comments');
}

$comments = array();

if ($result->num_rows > 0) {
    while ($row = $result->fetch_assoc()) {
        $userUid = !empty($row['uid'])
            ? (string)$row['uid']
            : (string)($row['user_id'] ?? '');
        $storeId = !empty($row['store_id']) ? (string)$row['store_id'] : '2';
        $createdAt = $row['created_at'];
        if (!empty($createdAt)) {
            $createdAt = gmdate('c', strtotime($createdAt . ' UTC'));
        }

        $comments[] = array(
            'id' => (string)$row['id'],
            'userId' => $userUid,
            'userName' => !empty($row['Fullname']) ? (string)$row['Fullname'] : 'مستخدم',
            'userAvatar' => 'https://martit.s3.ap-south-1.amazonaws.com/Users/store_' . $storeId . '/' . $userUid . '/1.jpg',
            'comment' => (string)$row['comment'],
            'createdAt' => $createdAt,
        );
    }
}

echo json_encode(array(
    'success' => true,
    'data' => $comments,
));

$db->close();
