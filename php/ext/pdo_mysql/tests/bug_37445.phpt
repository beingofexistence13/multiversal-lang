--TEST--
PDO MySQL Bug #37445 (Premature stmt object destruction)
--EXTENSIONS--
pdo
pdo_mysql
--SKIPIF--
<?php
require __DIR__ . '/config.inc';
require __DIR__ . '/../../../ext/pdo/tests/pdo_test.inc';
PDOTest::skip();
?>
--FILE--
<?php
require __DIR__ . '/../../../ext/pdo/tests/pdo_test.inc';
$db = PDOTest::test_factory(__DIR__ . '/common.phpt');

$db->setAttribute(PDO :: ATTR_EMULATE_PREPARES, true);
$stmt = $db->prepare("SELECT 1");
$stmt->bindParam(':a', 'b');
?>
--EXPECTF--
Fatal error: Uncaught Error: PDOStatement::bindParam(): Argument #2 ($var) could not be passed by reference in %sbug_37445.php:%d
Stack trace:
#0 {main}
  thrown in %sbug_37445.php on line %d
