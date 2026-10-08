<?php
/**
 * MartIt S3 product media URLs.
 * Pattern: https://martit.s3.ap-south-1.amazonaws.com/store_{store_id}/{idx}/{index}.{ext}
 * Falls back to item id when idx is empty.
 */
define('MARTIT_S3_BASE_URL', 'https://martit.s3.ap-south-1.amazonaws.com');

function martit_normalize_store_id($storeid)
{
    $storeid = trim((string)$storeid);
    return $storeid !== '' ? $storeid : '1';
}

function martit_resolve_item_path_key($idx, $itemId)
{
    $idx = trim((string)$idx);
    if ($idx !== '') {
        return $idx;
    }
    $itemId = trim((string)$itemId);
    return $itemId !== '' ? $itemId : '1';
}

function martit_item_media_url($storeid, $itemId, $index = 1, $idx = null, $extension = 'jpg')
{
    $store = martit_normalize_store_id($storeid);
    $pathKey = martit_resolve_item_path_key($idx, $itemId);
    $index = (int)$index;
    if ($index < 1) {
        $index = 1;
    }
    $extension = trim((string)$extension);
    if ($extension === '') {
        $extension = 'jpg';
    }

    return MARTIT_S3_BASE_URL . "/store_{$store}/{$pathKey}/{$index}.{$extension}";
}

function item_thumbnail_url($storeid, $itemId, $idx = null, $media = null)
{
    if (!empty($media)) {
        return item_thumbnail_url_from_media($storeid, $itemId, $media, $idx);
    }

    return martit_item_media_url($storeid, $itemId, 1, $idx, 'webp');
}

/**
 * Pick first image in upload order; if none, first video; else 1.jpg.
 */
function item_thumbnail_url_from_media($storeid, $itemId, $media, $idx = null)
{
    if (empty($media)) {
        return item_thumbnail_url($storeid, $itemId, $idx);
    }

    $store = martit_normalize_store_id($storeid);
    $pathKey = martit_resolve_item_path_key($idx, $itemId);
    $files = array_map('trim', explode(',', (string)$media));
    $firstVideo = null;

    foreach ($files as $file) {
        if ($file === '') {
            continue;
        }

        if (stripos($file, 'http://') === 0 || stripos($file, 'https://') === 0) {
            if (preg_match('/\.(jpg|jpeg|webp|png)(\?|$)/i', $file)) {
                return $file;
            }
            if ($firstVideo === null && preg_match('/\.(mp4|mov|avi)(\?|$)/i', $file)) {
                $firstVideo = $file;
            }
            continue;
        }

        if (preg_match('/\.(jpg|jpeg|webp|png)$/i', $file)) {
            return MARTIT_S3_BASE_URL . "/store_{$store}/{$pathKey}/{$file}";
        }

        if ($firstVideo === null && preg_match('/\.(mp4|mov|avi)$/i', $file)) {
            $firstVideo = $file;
        }
    }

    if ($firstVideo !== null) {
        return MARTIT_S3_BASE_URL . "/store_{$store}/{$pathKey}/{$firstVideo}";
    }

    return martit_item_media_url($storeid, $itemId, 1, $idx, 'webp');
}

function build_item_media_urls($storeid, $itemId, $media, $baseUrl = null, $itemIdx = '')
{
    if (empty($media)) {
        return array();
    }

    $s3Base = !empty($baseUrl) ? rtrim($baseUrl, '/') : 'https://martit.s3.ap-south-1.amazonaws.com';
    $store = !empty($storeid) ? (string)$storeid : '1';
    $pathKey = !empty($itemIdx) ? (string)$itemIdx : (string)$itemId;

    $files = array_map('trim', explode(',', (string)$media));
    $urls = array();

    foreach ($files as $file) {
        if ($file === '') {
            continue;
        }

        if (stripos($file, 'http://') === 0 || stripos($file, 'https://') === 0) {
            $urls[] = $file;
            continue;
        }

        $urls[] = $s3Base . '/store_' . $store . '/' . $pathKey . '/' . $file;
    }

    return $urls;
}

function albadaa_thumbnail_url($itemId, $idx = null)
{
    return item_thumbnail_url('4', $itemId, $idx);
}

/**
 * Profile avatar on MartIt S3: Users/store_{store_id}/{user_uid}/1.jpg
 */
function user_avatar_url($userUid, $storeid = '2')
{
    $userUid = trim((string)$userUid);
    if ($userUid === '') {
        return '';
    }
    $store = martit_normalize_store_id($storeid);

    return MARTIT_S3_BASE_URL . "/Users/store_{$store}/{$userUid}/1.jpg";
}
