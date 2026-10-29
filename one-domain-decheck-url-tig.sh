

# ตรวจสอบว่า script นี้ถูกเรียกใช้พร้อมกับ argument หรือไม่
if [ "$#" -eq 0 ]
then
  echo "No arguments supplied"
  echo "Example : "
  echo " ./one-domain-decheck-url-XXX.sh 292,18-21-teens.com/"
  exit 1
fi

# กำหนดค่าไฟล์ชั่วคราวที่ใช้เก็บข้อมูล CSV และผลลัพธ์จากการใช้คำสั่ง curl
xCSV_TempFile="/tmp/one-domain-decheck-url-XXX.csv"
xTmp_curl_File="/tmp/one-domain-decheck-url-XXX.curl.$$"

# กำหนดวันที่ปัจจุบันในรูปแบบ YYYYMMDD
xDATE=`date '+%Y%m%d'`

# แยก ID และ URL ออกจาก argument ที่ส่งมา
xID=`echo $1 | cut -d',' -f1`
xURL=`echo $1 | cut -d',' -f2-99`

# แยก domain name ออกจาก URL
xDomain=`echo $xURL | cut -d'/' -f1`

# ทดสอบว่าชื่อ domain นี้สามารถแปลงเป็น punny code ได้หรือไม่
echo $xDomain | idn > /dev/null 2>&1
if [ $? -ne '0' ]
then
        # ถ้าไม่สามารถแปลงได้ แสดงว่าเป็นชื่อ domain ที่ไม่ถูกต้อง จึงบันทึกข้อมูลลงไฟล์ CSV พร้อมสถานะ ERR_NAME_NOT_RESOLVED
        echo "$xID,$xDATE,$xURL,ERR_NAME_NOT_RESOLVED," > $xCSV_TempFile

        # นำข้อมูลจากไฟล์ CSV นั้นไปบันทึกในฐานข้อมูล MySQL
        mysql -u root -p"P@ssword" --local-infile TIG_WEBSCREEN_BLOCKED_WEB -e "LOAD DATA LOCAL INFILE '$xCSV_TempFile'  INTO TABLE ti_url_test  FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n'" 2>&1 | grep -v  "^mysql: \[Warning\]"

else
        # ถ้าแปลงเป็น punny code ได้สำเร็จ ให้แปลงและบันทึกชื่อ domain ที่ถูกแปลง
        xDomain_IDN=`echo $xDomain | idn`

        # ทดสอบการ resolve domain ด้วย DNS เซิร์ฟเวอร์ 8.8.8.8
        host $xDomain_IDN 8.8.8.8 > /dev/null 2>&1  #TEST
        if [ $? -eq '0' ]
        then
                # หาก resolve ได้สำเร็จ ให้ดึง IP address แบบ IPv4 ของ domain นั้น
                for Input_IP4 in `host $xDomain_IDN 8.8.8.8 |  awk -F' has address ' '{print $2}'`
                do
                        # บันทึก ID, วันที่, URL และ IP address ลงไฟล์ CSV
                        echo -e -n "${xID}\t${xDATE}\t${xURL}\t$Input_IP4\t"  > $xCSV_TempFile

                        # ใช้ curl ทดสอบการเชื่อมต่อไปยัง URL นั้นด้วยการ resolve domain กับ IP ที่ได้มา
                        curl -v $xURL    --resolve $xDomain_IDN:80:$Input_IP4 2>$xTmp_curl_File
                        # เก็บผลลัพธ์จาก curl ที่ต้องการลงในไฟล์ CSV
                        egrep "* Connected to|<"  $xTmp_curl_File | egrep -v "Connection:|Content-type|^< $" >> $xCSV_TempFile

                        # นำข้อมูลจากไฟล์ CSV นั้นไปบันทึกในฐานข้อมูล MySQL
                        mysql -u root -p"P@ssword" --local-infile TIG_WEBSCREEN_BLOCKED_WEB -e "LOAD DATA LOCAL INFILE '$xCSV_TempFile'  INTO TABLE ti_url_test  FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\n%%\n' " 2>&1 | grep -v  "^mysql: \[Warning\]"

                done

                # ดึง IP address แบบ IPv6 ของ domain นั้น
                for Input_IP6 in `host $xDomain_IDN 8.8.8.8 |  awk -F' has IPv6 address ' '{print $2}'`
                do
                        # บันทึก ID, วันที่, URL และ IP address ลงไฟล์ CSV พร้อมระบุว่ายังไม่สามารถ block IPv6 ได้
                        echo "$xID,$xDATE,$xURL,$Input_IP6,can't block IPv6"  > $xCSV_TempFile

                        # นำข้อมูลจากไฟล์ CSV นั้นไปบันทึกในฐานข้อมูล MySQL
                       mysql -u root -p"P@ssword" --local-infile TIG_WEBSCREEN_BLOCKED_WEB -e "LOAD DATA LOCAL INFILE '$xCSV_TempFile'  INTO TABLE ti_url_test  FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n'" 2>&1 | grep -v  "^mysql: \[Warning\]"

                done

        else
                # หากไม่สามารถ resolve domain ได้ แสดงว่าเป็นชื่อ domain ที่ไม่ถูกต้อง จึงบันทึกข้อมูลลงไฟล์ CSV พร้อมสถานะ ERR_NAME_NOT_RESOLVED
                echo "$xID,$xDATE,$xURL,ERR_NAME_NOT_RESOLVED," > $xCSV_TempFile

                # นำข้อมูลจากไฟล์ CSV นั้นไปบันทึกในฐานข้อมูล MySQL
                mysql -u root -p"P@ssword" --local-infile TIG_WEBSCREEN_BLOCKED_WEB -e "LOAD DATA LOCAL INFILE '$xCSV_TempFile'  INTO TABLE ti_url_test  FIELDS TERMINATED BY ',' LINES TERMINATED BY '\n'" 2>&1 | grep -v  "^mysql: \[Warning\]"

        fi

fi

# ลบไฟล์ชั่วคราวที่สร้างขึ้น
rm -f $xTmp_curl_File  $xCSV_TempFile

