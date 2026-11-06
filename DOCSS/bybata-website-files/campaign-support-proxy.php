<?php
/**
 * Same-origin proxy for campaign-support.html (avoids browser CORS to Railway).
 * Upload to public_html/ alongside campaign-support.html
 */
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: https://bybata.com');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
  http_response_code(204);
  exit;
}

$base = 'https://bybataapi-production.up.railway.app';
$path = isset($_GET['path']) ? (string) $_GET['path'] : '';

if ($path === '' || $path[0] !== '/' || strpos($path, '..') !== false) {
  http_response_code(400);
  echo json_encode(['message' => 'Invalid path']);
  exit;
}

$allowed = [
  '/v1/public/browse/campaigns/',
  '/v1/auth/login',
  '/v1/wallet/balance',
  '/v1/campaigns/',
];

$ok = false;
foreach ($allowed as $prefix) {
  if (strpos($path, $prefix) === 0) {
    $ok = true;
    break;
  }
}
if (!$ok) {
  http_response_code(403);
  echo json_encode(['message' => 'Path not allowed']);
  exit;
}

$url = $base . $path;
$method = $_SERVER['REQUEST_METHOD'];
$body = file_get_contents('php://input');

$headers = ['Accept: application/json'];
$contentType = $_SERVER['HTTP_CONTENT_TYPE'] ?? $_SERVER['CONTENT_TYPE'] ?? '';
if ($contentType !== '') {
  $headers[] = 'Content-Type: ' . $contentType;
}
if (!empty($_SERVER['HTTP_AUTHORIZATION'])) {
  $headers[] = 'Authorization: ' . $_SERVER['HTTP_AUTHORIZATION'];
}

$ch = curl_init($url);
$timeout = (strpos($path, '/donate') !== false) ? 90 : 30;
curl_setopt_array($ch, [
  CURLOPT_RETURNTRANSFER => true,
  CURLOPT_CUSTOMREQUEST => $method,
  CURLOPT_HTTPHEADER => $headers,
  CURLOPT_TIMEOUT => $timeout,
  CURLOPT_FOLLOWLOCATION => true,
]);
if ($method === 'POST' && $body !== false && $body !== '') {
  curl_setopt($ch, CURLOPT_POSTFIELDS, $body);
}

$response = curl_exec($ch);
$status = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
$err = curl_error($ch);
curl_close($ch);

if ($response === false) {
  http_response_code(502);
  echo json_encode(['message' => 'API unreachable', 'detail' => $err]);
  exit;
}

http_response_code($status > 0 ? $status : 502);
echo $response;
