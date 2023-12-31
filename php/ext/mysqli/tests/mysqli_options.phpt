--TEST--
mysqli_options()
--EXTENSIONS--
mysqli
--SKIPIF--
<?php
require_once 'skipifconnectfailure.inc';

?>
--FILE--
<?php
require_once 'connect.inc';

$link = mysqli_init();

/* set it twice, checking if memory for the previous one is correctly freed */
mysqli_options($link, MYSQLI_SET_CHARSET_NAME, "utf8");
mysqli_options($link, MYSQLI_SET_CHARSET_NAME, "latin1");

// print "run_tests.php don't fool me with your 'ungreedy' expression '.+?'!\n";
var_dump("MYSQLI_READ_DEFAULT_GROUP", mysqli_options($link, MYSQLI_READ_DEFAULT_GROUP, 'extra_my.cnf'));
var_dump("MYSQLI_READ_DEFAULT_FILE", mysqli_options($link, MYSQLI_READ_DEFAULT_FILE, 'extra_my.cnf'));
var_dump("MYSQLI_OPT_CONNECT_TIMEOUT", mysqli_options($link, MYSQLI_OPT_CONNECT_TIMEOUT, 10));
var_dump("MYSQLI_OPT_LOCAL_INFILE", mysqli_options($link, MYSQLI_OPT_LOCAL_INFILE, 1));
var_dump("MYSQLI_INIT_COMMAND", mysqli_options($link, MYSQLI_INIT_COMMAND, array('SET AUTOCOMMIT=0', 'SET AUTOCOMMIT=1')));

if (!$link2 = my_mysqli_connect($host, $user, $passwd, $db, $port, $socket)) {
    printf("[006] Cannot connect to the server using host=%s, user=%s, passwd=***, dbname=%s, port=%s, socket=%s\n",
        $host, $user, $db, $port, $socket);
}

if (!$res = mysqli_query($link2, "SHOW CHARACTER SET")) {
    printf("[010] Cannot get list of available character sets, [%d] %s\n",
        mysqli_errno($link2), mysqli_error($link2));
}

$charsets = array();
while ($row = mysqli_fetch_assoc($res)) {
    $charsets[] = $row;
}
mysqli_free_result($res);
mysqli_close($link2);

foreach ($charsets as $charset) {
    /* The server currently 17.07.2007 can't handle data sent in ucs2 */
    /* The server currently 16.08.2010 can't handle data sent in utf16 and utf32 */
    /* As of MySQL 8.0.28, `SHOW CHARACTER SET` contains utf8mb3, but that is not yet supported by mysqlnd */
    if ($charset['Charset'] == 'ucs2' || $charset['Charset'] == 'utf16' || $charset['Charset'] == 'utf32' || $charset['Charset'] == 'utf8mb3') {
        continue;
    }
    if (true !== mysqli_options($link, MYSQLI_SET_CHARSET_NAME, $charset['Charset'])) {
        printf("[009] Setting charset name '%s' has failed\n", $charset['Charset']);
    }
}

var_dump("MYSQLI_READ_DEFAULT_GROUP", mysqli_options($link, MYSQLI_READ_DEFAULT_GROUP, 'extra_my.cnf'));
var_dump("MYSQLI_READ_DEFAULT_FILE", mysqli_options($link, MYSQLI_READ_DEFAULT_FILE, 'extra_my.cnf'));
var_dump("MYSQLI_OPT_CONNECT_TIMEOUT", mysqli_options($link, MYSQLI_OPT_CONNECT_TIMEOUT, 10));
var_dump("MYSQLI_OPT_LOCAL_INFILE", mysqli_options($link, MYSQLI_OPT_LOCAL_INFILE, 1));
var_dump("MYSQLI_INIT_COMMAND", mysqli_options($link, MYSQLI_INIT_COMMAND, 'SET AUTOCOMMIT=0'));

/* mysqli_real_connect() */
var_dump("MYSQLI_CLIENT_SSL", mysqli_options($link, MYSQLI_CLIENT_SSL, 'not a mysqli_option'));

mysqli_close($link);

echo "Link closed\n";
try {
    mysqli_options($link, MYSQLI_INIT_COMMAND, 'SET AUTOCOMMIT=1');
} catch (Error $exception) {
    echo $exception->getMessage() . "\n";
}

mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
$link = mysqli_init();

// test for error reporting - only mysqlnd reports errors
try {
    mysqli_options($link, MYSQLI_SET_CHARSET_NAME, "foobar");
} catch (mysqli_sql_exception $e) {
    echo $e->getMessage() . "\n";
}

// invalid options do not generate errors
mysqli_options($link, -1, "Invalid option");

print "done!";
?>
--EXPECTF--
%s(25) "MYSQLI_READ_DEFAULT_GROUP"
bool(true)
%s(24) "MYSQLI_READ_DEFAULT_FILE"
bool(true)
%s(26) "MYSQLI_OPT_CONNECT_TIMEOUT"
bool(true)
%s(23) "MYSQLI_OPT_LOCAL_INFILE"
bool(true)

Warning: Array to string conversion in %s on line %d
%s(19) "MYSQLI_INIT_COMMAND"
bool(true)
%s(25) "MYSQLI_READ_DEFAULT_GROUP"
bool(true)
%s(24) "MYSQLI_READ_DEFAULT_FILE"
bool(true)
%s(26) "MYSQLI_OPT_CONNECT_TIMEOUT"
bool(true)
%s(23) "MYSQLI_OPT_LOCAL_INFILE"
bool(true)
%s(19) "MYSQLI_INIT_COMMAND"
bool(true)
%s(17) "MYSQLI_CLIENT_SSL"
bool(false)
Link closed
mysqli object is already closed
Unknown character set
done!
