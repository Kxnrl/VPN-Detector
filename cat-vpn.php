<?php

if(!isset($_GET['id']) || empty($_GET['id'])) {
    echo "Invalid SteamId";
    die(404);
}

$rds = new mysqli("{HOST}", "{USERNAME}", "{PASSWORD}", "{DATABASE}", "{PORT}");

if($rds->connect_errno) {
    echo "Failed to connect to database: " . $rds->connect_error;
    die(403);
}

$id = $_GET['id'];
$ip = get_userip();

if($result = $rds->query("SELECT * FROM k_antiproxy WHERE steamid=$id")) {
    $row = $result->fetch_array();
    if(strcmp($ip, $row['ip']) == 0) {
        $rds->query("UPDATE k_antiproxy SET `result` = 2 WHERE steamid=$id");
        die(200);
    } else {
        $rds->query("UPDATE k_antiproxy SET `result` = 1 WHERE steamid=$id");
        die(200);
    }
} else {
    echo "Failed to check steamid:" . $id;
    die(403);
}

function get_userip() {
    if(isset($_SERVER)) {
        if(isset($_SERVER['HTTP_CF_CONNECTING_IP'])) {
            return $_SERVER['HTTP_CF_CONNECTING_IP'];
        } elseif(isset($_SERVER['HTTP_X_FORWARDED_FOR'])) {
            return $_SERVER['HTTP_X_FORWARDED_FOR'];
        } elseif(isset($_SERVER['HTTP_CLIENT_IP'])) {
            return $_SERVER['HTTP_CLIENT_IP'];
        } else {
            return $_SERVER['REMOTE_ADDR'];
        }
    } else {
        if(getenv('HTTP_X_FORWARDED_FOR')) {
            return getenv('HTTP_X_FORWARDED_FOR');
        } elseif(getenv('HTTP_CLIENT_IP')) {
            return getenv('HTTP_CLIENT_IP');
        } else {
            return getenv('REMOTE_ADDR');
        }
    }
    return "0.0.0.0";
}
