--TEST--
Bug #74936 session_cache_expire() triggers a warning in read mode.
--EXTENSIONS--
session
--SKIPIF--
<?php
include('skipif.inc');
?>
--FILE--
<?php

session_start();
var_dump(session_cache_expire());
var_dump(session_cache_limiter());
var_dump(session_save_path());
?>
--EXPECTF--
int(%d)
string(%d) "%S"
string(%d) "%S"
