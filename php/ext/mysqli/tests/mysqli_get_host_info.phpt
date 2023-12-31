--TEST--
mysqli_get_host_info()
--EXTENSIONS--
mysqli
--SKIPIF--
<?php
require_once 'skipifconnectfailure.inc';
?>
--FILE--
<?php
    require_once 'connect.inc';
    if (!$link = my_mysqli_connect($host, $user, $passwd, $db, $port, $socket)) {
        printf("Cannot connect to the server using host=%s, user=%s, passwd=***, dbname=%s, port=%s, socket=%s\n",
            $host, $user, $db, $port, $socket);
        exit(1);
    }

    if (!is_string($info = mysqli_get_host_info($link)) || ('' === $info))
        printf("[003] Expecting string/any_non_empty, got %s/%s\n", gettype($info), $info);

    if ($host != 'localhost' && $host != '127.0.0.1' && $port != '' && $host != "" && strtoupper(substr(PHP_OS, 0, 3)) != 'WIN') {
        /* this should be a TCP/IP connection and not a Unix Socket (or SHM or Named Pipe) */
        if (!stristr($info, "TCP/IP"))
            printf("[004] Should be a TCP/IP connection but mysqlnd says '%s'\n", $info);
    }
    print "done!";
?>
--EXPECT--
done!
