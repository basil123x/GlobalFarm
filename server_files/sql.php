<?php
/*
CREATE TABLE IF NOT EXISTS NotifyRequests (
  id INT AUTO_INCREMENT PRIMARY KEY,
  item_id VARCHAR(50) NOT NULL,
  user_id VARCHAR(50) NOT NULL,
  store_id VARCHAR(10) DEFAULT '1',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  notified_at DATETIME NULL,
  UNIQUE KEY unique_notify (item_id, user_id)
);
*/

// Enable error reporting for debugging
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Set JSON header
header('Content-Type: application/json');

include 'xtras/config.php';
if (file_exists(__DIR__ . '/sync_helper.php')) {
    require_once __DIR__ . '/sync_helper.php';
}
require_once __DIR__ . '/media_helper.php';

// Get action from POST or GET request
$action = isset($_POST['action']) ? $_POST['action'] : '';
if ($action === '' && isset($_GET['action'])) {
    $action = $_GET['action'];
}

// Response array
$response = array('success' => false);

/**
 * Lookup employee by phone (digits only match). Returns row or null.
 */
function martit_find_employee_by_phone($conx, $phone) {
    $phone = trim((string)$phone);
    if ($phone === '') {
        return null;
    }
    $phone_esc = $conx->real_escape_string($phone);
    $sql = "SELECT id, name, email, phone, store_id, player_id
            FROM employees
            WHERE phone = '$phone_esc'
               OR REPLACE(REPLACE(REPLACE(phone, '+', ''), ' ', ''), '-', '') = '$phone_esc'
            LIMIT 1";
    $result = $conx->query($sql);
    if ($result && $result->num_rows > 0) {
        return $result->fetch_assoc();
    }
    return null;
}

/**
 * If phone belongs to employees, force Admin + employee store_id.
 * Optionally persist role/store on Users when a uid is known.
 */
function martit_apply_employee_admin($conx, &$user, $phone = null, $persist = true) {
    if (!is_array($user)) {
        return;
    }
    $checkPhone = $phone !== null && $phone !== ''
        ? $phone
        : (isset($user['phone']) ? $user['phone'] : '');
    $emp = martit_find_employee_by_phone($conx, $checkPhone);
    if (!$emp) {
        return;
    }
    $user['role'] = 'Admin';
    if (isset($emp['store_id']) && $emp['store_id'] !== '' && $emp['store_id'] !== null) {
        $user['store_id'] = (string)$emp['store_id'];
    }
    $user['is_employee'] = true;
    if ($persist && !empty($user['id'])) {
        $uid_esc = $conx->real_escape_string((string)$user['id']);
        $store_esc = $conx->real_escape_string((string)$user['store_id']);
        $conx->query("UPDATE Users SET role = 'Admin', store_id = '$store_esc' WHERE uid = '$uid_esc'");
    }
}

/**
 * Ensure an employee has a Users row so phone login works without signup.
 */
function martit_ensure_user_for_employee($conx, $emp) {
    if (!is_array($emp) || empty($emp['phone'])) {
        return null;
    }
    $phone_esc = $conx->real_escape_string(trim((string)$emp['phone']));
    $existing = $conx->query("SELECT Fullname, PhoneNumber, uid, urlAvatar, oid, role, store_id FROM Users WHERE PhoneNumber = '$phone_esc' LIMIT 1");
    if ($existing && $existing->num_rows > 0) {
        $row = $existing->fetch_assoc();
        $user = array(
            'id' => $row['uid'],
            'oid' => $row['oid'],
            'name' => $row['Fullname'],
            'phone' => $row['PhoneNumber'],
            'avatar' => $row['urlAvatar'],
            'role' => 'Admin',
            'store_id' => isset($emp['store_id']) ? (string)$emp['store_id'] : ($row['store_id'] ?? null),
            'is_employee' => true,
        );
        martit_apply_employee_admin($conx, $user, $phone_esc, true);
        return $user;
    }

    $uid = (string)(1000 + mt_rand(0, 8999));
    $oid = (string)(1000 + mt_rand(0, 8999));
    // Avoid rare uid collisions
    for ($i = 0; $i < 5; $i++) {
        $check = $conx->query("SELECT uid FROM Users WHERE uid = '$uid' LIMIT 1");
        if (!$check || $check->num_rows === 0) {
            break;
        }
        $uid = (string)(1000 + mt_rand(0, 8999));
    }
    $name_esc = $conx->real_escape_string(isset($emp['name']) ? (string)$emp['name'] : 'Employee');
    $email_esc = $conx->real_escape_string(isset($emp['email']) ? (string)$emp['email'] : '');
    $store_esc = $conx->real_escape_string(isset($emp['store_id']) ? (string)$emp['store_id'] : '2');
    $player_esc = $conx->real_escape_string(isset($emp['player_id']) ? (string)$emp['player_id'] : '');
    $date = date('Y-m-d');
    $sql = "INSERT INTO Users(Fullname, PhoneNumber, Email, uid, oid, Created_at, status, player_id, login_type, store_id, role)
            VALUES('$name_esc', '$phone_esc', '$email_esc', '$uid', '$oid', '$date', '1', '$player_esc', 'Phone', '$store_esc', 'Admin')";
    if (!$conx->query($sql)) {
        return null;
    }
    return array(
        'id' => $uid,
        'oid' => $oid,
        'name' => isset($emp['name']) ? $emp['name'] : 'Employee',
        'phone' => $emp['phone'],
        'avatar' => null,
        'role' => 'Admin',
        'store_id' => $store_esc,
        'is_employee' => true,
    );
}

/**
 * When stock goes from 0 to > 0, return pending notify subscribers and mark notified.
 */
function martit_process_notify_restock($conx, $item_id, $old_qtt, $new_qtt) {
    $notify_users = array();
    $old_qtt = (int)$old_qtt;
    $new_qtt = (int)$new_qtt;

    if ($old_qtt != 0 || $new_qtt <= 0) {
        return $notify_users;
    }

    $item_id_esc = $conx->real_escape_string((string)$item_id);
    $sql = "SELECT nr.user_id, nr.item_id, u.player_id
            FROM NotifyRequests nr
            LEFT JOIN Users u ON nr.user_id = u.uid
            WHERE nr.item_id = '$item_id_esc' AND nr.notified_at IS NULL";
    $result = $conx->query($sql);

    if ($result) {
        while ($row = $result->fetch_assoc()) {
            $notify_users[] = array(
                'user_id' => (string)$row['user_id'],
                'item_id' => (string)$row['item_id'],
                'player_id' => (string)($row['player_id'] ?? ''),
            );
        }
    }

    $conx->query(
        "UPDATE NotifyRequests SET notified_at = NOW() WHERE item_id = '$item_id_esc' AND notified_at IS NULL"
    );

    return $notify_users;
}

try {
    switch ($action) {
        
        // =====================================
        // جلب الأصناف (Fetch Items)
        // =====================================
        case 'track_interaction':
            $user_id = $conx->real_escape_string($_POST['user_id'] ?? '');
            $item_id = $conx->real_escape_string($_POST['item_id'] ?? '');
            $action = $conx->real_escape_string($_POST['interaction'] ?? '');
            $watch_seconds = (int)($_POST['watch_seconds'] ?? 0);

            if (empty($user_id) || empty($item_id)) {
                break;
            }

            $itemRow = $conx->query("SELECT category, store_id FROM Items WHERE id = '$item_id' LIMIT 1");
            $itemData = $itemRow ? $itemRow->fetch_assoc() : null;
            $category = $conx->real_escape_string($itemData['category'] ?? '');
            $store_id = $conx->real_escape_string($itemData['store_id'] ?? '1');

            $conx->query("INSERT INTO UserInteractions 
                (user_id, item_id, store_id, action, watch_seconds) 
                VALUES ('$user_id', '$item_id', '$store_id', '$action', $watch_seconds)");

            $scores = array(
                'view' => 1, 'like' => 5, 'cart' => 8,
                'share' => 6, 'follow' => 10, 'skip' => -2, 'report' => -20
            );
            $score = isset($scores[$action]) ? $scores[$action] : 0;

            if ($watch_seconds > 3) {
                $score += min(floor($watch_seconds / 3), 10);
            }

            if (!empty($category) && $score != 0) {
                $conx->query("INSERT INTO UserCategoryScore (user_id, category, store_id, score)
                    VALUES ('$user_id', '$category', '$store_id', $score)
                    ON DUPLICATE KEY UPDATE 
                    score = LEAST(score + $score, 1000),
                    updated_at = NOW()");
            }

            $response = array('success' => true);
            break;

        case 'get_user_scores':
            $user_id = $conx->real_escape_string($_POST['user_id'] ?? '');
            if (empty($user_id)) {
                $response = array('success' => false, 'error' => 'user_id required');
                break;
            }
            // One-time cleanup — remove after first deploy
            $conx->query("DELETE FROM UserCategoryScore WHERE category LIKE 'seller_%'");
            $sql = "SELECT category, score FROM UserCategoryScore 
                    WHERE user_id = '$user_id'
                    AND category NOT LIKE 'seller_%'
                    ORDER BY score DESC LIMIT 10";
            $result = $conx->query($sql);
            $categories = array();
            if ($result) {
                while ($row = $result->fetch_assoc()) {
                    $categories[] = $row;
                }
            }
            $response = array('success' => true, 'top_categories' => $categories);
            break;

        case 'fetch':
            $page = isset($_POST['page']) ? (int)$_POST['page'] : 0;
            $limit = isset($_POST['limit']) ? (int)$_POST['limit'] : 10;
            $offset = $page * $limit;
            $user_id = isset($_POST['user_id']) ? $conx->real_escape_string($_POST['user_id']) : '';
            $itemSrchId = isset($_POST['itemSrchId']) ? $conx->real_escape_string($_POST['itemSrchId']) : '';
            $store_id = isset($_POST['store_id']) ? $conx->real_escape_string($_POST['store_id']) : '';
            $category = isset($_POST['category']) ? $conx->real_escape_string($_POST['category']) : '';
            $country = isset($_POST['country']) ? $conx->real_escape_string($_POST['country']) : '';
            $pinnedItemId = isset($_POST['pinnedItemId']) ? $conx->real_escape_string(trim($_POST['pinnedItemId'])) : '';
            $get_store = "";
            
            // Debug logging
            error_log("📦 fetch - Category received: " . ($category ? $category : 'NULL'));
            $img_url = "https://globee.b-cdn.net/";
            if ($store_id) {
                $get_store = "AND Items.store_id = '$store_id'";
            }
            switch ($store_id) {
                case '2':
                    $img_url = "https://globalfarmnursery.s3.ap-south-1.amazonaws.com/items/";
                    break;
                case '3':
                    $img_url = "https://globee.b-cdn.net/GES/";
                    break;
                default:
                    break;
            }
            $d1 = "";
            $d2 = "";
            $d3 = "";
            if ($itemSrchId) {
                $d1 = "AND Items.id = '$itemSrchId'";
            }
            if (!empty($category)) {
                $d3 = "AND Items.category = '$category'";
            }

            $ucsJoin = "";
            $order_by = "RAND()";
            if (!empty($user_id)) {
                $ucsJoin = "
            LEFT JOIN UserCategoryScore ucs 
                ON Items.category = ucs.category 
                AND ucs.user_id = '$user_id'
                AND ucs.store_id = Items.store_id";
                $order_by = "(COALESCE(ucs.score, 0) * 3 + COALESCE(likes_count.total_likes, 0) * 0.2 + (RAND() * 30)) DESC";
            }

            $fetchSelect = "SELECT
                Items.id,
                Items.idx,
                Items.store_id AS storeid,
                Items.barcode,
                Items.`name`,
                Items.eng,
                Items.price,
                Items.qtt,
                Items.description,
                Items.description_arb,
                Items.Views,
                Items.media,
                Items.created_at,
                Items.uid AS firebase_uid,
                Users.id AS seller_db_id,
                Users.Fullname,
                Users.uid AS user_id,
                Users.player_id AS token,
                COALESCE(likes_count.total_likes, 0) as likes_count,
                COALESCE(comments_count.total_comments, 0) as comments_count,
                COALESCE(cart_count.total_cart, 0) as cart_quantity,
                CASE WHEN user_likes.user_id IS NOT NULL THEN 1 ELSE 0 END as is_liked,
                CASE WHEN followers.buyer_id IS NOT NULL THEN 1 ELSE 0 END as is_following";

            $fetchFrom = "
            FROM
                Items
            LEFT JOIN Users
                ON Items.uid = Users.uid
            LEFT JOIN (
                SELECT item_id, COUNT(*) as total_likes 
                FROM Likes 
                GROUP BY item_id
            ) likes_count ON Items.id = likes_count.item_id
            LEFT JOIN (
                SELECT item_id, COUNT(*) as total_comments 
                FROM Comments 
                GROUP BY item_id
            ) comments_count ON Items.id = comments_count.item_id
            LEFT JOIN (
                SELECT item_id, SUM(qtt) as total_cart 
                FROM Cart " . (!empty($user_id) ? "WHERE user_id = '$user_id'" : "") . "
                GROUP BY item_id
            ) cart_count ON Items.id = cart_count.item_id
            LEFT JOIN (
                SELECT item_id, user_id 
                FROM Likes " . (!empty($user_id) ? "WHERE user_id = '$user_id'" : "WHERE 1=0") . "
            ) user_likes ON Items.id = user_likes.item_id
            LEFT JOIN (
                SELECT user_id, buyer_id
                FROM Followers " . (!empty($user_id) ? "WHERE buyer_id = '$user_id'" : "WHERE 1=0") . "
            ) followers ON Users.uid = followers.user_id" . $ucsJoin;

            $fetchWherePublic = "Items.Visibility = 'Public' AND Items.country = '$country' AND Items.has_image = 1 $get_store $d3";

            if (!empty($pinnedItemId) && $offset == 0 && empty($itemSrchId)) {
                $restLimit = max(1, $limit - 1);
                $sql = "($fetchSelect $fetchFrom WHERE Items.id = '$pinnedItemId')
                        UNION ALL
                        ($fetchSelect $fetchFrom WHERE $fetchWherePublic AND Items.id != '$pinnedItemId' ORDER BY $order_by LIMIT $restLimit)";
            } elseif (!empty($itemSrchId)) {
                $escapedId = $conx->real_escape_string($itemSrchId);
                $lookupSql = "SELECT Items.id FROM Items WHERE Items.Visibility = 'Public' AND Items.id = '$escapedId' $get_store LIMIT 1";
                $lookupResult = $conx->query($lookupSql);
                if (!$lookupResult || $lookupResult->num_rows === 0) {
                    $lookupSql = "SELECT Items.id FROM Items WHERE Items.Visibility = 'Public' AND Items.idx = '$escapedId' $get_store LIMIT 1";
                    $lookupResult = $conx->query($lookupSql);
                }
                if ($lookupResult && $lookupResult->num_rows > 0) {
                    $foundRow = $lookupResult->fetch_assoc();
                    $foundId = $conx->real_escape_string((string)$foundRow['id']);
                    $restLimit = max(1, $limit - 1);
                    $sql = "($fetchSelect $fetchFrom WHERE Items.id = '$foundId')
                            UNION ALL
                            ($fetchSelect $fetchFrom WHERE $fetchWherePublic AND Items.id != '$foundId' ORDER BY $order_by LIMIT $restLimit)";
                } else {
                    $sql = "$fetchSelect $fetchFrom WHERE 1=0";
                }
            } else {
                $sql = "$fetchSelect $fetchFrom
                WHERE $fetchWherePublic $d1
                ORDER BY $order_by
                LIMIT $limit OFFSET $offset";
            }

        
            // Debug: Log the SQL query
            error_log("📦 fetch SQL: " . $sql);
            
            $result = $conx->query($sql);
            $items = array();
            
            if ($result && $result->num_rows > 0) {
                while($row = $result->fetch_assoc()) {
                    $storeid = (string)($row['storeid'] ?? '1');
                    $itemId = (string)$row['id'];
                    $mediaFiles = build_item_media_urls($storeid, $itemId, $row['media'], null, (string)($row['idx'] ?? ''));
                    
                    $sellerUid = !empty($row['firebase_uid'])
                        ? (string)$row['firebase_uid']
                        : (string)($row['user_id'] ?? '');
                    $sellerDbId = !empty($row['seller_db_id'])
                        ? (string)$row['seller_db_id']
                        : $sellerUid;

                    $item = array(
                        'id' => (string)$row['id'],
                        'idx' => (string)$row['idx'],
                        'storeid' => (string)$row['storeid'],
                        'barcode' => (string)$row['barcode'],
                        'name' => (string)$row['name'],
                        'eng' => (string)($row['eng'] ?? ''),
                        'price' => (string)$row['price'],
                        'quantity' => (int)$row['qtt'],
                        'description' => (string)$row['description'],
                        'description_arb' => (string)($row['description_arb'] ?? ''),
                        'views' => (int)$row['Views'],
                        'media' => $mediaFiles,
                        'seller' => array(
                            'id' => $sellerDbId,
                            'uid' => $sellerUid,
                            'name' => (string)($row['Fullname'] ?? 'مستخدم'),
                            'avatar' => user_avatar_url($sellerUid, $storeid),
                            'isFollowing' => (bool)$row['is_following'],
                            'token' => $row['token']
                        ),
                        'interactions' => array(
                            'likes' => (int)$row['likes_count'],
                            'comments' => (int)$row['comments_count'],
                            'shares' => 0,
                            'cartQuantity' => (int)$row['cart_quantity'],
                            'isLiked' => (bool)$row['is_liked']
                        )
                    );
                    
                    $items[] = $item;
                }
            }
            
            $response = array(
                'success' => true,
                'data' => $items,
                'page' => $page,
                'hasMore' => count($items) >= $limit
            );
            break;
            
        case 'follow_user':
            $buyer_id = isset($_POST['buyer_id']) ? $conx->real_escape_string($_POST['buyer_id']) : '';
            $user_id = isset($_POST['user_id']) ? $conx->real_escape_string($_POST['user_id']) : '';
            $user_token = isset($_POST['user_token']) ? $conx->real_escape_string($_POST['user_token']) : '';
        
            if (empty($buyer_id) || empty($user_id)) {
                $response = array(
                    'success' => false,
                    'error' => 'بيانات غير كاملة'
                );
                break;
            }
        
            // ✅ شيك لو المستخدم بيتابع نفسه
            if ($buyer_id === $user_id) {
                $response = array(
                    'success' => false,
                    'error' => 'لا يمكنك متابعة نفسك'
                );
                break;
            }
        
            // ✅ شيك لو في متابعة موجودة
            $check_sql = "SELECT * FROM Followers WHERE buyer_id = '$buyer_id' AND user_id = '$user_id'";
            $check_result = $conx->query($check_sql);
        
            if ($check_result && $check_result->num_rows > 0) {
                // ✅ لو موجود، احذف المتابعة (unfollow)
                $delete_sql = "DELETE FROM Followers WHERE buyer_id = '$buyer_id' AND user_id = '$user_id'";
                
                if ($conx->query($delete_sql)) {
                    $response = array(
                        'success' => true,
                        'message' => 'تم إلغاء المتابعة',
                        'action' => 'unfollowed'
                    );
                } else {
                    $response = array(
                        'success' => false,
                        'error' => 'فشل في إلغاء المتابعة: ' . $conx->error
                    );
                }
            } else {
                // ✅ لو مش موجود، أضف متابعة جديدة (follow)
                $insert_sql = "INSERT INTO Followers (buyer_id, user_id, user_token) 
                               VALUES ('$buyer_id', '$user_id', '$user_token')";
                
                if ($conx->query($insert_sql)) {
                    $response = array(
                        'success' => true,
                        'message' => 'تمت المتابعة بنجاح',
                        'action' => 'followed'
                    );
                } else {
                    $response = array(
                        'success' => false,
                        'error' => 'فشل في المتابعة: ' . $conx->error
                    );
                }
            }
            break;

        // =====================================
        // جلب منتجات حساب واحد (Fetch Items for One Account)
        // =====================================
        case 'fetch_items_one_account':
            $uid_val = $conx->real_escape_string($_POST['uid'] ?? '');
            if (is_numeric($uid_val)) {
                $uidRow = $conx->query(
                    "SELECT uid FROM Users WHERE id = '$uid_val' OR uid = '$uid_val' LIMIT 1"
                );
                if ($uidRow && $row = $uidRow->fetch_assoc()) {
                    $uid_val = $conx->real_escape_string($row['uid']);
                }
            }

            if (empty($uid_val)) {
                $response = array('success' => false, 'error' => 'uid required');
                break;
            }

            $limit = isset($_POST['limit']) ? (int)$_POST['limit'] : 20;
            $offset = isset($_POST['offset']) ? (int)$_POST['offset'] : 0;
            $sort = isset($_POST['sort']) ? $_POST['sort'] : 'views';
            
            // Determine sort order
            $orderBy = "Views DESC"; // Default: الرائجة (most views)
            if ($sort === 'newest') {
                $orderBy = "id DESC";
            } else if ($sort === 'oldest') {
                $orderBy = "id ASC";
            }
            
            $sql = "SELECT 
    Items.id, 
    Items.idx, 
    Items.store_id AS storeid, 
    Items.`name`, 
    Items.eng,
    Items.price, 
    Items.qtt,
    Items.description,
    Items.description_arb,
    Items.Views, 
    Items.media, 
    Items.created_at,
    Users.Fullname AS seller_name,
    Users.uid AS seller_id
FROM Items 
LEFT JOIN Users ON Items.uid = Users.uid
WHERE Items.uid = '$uid_val' 
ORDER BY $orderBy 
LIMIT $limit OFFSET $offset";
            $result = $conx->query($sql);
            $items = array();
            
            if ($result && $result->num_rows > 0) {
                while($row = $result->fetch_assoc()) {
                    $storeid = (string)($row['storeid'] ?? '1');
                    $itemId = (string)$row['id'];
                    $mediaFiles = build_item_media_urls(
                        $storeid,
                        $itemId,
                        $row['media'],
                        null,
                        (string)($row['idx'] ?? '')
                    );
                    
                    $item = array(
                        'id' => (string)$row['id'],
                        'idx' => (string)$row['idx'],
                        'storeid' => (string)($row['storeid'] ?? '1'),
                        'name' => (string)$row['name'],
                        'eng' => (string)($row['eng'] ?? ''),
                        'price' => (string)$row['price'],
                        'qtt' => (int)($row['qtt'] ?? 0),
                        'description' => (string)($row['description'] ?? ''),
                        'description_arb' => (string)($row['description_arb'] ?? ''),
                        'seller_name' => (string)($row['seller_name'] ?? ''),
                        'seller_id' => (string)($row['seller_id'] ?? ''),
                        'views' => (int)$row['Views'],
                        'media' => $mediaFiles,
                        'created_at' => $row['created_at'] ?? '',
                    );
                    
                    $items[] = $item;
                }
            }
            
            // Get total count for pagination info
            $countSql = "SELECT COUNT(*) as total FROM Items WHERE uid = '$uid_val'";
            $countResult = $conx->query($countSql);
            $totalCount = 0;
            if ($countResult && $countRow = $countResult->fetch_assoc()) {
                $totalCount = (int)$countRow['total'];
            }
            
            $response = array(
                'success' => true,
                'data' => $items,
                'total' => $totalCount,
                'hasMore' => ($offset + $limit) < $totalCount,
            );
            break;
        case 'insert':
            // التحقق من البيانات المطلوبة
            $itemId = isset($_POST['item_id']) ? $conx->real_escape_string($_POST['item_id']) : '';
            $uid = isset($_POST['uid']) ? $conx->real_escape_string($_POST['uid']) : '';
            $barcode = isset($_POST['barcode']) ? $conx->real_escape_string($_POST['barcode']) : '';
            $name = isset($_POST['name']) ? $conx->real_escape_string($_POST['name']) : '';
            $eng = isset($_POST['eng']) ? $conx->real_escape_string($_POST['eng']) : '';
            $category = isset($_POST['category']) ? $conx->real_escape_string($_POST['category']) : '';
            $price = isset($_POST['price']) ? $conx->real_escape_string($_POST['price']) : '';
            $qtt = isset($_POST['qtt']) ? (int)$_POST['qtt'] : 0;
            $description = isset($_POST['description']) ? $conx->real_escape_string($_POST['description']) : '';
            $description_arb = isset($_POST['description_arb']) ? $conx->real_escape_string($_POST['description_arb']) : '';
            $visibility = isset($_POST['visibility']) ? $conx->real_escape_string($_POST['visibility']) : 'Public';
            $media = isset($_POST['media']) ? $conx->real_escape_string($_POST['media']) : '';
            $comments = isset($_POST['comments']) ? $conx->real_escape_string($_POST['comments']) : '';
            $idx = isset($_POST['idx']) ? (int)$_POST['idx'] : 0;
            $client_id = isset($_POST['client_id']) ? (int)$_POST['client_id'] : 0;
            $client_id_ges = isset($_POST['client_id_ges']) ? (int)$_POST['client_id_ges'] : $idx;
            $idx_sql = $idx > 0 ? ", idx = $idx" : '';
            $store_id = isset($_POST['store_id']) ? $conx->real_escape_string($_POST['store_id']) : '2';

            if (empty($uid) || empty($name) || empty($price)) {
                $response = array(
                    'success' => false,
                    'error' => 'البيانات المطلوبة ناقصة (uid, name, price)'
                );
                break;
            }


            
            $old_qtt = 0;
            $oldQttResult = $conx->query("SELECT qtt FROM Items WHERE id = '$itemId' LIMIT 1");
            if ($oldQttResult && $oldQttRow = $oldQttResult->fetch_assoc()) {
                $old_qtt = (int)$oldQttRow['qtt'];
            }

            $sql = "UPDATE Items SET uid = '$uid', barcode = '$barcode' ,name = '$name', eng = '$eng', description = '$description', description_arb = '$description_arb', category = '$category', price = '$price', qtt = '$qtt', Visibility = '$visibility', comments = '$comments', media = '$media', status = '1', has_image = CASE WHEN '$media' != '' THEN '1' ELSE has_image END$idx_sql WHERE id = '$itemId'";

            if ($conx->query($sql)) {
                $notify_users = martit_process_notify_restock($conx, $itemId, $old_qtt, $qtt);
                 // Sync to client
    $syncData = [
        'barcode'         => $barcode,
        'name'            => $name,
        'eng'             => $eng,
        'description'     => $description,
        'description_arb' => $description_arb,
        'price'           => $price,
        'qtt'             => $qtt,
        'category'        => $category,
        'martit_item_id'  => $itemId,
    ];
// ✅ عرّف المتغيرات الأول
$syncResult = null;
$syncResult_ges = null;

if ($store_id == '2') {
    if ($client_id > 0) {
        $syncData['id'] = $client_id;
    }
    $syncResult = syncToClient($syncData, '2');
}

if ($store_id == '3') {
    $syncData['id'] = $client_id_ges;
    $syncResult_ges = syncToClient($syncData, '3');
}

if ($store_id == '4') {
    $syncData['id'] = isset($_POST['client_id_badaa']) ? (int)$_POST['client_id_badaa'] : 0;
    syncToClient($syncData, '4');
}

if ($store_id == '5') {
    $syncData['id'] = isset($_POST['client_id_badaa']) ? (int)$_POST['client_id_badaa'] : 0;
    syncToClient($syncData, '5');
}

                $response = array(
                    'success' => true,
                    'message' => 'تم إضافة الصنف بنجاح',
                    'item_id' => $conx->insert_id,
                    'sync_result' => $syncResult,
                    'ges_sync_result' => $syncResult_ges,
                    'notify_users' => $notify_users
                );
            } else {
                $response = array(
                    'success' => false,
                    'error' => 'فشل في إضافة الصنف: ' . $conx->error
                );
            }
            break;
            
        // =====================================
        // آخر idx للمتجر (لتسمية مجلدات S3)
        // =====================================
        case 'get_last_idx':
            $store_id = isset($_GET['store_id']) ? $conx->real_escape_string($_GET['store_id']) : '';
            if ($store_id === '' && isset($_POST['store_id'])) {
                $store_id = $conx->real_escape_string($_POST['store_id']);
            }
            if ($store_id === '') {
                $store_id = '2';
            }
            try {
                $sql = "SELECT MAX(CAST(idx AS UNSIGNED)) AS last_idx FROM Items WHERE store_id = '$store_id' AND idx IS NOT NULL AND idx != ''";
                $result = $conx->query($sql);
                $last_idx = 0;
                if ($result && $row = $result->fetch_assoc()) {
                    $last_idx = $row['last_idx'] !== null ? (int)$row['last_idx'] : 0;
                }
                $response = array(
                    'success' => true,
                    'last_idx' => $last_idx
                );
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في جلب last_idx: ' . $e->getMessage(),
                    'last_idx' => 0
                );
            }
            break;

        case 'insertNewOne':
    $date = date('Y-m-d H:i:s');
    $store_id = isset($_POST['store_id']) ? $conx->real_escape_string($_POST['store_id']) : '1';
    $country = isset($_POST['country']) ? $conx->real_escape_string($_POST['country']) : '1';
    $uid = isset($_POST['uid']) ? $conx->real_escape_string($_POST['uid']) : '';
    
    $client_id_badaa = '';
    if ($store_id !== '4') {
            $idxResult = $conx->query(
                "SELECT COALESCE(MAX(CAST(idx AS UNSIGNED)), 0) + 1 AS next_idx
                 FROM Items
                 WHERE store_id = '$store_id'"
            );
            if ($idxResult && $row = $idxResult->fetch_assoc()) {
                $client_id_badaa = (string)$row['next_idx'];
            } else {
                $client_id_badaa = '1';
            }
    }

    if (!empty($uid)) {
        $sql = "INSERT INTO Items (id, created_at, status, store_id, country, uid) VALUES (null, '$date', '0', '$store_id', '$country', '$uid')";
    } else {
        $sql = "INSERT INTO Items (id, created_at, status, store_id, country) VALUES (null, '$date', '0', '$store_id', '$country')";
    }

    if ($conx->query($sql)) {
        $newItemId = $conx->insert_id;
        
        $gesClientId = $badaaClientId = 0;
        $clientId = 0; // شيل syncEmptyToClient خالص

        if ($store_id == '3') {
            $gesClientId = syncEmptyToClient('3');
        }

        if ($store_id == '4') {
            $badaaClientId = syncEmptyToClient('4');
            if ($badaaClientId > 0) {
                $client_id_badaa = (string)$badaaClientId;
                $conx->query("UPDATE Items SET idx = '$badaaClientId' WHERE id = '$newItemId'");
            }
        }
        // لا تحدث idx من GlobalFarm هنا
        
        $response = array(
            'success' => true,
            'item_id' => $newItemId,
            'client_id' => $clientId,
            'client_id_ges' => $gesClientId,
            'client_id_badaa' => $client_id_badaa,
            'idx' => $client_id_badaa,
        );
    }
    break;
            
        case 'user_status':
            $uid = isset($_POST['uid']) ? $conx->real_escape_string($_POST['uid']) : '';
            $sql = "SELECT status FROM Users WHERE uid = '$uid' ";
            $status = $conx->query($sql)->fetch_array()[0];

            $response = array(
                'success' => true,
                'status' => $status
            );
            break;

        // =====================================
        // جلب التصنيفات (Get Categories)
        // =====================================
        case 'get_categories':
    $store_id = isset($_POST['store_id']) ? $conx->real_escape_string($_POST['store_id']) : '';
    
    $store_clause = !empty($store_id) ? "AND store_id = '$store_id'" : '';
    $sql = "SELECT DISTINCT category 
            FROM Items 
            WHERE category IS NOT NULL 
            AND category != '' 
            $store_clause
            ORDER BY category ASC";
    
    $result = $conx->query($sql);
    $categories = array();
    
    if ($result && $result->num_rows > 0) {
        while ($row = $result->fetch_assoc()) {
            $categories[] = $row['category'];
        }
    }
    
    $response = array(
        'status' => 'success',
        'categories' => $categories
    );
    break;

        // =====================================
        // تحديث صنف (Update Item)
        // =====================================
        case 'update':
            $item_id = isset($_POST['item_id']) ? (int)$_POST['item_id'] : 0;
            
            if ($item_id <= 0) {
                $response = array(
                    'success' => false,
                    'error' => 'معرف الصنف مطلوب'
                );
                break;
            }

            $updates = array();
            
            if (isset($_POST['name'])) {
                $name = $conx->real_escape_string($_POST['name']);
                $updates[] = "`name` = '$name'";
            }
            if (isset($_POST['price'])) {
                $price = $conx->real_escape_string($_POST['price']);
                $updates[] = "price = '$price'";
            }
            if (isset($_POST['quantity'])) {
                $qtt = (int)$_POST['quantity'];
                $updates[] = "qtt = $qtt";
            }
            if (isset($_POST['description'])) {
                $description = $conx->real_escape_string($_POST['description']);
                $updates[] = "description = '$description'";
            }
            if (isset($_POST['visibility'])) {
                $visibility = $conx->real_escape_string($_POST['visibility']);
                $updates[] = "Visibility = '$visibility'";
            }
            if (isset($_POST['media'])) {
                $media = $conx->real_escape_string($_POST['media']);
                $updates[] = "media = '$media'";
            }

            if (empty($updates)) {
                $response = array(
                    'success' => false,
                    'error' => 'لا توجد بيانات للتحديث'
                );
                break;
            }

            $old_qtt = isset($_POST['old_qtt']) ? (int)$_POST['old_qtt'] : -1;
            $new_qtt = isset($_POST['quantity']) ? (int)$_POST['quantity'] : -1;

            $sql = "UPDATE Items SET " . implode(', ', $updates) . " WHERE id = $item_id";

            if ($conx->query($sql)) {
                $response = array(
                    'success' => true,
                    'message' => 'تم تحديث الصنف بنجاح',
                    'affected_rows' => $conx->affected_rows
                );

                if ($old_qtt >= 0 && $new_qtt >= 0) {
                    $notify_users = martit_process_notify_restock($conx, $item_id, $old_qtt, $new_qtt);
                    $response['notify_users'] = $notify_users;
                }
            } else {
                $response = array(
                    'success' => false,
                    'error' => 'فشل في تحديث الصنف: ' . $conx->error
                );
            }
            break;

        case 'add_notify_request':
            $item_id = isset($_POST['item_id']) ? $conx->real_escape_string($_POST['item_id']) : '';
            $user_id = isset($_POST['user_id']) ? $conx->real_escape_string($_POST['user_id']) : '';
            $store_id = isset($_POST['store_id']) ? $conx->real_escape_string($_POST['store_id']) : '1';

            if ($item_id === '' || $user_id === '') {
                $response = array(
                    'success' => false,
                    'error' => 'معرف الصنف ومعرف المستخدم مطلوبان'
                );
                break;
            }

            $checkSql = "SELECT id FROM NotifyRequests WHERE item_id = '$item_id' AND user_id = '$user_id' LIMIT 1";
            $checkResult = $conx->query($checkSql);

            if ($checkResult && $checkResult->num_rows > 0) {
                $response = array(
                    'success' => true,
                    'already_subscribed' => true,
                    'message' => 'أنت مشترك بالفعل في هذا التنبيه'
                );
                break;
            }

            $created_at = date('Y-m-d H:i:s');
            $insertSql = "INSERT INTO NotifyRequests (item_id, user_id, store_id, created_at, notified_at)
                          VALUES ('$item_id', '$user_id', '$store_id', '$created_at', NULL)";

            if ($conx->query($insertSql)) {
                $response = array(
                    'success' => true,
                    'already_subscribed' => false,
                    'message' => 'سيتم إشعارك عند توفر المنتج'
                );
            } else {
                $response = array(
                    'success' => false,
                    'error' => 'فشل في تسجيل التنبيه: ' . $conx->error
                );
            }
            break;

        case 'check_notify_status':
            $item_id = isset($_POST['item_id']) ? $conx->real_escape_string($_POST['item_id']) : '';
            $user_id = isset($_POST['user_id']) ? $conx->real_escape_string($_POST['user_id']) : '';

            if ($item_id === '' || $user_id === '') {
                $response = array(
                    'success' => false,
                    'error' => 'معرف الصنف ومعرف المستخدم مطلوبان'
                );
                break;
            }

            $statusSql = "SELECT id FROM NotifyRequests
                          WHERE item_id = '$item_id' AND user_id = '$user_id' AND notified_at IS NULL
                          LIMIT 1";
            $statusResult = $conx->query($statusSql);
            $is_subscribed = ($statusResult && $statusResult->num_rows > 0);

            $response = array(
                'success' => true,
                'is_subscribed' => $is_subscribed
            );
            break;

        case 'get_user_notify_subscriptions':
            $user_id = isset($_POST['user_id']) ? $conx->real_escape_string($_POST['user_id']) : '';
            if (empty($user_id)) {
                $response = array('success' => false, 'error' => 'user_id مطلوب');
                break;
            }
            $sql = "SELECT item_id FROM NotifyRequests WHERE user_id = '$user_id' AND notified_at IS NULL";
            $result = $conx->query($sql);
            $item_ids = array();
            if ($result) {
                while ($row = $result->fetch_assoc()) {
                    $item_ids[] = $row['item_id'];
                }
            }
            $response = array('success' => true, 'item_ids' => $item_ids);
            break;

        case 'update_has_image':
            $item_id = isset($_POST['item_id']) ? $conx->real_escape_string($_POST['item_id']) : '';
            $has_image = isset($_POST['has_image']) ? (int)$_POST['has_image'] : 0;
            $sql = "UPDATE Items SET has_image = '$has_image' WHERE id = '$item_id'";
            if ($conx->query($sql)) {
                $response = ['success' => true];
            } else {
                $response = ['success' => false, 'error' => $conx->error];
            }
            break;

        case 'update_item_media':
            $item_id = isset($_POST['item_id']) ? $conx->real_escape_string($_POST['item_id']) : '';
            $media = isset($_POST['media']) ? $conx->real_escape_string($_POST['media']) : '';
            if ($item_id === '') {
                $response = ['success' => false, 'error' => 'item_id required'];
                break;
            }
            $sql = "UPDATE Items SET has_image = '1', media = '$media' WHERE id = '$item_id'";
            if ($conx->query($sql)) {
                $response = ['success' => true];
            } else {
                $response = ['success' => false, 'error' => $conx->error];
            }
            break;

        case 'update_item_idx':
            $item_id = isset($_POST['item_id']) ? $conx->real_escape_string($_POST['item_id']) : '';
            $idx = isset($_POST['idx']) ? $conx->real_escape_string($_POST['idx']) : '';
            if ($item_id === '' || $idx === '') {
                $response = ['success' => false, 'error' => 'item_id and idx required'];
                break;
            }
            $sql = "UPDATE Items SET idx = '$idx' WHERE id = '$item_id'";
            if ($conx->query($sql)) {
                $response = ['success' => true];
            } else {
                $response = ['success' => false, 'error' => $conx->error];
            }
            break;

        // =====================================
        // حذف صنف (Delete Item)
        // =====================================
        case 'delete':
            $item_id = isset($_POST['item_id']) ? (int)$_POST['item_id'] : 0;
            
            if ($item_id <= 0) {
                $response = array(
                    'success' => false,
                    'error' => 'معرف الصنف مطلوب'
                );
                break;
            }

            $sql = "DELETE FROM Items WHERE id = $item_id";

            if ($conx->query($sql)) {
                $response = array(
                    'success' => true,
                    'message' => 'تم حذف الصنف بنجاح',
                    'affected_rows' => $conx->affected_rows
                );
            } else {
                $response = array(
                    'success' => false,
                    'error' => 'فشل في حذف الصنف: ' . $conx->error
                );
            }
            break;

        // =====================================
        // جلب صنف واحد (Get Single Item)
        // =====================================
        case 'get_item':
            $item_id = isset($_POST['item_id']) ? trim((string)$_POST['item_id']) : '';
            $user_id = isset($_POST['user_id']) ? $conx->real_escape_string($_POST['user_id']) : '';
            $store_id = isset($_POST['store_id']) ? $conx->real_escape_string($_POST['store_id']) : '';
            
            if ($item_id === '') {
                $response = array(
                    'success' => false,
                    'error' => 'معرف الصنف مطلوب'
                );
                break;
            }

            $escapedId = $conx->real_escape_string($item_id);
            $get_store = $store_id !== '' ? "AND Items.store_id = '$store_id'" : '';

            $sql = "SELECT
                Items.id,
                Items.idx,
                Items.store_id AS storeid,
                Items.barcode,
                Items.name,
                Items.eng,
                Items.price,
                Items.qtt,
                Items.description,
                Items.description_arb,
                Items.Views,
                Items.media,
                Items.uid AS firebase_uid,
                Users.id AS seller_db_id,
                Users.Fullname,
                Users.uid AS user_id,
                COALESCE(likes_count.total_likes, 0) as likes_count,
                COALESCE(comments_count.total_comments, 0) as comments_count,
                COALESCE(cart_count.total_cart, 0) as cart_quantity,
                CASE WHEN user_likes.user_id IS NOT NULL THEN 1 ELSE 0 END as is_liked
            FROM
                Items
            LEFT JOIN Users
                ON Items.uid = Users.uid
            LEFT JOIN (
                SELECT item_id, COUNT(*) as total_likes 
                FROM Likes 
                GROUP BY item_id
            ) likes_count ON Items.id = likes_count.item_id
            LEFT JOIN (
                SELECT item_id, COUNT(*) as total_comments 
                FROM Comments 
                GROUP BY item_id
            ) comments_count ON Items.id = comments_count.item_id
            LEFT JOIN (
                SELECT item_id, SUM(qtt) as total_cart 
                FROM Cart " . (!empty($user_id) ? "WHERE user_id = '$user_id'" : "") . "
                GROUP BY item_id
            ) cart_count ON Items.id = cart_count.item_id
            LEFT JOIN (
                SELECT item_id, user_id 
                FROM Likes " . (!empty($user_id) ? "WHERE user_id = '$user_id'" : "WHERE 1=0") . "
            ) user_likes ON Items.id = user_likes.item_id
            WHERE Items.Visibility = 'Public'
            AND (Items.id = '$escapedId' OR Items.idx = '$escapedId' OR Items.barcode = '$escapedId')
            $get_store
            LIMIT 1";

            $result = $conx->query($sql);
            
            if ($result && $result->num_rows > 0) {
                $row = $result->fetch_assoc();
                
                $storeid = (string)($row['storeid'] ?? '1');
                $itemId = (string)$row['id'];
                $mediaFiles = build_item_media_urls(
                    $storeid,
                    $itemId,
                    $row['media'],
                    null,
                    (string)($row['idx'] ?? '')
                );
                
                $sellerUid = !empty($row['firebase_uid'])
                    ? (string)$row['firebase_uid']
                    : (string)($row['user_id'] ?? '');
                $sellerDbId = !empty($row['seller_db_id'])
                    ? (string)$row['seller_db_id']
                    : $sellerUid;

                $item = array(
                    'id' => $itemId,
                    'idx' => (string)($row['idx'] ?? ''),
                    'storeid' => $storeid,
                    'barcode' => (string)($row['barcode'] ?? ''),
                    'name' => (string)$row['name'],
                    'eng' => (string)($row['eng'] ?? ''),
                    'price' => (string)$row['price'],
                    'quantity' => (int)$row['qtt'],
                    'description' => (string)$row['description'],
                    'description_arb' => (string)($row['description_arb'] ?? ''),
                    'views' => (int)$row['Views'],
                    'media' => $mediaFiles,
                    'seller' => array(
                        'id' => $sellerDbId,
                        'uid' => $sellerUid,
                        'name' => (string)($row['Fullname'] ?? 'مستخدم'),
                        'avatar' => user_avatar_url($sellerUid, $storeid),
                        'isFollowing' => false,
                        'token' => ''
                    ),
                    'interactions' => array(
                        'likes' => (int)$row['likes_count'],
                        'comments' => (int)$row['comments_count'],
                        'shares' => 0,
                        'cartQuantity' => (int)$row['cart_quantity'],
                        'isLiked' => (bool)$row['is_liked']
                    )
                );
                
                $response = array(
                    'success' => true,
                    'data' => $item
                );
            } else {
                $response = array(
                    'success' => false,
                    'error' => 'الصنف غير موجود'
                );
            }
            break;

        // =====================================
        // زيادة عدد المشاهدات (Increment Views)
        // =====================================
        case 'increment_views':
            $item_id = isset($_POST['item_id']) ? (int)$_POST['item_id'] : 0;
            
            if ($item_id <= 0) {
                $response = array(
                    'success' => false,
                    'error' => 'معرف الصنف مطلوب'
                );
                break;
            }

            $sql = "UPDATE Items SET Views = Views + 1 WHERE id = $item_id";

            if ($conx->query($sql)) {
                $response = array(
                    'success' => true,
                    'message' => 'تم تحديث المشاهدات'
                );
            } else {
                $response = array(
                    'success' => false,
                    'error' => 'فشل في تحديث المشاهدات: ' . $conx->error
                );
            }
            break;

        // =====================================
        // البحث عن أصناف (Search Items)
        // =====================================
         case 'search':
            $searchQuery = isset($_GET['q']) ? trim($_GET['q']) : '';
    
            try {
                if (empty($searchQuery)) {
                    echo json_encode(array(
                        'success' => true,
                        'data' => array()
                    ));
                    exit;
                }
                
                // SQL query to search items by name
                $searchQuery = $conx->real_escape_string($searchQuery);
                $store_id_filter = isset($_GET['store_id']) ? $conx->real_escape_string($_GET['store_id']) : '';
                $store_clause = $store_id_filter !== '' ? " AND Items.store_id = '$store_id_filter'" : '';

                $sql = "SELECT
                    Items.id,
                    Items.idx,
                    Items.`name`,
                    Items.eng,
                    Items.price,
                    Items.media,
                    Items.store_id AS storeid,
                    Users.Fullname,
                    Users.id AS user_id
                FROM
                    Items
                LEFT JOIN Users
                    ON Items.uid = Users.uid
                WHERE Items.Visibility = 'Public'
                    AND (
                        Items.`name` LIKE '%$searchQuery%'
                        OR Items.eng LIKE '%$searchQuery%'
                        OR Items.description_arb LIKE '%$searchQuery%'
                        OR Items.description LIKE '%$searchQuery%'
                        OR Items.barcode LIKE '%$searchQuery%'
                        OR Items.id = '$searchQuery'
                        OR Items.idx = '$searchQuery'
                    )
                    $store_clause
                ORDER BY Items.`name` ASC
                LIMIT 20";
            
                $result = $conx->query($sql);
                
                if ($result->num_rows > 0) {
                    $items = array();
                    
                    while($row = $result->fetch_assoc()) {
                        $storeid = !empty($row['storeid']) ? (string)$row['storeid'] : '1';
                        $itemId = (string)$row['id'];
                        $itemIdx = (string)($row['idx'] ?? '');
                        $storeid_val = !empty($row['storeid']) ? $row['storeid'] : '1';
                        $thumbnail = item_thumbnail_url_from_media(
                            $storeid_val,
                            $itemId,
                            $row['media'],
                            $itemIdx
                        );
                        
                        // Build search result object
                        $item = array(
                            'id' => $row['id'],
                            'idx' => $itemIdx,
                            'store_id' => $storeid,
                            'storeid' => $storeid,
                            'name' => $row['name'],
                            'eng' => (string)($row['eng'] ?? ''),
                            'price' => $row['price'],
                            'media' => (string)($row['media'] ?? ''),
                            'thumbnail' => $thumbnail,
                            'seller' => array(
                                'id' => $row['user_id'],
                                'name' => $row['Fullname']
                            )
                        );
                        
                        $items[] = $item;
                    }
                    
                    echo json_encode(array(
                        'success' => true,
                        'data' => $items
                    ));
                    
                } else {
                    echo json_encode(array(
                        'success' => true,
                        'data' => array()
                    ));
                }
                
            } catch (Exception $e) {
                echo json_encode(array(
                    'success' => false,
                    'error' => 'Search error: ' . $e->getMessage()
                ));
            }
            
            $conx->close();
        
        case 'get_user_details':
            $phone = isset($_POST['phone']) ? trim($_POST['phone']) : '';
            $email = isset($_POST['email']) ? trim($_POST['email']) : '';
            $id = isset($_POST['id']) ? trim($_POST['id']) : '';
            if (isset($_POST['fcm_token']))
            {
                $oid = isset($_POST['oid']) ? trim($_POST['oid']) : '';
                $fcm_token = isset($_POST['fcm_token']) ? trim($_POST['fcm_token']) : '';
                $id_esc = $conx->real_escape_string($id);
                $oid_esc = $conx->real_escape_string($oid);
                $fcm_esc = $conx->real_escape_string($fcm_token);
                if ($id_esc !== '') {
                    $conx->query("UPDATE Users SET player_id = '$fcm_esc', oid = '$oid_esc' WHERE uid = '$id_esc'");
                }
                if ($phone !== '') {
                    $phone_esc_token = $conx->real_escape_string($phone);
                    $conx->query("UPDATE employees SET player_id = '$fcm_esc' WHERE phone = '$phone_esc_token'");
                }
            }
        
            try {
                if (empty($phone) && empty($email) && empty($id)) {
                    $response = ['success' => false, 'error' => 'رقم الهاتف أو البريد الإلكتروني مطلوب'];
                    break;
                }
                
                $sql = "";
                if (!empty($id) && empty($phone) && empty($email)) {
                    $id_esc = $conx->real_escape_string($id);
                    $sql = "SELECT Fullname, PhoneNumber, uid, urlAvatar, oid, role, store_id FROM Users WHERE uid = '$id_esc' LIMIT 1";
                } else if (!empty($email)) {
                    $email = $conx->real_escape_string($email);
                    $sql = "SELECT Fullname, PhoneNumber, uid, urlAvatar, oid, role, store_id FROM Users WHERE Email = '$email' LIMIT 1";
                } else {
                    $phone = $conx->real_escape_string($phone);
                    $sql = "SELECT Fullname, PhoneNumber, uid, urlAvatar, oid, role, store_id FROM Users WHERE PhoneNumber = '$phone' LIMIT 1";
                }
            
                $result = $conx->query($sql);
                
                // تحقق من وجود نتائج
                if ($result && $result->num_rows > 0) {
                    $row = $result->fetch_assoc(); // استخدم fetch_assoc بدلاً من fetch_array
                    
                    $user = array(
                        'id' => $row['uid'],
                        'oid' => $row['oid'],
                        'name' => $row['Fullname'],
                        'phone' => $row['PhoneNumber'],
                        'avatar' => $row['urlAvatar'],
                        'role' => $row['role'] ?? null,
                        'store_id' => $row['store_id'] ?? null,
                    );
                    martit_apply_employee_admin($conx, $user, $user['phone'], true);
                    
                    $response = array(
                        'success' => true,
                        'data' => $user
                    );
                } else if (!empty($phone)) {
                    // Phone not in Users — allow login if listed in employees
                    $emp = martit_find_employee_by_phone($conx, $phone);
                    if ($emp) {
                        $user = martit_ensure_user_for_employee($conx, $emp);
                        if ($user) {
                            $response = array(
                                'success' => true,
                                'data' => $user
                            );
                        } else {
                            $response = array(
                                'success' => false,
                                'error' => 'تعذر تجهيز حساب الموظف'
                            );
                        }
                    } else {
                        $response = array(
                            'success' => false,
                            'error' => 'المستخدم غير موجود'
                        );
                    }
                } else {
                    $response = array(
                        'success' => false,
                        'error' => 'المستخدم غير موجود'
                    );
                }
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في البحث: ' . $e->getMessage()
                );
            }
            
            break;
            
        case 'create_account':
            $uid = isset($_POST['uid']) ? trim($_POST['uid']) : '';
            $oid = isset($_POST['oid']) ? trim($_POST['oid']) : '';
            $name = isset($_POST['name']) ? trim($_POST['name']) : '';
            $phone = isset($_POST['phone']) ? trim($_POST['phone']) : '';
            $email = isset($_POST['email']) ? $conx->real_escape_string(trim($_POST['email'])) : '';
            $player_id = isset($_POST['player_id']) ? trim($_POST['player_id']) : '';
            $store_id = isset($_POST['store_id']) ? trim($_POST['store_id']) : '1';
            $login_type = isset($_POST['login_type']) ? trim($_POST['login_type']) : 'Phone';
            $avatar_url = isset($_POST['avatar_url']) ? $conx->real_escape_string(trim($_POST['avatar_url'])) : '';
            $date = date('Y-m-d');
        
            if (empty($phone) && empty($_POST['email'])) {
                $response = array(
                    'success' => false,
                    'error' => 'رقم الهاتف مطلوب'
                );
                break;
            }
            
            if (!empty($phone)) {
                $userExists = $conx->query("SELECT PhoneNumber, uid, oid, role, store_id FROM Users WHERE PhoneNumber = '$phone'");
            } else {
                $userExists = $conx->query("SELECT PhoneNumber, uid, oid, role, store_id FROM Users WHERE Email = '$email'");
            }
            
            if ($userExists && $userExists->num_rows > 0) {
    $existingUser = $userExists->fetch_assoc();
    $roleOut = $existingUser['role'] ?? null;
    $storeOut = $existingUser['store_id'] ?? null;
    $empUser = array(
        'id' => $existingUser['uid'],
        'phone' => !empty($phone) ? $phone : null,
        'role' => $roleOut,
        'store_id' => $storeOut,
    );
    martit_apply_employee_admin($conx, $empUser, $phone, true);
    $response = array(
        'success' => false,
        'error' => 'المستخدم موجود بالفعل',
        'uid' => array(
            'uid' => $existingUser['uid'],
            'oid' => $existingUser['oid'],
            'role' => $empUser['role'] ?? $roleOut,
            'store_id' => $empUser['store_id'] ?? $storeOut,
        )
    );
} else {
    $roleInsert = 'NULL';
    $emp = !empty($phone) ? martit_find_employee_by_phone($conx, $phone) : null;
    if ($emp) {
        $roleInsert = "'Admin'";
        if (!empty($emp['store_id'])) {
            $store_id = $conx->real_escape_string((string)$emp['store_id']);
        }
    }
    $sql = "INSERT INTO Users(Fullname, PhoneNumber, Email, uid, oid, Created_at, status, player_id, login_type, store_id, urlAvatar, role) 
            VALUES('$name', '$phone', '$email', '$uid', '$oid', '$date', '0', '$player_id', '$login_type', '$store_id', '$avatar_url', " . ($roleInsert === 'NULL' ? "NULL" : $roleInsert) . ")";
    $conx->query("UPDATE employees SET player_id = '$player_id' WHERE phone = '$phone'");
    $result = $conx->query($sql);

    $dataOut = array(
        'id' => $uid,
        'oid' => $oid,
        'role' => $emp ? 'Admin' : null,
        'store_id' => $store_id,
        'is_employee' => $emp ? true : false,
    );
    
    $response = array(
        'success' => true,
        'message' => 'تم إضافة المستخدم بنجاح',
        'data' => $dataOut,
    );
}
            break;
        case 'get_tokens':
                $empnumbers = '71402613';
                $sql = "SELECT id, phone, player_id FROM employees WHERE phone IN ($empnumbers)";
                $result = $conx->query($sql);
                $player_ids = array();
                while($rows = $result->fetch_assoc()) {
                    $player_ids[] = $rows;
                }
                
                
                
                $response = array(
                    'success' => true,
                    'player_ids' => $player_ids
                );
            break;

        // =====================================
        // جلب إحصائيات الصنف (Get Item Stats)
        // =====================================
        case 'get_stats':
            $item_id = isset($_POST['item_id']) ? (int)$_POST['item_id'] : 0;
            
            if ($item_id <= 0) {
                $response = array(
                    'success' => false,
                    'error' => 'معرف الصنف مطلوب'
                );
                break;
            }

            try {
                // جلب بيانات الصنف مع الإحصائيات
                $sql = "SELECT 
                    Items.description,
                    Items.Views,
                    Items.created_at,
                    COALESCE(COUNT(Likes.id), 0) AS likes_count
                FROM Items 
                LEFT JOIN Likes ON Likes.item_id = Items.id 
                WHERE Items.id = $item_id
                GROUP BY Items.id";

                $result = $conx->query($sql);
                
                if ($result && $result->num_rows > 0) {
                    $row = $result->fetch_assoc();
                    
                    // تنسيق التاريخ
                    $created_date = '';
                    if (!empty($row['created_at'])) {
                        $date = new DateTime($row['created_at']);
                        $created_date = $date->format('Y-m-d H:i');
                    }
                    
                    $stats = array(
                        'description' => (string)$row['description'],
                        'likes' => (int)$row['likes_count'],
                        'views' => (int)$row['Views'],
                        'created_at' => $created_date
                    );
                    
                    $response = array(
                        'success' => true,
                        'data' => $stats
                    );
                } else {
                    $response = array(
                        'success' => false,
                        'error' => 'الصنف غير موجود'
                    );
                }
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في جلب الإحصائيات: ' . $e->getMessage()
                );
            }
            break;

        // =====================================
        // إضافة بلاغ (Add Report)
        // =====================================
        case 'add_report':
            $item_id = isset($_POST['item_id']) ? $conx->real_escape_string($_POST['item_id']) : '';
            $user_id = isset($_POST['user_id']) ? $conx->real_escape_string($_POST['user_id']) : '';
            $reason = isset($_POST['reason']) ? $conx->real_escape_string($_POST['reason']) : '';
            $created_at = date('Y-m-d H:i:s');
            
            if (empty($item_id) || empty($user_id) || empty($reason)) {
                $response = array(
                    'success' => false,
                    'error' => 'جميع البيانات مطلوبة (item_id, user_id, reason)'
                );
                break;
            }

            try {
                $sql = "INSERT INTO Flags (item_id, user_id, reason, created_at, status) 
                        VALUES ('$item_id', '$user_id', '$reason', '$created_at', 'pending')";

                if ($conx->query($sql)) {
                    $response = array(
                        'success' => true,
                        'message' => 'تم إرسال البلاغ بنجاح'
                    );
                } else {
                    $response = array(
                        'success' => false,
                        'error' => 'فشل في إرسال البلاغ: ' . $conx->error
                    );
                }
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في إرسال البلاغ: ' . $e->getMessage()
                );
            }
            break;

        // =====================================
        // جلب الأصناف مع حالة الإعجابات (Fetch with Likes)
        // =====================================
        case 'fetch_with_likes':
            $user_id = isset($_POST['user_id']) ? $conx->real_escape_string($_POST['user_id']) : '';
            $limit = isset($_POST['limit']) ? (int)$_POST['limit'] : 10;
            $offset = isset($_POST['offset']) ? (int)$_POST['offset'] : 0;
            $itemSrchId = isset($_POST['itemSrchId']) ? $conx->real_escape_string($_POST['itemSrchId']) : '';
            $store_id = isset($_POST['store_id']) ? $conx->real_escape_string($_POST['store_id']) : '';
            $category = isset($_POST['category']) ? $conx->real_escape_string($_POST['category']) : '';
            $country = isset($_POST['country']) ? $conx->real_escape_string($_POST['country']) : '';
            $pinnedItemId = isset($_POST['pinnedItemId']) ? $conx->real_escape_string(trim($_POST['pinnedItemId'])) : '';
            $get_store = "";
            if ($store_id) {
                $get_store = "AND Items.store_id = '$store_id'";
            }
            // Debug logging
            error_log("📦 fetch_with_likes - Category received: " . ($category ? $category : 'NULL'));
            $img_url = "https://globee.b-cdn.net/";
            $d1 = "";
            $d2 = "";
            $d3 = "";
            if ($itemSrchId) {
                $d1 = "AND Items.id = '$itemSrchId'";
            }
            if (!empty($category)) {
                $d3 = "AND Items.category = '$category'";
            }

            $ucsJoin = "";
            $order_by = "RAND()";
            if (!empty($user_id)) {
                $ucsJoin = "
                LEFT JOIN UserCategoryScore ucs 
                    ON Items.category = ucs.category 
                    AND ucs.user_id = '$user_id'
                    AND ucs.store_id = Items.store_id";
                $order_by = "(COALESCE(ucs.score, 0) * 3 + COALESCE(likes_count.total_likes, 0) * 0.2 + (RAND() * 30)) DESC";
            }
            
            try {
                $likesSelect = "SELECT 
                    Items.id,
                    Items.idx,
                    Items.store_id AS storeid,
                    Items.barcode,
                    Items.name,
                    Items.eng,
                    Items.price,
                    Items.qtt,
                    Items.description,
                    Items.description_arb,
                    Items.Views,
                    Items.media,
                    Items.created_at,
                    Items.uid AS firebase_uid,
                    Users.id AS seller_db_id,
                    Users.Fullname,
                    Users.uid AS user_id,
                    Users.player_id AS token,
                    COALESCE(likes_count.total_likes, 0) as likes_count,
                    CASE WHEN user_likes.user_id IS NOT NULL THEN 1 ELSE 0 END as is_liked,
                    CASE WHEN user_follows.buyer_id IS NOT NULL THEN 1 ELSE 0 END as is_following,
                    COALESCE(comments_count.total_comments, 0) as comments_count,
                    COALESCE(cart_count.total_cart, 0) as cart_quantity";

                $likesFrom = "
                FROM Items 
                LEFT JOIN Users ON Items.uid = Users.uid
                LEFT JOIN (
                    SELECT item_id, COUNT(*) as total_likes 
                    FROM Likes 
                    GROUP BY item_id
                ) likes_count ON Items.id = likes_count.item_id
                LEFT JOIN (
                    SELECT item_id, user_id 
                    FROM Likes 
                    WHERE user_id = '$user_id'
                ) user_likes ON Items.id = user_likes.item_id
                LEFT JOIN (
                    SELECT user_id, buyer_id 
                    FROM Followers 
                    WHERE buyer_id = '$user_id'
                ) user_follows ON Items.uid = user_follows.user_id
                LEFT JOIN (
                    SELECT item_id, COUNT(*) as total_comments 
                    FROM Comments 
                    GROUP BY item_id
                ) comments_count ON Items.id = comments_count.item_id
                LEFT JOIN (
                    SELECT item_id, SUM(qtt) as total_cart 
                    FROM Cart 
                    WHERE user_id = '$user_id'
                    GROUP BY item_id
                ) cart_count ON Items.id = cart_count.item_id" . $ucsJoin;

                $likesWherePublic = "Items.Visibility = 'Public' AND Items.country = '$country' AND Items.has_image = 1 $get_store $d3";

                if (!empty($pinnedItemId) && $offset == 0 && empty($itemSrchId)) {
                    $restLimit = max(1, $limit - 1);
                    $sql = "($likesSelect $likesFrom WHERE Items.id = '$pinnedItemId')
                            UNION ALL
                            ($likesSelect $likesFrom WHERE $likesWherePublic AND Items.id != '$pinnedItemId' ORDER BY $order_by LIMIT $restLimit)";
                } elseif (!empty($itemSrchId)) {
                    $escapedId = $conx->real_escape_string($itemSrchId);
                    $lookupSql = "SELECT Items.id FROM Items WHERE Items.Visibility = 'Public' AND Items.id = '$escapedId' $get_store LIMIT 1";
                    $lookupResult = $conx->query($lookupSql);
                    if (!$lookupResult || $lookupResult->num_rows === 0) {
                        $lookupSql = "SELECT Items.id FROM Items WHERE Items.Visibility = 'Public' AND Items.idx = '$escapedId' $get_store LIMIT 1";
                        $lookupResult = $conx->query($lookupSql);
                    }
                    if ($lookupResult && $lookupResult->num_rows > 0) {
                        $foundRow = $lookupResult->fetch_assoc();
                        $foundId = $conx->real_escape_string((string)$foundRow['id']);
                        $restLimit = max(1, $limit - 1);
                        $sql = "($likesSelect $likesFrom WHERE Items.id = '$foundId')
                                UNION ALL
                                ($likesSelect $likesFrom WHERE $likesWherePublic AND Items.id != '$foundId' ORDER BY $order_by LIMIT $restLimit)";
                    } else {
                        $sql = "$likesSelect $likesFrom WHERE 1=0";
                    }
                } else {
                    $sql = "$likesSelect $likesFrom
                    WHERE $likesWherePublic $d1
                    ORDER BY $order_by
                    LIMIT $limit OFFSET $offset";
                }
        
                $result = $conx->query($sql);
                
                if ($result) {
                    $items = array();
                    while ($row = $result->fetch_assoc()) {
                        $storeid = (string)($row['storeid'] ?? '1');
                        $itemId = (string)$row['id'];
                        $mediaFiles = build_item_media_urls($storeid, $itemId, $row['media'], null, (string)($row['idx'] ?? ''));

                        $sellerUid = !empty($row['firebase_uid'])
                            ? (string)$row['firebase_uid']
                            : (string)($row['user_id'] ?? '');
                        $sellerDbId = !empty($row['seller_db_id'])
                            ? (string)$row['seller_db_id']
                            : $sellerUid;

                        $item = array(
                            'id' => (string)$row['id'],
                            'idx' => (string)$row['idx'],
                            'storeid' => (string)$row['storeid'],
                            'barcode' => (string)$row['barcode'],
                            'name' => (string)$row['name'],
                            'eng' => (string)($row['eng'] ?? ''),
                            'price' => (string)$row['price'],
                            'quantity' => (int)$row['qtt'],
                            'description' => (string)$row['description'],
                            'description_arb' => (string)($row['description_arb'] ?? ''),
                            'views' => (int)$row['Views'],
                            'media' => $mediaFiles,
                            'seller' => array(
                                'id' => $sellerDbId,
                                'uid' => $sellerUid,
                                'name' => (string)($row['Fullname'] ?? 'مستخدم'),
                                'avatar' => user_avatar_url($sellerUid, $storeid),
                                'isFollowing' => (bool)$row['is_following'],
                                'token' => (string)($row['token'] ?? '')
                            ),
                            'interactions' => array(
                                'likes' => (int)$row['likes_count'],
                                'isLiked' => (bool)$row['is_liked'],
                                'comments' => (int)$row['comments_count'],
                                'shares' => 0,
                                'cartQuantity' => (int)$row['cart_quantity']
                            )
                        );
                        
                        $items[] = $item;
                    }
                    
                    $response = array(
                        'success' => true,
                        'data' => $items
                    );
                } else {
                    $response = array(
                        'success' => false,
                        'error' => 'فشل في جلب الأصناف: ' . $conx->error
                    );
                }
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في جلب الأصناف: ' . $e->getMessage()
                );
            }
            break;
        case 'get_token_followers':
            $user_id = isset($_POST['user_id']) ? $conx->real_escape_string($_POST['user_id']) : '';
            
            try {
                $sql = "SELECT user_token FROM Followers WHERE user_id = '$user_id'";
                $result = $conx->query($sql);
                $tokens = array();
                while ($row = $result->fetch_assoc()) {
                    $tokens[] = $row;
                }
                
                $response = array(
                    'success' => true,
                    'data' => $tokens
                );
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في جلب الأصناف: ' . $e->getMessage()
                );
            }
            break;

        // =====================================
        // إدارة الإعجابات (Like/Unlike)
        // =====================================
        case 'toggle_like':
            $item_id = isset($_POST['item_id']) ? $conx->real_escape_string($_POST['item_id']) : '';
            $user_id = isset($_POST['user_id']) ? $conx->real_escape_string($_POST['user_id']) : '';
            
            if (empty($item_id) || empty($user_id)) {
                $response = array(
                    'success' => false,
                    'error' => 'معرف الصنف ومعرف المستخدم مطلوبان'
                );
                break;
            }

            try {
                // التحقق من وجود إعجاب سابق
                $checkSql = "SELECT id FROM Likes WHERE item_id = '$item_id' AND user_id = '$user_id'";
                $checkResult = $conx->query($checkSql);
                
                if ($checkResult && $checkResult->num_rows > 0) {
                    // إزالة الإعجاب
                    $deleteSql = "DELETE FROM Likes WHERE item_id = '$item_id' AND user_id = '$user_id'";
                    if ($conx->query($deleteSql)) {
                        $response = array(
                            'success' => true,
                            'action' => 'unliked',
                            'message' => 'تم إلغاء الإعجاب'
                        );
                    } else {
                        $response = array(
                            'success' => false,
                            'error' => 'فشل في إلغاء الإعجاب: ' . $conx->error
                        );
                    }
                } else {
                    // إضافة إعجاب جديد
                    $created_at = date('Y-m-d H:i:s');
                    $insertSql = "INSERT INTO Likes (item_id, user_id, created_at) VALUES ('$item_id', '$user_id', '$created_at')";
                    if ($conx->query($insertSql)) {
                        $response = array(
                            'success' => true,
                            'action' => 'liked',
                            'message' => 'تم الإعجاب بنجاح'
                        );
                    } else {
                        $response = array(
                            'success' => false,
                            'error' => 'فشل في إضافة الإعجاب: ' . $conx->error
                        );
                    }
                }
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في إدارة الإعجاب: ' . $e->getMessage()
                );
            }
            break;
        // =====================================
        // إدارة سلة التسوق (Cart Management)
        // =====================================
        case 'add_to_cart':
            $item_id = isset($_POST['item_id']) ? $conx->real_escape_string($_POST['item_id']) : '';
            $user_id = isset($_POST['user_id']) ? $conx->real_escape_string($_POST['user_id']) : '';
            $quantity = isset($_POST['quantity']) ? (int)$_POST['quantity'] : 1;
            
            if (empty($item_id) || empty($user_id)) {
                $response = array(
                    'success' => false,
                    'error' => 'معرف الصنف ومعرف المستخدم مطلوبان'
                );
                break;
            }
        
            try {
                // ✅ التحقق من وجود الصنف في السلة
                $checkSql = "SELECT id, qtt FROM Cart WHERE item_id = '$item_id' AND user_id = '$user_id'";
                $checkResult = $conx->query($checkSql);
                
                
                
                if ($checkResult && $checkResult->num_rows > 0) {
                    // ✅ تحديث الكمية إذا كان الصنف موجود
                    $row = $checkResult->fetch_assoc();
                    $newQuantity = $row['qtt'] + $quantity;
                    $updateSql = "UPDATE Cart SET qtt = $newQuantity WHERE id = " . $row['id'];
                    
                    if ($conx->query($updateSql)) {
                        $response = array(
                            'success' => true,
                            'message' => 'تم تحديث الكمية في السلة',
                            'quantity' => $newQuantity
                        );
                    } else {
                        $response = array(
                            'success' => false,
                            'error' => 'فشل في تحديث السلة: ' . $conx->error
                        );
                    }
                } else {
                     // ✅ إضافة صنف جديد للسلة
                        // ✅ رقم طلب عشوائي مكون من 8 أرقام
                        $order_id = isset($_POST['oid']) ? $conx->real_escape_string($_POST['oid']) : '';
                        
                        $insertSql = "INSERT INTO Cart (user_id, item_id, qtt, order_id) VALUES ('$user_id', '$item_id', $quantity, '$order_id')";
                        
                        if ($conx->query($insertSql)) {
                            $response = array(
                                'success' => true,
                                'message' => 'تم إضافة الصنف للسلة',
                                'quantity' => $quantity,
                                'order_id' => $order_id
                            );
                        } else {
                            $response = array(
                                'success' => false,
                                'error' => 'فشل في إضافة الصنف للسلة: ' . $conx->error,
                                'sql' => $insertSql
                            );
                        }
                        
                }
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في إدارة السلة: ' . $e->getMessage()
                );
            }
            break;
        
        case 'remove_from_cart':
            $item_id = isset($_POST['item_id']) ? $conx->real_escape_string($_POST['item_id']) : '';
            $user_id = isset($_POST['user_id']) ? $conx->real_escape_string($_POST['user_id']) : '';
            
            if (empty($item_id) || empty($user_id)) {
                $response = array(
                    'success' => false,
                    'error' => 'معرف الصنف ومعرف المستخدم مطلوبان'
                );
                break;
            }
        
            try {
                // ✅ التحقق من وجود الصنف في السلة
                $checkSql = "SELECT id, qtt FROM Cart 
                             WHERE item_id = '$item_id' 
                             AND user_id = '$user_id'";
                $checkResult = $conx->query($checkSql);
                
                if ($checkResult && $checkResult->num_rows > 0) {
                    $row = $checkResult->fetch_assoc();
                    $currentQuantity = $row['qtt'];
                    
                    if ($currentQuantity > 1) {
                        // ✅ تقليل الكمية
                        $newQuantity = $currentQuantity - 1;
                        $updateSql = "UPDATE Cart SET qtt = $newQuantity WHERE id = " . $row['id'];
                        
                        if ($conx->query($updateSql)) {
                            $response = array(
                                'success' => true,
                                'message' => 'تم تقليل الكمية',
                                'quantity' => $newQuantity
                            );
                        } else {
                            $response = array(
                                'success' => false,
                                'error' => 'فشل في تحديث السلة: ' . $conx->error
                            );
                        }
                    } else {
                        // ✅ حذف الصنف من السلة (الكمية = 1)
                        $deleteSql = "DELETE FROM Cart WHERE id = " . $row['id'];
                        
                        if ($conx->query($deleteSql)) {
                            $response = array(
                                'success' => true,
                                'message' => 'تم حذف الصنف من السلة',
                                'quantity' => 0
                            );
                        } else {
                            $response = array(
                                'success' => false,
                                'error' => 'فشل في حذف الصنف: ' . $conx->error
                            );
                        }
                    }
                } else {
                    $response = array(
                        'success' => false,
                        'error' => 'الصنف غير موجود في السلة',
                        'quantity' => 0
                    );
                }
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في إدارة السلة: ' . $e->getMessage()
                );
            }
            break;
        
        case 'get_cart_quantity':
            $item_id = isset($_POST['item_id']) ? $conx->real_escape_string($_POST['item_id']) : '';
            $user_id = isset($_POST['user_id']) ? $conx->real_escape_string($_POST['user_id']) : '';
            
            if (empty($item_id) || empty($user_id)) {
                $response = array(
                    'success' => false,
                    'error' => 'معرف الصنف ومعرف المستخدم مطلوبان'
                );
                break;
            }
        
            try {
                $sql = "SELECT COALESCE(SUM(qtt), 0) as total_quantity 
                        FROM Cart 
                        WHERE item_id = '$item_id' 
                        AND user_id = '$user_id'";
                $result = $conx->query($sql);
                
                if ($result) {
                    $row = $result->fetch_assoc();
                    $response = array(
                        'success' => true,
                        'quantity' => (int)$row['total_quantity']
                    );
                } else {
                    $response = array(
                        'success' => false,
                        'error' => 'فشل في جلب كمية السلة: ' . $conx->error
                    );
                }
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في جلب كمية السلة: ' . $e->getMessage()
                );
            }
            break;

        // =====================================
        // جلب عناصر السلة (Get Cart Items)
        // =====================================
        case 'get_from_cart':
            $user_id = isset($_POST['user_id']) ? $conx->real_escape_string($_POST['user_id']) : '';
            $store_id = isset($_POST['store_id']) ? $conx->real_escape_string($_POST['store_id']) : '';
            
            if (empty($user_id)) {
                $response = array(
                    'success' => false,
                    'error' => 'معرف المستخدم مطلوب'
                );
                break;
            }
            $get_store = "";
            if (!empty($store_id) && $store_id != '1') {
                $get_store = "AND Items.store_id = '$store_id'";
            }

            try {
                $sql = "SELECT 
                    Cart.id as cart_id,
                    Cart.qtt as cart_quantity,
                    Cart.order_id,
                    Items.id as item_id,
                    Items.idx as item_idx,
                    Items.name as item_name,
                    Items.price as item_price,
                    Items.qtt as available_quantity,
                    Items.media,
                    Items.store_id AS item_store_id,
                    Users.store_id,
                    Users.Fullname as seller_name,
                    Users.uid as seller_id
                FROM Cart 
                LEFT JOIN Items ON Cart.item_id = Items.id
                LEFT JOIN Users ON Items.uid = Users.uid
                WHERE Cart.user_id = '$user_id' $get_store
                ORDER BY Cart.id DESC";

                $result = $conx->query($sql);
                $cartItems = array();
                
                if ($result && $result->num_rows > 0) {
                    while($row = $result->fetch_assoc()) {
                        $itemStoreId = !empty($row['item_store_id'])
                            ? (string)$row['item_store_id']
                            : '1';
                        $thumbnail = item_thumbnail_url_from_media(
                            $itemStoreId,
                            (string)$row['item_id'],
                            (string)($row['media'] ?? ''),
                            (string)($row['item_idx'] ?? '')
                        );
                        
                        $cartItem = array(
                            'cart_id' => (string)$row['cart_id'],
                            'order_id' => (string)$row['order_id'],
                            'cart_quantity' => (int)$row['cart_quantity'],
                            'item' => array(
                                'id' => (string)$row['item_id'],
                                'idx' => (string)$row['item_idx'],
                                'name' => (string)$row['item_name'],
                                'price' => (string)$row['item_price'],
                                'available_quantity' => (int)$row['available_quantity'],
                                'media' => (string)($row['media'] ?? ''),
                                'thumbnail' => $thumbnail,
                                'store_id' => $row['item_store_id'] ?? $row['store_id']
                            ),
                            'seller' => array(
                                'id' => (string)$row['seller_id'],
                                'name' => (string)$row['seller_name']
                            )
                        );
                        
                        $cartItems[] = $cartItem;
                    }
                }
                
                $response = array(
                    'success' => true,
                    'data' => $cartItems
                );
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في جلب عناصر السلة: ' . $e->getMessage()
                );
            }
            break;

        // =====================================
        // تحديث كمية عنصر في السلة (Update Cart Quantity)
        // =====================================
        case 'update_cart_quantity':
            $cart_id = isset($_POST['cart_id']) ? (int)$_POST['cart_id'] : 0;
            $quantity = isset($_POST['quantity']) ? (int)$_POST['quantity'] : 1;
            
            if ($cart_id <= 0 || $quantity < 0) {
                $response = array(
                    'success' => false,
                    'error' => 'بيانات غير صحيحة'
                );
                break;
            }

            try {
                if ($quantity == 0) {
                    // حذف العنصر من السلة
                    $sql = "DELETE FROM Cart WHERE id = $cart_id";
                } else {
                    // تحديث الكمية
                    $sql = "UPDATE Cart SET qtt = $quantity WHERE id = $cart_id";
                }

                if ($conx->query($sql)) {
                    $response = array(
                        'success' => true,
                        'message' => $quantity == 0 ? 'تم حذف العنصر من السلة' : 'تم تحديث الكمية',
                        'quantity' => $quantity
                    );
                } else {
                    $response = array(
                        'success' => false,
                        'error' => 'فشل في تحديث السلة: ' . $conx->error
                    );
                }
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في تحديث السلة: ' . $e->getMessage()
                );
            }
            break;

        // =====================================
        // إضافة عنوان شحن جديد (Add Shipping Address)
        // =====================================
        case 'add_shipping_address':
            $fullname = isset($_POST['fullname']) ? $conx->real_escape_string($_POST['fullname']) : '';
            $mobile = isset($_POST['mobile']) ? $conx->real_escape_string($_POST['mobile']) : '';
            $email = isset($_POST['email']) ? $conx->real_escape_string($_POST['email']) : '';
            $country = isset($_POST['country']) ? $conx->real_escape_string($_POST['country']) : '';
            $city = isset($_POST['city']) ? $conx->real_escape_string($_POST['city']) : '';
            $zone_number = isset($_POST['zone_number']) ? $conx->real_escape_string($_POST['zone_number']) : '';
            $street_number = isset($_POST['street_number']) ? $conx->real_escape_string($_POST['street_number']) : '';
            $building_number = isset($_POST['building_number']) ? $conx->real_escape_string($_POST['building_number']) : '';
            $uid = isset($_POST['uid']) ? $conx->real_escape_string($_POST['uid']) : '';
            $oid = isset($_POST['oid']) ? $conx->real_escape_string($_POST['oid']) : '';
            
            if (empty($fullname) || empty($mobile) || empty($uid)) {
                $response = array(
                    'success' => false,
                    'error' => 'الاسم الكامل ورقم الهاتف ومعرف المستخدم مطلوبة'
                );
                break;
            }

            try {
                $sql = "INSERT INTO Shipping_Orders (Fullname, MobileNumber, Email, Country, City, `Zone Number`, `Street Number`, `Building Number`, uid, oid) 
                        VALUES ('$fullname', '$mobile', '$email', '$country', '$city', '$zone_number', '$street_number', '$building_number', '$uid', '$oid')";

                if ($conx->query($sql)) {
                    $response = array(
                        'success' => true,
                        'message' => 'تم إضافة العنوان بنجاح',
                        'address_id' => $conx->insert_id
                    );
                } else {
                    $response = array(
                        'success' => false,
                        'error' => 'فشل في إضافة العنوان: ' . $conx->error
                    );
                }
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في إضافة العنوان: ' . $e->getMessage()
                );
            }
            break;

        // =====================================
        // جلب عناوين الشحن (Get Shipping Addresses)
        // =====================================
        case 'get_shipping_addresses':
            $uid = isset($_POST['uid']) ? $conx->real_escape_string($_POST['uid']) : '';
            
            if (empty($uid)) {
                $response = array(
                    'success' => false,
                    'error' => 'معرف المستخدم مطلوب'
                );
                break;
            }

            try {
                $sql = "SELECT * FROM Shipping_Orders WHERE uid = '$uid' ORDER BY id DESC";
                $result = $conx->query($sql);
                $addresses = array();
                
                if ($result && $result->num_rows > 0) {
                    while($row = $result->fetch_assoc()) {
                        $address = array(
                            'id' => (int)$row['id'],
                            'fullname' => (string)$row['Fullname'],
                            'mobile' => (string)$row['MobileNumber'],
                            'email' => (string)$row['Email'],
                            'country' => (string)$row['Country'],
                            'city' => (string)$row['City'],
                            'zone_number' => (string)$row['Zone Number'],
                            'street_number' => (string)$row['Street Number'],
                            'building_number' => (string)$row['Building Number'],
                            'uid' => (string)$row['uid'],
                            'oid' => (string)$row['oid']
                        );
                        
                        $addresses[] = $address;
                    }
                }
                
                $response = array(
                    'success' => true,
                    'data' => $addresses
                );
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في جلب العناوين: ' . $e->getMessage()
                );
            }
            break;

        // =====================================
        // جلب البائعين الذين اشترى منهم المستخدم (Get User's Sellers)
        // =====================================
        case 'get_user_sellers':
            $user_id = isset($_POST['user_id']) ? $conx->real_escape_string($_POST['user_id']) : '';
            
            if (empty($user_id)) {
                $response = array(
                    'success' => false,
                    'error' => 'معرف المستخدم مطلوب'
                );
                break;
            }

            try {
                $sql = "SELECT 
                    Users.uid AS seller_id,
                    Users.Fullname AS seller_name,
                    Users.player_id AS seller_token,
                    (
                        SELECT conversation_id 
                        FROM Chat_Messages 
                        WHERE  Chat_Messages.seller_id = '$user_id'
                        ORDER BY Chat_Messages.id DESC 
                        LIMIT 1
                    ) AS conversation_id
                FROM
                    Users
                INNER JOIN Items ON Items.uid = Users.uid
                INNER JOIN Cart ON Cart.item_id = Items.id AND Cart.user_id = '$user_id'
                WHERE
                    Users.uid IS NOT NULL
                GROUP BY 
                    Users.uid,
                    Users.Fullname,
                    Users.player_id
                ORDER BY
                    Users.Fullname ASC";

                $result = $conx->query($sql);
                $sellers = array();
                
                if ($result && $result->num_rows > 0) {
                    while($row = $result->fetch_assoc()) {
                        $seller = array(
                            'id' => (string)$row['seller_id'],
                            'name' => (string)$row['seller_name'],
                            'avatar' => user_avatar_url($row['seller_id']),
                            'token' => (string)($row['seller_token'] ?? ''),
                            'conv_id' => (string)($row['conversation_id'] ?? '')
                        );
                        
                        $sellers[] = $seller;
                    }
                }
                
                $response = array(
                    'success' => true,
                    'data' => $sellers
                );
                
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في جلب البائعين: ' . $e->getMessage()
                );
            }
            break;

        // =====================================
        // تحديث الملف الشخصي
        // =====================================
        case 'update_user_profile':
            $uid = isset($_POST['uid']) ? $conx->real_escape_string($_POST['uid']) : '';
            $name = isset($_POST['name']) ? $conx->real_escape_string($_POST['name']) : '';
            $phone = isset($_POST['phone']) ? $conx->real_escape_string($_POST['phone']) : '';

            if (empty($uid)) {
                $response = ['success' => false, 'error' => 'معرف المستخدم مطلوب'];
                break;
            }

            $updates = [];
            if (!empty($name)) {
                $updates[] = "Fullname = '$name'";
            }
            if (!empty($phone)) {
                $updates[] = "PhoneNumber = '$phone'";
            }

            if (empty($updates)) {
                $response = ['success' => false, 'error' => 'لا توجد حقول للتحديث'];
                break;
            }

            $sql = "UPDATE Users SET " . implode(', ', $updates) . " WHERE uid = '$uid'";

            if ($conx->query($sql) === TRUE) {
                $response = ['success' => true, 'message' => 'تم تحديث الملف الشخصي بنجاح'];
            } else {
                $response = ['success' => false, 'error' => 'فشل في تحديث الملف الشخصي: ' . $conx->error];
            }
            break;

        case 'update_user_avatar':
            $uid = isset($_POST['uid']) ? $conx->real_escape_string($_POST['uid']) : '';
            $avatar_url = isset($_POST['avatar_url']) ? $conx->real_escape_string($_POST['avatar_url']) : '';

            if (empty($uid) || empty($avatar_url)) {
                $response = ['success' => false, 'error' => 'معرف المستخدم و رابط الصورة مطلوبان'];
                break;
            }

            $sql = "UPDATE Users SET urlAvatar = '$avatar_url' WHERE uid = '$uid'";

            if ($conx->query($sql) === TRUE) {
                $response = ['success' => true, 'message' => 'تم تحديث صورة الملف الشخصي بنجاح'];
            } else {
                $response = ['success' => false, 'error' => 'فشل في تحديث صورة الملف الشخصي: ' . $conx->error];
            }
            break;

        // =====================================
        // تفريغ السلة وتحديث OID
        // =====================================
        case 'clear_cart_update_oid':
            $user_id = isset($_POST['user_id']) ? $conx->real_escape_string($_POST['user_id']) : '';
            $new_oid = isset($_POST['new_oid']) ? $conx->real_escape_string($_POST['new_oid']) : '';
            
            if (empty($user_id) || empty($new_oid)) {
                $response = ['success' => false, 'error' => 'معرف المستخدم والـ OID الجديد مطلوبان'];
                break;
            }
            
            // Start transaction
            $conx->begin_transaction();
            
            try {
                // Clear cart for user
                $clear_cart_sql = "DELETE FROM Cart WHERE user_id = '$user_id'";
                if (!$conx->query($clear_cart_sql)) {
                    throw new Exception('فشل في تفريغ السلة: ' . $conx->error);
                }
                
                // Update user OID
                $update_oid_sql = "UPDATE Users SET oid = '$new_oid' WHERE uid = '$user_id'";
                if (!$conx->query($update_oid_sql)) {
                    throw new Exception('فشل في تحديث OID: ' . $conx->error);
                }
                
                // Commit transaction
                $conx->commit();
                $response = ['success' => true, 'message' => 'تم تفريغ السلة وتحديث OID بنجاح'];
                
            } catch (Exception $e) {
                // Rollback transaction
                $conx->rollback();
                $response = ['success' => false, 'error' => $e->getMessage()];
            }
            break;

        // =====================================
        // جلب رسائل الدردشة
        // =====================================
        case 'get_chat_messages':
            $sender_id = isset($_POST['sender_id']) ? $conx->real_escape_string($_POST['sender_id']) : '';
            $receiver_id = isset($_POST['receiver_id']) ? $conx->real_escape_string($_POST['receiver_id']) : '';
            $conversation_id = isset($_POST['conversation_id']) ? $conx->real_escape_string($_POST['conversation_id']) : '';
            
            if (empty($sender_id) || empty($receiver_id)) {
                $response = ['success' => false, 'error' => 'معرف المرسل والمستقبل مطلوبان'];
                break;
            }
            
            // إذا كان هناك conversation_id، جلب رسائل هذه المحادثة فقط
            if (!empty($conversation_id)) {
                $sql = "SELECT * FROM Chat_Messages 
                        WHERE conversation_id = '$conversation_id'
                        ORDER BY timestamp ASC";
            } else {
                // للتوافق مع النظام القديم
                $sql = "SELECT * FROM Chat_Messages 
                        WHERE (sender_id = '$sender_id' AND receiver_id = '$receiver_id') 
                        OR (sender_id = '$receiver_id' AND receiver_id = '$sender_id')
                        ORDER BY timestamp ASC";
            }
            
            $result = $conx->query($sql);
            $messages = [];
            
            if ($result && $result->num_rows > 0) {
                while ($row = $result->fetch_assoc()) {
                    $messages[] = $row;
                }
            }
            
            $response = ['success' => true, 'data' => $messages];
            break;

        // =====================================
        // إرسال رسالة دردشة
        // =====================================
        case 'send_chat_message':
            $sender_id = isset($_POST['sender_id']) ? $conx->real_escape_string($_POST['sender_id']) : '';
            $receiver_id = isset($_POST['receiver_id']) ? $conx->real_escape_string($_POST['receiver_id']) : '';
            $message = isset($_POST['message']) ? $conx->real_escape_string($_POST['message']) : '';
            $conversation_id = isset($_POST['conversation_id']) ? $conx->real_escape_string($_POST['conversation_id']) : '';
            $message_type = isset($_POST['message_type']) ? $conx->real_escape_string($_POST['message_type']) : 'text';
            $location_lat = isset($_POST['location_lat']) ? $conx->real_escape_string($_POST['location_lat']) : null;
            $location_lng = isset($_POST['location_lng']) ? $conx->real_escape_string($_POST['location_lng']) : null;
            
            if (empty($sender_id) || empty($receiver_id) || empty($message)) {
                $response = ['success' => false, 'error' => 'جميع الحقول مطلوبة'];
                break;
            }
            
            // ✅ إذا لم يكن هناك conversation_id، نبحث عن محادثة موجودة أو ننشئ واحدة ثابتة
            if (empty($conversation_id)) {
                // البحث عن محادثة موجودة بين المستخدمين
                $check_sql = "SELECT conversation_id FROM Chat_Messages 
                              WHERE (sender_id = '$sender_id' AND receiver_id = '$receiver_id')
                              OR (sender_id = '$receiver_id' AND receiver_id = '$sender_id')
                              LIMIT 1";
                $check_result = $conx->query($check_sql);
                
                if ($check_result && $check_result->num_rows > 0) {
                    // استخدام conversation_id الموجود
                    $row = $check_result->fetch_assoc();
                    $conversation_id = $row['conversation_id'];
                } else {
                    // إنشاء conversation_id ثابت بناءً على المستخدمين (الأصغر أولاً)
                    $min_id = min($sender_id, $receiver_id);
                    $max_id = max($sender_id, $receiver_id);
                    $conversation_id = "conv_{$min_id}_{$max_id}";
                }
            }
            
            $sql = "INSERT INTO Chat_Messages (sender_id, receiver_id, seller_id, message, conversation_id, message_type, location_lat, location_lng, timestamp, is_read) 
                    VALUES ('$sender_id', '$receiver_id', '$receiver_id', '$message', '$conversation_id', '$message_type', " . 
                    ($location_lat ? "'$location_lat'" : "NULL") . ", " . 
                    ($location_lng ? "'$location_lng'" : "NULL") . ", NOW(), 0)";
            
            if ($conx->query($sql) === TRUE) {
                $message_id = $conx->insert_id;
                $response = ['success' => true, 'message_id' => $message_id, 'conversation_id' => $conversation_id];
            } else {
                $response = ['success' => false, 'error' => 'فشل في إرسال الرسالة: ' . $conx->error];
            }
            break;

        // =====================================
        // إرسال إشعار دردشة
        // =====================================
        case 'send_chat_notification':
            $receiver_id = isset($_POST['receiver_id']) ? $conx->real_escape_string($_POST['receiver_id']) : '';
            $sender_name = isset($_POST['sender_name']) ? $conx->real_escape_string($_POST['sender_name']) : '';
            $message = isset($_POST['message']) ? $conx->real_escape_string($_POST['message']) : '';
            
            if (empty($receiver_id)) {
                $response = ['success' => false, 'error' => 'معرف المستقبل مطلوب'];
                break;
            }
            
            // Get receiver's FCM token
            $sql = "SELECT fcm_token FROM Users WHERE uid = '$receiver_id'";
            $result = $conx->query($sql);
            
            if ($result && $result->num_rows > 0) {
                $row = $result->fetch_assoc();
                $fcm_token = $row['fcm_token'];
                
                if (!empty($fcm_token)) {
                    // TODO: Send push notification using OneSignal or FCM
                    // For now, just return success
                    $response = ['success' => true, 'message' => 'تم إرسال الإشعار'];
                } else {
                    $response = ['success' => false, 'error' => 'لا يوجد رمز إشعارات للمستخدم'];
                }
            } else {
                $response = ['success' => false, 'error' => 'المستخدم غير موجود'];
            }
            break;

        // =====================================
        // جلب قائمة المحادثات
        // =====================================
        case 'get_chat_conversations':
            $user_id = isset($_POST['user_id']) ? $conx->real_escape_string($_POST['user_id']) : '';
            $store_id = isset($_POST['store_id']) ? $conx->real_escape_string($_POST['store_id']) : '';
            
            if (empty($user_id)) {
                $response = ['success' => false, 'error' => 'معرف المستخدم مطلوب'];
                break;
            }
            
            // ✅ جلب المحادثات مجمّعة حسب الطرف الآخر (participant) وليس conversation_id
            // هذا يضمن ظهور محادثة واحدة لكل شخص حتى لو كان conversation_id مختلف
            $sql = "SELECT 
                participant_id,
                participant_name,
                participant_avatar,
                participant_token,
                last_message,
                last_message_time,
                conversation_id,
                COALESCE(unread_count, 0) as unread_count
            FROM (
                SELECT 
                    CASE 
                        WHEN cm.sender_id = '$user_id' THEN cm.receiver_id 
                        ELSE cm.sender_id 
                    END as participant_id,
                    u.Fullname as participant_name,
                    CONCAT('https://globee.b-cdn.net/users/', u.uid, '/avatar.jpg') as participant_avatar,
                    u.player_id as participant_token,
                    cm.message as last_message,
                    cm.timestamp as last_message_time,
                    cm.conversation_id,
                    ROW_NUMBER() OVER (
                        PARTITION BY CASE 
                            WHEN cm.sender_id = '$user_id' THEN cm.receiver_id 
                            ELSE cm.sender_id 
                        END 
                        ORDER BY cm.timestamp DESC
                    ) as rn
                FROM Chat_Messages cm
                JOIN Users u ON u.uid = CASE 
                    WHEN cm.sender_id = '$user_id' THEN cm.receiver_id 
                    ELSE cm.sender_id 
                END
                WHERE cm.sender_id = '$user_id' OR cm.receiver_id = '$user_id'
            ) as ranked_messages
            LEFT JOIN (
                SELECT 
                    CASE 
                        WHEN sender_id = '$user_id' THEN receiver_id 
                        ELSE sender_id 
                    END as p_id,
                    COUNT(*) as unread_count
                FROM Chat_Messages
                WHERE receiver_id = '$user_id' AND is_read = 0
                GROUP BY p_id
            ) as unread_counts ON unread_counts.p_id = participant_id
            WHERE rn = 1
            ORDER BY last_message_time DESC";
            
            error_log("🔍 get_chat_conversations - user_id: $user_id");
            
            $result = $conx->query($sql);
            
            // ✅ إذا فشل الاستعلام (MySQL قديم لا يدعم ROW_NUMBER)، نستخدم استعلام بديل
            if (!$result) {
                error_log("❌ get_chat_conversations - ROW_NUMBER failed, using fallback query");
                
                // استعلام بديل بدون ROW_NUMBER
                $sql = "SELECT 
                    CASE 
                        WHEN cm.sender_id = '$user_id' THEN cm.receiver_id 
                        ELSE cm.sender_id 
                    END as participant_id,
                    u.Fullname as participant_name,
                    CONCAT('https://globee.b-cdn.net/users/', u.uid, '/avatar.jpg') as participant_avatar,
                    u.player_id as participant_token,
                    cm.message as last_message,
                    cm.timestamp as last_message_time,
                    cm.conversation_id,
                    0 as unread_count
                FROM Chat_Messages cm
                JOIN Users u ON u.uid = CASE 
                    WHEN cm.sender_id = '$user_id' THEN cm.receiver_id 
                    ELSE cm.sender_id 
                END
                WHERE (cm.sender_id = '$user_id' OR cm.receiver_id = '$user_id')
                AND u.store_id = '$store_id'
                AND cm.timestamp = (
                    SELECT MAX(cm2.timestamp) 
                    FROM Chat_Messages cm2 
                    WHERE (cm2.sender_id = cm.sender_id AND cm2.receiver_id = cm.receiver_id)
                    OR (cm2.sender_id = cm.receiver_id AND cm2.receiver_id = cm.sender_id)
                )
                GROUP BY participant_id
                ORDER BY last_message_time DESC";
                
                $result = $conx->query($sql);
            }
            
            $conversations = [];
            
            if ($result && $result->num_rows > 0) {
                while ($row = $result->fetch_assoc()) {
                    $conversations[] = $row;
                }
            }
            
            error_log("✅ get_chat_conversations - Found " . count($conversations) . " conversations");
            $response = ['success' => true, 'data' => $conversations];
            break;

        // =====================================
        // تحديث حالة الاتصال
        // =====================================
        case 'update_online_status':
            $user_id = isset($_POST['user_id']) ? $conx->real_escape_string($_POST['user_id']) : '';
            
            if (empty($user_id)) {
                $response = ['success' => false, 'error' => 'معرف المستخدم مطلوب'];
                break;
            }
            
            $sql = "UPDATE Users SET last_seen = NOW() WHERE uid = '$user_id'";
            
            if ($conx->query($sql) === TRUE) {
                $response = ['success' => true];
            } else {
                $response = ['success' => false, 'error' => 'فشل في تحديث الحالة'];
            }
            break;

      // =====================================
        // جلب حالة الاتصال
        // =====================================
        case 'get_user_status':
            $user_id = isset($_POST['user_id']) ? $conx->real_escape_string($_POST['user_id']) : '';

            if (empty($user_id)) {
                $response = array('success' => false, 'error' => 'user_id required');
                break;
            }

            $sql = "SELECT last_seen,
                    TIMESTAMPDIFF(SECOND, last_seen, NOW()) as seconds_ago
                    FROM Users WHERE uid = '$user_id' OR id = '$user_id'";

            $result = $conx->query($sql);

            if ($result && $result->num_rows > 0) {
                $row = $result->fetch_assoc();
                $seconds_ago = (int)$row['seconds_ago'];
                $minutes_ago = floor($seconds_ago / 60);

                $is_online = $seconds_ago < 45;

                $response = array(
                    'success' => true,
                    'is_online' => $is_online,
                    'last_seen' => $row['last_seen'],
                    'seconds_ago' => $seconds_ago,
                    'minutes_ago' => $minutes_ago,
                );
            } else {
                $response = array('success' => false, 'error' => 'المستخدم غير موجود');
            }
            break;
            
        // =====================================
        // إنشاء طلب جديد (Create Order)
        // =====================================
        case 'create_order':
            $uid = isset($_POST['uid']) ? $conx->real_escape_string($_POST['uid']) : '';
            $cust_id = isset($_POST['cust_id']) ? $conx->real_escape_string($_POST['cust_id']) : '';
            $oid = isset($_POST['oid']) ? $conx->real_escape_string($_POST['oid']) : '';
            $ship_id = isset($_POST['ship_id']) ? $conx->real_escape_string($_POST['ship_id']) : '';
            $items = isset($_POST['items']) ? $_POST['items'] : '';
            $total_amount = isset($_POST['total_amount']) ? $conx->real_escape_string($_POST['total_amount']) : '';
            
            if (empty($uid) || empty($cust_id) || empty($oid)) {
                $response = ['success' => false, 'error' => 'البيانات المطلوبة ناقصة'];
                break;
            }
            
            try {
                $created_at = date('Y-m-d H:i:s');
                $sql = "INSERT INTO Orders (uid, cust_id, oid, ship_id, created_at, status, items, total_amount) 
                        VALUES ('$uid', '$cust_id', '$oid', '$ship_id', '$created_at', 'pending', '$items', '$total_amount')";
                
                if ($conx->query($sql)) {
                    $response = [
                        'success' => true,
                        'message' => 'تم إنشاء الطلب بنجاح',
                        'order_id' => $conx->insert_id
                    ];
                } else {
                    $response = ['success' => false, 'error' => 'فشل في إنشاء الطلب: ' . $conx->error];
                }
            } catch (Exception $e) {
                $response = ['success' => false, 'error' => 'خطأ في إنشاء الطلب: ' . $e->getMessage()];
            }
            break;

        // =====================================
        // جلب طلباتي كمشتري (Get My Orders as Buyer)
        // =====================================
        case 'get_my_orders':
            $cust_id = isset($_POST['cust_id']) ? $conx->real_escape_string($_POST['cust_id']) : '';
            $store_id = isset($_POST['store_id']) ? $conx->real_escape_string($_POST['store_id']) : '';
            $myorders = "";
            // ✅ فقط نضيف فلتر المتجر إذا كان محدداً وليس فارغاً
            if (!empty($store_id) && $store_id != '1') {
                $myorders = "AND Users.store_id = '$store_id'";
            }
            
            // Debug logging
            error_log("🔍 get_my_orders - cust_id received: " . ($cust_id ? $cust_id : 'EMPTY'));
            error_log("🔍 get_my_orders - store_id received: " . ($store_id ? $store_id : 'EMPTY'));
            
            if (empty($cust_id)) {
                $response = ['success' => false, 'error' => 'معرف العميل مطلوب'];
                break;
            }
            
            try {
                $sql = "SELECT 
                    Orders.*,
                    Users.uid,
                    Users.Fullname as seller_name,
                    Users.PhoneNumber as seller_phone
                FROM Orders 
                LEFT JOIN Users ON Orders.uid = Users.uid
                WHERE Orders.cust_id = '$cust_id' $myorders
                ORDER BY Orders.created_at DESC";
                
                // Debug: Log the SQL query
                error_log("🔍 get_my_orders SQL: " . $sql);
                
                $result = $conx->query($sql);
                $orders = [];
                
                // Debug: Log result count
                $rowCount = $result ? $result->num_rows : 0;
                error_log("🔍 get_my_orders - Found $rowCount orders for cust_id: $cust_id");
                
                if ($result && $result->num_rows > 0) {
                    $grouped = [];
                    while ($row = $result->fetch_assoc()) {
                        $oid = (string)$row['oid'];
                        if (!isset($grouped[$oid])) {
                            $grouped[$oid] = [
                                'oid' => $oid,
                                'status' => (string)$row['status'],
                                'created_at' => (string)$row['created_at'],
                                'ship_id' => (string)$row['ship_id'],
                                'total_amount' => 0,
                                'seller_uids' => [],
                            ];
                        }
                        $grouped[$oid]['total_amount'] += (float)$row['total_amount'];
                        $uid = (string)$row['uid'];
                        if ($uid !== '') {
                            $grouped[$oid]['seller_uids'][$uid] = true;
                        }
                    }

                    foreach ($grouped as $group) {
                        $orders[] = [
                            'oid' => $group['oid'],
                            'status' => $group['status'],
                            'created_at' => $group['created_at'],
                            'ship_id' => $group['ship_id'],
                            'total_amount' => (string)$group['total_amount'],
                            'seller_count' => count($group['seller_uids']),
                        ];
                    }
                }
                
                error_log("🔍 get_my_orders - Returning " . count($orders) . " orders");
                $response = ['success' => true, 'data' => $orders];
            } catch (Exception $e) {
                $response = ['success' => false, 'error' => 'خطأ في جلب الطلبات: ' . $e->getMessage()];
            }
            break;

        // =====================================
        // جلب طلبات العملاء كبائع (Get Customer Orders as Seller)
        // =====================================
        case 'get_customer_orders':
            $uid = isset($_POST['uid']) ? $conx->real_escape_string($_POST['uid']) : '';
            $store_id = isset($_POST['store_id']) ? $conx->real_escape_string($_POST['store_id']) : '';
            
            if (empty($uid) && empty($store_id)) {
                $response = ['success' => false, 'error' => 'معرف البائع أو المتجر مطلوب'];
                break;
            }
            
            try {
                if (!empty($store_id)) {
                    $sql = "SELECT 
                        Orders.*,
                        Users.Fullname as customer_name,
                        Users.PhoneNumber as customer_phone,
                        Shipping_Orders.Fullname as ship_fullname,
                        Shipping_Orders.MobileNumber as ship_mobile,
                        Shipping_Orders.Country as ship_country,
                        Shipping_Orders.City as ship_city
                    FROM Orders 
                    LEFT JOIN Users ON Orders.cust_id = Users.uid
                    LEFT JOIN Users Seller ON Orders.uid = Seller.uid
                    LEFT JOIN Shipping_Orders ON Orders.ship_id = Shipping_Orders.id
                    WHERE Seller.store_id = '$store_id'
                    ORDER BY Orders.created_at DESC";
                } else {
                    $sql = "SELECT 
                        Orders.*,
                        Users.Fullname as customer_name,
                        Users.PhoneNumber as customer_phone,
                        Shipping_Orders.Fullname as ship_fullname,
                        Shipping_Orders.MobileNumber as ship_mobile,
                        Shipping_Orders.Country as ship_country,
                        Shipping_Orders.City as ship_city
                    FROM Orders 
                    LEFT JOIN Users ON Orders.cust_id = Users.uid
                    LEFT JOIN Shipping_Orders ON Orders.ship_id = Shipping_Orders.id
                    WHERE Orders.uid = '$uid'
                    ORDER BY Orders.created_at DESC";
                }
                
                $result = $conx->query($sql);
                $orders = [];
                
                if ($result && $result->num_rows > 0) {
                    while ($row = $result->fetch_assoc()) {
                        $orders[] = [
                            'id' => (int)$row['id'],
                            'oid' => (string)$row['oid'],
                            'ship_id' => (string)$row['ship_id'],
                            'customer_id' => (string)$row['cust_id'],
                            'customer_name' => (string)$row['customer_name'],
                            'customer_phone' => (string)$row['customer_phone'],
                            'created_at' => (string)$row['created_at'],
                            'status' => (string)$row['status'],
                            'items' => (string)$row['items'],
                            'total_amount' => (string)$row['total_amount'],
                            'shipping_info' => [
                                'fullname' => (string)$row['ship_fullname'],
                                'mobile' => (string)$row['ship_mobile'],
                                'country' => (string)$row['ship_country'],
                                'city' => (string)$row['ship_city']
                            ]
                        ];
                    }
                }
                
                $response = ['success' => true, 'data' => $orders];
            } catch (Exception $e) {
                $response = ['success' => false, 'error' => 'خطأ في جلب طلبات العملاء: ' . $e->getMessage()];
            }
            break;
            
        
        // =====================================
        // تحديث حالة الطلب (Update Order Status)
        // =====================================
        case 'update_order_status':
            $order_id = isset($_POST['order_id']) ? $conx->real_escape_string($_POST['order_id']) : '';
            $status = isset($_POST['status']) ? $conx->real_escape_string($_POST['status']) : '';
            $uid = isset($_POST['uid']) ? $conx->real_escape_string($_POST['uid']) : '';
            
            if (empty($order_id) || empty($status) || empty($uid)) {
                $response = ['success' => false, 'error' => 'معرف الطلب والحالة والبائع مطلوبان'];
                break;
            }
            
            // التحقق من أن الحالة صحيحة
            $valid_statuses = ['Pending', 'Preparing', 'ReadyToShip', 'Shipping', 'Delivered'];
            if (!in_array($status, $valid_statuses)) {
                $response = ['success' => false, 'error' => 'حالة غير صحيحة'];
                break;
            }
            
            try {
                $sql = "UPDATE Orders SET status = '$status' WHERE oid = '$order_id' AND uid = '$uid'";
                $customer_id = "SELECT
                                    Users.Fullname,
                                    Users.player_id
                                    FROM
                                    Orders
                                    LEFT JOIN Users
                                    ON Orders.uid = Users.uid
                                    WHERE Orders.oid = '$order_id' AND Orders.uid = '$uid'";
                $custo = array();
                $cok = $conx->query($customer_id);
                if ($cok) {
                    while ($rows = $cok->fetch_assoc()) {
                        $custo[] = $rows;
                    }
                }
                
                if ($conx->query($sql)) {
                    if ($conx->affected_rows > 0) {
                        $response = [
                            'success' => true, 
                            'message' => 'تم تحديث حالة الطلب بنجاح',
                            'new_status' => $status,
                            'client_token' => $custo
                        ];
                    } else {
                        $response = ['success' => false, 'error' => 'الطلب غير موجود أو الحالة لم تتغير'];
                    }
                } else {
                    $response = ['success' => false, 'error' => 'فشل في تحديث الحالة: ' . $conx->error];
                }
            } catch (Exception $e) {
                $response = ['success' => false, 'error' => 'خطأ في تحديث حالة الطلب: ' . $e->getMessage()];
            }
            break;
            
        // =====================================
        // حذف الحساب نهائياً
        // =====================================
        case 'delete_account_permit':
            $uid = isset($_POST['uid']) ? $conx->real_escape_string($_POST['uid']) : '';
            
            try {
                $sql = "DELETE FROM Users WHERE uid = '$uid'";
 
                
                if ($conx->query($sql)) {
                    $response = [
                        'success' => true, 
                        'message' => 'تم حذف الحساب نهائياً بنجاح',
                    ];
                } else {
                    $response = ['success' => false, 'error' => 'فشل في تحديث الحالة: ' . $conx->error];
                }
            } catch (Exception $e) {
                $response = ['success' => false, 'error' => 'خطأ في تحديث حالة الطلب: ' . $e->getMessage()];
            }
            break;
            
       case 'get_group':
            $store_id = isset($_POST['store_id']) ? $conx->real_escape_string($_POST['store_id']) : '';
            $get_store = "";
            
            if ($store_id) {
                $get_store = "AND store_id = '$store_id'";
            }
            
            // Debug logging
            error_log("📦 get_group - Store ID received: " . ($store_id ? $store_id : 'NULL'));
            
            try {
                // بناء الاستعلام
                $sql = "SELECT DISTINCT category FROM Items WHERE Visibility = 'Public' $get_store AND status = 1 AND category IS NOT NULL AND category != '' AND category != 'null'";
                
                // إضافة شرط المتجر إذا كان محدداً
                if (!empty($store_id)) {
                    $sql .= " AND store_id = '$store_id'";
                }
                
                $sql .= " ORDER BY category ASC";
                
                // Debug: Log the SQL query
                error_log("📦 get_group SQL: " . $sql);
                
                $result = $conx->query($sql);
                
                if ($result) {
                    $categories = [];
                    while ($row = $result->fetch_assoc()) {
                        $categories[] = [
                            'category' => $row['category']
                        ];
                    }
                    
                    $response = [
                        'success' => true,
                        'data' => $categories,
                        'count' => count($categories),
                        'message' => 'تم جلب المجموعات بنجاح'
                    ];
                } else {
                    $response = [
                        'success' => false,
                        'error' => 'فشل في جلب المجموعات: ' . $conx->error
                    ];
                }
            } catch (Exception $e) {
                $response = [
                    'success' => false,
                    'error' => 'خطأ في جلب المجموعات: ' . $e->getMessage()
                ];
            }
            break;
        
        // =====================================
        // تسجيل الدخول بالبريد الإلكتروني
        // =====================================
        case 'login_with_email':
            $email = isset($_POST['email']) ? $conx->real_escape_string($_POST['email']) : '';
            $password = isset($_POST['password']) ? $_POST['password'] : '';
            
            try {
                // ← شيل OR Password IS NOT NULL دي غلط
                $sql = "SELECT uid, oid, Fullname, Email, Password, role, store_id FROM Users WHERE Email = '$email'";
                $result = $conx->query($sql);
                
                if ($result && $result->num_rows > 0) {
                    $user = $result->fetch_assoc();
                    
                    // السيناريو 1: متسجل بجوجل (Password = NULL)
                    if (is_null($user['Password'])) {
                        $response = [
                            'success' => false,
                            'message' => 'هذا الحساب مسجل بجوجل، يرجى تسجيل الدخول عبر جوجل'
                        ];
                    }
                    // السيناريو 2: حساب عادي
                    elseif ($password === $user['Password'] || password_verify($password, $user['Password'])) {
                        $response = [
                            'success' => true,
                            'message' => 'تم تسجيل الدخول بنجاح',
                            'data' => [
                                'id' => $user['uid'],
                                'oid' => $user['oid'],
                                'name' => $user['Fullname'],
                                'email' => $user['Email'],
                                'role' => $user['role'] ?? null,
                                'store_id' => $user['store_id'] ?? null,
                            ]
                        ];
                    } else {
                        $response = [
                            'success' => false,
                            'message' => 'كلمة المرور غير صحيحة'
                        ];
                    }
                    
                } else {
                    // السيناريو 3: مش موجود خالص
                    $response = [
                        'success' => false,
                        'message' => 'المستخدم غير موجود'
                    ];
                }
            } catch (Exception $e) {
                $response = ['success' => false, 'error' => $e->getMessage()];
            }
            break;

        // =====================================
        // جلب مستخدم بالبريد (للتحقق قبل إنشاء حساب جديد)
        // =====================================
        case 'get_user_by_email':
            $email = isset($_POST['email']) ? trim($_POST['email']) : '';
            if ($email === '') {
                $response = [
                    'success' => false,
                    'message' => 'البريد الإلكتروني مطلوب'
                ];
                break;
            }
            $email_esc = $conx->real_escape_string($email);
            try {
                $sql = "SELECT uid, oid, Fullname, Email, role, store_id FROM Users WHERE LOWER(TRIM(Email)) = LOWER(TRIM('$email_esc')) LIMIT 1";
                $result = $conx->query($sql);
                if ($result && $result->num_rows > 0) {
                    $row = $result->fetch_assoc();
                    $response = [
                        'success' => true,
                        'message' => 'المستخدم موجود',
                        'data' => [
                            'id' => (string)$row['uid'],
                            'oid' => (string)$row['oid'],
                            'name' => $row['Fullname'],
                            'email' => $row['Email'],
                            'role' => $row['role'] ?? null,
                            'store_id' => $row['store_id'] ?? null,
                        ]
                    ];
                } else {
                    $response = [
                        'success' => false,
                        'message' => 'المستخدم غير موجود'
                    ];
                }
            } catch (Exception $e) {
                $response = [
                    'success' => false,
                    'error' => 'خطأ في البحث: ' . $e->getMessage()
                ];
            }
            break;

        // =====================================
        // إنشاء حساب بالبريد الإلكتروني
        // =====================================
        case 'create_email_account':
            $name = isset($_POST['name']) ? $conx->real_escape_string($_POST['name']) : '';
            $email = isset($_POST['email']) ? $conx->real_escape_string($_POST['email']) : '';
            $password = isset($_POST['password']) ? $_POST['password'] : '';
            $player_id = isset($_POST['player_id']) ? $conx->real_escape_string($_POST['player_id']) : '';
            $avatar_url = isset($_POST['avatar_url']) ? $conx->real_escape_string($_POST['avatar_url']) : '';
            $store_id = isset($_POST['store_id']) ? $conx->real_escape_string($_POST['store_id']) : '1';
            $login_type = isset($_POST['login_type']) ? $conx->real_escape_string($_POST['login_type']) : 'Email';
            // $hashed_password = password_hash($password, PASSWORD_DEFAULT);
            
            try {
                $check_sql = "SELECT uid FROM Users WHERE Email = '$email'";
                $check_result = $conx->query($check_sql);
                
                if ($check_result && $check_result->num_rows > 0) {
                    $response = [
                        'success' => false,
                        'message' => 'البريد الإلكتروني مسجل مسبقاً'
                    ];
                } else {
                    $uid = rand(1000, 9000);
                    $oid = rand(1000, 9000);
                    
                    $sql = "INSERT INTO Users (uid, oid, Fullname, Email, Password, player_id, urlAvatar, Created_At, store_id, login_type) 
                            VALUES ('$uid', '$oid', '$name', '$email', '$password', '$player_id', '$avatar_url', NOW(), '$store_id', '$login_type')";
                    
                    if ($conx->query($sql)) {
                        $response = [
                            'success' => true,
                            'message' => 'تم إنشاء الحساب بنجاح',
                            'data' => [
                                'id' => (string)$uid,
                                'oid' => (string)$oid,
                                'name' => $name,
                                'email' => $email
                            ]
                        ];
                    } else {
                        $response = [
                            'success' => false,
                            'error' => 'فشل في إنشاء الحساب: ' . $conx->error
                        ];
                    }
                }
            } catch (Exception $e) {
                $response = [
                    'success' => false,
                    'error' => 'خطأ في إنشاء الحساب: ' . $e->getMessage(),
                    'sql' => $sql
                ];
            }
            break;
        case 'create_social_account':
            $name = isset($_POST['name']) ? $conx->real_escape_string($_POST['name']) : '';
            $email = isset($_POST['email']) ? $conx->real_escape_string($_POST['email']) : '';
            $uid = rand(1000, 9000);
            $oid = rand(1000, 9000);
            $avatar_url = isset($_POST['avatar_url']) ? $conx->real_escape_string($_POST['avatar_url']) : '';
            $player_id = isset($_POST['player_id']) ? $conx->real_escape_string($_POST['player_id']) : '';
            $login_type = isset($_POST['login_type']) ? $conx->real_escape_string($_POST['login_type']) : 'Google';
            $store_id = isset($_POST['store_id']) ? $conx->real_escape_string($_POST['store_id']) : '1';
            $date = date('Y-m-d');
            try {
                    $sql = "INSERT INTO Users (uid, oid, Fullname, Email, player_id, login_type, urlAvatar, Created_At, store_id) 
                            VALUES ('$uid', '$oid', '$name', '$email', '$player_id', '$login_type', '$avatar_url', '$date', '$store_id')";
                    
                    if ($conx->query($sql)) {
                        $response = [
                            'success' => true,
                            'message' => 'تم إنشاء الحساب بنجاح',
                            'data' => [
                                'id' => (string)$uid,
                                'oid' => (string)$oid,
                                'name' => $name,
                                'email' => $email,
                                'role' => null,
                                'store_id' => $store_id,
                            ]
                        ];
                    } else {
                        $response = [
                            'success' => false,
                            'error' => 'فشل في إنشاء الحساب: ' . $conx->error
                        ];
                    }
            } catch (Exception $e) {
                $response = [
                    'success' => false,
                    'error' => 'خطأ في إنشاء الحساب: ' . $e->getMessage(),
                    'sql' => $sql
                ];
            }
            break;
        case 'get_social_account':
            $name = isset($_POST['name']) ? $conx->real_escape_string($_POST['name']) : '';
            $email = isset($_POST['email']) ? $conx->real_escape_string($_POST['email']) : '';
            $avatar_url = isset($_POST['avatar_url']) ? $conx->real_escape_string($_POST['avatar_url']) : '';
            try {
                    $sql = "SELECT uid, oid, Fullname, email, urlAvatar, player_id FROM Users WHERE Fullname = '$name' AND email = '$email' AND urlAvatar = '$avatar_url' ";
                    
                    $user_social = $conx->query($sql)->fetch_array();
                    $uid = $user_social[0];
                    $oid = $user_social[1];
                    $response = [
                        'success' => true,
                        'message' => 'تم إنشاء الحساب بنجاح',
                        'data' => [
                            'id' => $uid,
                            'oid' => $oid,
                            'name' => $name,
                            'email' => $email,
                            'urlAvatar' => $avatar_url
                        ]
                    ];
            } catch (Exception $e) {
                $response = [
                    'success' => false,
                    'error' => 'خطأ في إنشاء الحساب: ' . $e->getMessage(),
                    'sql' => $sql
                ];
            }
            break;

        // =====================================
        // تعيين store_id للمستخدم (MartIt = 1)
        // =====================================
        case 'set_user_store_id':
            $uid = isset($_POST['uid']) ? $conx->real_escape_string($_POST['uid']) : '';
            $store_id = isset($_POST['store_id']) ? $conx->real_escape_string($_POST['store_id']) : '1';
            if ($uid === '') {
                $response = [
                    'success' => false,
                    'message' => 'معرف المستخدم مطلوب'
                ];
                break;
            }
            try {
                $sql = "UPDATE Users SET store_id = '$store_id' WHERE uid = '$uid'";
                if ($conx->query($sql)) {
                    $response = [
                        'success' => true,
                        'message' => 'تم تحديث المتجر بنجاح',
                        'store_id' => $store_id
                    ];
                } else {
                    $response = [
                        'success' => false,
                        'error' => 'فشل في تحديث المتجر: ' . $conx->error
                    ];
                }
            } catch (Exception $e) {
                $response = [
                    'success' => false,
                    'error' => 'خطأ في تحديث المتجر: ' . $e->getMessage()
                ];
            }
            break;

        // =====================================
        // تحديث FCM Token
        // =====================================
        case 'update_fcm_token':
            $email = isset($_POST['email']) ? $conx->real_escape_string($_POST['email']) : '';
            $fcm_token = isset($_POST['fcm_token']) ? $conx->real_escape_string($_POST['fcm_token']) : '';
            
            try {
                $sql = "UPDATE Users SET player_id = '$fcm_token' WHERE Email = '$email'";
                
                if ($conx->query($sql)) {
                    $response = [
                        'success' => true,
                        'message' => 'تم تحديث التوكن بنجاح'
                    ];
                } else {
                    $response = [
                        'success' => false,
                        'error' => 'فشل في تحديث التوكن: ' . $conx->error
                    ];
                }
            } catch (Exception $e) {
                $response = [
                    'success' => false,
                    'error' => 'خطأ في تحديث التوكن: ' . $e->getMessage()
                ];
            }
            break;
            
        // =====================================
        // تحديث FCM Token
        // =====================================
        case 'add_new_transactions':
            $oid = isset($_POST['oid']) ? $conx->real_escape_string($_POST['oid']) : '';
            $name = isset($_POST['name']) ? $conx->real_escape_string($_POST['name']) : '';
            $mobile = isset($_POST['mobile']) ? $conx->real_escape_string($_POST['mobile']) : '';
            $trans_id = isset($_POST['trans_id']) ? $conx->real_escape_string($_POST['trans_id']) : '';
            $status = isset($_POST['status']) ? $conx->real_escape_string($_POST['status']) : '';
            $amount = isset($_POST['amount']) ? $conx->real_escape_string($_POST['amount']) : '';
            $pay_mode = isset($_POST['pay_mode']) ? $conx->real_escape_string($_POST['pay_mode']) : '';
            $store_id = isset($_POST['store_id']) ? $conx->real_escape_string($_POST['store_id']) : '2';

            if (empty($oid) && empty($trans_id)) {
                $response = [
                    'success' => false,
                    'error' => 'بيانات المعاملة غير مكتملة',
                ];
                break;
            }

            try {
                $sql = "INSERT INTO Transactions
                    (oid, name, mobile, Trans_id, status, amount, payment_mode, store_id)
                    VALUES
                    ('$oid', '$name', '$mobile', '$trans_id', '$status', '$amount', '$pay_mode', '$store_id')";

                if ($conx->query($sql)) {
                    $response = [
                        'success' => true,
                        'message' => 'تم إضافة معاملة دفع جديدة',
                        'transaction_id' => (string)$conx->insert_id,
                    ];
                } else {
                    $response = [
                        'success' => false,
                        'error' => 'فشل في إضافة المعاملة الجديدة: ' . $conx->error,
                    ];
                }
            } catch (Exception $e) {
                $response = [
                    'success' => false,
                    'error' => 'خطأ في إضافة المعاملة الجديدة: ' . $e->getMessage(),
                ];
            }
            break;


        // =====================================
        // جلب ملف المستخدم (Get User Profile)
        // =====================================
        case 'get_user_profile':
            $user_id = isset($_POST['user_id']) ? (int)$_POST['user_id'] : 0;
            $uid = isset($_POST['uid']) ? $conx->real_escape_string($_POST['uid']) : '';

            if ($user_id > 0) {
                $where = "WHERE (Users.id = $user_id OR Users.uid = '$user_id')";
            } elseif (!empty($uid)) {
                $where = "WHERE Users.uid = '$uid'";
            } else {
                $response = array('success' => false, 'error' => 'user_id or uid required');
                break;
            }

            $sql = "SELECT 
                Users.id,
                Users.uid,
                Users.Fullname,
                Users.PhoneNumber,
                Users.urlAvatar,
                Users.store_id,
                COUNT(Items.id) as items_count
            FROM Users
            LEFT JOIN Items ON Items.uid = Users.uid
            $where
            GROUP BY Users.id
            LIMIT 1";

            $result = $conx->query($sql);

            if ($result && $result->num_rows > 0) {
                $row = $result->fetch_assoc();
                $response = array(
                    'success' => true,
                    'data' => array(
                        'id' => (string)$row['id'],
                        'uid' => (string)$row['uid'],
                        'name' => (string)$row['Fullname'],
                        'phone' => (string)($row['PhoneNumber'] ?? ''),
                        'avatar' => (string)($row['urlAvatar'] ?? ''),
                        'type' => 'seller',
                        'items_count' => (int)$row['items_count'],
                        'store_id' => (string)($row['store_id'] ?? '1'),
                    )
                );
            } else {
                $response = array('success' => false, 'error' => 'المستخدم غير موجود');
            }
            break;

        // =====================================
        // Recent events (last 5 minutes)
        // =====================================
        case 'get_recent_events':
            try {
                $last_user_id = isset($_POST['last_user_id']) ? (int)$_POST['last_user_id'] : 0;
                $last_order_id = isset($_POST['last_order_id']) ? (int)$_POST['last_order_id'] : 0;
                $last_flag_id = isset($_POST['last_flag_id']) ? (int)$_POST['last_flag_id'] : 0;

                $new_users = array();
                $new_orders = array();
                $new_flags = array();
                $max_user_id = $last_user_id;
                $max_order_id = $last_order_id;
                $max_flag_id = $last_flag_id;

                $usersSql = "SELECT id, Fullname, PhoneNumber, Email, store_id, Created_At
                             FROM Users
                             WHERE id > $last_user_id
                             ORDER BY id ASC";
                $usersResult = $conx->query($usersSql);
                if ($usersResult) {
                    while ($row = $usersResult->fetch_assoc()) {
                        $userId = (int)$row['id'];
                        if ($userId > $max_user_id) {
                            $max_user_id = $userId;
                        }
                        $new_users[] = array(
                            'id' => (string)$row['id'],
                            'Fullname' => (string)$row['Fullname'],
                            'PhoneNumber' => (string)($row['PhoneNumber'] ?? ''),
                            'Email' => (string)($row['Email'] ?? ''),
                            'store_id' => (string)($row['store_id'] ?? '1'),
                            'Created_At' => (string)$row['Created_At'],
                        );
                    }
                }

                $ordersSql = "SELECT Orders.id, Orders.oid, Orders.total_amount, Orders.status, Orders.created_at,
                                     Customer.Fullname as customer_name, Orders.uid as seller_id,
                                     Seller.store_id as store_id
                              FROM Orders
                              LEFT JOIN Users Customer ON Orders.cust_id = Customer.uid
                              LEFT JOIN Users Seller ON Orders.uid = Seller.uid
                              WHERE Orders.id > $last_order_id
                              ORDER BY Orders.id ASC";
                $ordersResult = $conx->query($ordersSql);
                if ($ordersResult) {
                    while ($row = $ordersResult->fetch_assoc()) {
                        $orderId = (int)$row['id'];
                        if ($orderId > $max_order_id) {
                            $max_order_id = $orderId;
                        }
                        $new_orders[] = array(
                            'id' => $orderId,
                            'oid' => (string)$row['oid'],
                            'total_amount' => (string)$row['total_amount'],
                            'status' => (string)$row['status'],
                            'created_at' => (string)$row['created_at'],
                            'customer_name' => (string)($row['customer_name'] ?? ''),
                            'seller_id' => (string)$row['seller_id'],
                            'store_id' => (string)($row['store_id'] ?? '1'),
                        );
                    }
                }

                $flagsSql = "SELECT Flags.id, Flags.item_id, Flags.reason, Flags.created_at,
                                    Users.Fullname as reporter_name
                             FROM Flags
                             LEFT JOIN Users ON Flags.user_id = Users.uid
                             WHERE Flags.id > $last_flag_id
                             ORDER BY Flags.id ASC";
                $flagsResult = $conx->query($flagsSql);
                if ($flagsResult) {
                    while ($row = $flagsResult->fetch_assoc()) {
                        $flagId = (int)$row['id'];
                        if ($flagId > $max_flag_id) {
                            $max_flag_id = $flagId;
                        }
                        $new_flags[] = array(
                            'id' => $flagId,
                            'item_id' => (string)$row['item_id'],
                            'reason' => (string)$row['reason'],
                            'created_at' => (string)$row['created_at'],
                            'reporter_name' => (string)($row['reporter_name'] ?? ''),
                        );
                    }
                }

                $response = array(
                    'success' => true,
                    'new_users' => $new_users,
                    'new_orders' => $new_orders,
                    'new_flags' => $new_flags,
                    'max_user_id' => $max_user_id,
                    'max_order_id' => $max_order_id,
                    'max_flag_id' => $max_flag_id,
                );
            } catch (Exception $e) {
                $response = array(
                    'success' => false,
                    'error' => 'خطأ في جلب الأحداث الأخيرة: ' . $e->getMessage(),
                );
            }
            break;

        // =====================================
        // Last IDs persistence (/tmp/martit_last_ids.json)
        // =====================================
        case 'get_last_ids':
            $file = __DIR__ . '/martit_last_ids.json';
            if (file_exists($file)) {
                $data = json_decode(file_get_contents($file), true);
                $response = ['success' => true, 'data' => $data];
            } else {
                $response = ['success' => true, 'data' => ['last_user_id' => 0, 'last_order_id' => 0, 'last_flag_id' => 0]];
            }
            break;

        case 'set_last_ids':
            $file = __DIR__ . '/martit_last_ids.json';
            $data = [
                'last_user_id' => (int)($_POST['last_user_id'] ?? 0),
                'last_order_id' => (int)($_POST['last_order_id'] ?? 0),
                'last_flag_id' => (int)($_POST['last_flag_id'] ?? 0)
            ];
            file_put_contents($file, json_encode($data));
            $response = ['success' => true];
            break;

        // =====================================
        // Action غير صحيح
        // =====================================
        default:
            $response = array(
                'success' => false,
                'error' => 'Action غير صحيح أو غير موجود',
                'available_actions' => array(
                    'fetch' => 'جلب الأصناف',
                    'insert' => 'إضافة صنف',
                    'update' => 'تحديث صنف',
                    'delete' => 'حذف صنف',
                    'get_item' => 'جلب صنف واحد',
                    'increment_views' => 'زيادة المشاهدات',
                    'search' => 'البحث عن أصناف'
                )
            );
            
            break;
    }
    
} catch (Exception $e) {
    $response = array(
        'success' => false,
        'error' => 'خطأ في قاعدة البيانات: ' . $e->getMessage()
    );
}

echo json_encode($response, true);
?>