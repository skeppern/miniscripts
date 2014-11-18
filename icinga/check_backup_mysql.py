#!/usr/bin/env python

import os
import sys
import datetime

files =['/var/backup/mysql2-av/mysql/snap_time','/var/backup/mysql-av/mysql/snap_time','/var/backup/webresmysql-av/mysql/snap_time','/var/backup/eff-mysql-av/mysql/snap_time','/var/backup/rentalfront-mysql-av/mysql/snap_time']

success = True

delta = 12

#Getting the current time
str(os.system('date +\"%Y%m%d%H%M%S\" > /tmp/now'))
n = open('/tmp/now','r')
now = str(n.readline().strip())

runtime = str(datetime.datetime.now().date()) + " 08:45:00"
r = datetime.datetime.strptime(runtime, '%Y-%m-%d %H:%M:%S')
runtime = str(datetime.datetime.strftime(r, '%Y%m%d%H%M%S'))

def convert_timedelta(duration):
    days, seconds = duration.days, duration.seconds
    hours = days * 24 + seconds // 3600
    minutes = (seconds % 3600) // 60
    seconds = (seconds % 60)
    return hours, minutes, seconds

def test(filname):
    f = open(filname, 'r')
    then = f.readline().strip();
    d = datetime.datetime.strptime(then, '%a %b  %d %H:%M:%S %Z %Y')
    n = datetime.datetime.strptime(now, '%Y%m%d%H%M%S')
    datefile = str(datetime.datetime.strftime(d, '%Y%m%d%H%M%S'))

    duration = n - d

    hours, minutes, seconds = convert_timedelta(duration)

    #print "Old: " + then + " New: " + now + " Duration: " + str(hours) + " " + str(minutes)

    if hours >= delta:
         print "CRITICAL: Last backup " + str(hours) + " hours ago: " + filname
         return False
    else:
         return True

for f in files:
    if test(f) == False:
         success = False

if success == True:
    print "OK: All backups done within " + str(delta) + " hours"
    sys.exit(0)
else:
    sys.exit(2)
