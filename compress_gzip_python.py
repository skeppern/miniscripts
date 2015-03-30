from __future__ import print_function
from datetime import date, datetime, timedelta
import mysql.connector
import zlib
import gzip
from StringIO import StringIO

cnx = mysql.connector.connect(user='root', database='r2d2_prod', password='b0mb3r&GRANATER', charset='utf8', autocommit=True)
cursor = cnx.cursor(dictionary=True, buffered=True)
insertor = cnx.cursor(dictionary=True)
cursor.execute("SELECT id, body FROM sent_email WHERE is_compressed='0' LIMIT 20000")
update_query = "UPDATE sent_email SET compressed_body=%s, is_compressed=1 WHERE id=%s"
row = cursor.fetchone()
while row is not None:
        strio = StringIO()
        strio.write(gzip.zlib.compress(row['body'], 9))
        parameters = (strio.getvalue().strip(), row['id'])
        insertor.execute(update_query, parameters)
        #print(update_query % parameters)
        #cursor.execute(update_query, parameters)
        print("Compressed id: {0}".format(row['id']))
        #print(compressed_body)
        cnx.commit()
        row = cursor.fetchone()
cursor.close()
cnx.close()
