--TEST--
Bug #69354 Incorrect use of SQLColAttributes with ODBC 3.0
--EXTENSIONS--
odbc
--SKIPIF--
<?php include 'skipif.inc'; ?>
--FILE--
<?php

include 'config.inc';

$conn = odbc_connect($dsn, $user, $pass);

odbc_exec($conn, 'CREATE TABLE bug69354 (ID INT, VARCHAR_COL VARCHAR(100))');

odbc_exec($conn, "INSERT INTO bug69354(ID, VARCHAR_COL) VALUES (1, '" . str_repeat("a", 100) . "')");

$res = odbc_exec($conn,"SELECT VARCHAR_COL FROM bug69354");
if ($res) {
    if (odbc_fetch_row($res)) {
        $ret = odbc_result($res,'varchar_col');
        echo strlen($ret), "\n";
        echo $ret[0], "\n";
        echo $ret[strlen($ret)-1], "\n";
    }
}
?>
--CLEAN--
<?php
include 'config.inc';

$conn = odbc_connect($dsn, $user, $pass);

odbc_exec($conn, 'DROP TABLE bug69354');

?>
--EXPECT--
100
a
a
