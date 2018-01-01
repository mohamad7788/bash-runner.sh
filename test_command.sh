#!/bin/bash

ret="`echo $RANDOM % 3 | bc`"

echo "sleep ${ret}sec"
ls $ret
sleep ${ret}

exit   ${ret}
