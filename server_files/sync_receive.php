<?php
header('Content-Type: application/json');

// GET endpoint — no auth needed
if (isset($_GET['action']) && $_GET['action'] === 'get_last_id') {
    include 'xtras/config.php';
    $sql = 'SELECT MAX(id) AS last_id FROM items';
    $result = $conn->query($sql);
    $last_id = 0;
    if ($result && $row = $result->fetch_assoc()) {
        $last_id = $row['last_id'] !== null ? (int)$row['last_id'] : 0;
    }
    echo json_encode(['success' => true, 'last_id' => $last_id]);
    exit;
}

$secretKey = 'GlobalFarm_Secret_2026';
$receivedKey = isset($_SERVER['HTTP_X_SYNC_KEY']) ? $_SERVER['HTTP_X_SYNC_KEY'] : '';

if ($receivedKey !== $secretKey) {
    echo json_encode(['success' => false, 'error' => 'Unauthorized']);
    exit;
}

$rawData = file_get_contents('php://input');
$data = json_decode($rawData, true);

if (!$data) {
    echo json_encode(['success' => false, 'error' => 'Invalid JSON']);
    exit;
}

include 'xtras/config.php';

// insert_empty — placeholder row; returns real auto-increment id
if (isset($data['action']) && $data['action'] === 'insert_empty') {
    $sql = "INSERT INTO items (a1) VALUES ('')";
    if ($conn->query($sql)) {
        $realId = (int)$conn->insert_id;
        echo json_encode(['success' => true, 'id' => $realId]);
    } else {
        echo json_encode(['success' => false, 'id' => 0, 'error' => $conn->error]);
    }
    exit;
}

$a1  = isset($data['a1'])           ? $conn->real_escape_string($data['a1'])
     : (isset($data['barcode'])      ? $conn->real_escape_string($data['barcode'])         : '');
$a3  = isset($data['a3'])           ? $conn->real_escape_string($data['a3'])
     : (isset($data['name'])         ? $conn->real_escape_string($data['name'])            : '');
$a4  = isset($data['a4'])           ? $conn->real_escape_string($data['a4'])
     : (isset($data['eng'])          ? $conn->real_escape_string($data['eng'])             : '');
$a5  = isset($data['a5'])           ? $conn->real_escape_string($data['a5'])
     : (isset($data['category'])    ? $conn->real_escape_string($data['category'])        : '');
$a7  = isset($data['a7'])           ? $conn->real_escape_string($data['a7'])
     : (isset($data['description_arb']) ? $conn->real_escape_string($data['description_arb']) : '');
$a8  = isset($data['description'])  ? $conn->real_escape_string($data['description'])
     : (isset($data['a8'])           ? $conn->real_escape_string($data['a8'])             : '');
$a10 = isset($data['a10'])          ? $conn->real_escape_string($data['a10'])
     : (isset($data['price'])        ? $conn->real_escape_string($data['price'])           : '');
$a30 = isset($data['a30'])          ? (int)$data['a30']
     : (isset($data['qtt'])          ? (int)$data['qtt']                                   : 0);
$explicitId = isset($data['id'])    ? (int)$data['id']                                    : 0;

if (empty($a3) || empty($a10)) {
    echo json_encode(['success' => false, 'error' => 'name and price are required']);
    exit;
}

$checkSql = "SELECT id FROM items WHERE a1 = '$a1' AND a1 != '' LIMIT 1";
$checkResult = $conn->query($checkSql);

if ($checkResult && $checkResult->num_rows > 0) {
    $row = $checkResult->fetch_assoc();
    $itemId = (int)$row['id'];
    $sql = "UPDATE items SET a1='$a1', a3='$a3', a4='$a4', a5='$a5', a7='$a7', a8='$a8', a10='$a10', a30=$a30 WHERE id=$itemId";
    $actionTaken = 'updated';
} elseif ($explicitId > 0) {
    $itemId = $explicitId;
    $sql = "UPDATE items SET a1='$a1', a3='$a3', a4='$a4', a5='$a5', a7='$a7', a8='$a8', a10='$a10', a30=$a30 WHERE id=$itemId";
    $actionTaken = 'updated';
} else {
    $sql = "INSERT INTO items (a1, a3, a4, a5, a7, a8, a10, a30) VALUES ('$a1','$a3','$a4','$a5','$a7','$a8','$a10',$a30)";
    $actionTaken = 'inserted';
}

if ($conn->query($sql)) {
    $newId = ($actionTaken === 'inserted') ? (int)$conn->insert_id : $itemId;
    echo json_encode(['success' => true, 'action' => $actionTaken, 'id' => $newId]);
} else {
    echo json_encode(['success' => false, 'error' => $conn->error]);
}
