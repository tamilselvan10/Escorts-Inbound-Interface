CREATE OR REPLACE PACKAGE BODY xxes_inbound_int_pkg

AS

--##################################################################################
--# Filename:xxes_inbound_int_pkg.pkb
--# Description:Escorts Inbound Interface
--#   Date       | Name                                      | Remarks
--# -------------------------------------------------------------------------------
--#  12-SEP-2022 | Escorts SFTP - Escorts ERP Integration    | Initial Release
--# -------------------------------------------------------------------------------
--# REF ID:
--##################################################################################

  -- Procedure to write messages in View Log.
    PROCEDURE write_log(p_text IN VARCHAR2)
    IS
    BEGIN
      apps.fnd_file.put_line(fnd_file.LOG, p_text);
      dbms_output.put_line(p_text);
    END write_log;
    
    

   -- Check FTP Connection:
PROCEDURE check_ftp_conn_proc(p_id IN NUMBER,p_status OUT VARCHAR2)
AS
  connection_id    NUMBER;
  lv_error_code    VARCHAR2(4000):=NULL;
  lv_error_message VARCHAR2(4000):=NULL;


BEGIN

  BEGIN
  as_sftp.open_connection( i_host =>apps.fnd_profile.value('ESCORTS_SFTP_IP_ADDRESS'), i_trust_server => true );
  as_sftp.login( i_user => apps.fnd_profile.value('ESCORTS_SFTP_USER_NAME'), i_password => apps.fnd_profile.value('ESCORTS_SFTP_PASSWORD'));
  connection_id :=1;
  as_sftp.close_connection;
  EXCEPTION WHEN OTHERS THEN
  connection_id :=0;
  lv_error_code:=SQLCODE;
  lv_error_message:=SUBSTR(SQLERRM,4000);
  END;
  
 IF connection_id =1 THEN
  
  p_status:=1;
--------------------------------------------------------------------------------------------------------------
  INSERT INTO xxes_in_process_conn_log_tb
  (
  id                    ,
  Interface_name        ,
  source                ,
  destination           ,
  connection_status     ,
  error_message         ,
  connection_check_date 
  )
  VALUES
  (
   p_id,
  'Escorts SFTP - Escorts ERP Inbound Process',
  'Escorts SFTP',
  'Escorts ERP',
  'CONNECTED',
   lv_error_code||'-'||lv_error_message,
   SYSDATE
   );
   COMMIT;
--------------------------------------------------------------------------------------------------------------
ELSE
   
  p_status:=0;
    
  INSERT INTO xxes_in_process_conn_log_tb
  (
  id                    ,
  Interface_name        ,
  source                ,
  destination           ,
  connection_status     ,
  error_message         ,
  connection_check_date 
  )
  VALUES
  (
   p_id,
  'Escorts SFTP - Escorts ERP Inbound Process',
  'Escorts SFTP',
  'Escorts ERP',
  'NOT CONNECTED',
   lv_error_code||'-'||lv_error_message,
   SYSDATE
   );
   COMMIT;
--------------------------------------------------------------------------------------------------------------
  
END IF;  

EXCEPTION WHEN OTHERS THEN
write_log('Error Occured while checking the SFTP Connection');
write_log('Error Code   :'||SQLCODE);
write_log('Error Message:'||SQLERRM);
p_status:=0;
lv_error_code:=SQLCODE;
lv_error_message:=SUBSTR(SQLERRM,1,4000);

--------------------------------------------------------------------------------------------------------------
  INSERT INTO xxes_in_process_conn_log_tb
  (
  id                    ,
  Interface_name        ,
  source                ,
  destination           ,
  connection_status     ,
  error_message         ,
  connection_check_date 
  )
  VALUES
  (
   p_id,
  'Escorts SFTP - Escorts ERP Inbound Process',
  'Escorts SFTP',
  'Escorts ERP',
  'NOT CONNECTED',
   lv_error_code||'-'||lv_error_message,
   SYSDATE
   );
  COMMIT;
--------------------------------------------------------------------------------------------------------------
  
END check_ftp_conn_proc;



--- Get Inbound details from lookup:
FUNCTION   get_inbound_dtls_func(p_code IN apps.fnd_lookup_values.lookup_code%TYPE)
RETURN apps.fnd_lookup_values.description%TYPE 
IS

CURSOR cur_out_bound_dtls
IS
SELECT UNIQUE description
FROM apps.fnd_lookup_values
WHERE 1=1
AND lookup_type='XXES_SFTP_INBOUND_LKPS'
AND lookup_code=p_code;

lv_value apps.fnd_lookup_values.description%TYPE :=NULL;

BEGIN

---
OPEN cur_out_bound_dtls;
FETCH cur_out_bound_dtls INTO lv_value;
CLOSE cur_out_bound_dtls;

RETURN lv_value;
---

EXCEPTION WHEN OTHERS THEN
write_log('Error Occured while retrieving the Inbound Details from the lookup XXES_SFTP_INBOUND_LKPS for the lookup code:'||p_code);
write_log('Error Code   :'||SQLCODE);
write_log('Error Message:'||SQLERRM);
END get_inbound_dtls_func;


--- Function to check whether the path exists or not
FUNCTION path_exists_or_not
RETURN VARCHAR2
AS

connection_id       NUMBER;
lv_sftp_path        VARCHAR2(1000):=get_inbound_dtls_func('50');  
lv_status           VARCHAR2(1000):=NULL;
lv_path             VARCHAR2(4000):=NULL;

BEGIN

 as_sftp.open_connection(i_host =>apps.fnd_profile.value('ESCORTS_SFTP_IP_ADDRESS') );
 
 as_sftp.login( i_user => apps.fnd_profile.value('ESCORTS_SFTP_USER_NAME'), 
               i_password => apps.fnd_profile.value('ESCORTS_SFTP_PASSWORD')); 
 
 lv_path:=(as_sftp.pwd||'/'||lv_sftp_path);
 
 write_log('-------------------');
 write_log('Path:'||lv_path);
 write_log('-------------------');
 

 IF as_sftp.path_exists(i_path => lv_path) THEN
 lv_status:='SUCCESS';
 ELSE
 lv_status:='FAILURE';
 END IF;
 
 as_sftp.close_connection;
 
RETURN lv_status; 
 
EXCEPTION WHEN OTHERS THEN
write_log('Error Occured while checking whether the path ['||lv_path||'] exists or not in the Escorts SFTP Server');
write_log('Error Code   :'||SQLCODE);
write_log('Error Message:'||SQLERRM); 
END path_exists_or_not;


-- Procedure to get the filelist and move from Source directory to Backup Directory:
    PROCEDURE backup_file_proc(p_id IN NUMBER)
    AS    
      lv_file_path    VARCHAR2(2000):=NULL;
      lv_source_dir   VARCHAR2(1000):=get_inbound_dtls_func('10');
      lv_source_path  VARCHAR2(1000):=get_inbound_dtls_func('20');
      lv_backup_dir   VARCHAR2(1000):=get_inbound_dtls_func('30');
      lv_backup_path  VARCHAR2(1000):=get_inbound_dtls_func('40');
      
      
     CURSOR cur_file_list IS 
     SELECT * FROM xxes_in_process_file_log_tb WHERE 1=1 AND transfer_status='SUCCESS' AND id=p_id;

    BEGIN
    
        FOR i IN cur_file_list 
    LOOP
    
    utl_file.fcopy (
    src_location   =>lv_source_dir,
    src_filename   =>i.file_name,
    dest_location  =>lv_backup_dir,
    dest_filename  =>i.file_name);
   
   COMMIT;
   
   END LOOP;
   
   
    EXCEPTION WHEN OTHERS THEN
    write_log('Error occured while copy the files from Source Location ['||lv_source_dir||'] to Destination Location ['||lv_backup_dir||']');
    write_log('Error code   :'||SQLCODE);
    write_log('Error message:'||SQLERRM);
    END backup_file_proc;
    
 --- remove files from SFTP:
PROCEDURE remove_files_proc(p_id IN NUMBER)
AS

lv_sftp_path  VARCHAR2(1000):=get_inbound_dtls_func('50');
v_result      BOOLEAN;

CURSOR cur_file_list IS 
SELECT * FROM xxes_in_process_file_log_tb WHERE 1=1 AND transfer_status='SUCCESS' AND id=p_id;

BEGIN

    -- Login to SFTP:
 as_sftp.open_connection( i_host =>apps.fnd_profile.value('ESCORTS_SFTP_IP_ADDRESS'), i_trust_server => true );
 as_sftp.login( i_user => apps.fnd_profile.value('ESCORTS_SFTP_USER_NAME'), i_password => apps.fnd_profile.value('ESCORTS_SFTP_PASSWORD'));
 
FOR i IN cur_file_list 
LOOP
     
     v_result:=as_sftp.remove_file(lv_sftp_path||'/'||i.file_name);
     
  IF v_result THEN
    write_log('File removed');
  ELSE
    write_log('File Not removed');
  END IF;

END LOOP;

as_sftp.close_connection;

EXCEPTION WHEN OTHERS THEN
    write_log('Error occured while removing the files from the SFTP');
    write_log('Error code   :'||SQLCODE);
    write_log('Error message:'||SQLERRM);
END remove_files_proc;    

--- File Process:
PROCEDURE get_files_proc (p_id IN NUMBER)
AS

  l_dir_listing    as_sftp.tp_dir_listing;
  lv_sftp_path     VARCHAR2(1000):=get_inbound_dtls_func('50');
  lv_file          blob;  
  lv_source_dir    VARCHAR2(1000):=get_inbound_dtls_func('10');
  lv_backup_dir    VARCHAR2(1000):=get_inbound_dtls_func('30');
  
  l_blob_len       INTEGER;
  l_file           UTL_FILE.FILE_TYPE;
  l_buffer         RAW(32767);
  l_amount         BINARY_INTEGER := 32767;
  l_pos            INTEGER := 1; 
  
  lv_file_exists   BOOLEAN;
  lv_length        NUMBER;
  lv_blocksize     NUMBER;
  
begin

/*  
    a) Login to SFTP
    b) Get File List
    c) Read only .txt files
    d) Get file BLOB
    e) Move file to Source Folder
    f) Check File exists in Source Folder or not
    g) Backup File Process
    h) remove files from the SFTP
*/

 -- a)Login to SFTP:
 as_sftp.open_connection( i_host =>apps.fnd_profile.value('ESCORTS_SFTP_IP_ADDRESS'), i_trust_server => true );
 as_sftp.login( i_user => apps.fnd_profile.value('ESCORTS_SFTP_USER_NAME'), i_password => apps.fnd_profile.value('ESCORTS_SFTP_PASSWORD'));
 
 -- b)Get Files list:
 l_dir_listing := as_sftp.read_dir( i_path => lv_sftp_path||'/');
 
   FOR i IN 1 .. l_dir_listing.COUNT
   LOOP
   
    -- c)Read only .txt files
    IF l_dir_listing( i ).file_name LIKE '%.txt' THEN
    
    write_log( l_dir_listing( i ).file_name );
    
    -- d)Get file BLOB:
    as_sftp.get_file( i_path => lv_sftp_path||'/'||l_dir_listing( i ).file_name, i_file => lv_file );  
        
    -- e)Move file to source folder:
    l_blob_len := dbms_lob.getlength(lv_file);
    l_file := utl_file.fopen(lv_source_dir,
                             l_dir_listing( i ).file_name,
                             'wb', 
                             32767);

   WHILE l_pos <= l_blob_len LOOP
    dbms_lob.read(lv_file, l_amount, l_pos, l_buffer);
    utl_file.put_raw(l_file, l_buffer, TRUE);
    l_pos := l_pos + l_amount;
   END LOOP;  
  utl_file.fclose(l_file);
  
  write_log('Move file to Source Folder -'||l_dir_listing( i ).file_name);
  
  -- f)Check File exists in Source Folder or not
    utl_file.fgetattr(lv_source_dir,
                      l_dir_listing(i).file_name,
                      lv_file_exists,
                      lv_length,
                      lv_blocksize);
                      
    IF lv_file_exists THEN
    
    write_log('Transferred -'||l_dir_listing( i ).file_name);
    
    INSERT INTO xxes_in_process_file_log_tb
    (
    id              ,
    interface_name  ,
    source          ,
    destination     ,
    file_name       ,
    transfer_date   ,
    transfer_status           
    )
    VALUES
    (
    p_id,
   'Escorts SFTP - Escorts ERP Outbound Process',
   'Escorts SFTP',
   'Escorts ERP',
   l_dir_listing( i ).file_name,
   SYSDATE,
   'SUCCESS'
   );
   COMMIT;
  
    ELSE
    
    write_log('Not Transferred -'||l_dir_listing( i ).file_name);
    
    INSERT INTO xxes_in_process_file_log_tb
    (
    id              ,
    interface_name  ,
    source          ,
    destination     ,
    file_name       ,
    transfer_date   ,
    transfer_status           
    )
    VALUES
   (
    p_id,
   'Escorts SFTP - Escorts ERP Outbound Process',
   'Escorts SFTP',
   'Escorts ERP',
   l_dir_listing( i ).file_name,
   SYSDATE,
   'FAILURE'
   );
   COMMIT;

    END IF;    
    END IF;
   END LOOP;    
   
   as_sftp.close_connection;
   
   dbms_lob.freetemporary( lv_file );
   
   --- g)Backup File Process:
   BEGIN
   backup_file_proc(p_id=>p_id);
   END;
   
   --- h)Remove Files from the SFTP:
   BEGIN
   remove_files_proc(p_id=>p_id);
   END;

EXCEPTION WHEN OTHERS THEN
    write_log('Error occured while get the files from the SFTP');
    write_log('Error code   :'||SQLCODE);
    write_log('Error message:'||SQLERRM);
END get_files_proc;    

---Procedure to sent Escorts Inbound Process Status Mail
PROCEDURE  xxes_in_email(p_id IN NUMBER)
AS

mail_conn         UTL_SMTP.CONNECTION;
crlf              VARCHAR2 (5)   := CHR (13) || CHR (10);
lv_mail_host      VARCHAR2(64)   := apps.fnd_profile.VALUE ('XXES_MAIL_SERVER_IP_ADDRESS'); 
lv_mail_port      NUMBER         := NVL(apps.fnd_profile.VALUE ('XXES_MAIL_SERVER_IP_PORT'),25);
lv_sender         VARCHAR2(32000):= apps.fnd_profile.VALUE ('XXES_FROM_MAIL');
lv_recipients     VARCHAR2(32000):= apps.fnd_profile.VALUE('XXES_TO_MAIL');
lv_instance_name  VARCHAR2(240)  := NULL;

szBuffer          VARCHAR2(2000);
szQuit            UTL_SMTP.REPLY;
location          NUMBER := 0;
my_index          NUMBER := 1;
my_recipients     VARCHAR2(32000);
my_sender         VARCHAR2(32000);

lv_date           VARCHAR2(30):=NULL;
lv_t_status       VARCHAR2(1000):=NULL;

----------------------------------------------------------
v_msg              VARCHAR2(32000);
src_file           BFILE;
i                  INTEGER := 1;
v_raw              RAW(57);
v_length           INTEGER := 0;
v_buffer_size      INTEGER := 57;
lv_file_name       VARCHAR2(1000):=TO_CHAR(SYSDATE,'DD-MON-YYYY HH:MI:SS')||'-'||p_id||'.xlsx';

BOUNDARY CONSTANT VARCHAR2(256) := '7D81B75CCC90D2974F7A1CBD';
FIRST_BOUNDARY CONSTANT VARCHAR2(256) := '--' || BOUNDARY ||UTL_TCP.CRLF;
LAST_BOUNDARY CONSTANT VARCHAR2(256) := '--' || BOUNDARY || '--' ||UTL_TCP.CRLF;
MULTIPART_MIME_TYPE CONSTANT VARCHAR2(256) := 'multipart/mixed; boundary="' ||BOUNDARY || '"';
------------------------------------------------------------------


BEGIN



---
BEGIN
select TO_CHAR(connection_check_date,'DD-MON-YYYY HH:MI:SS AM') INTO lv_date from apps.xxes_in_process_conn_log_tb where 1=1 and id=p_id;
EXCEPTION WHEN OTHERS THEN
lv_date:=NULL;
END;
---


mail_conn := utl_smtp.open_connection(lv_mail_host , lv_mail_port);
utl_smtp.helo(mail_conn,lv_mail_host);


/***************SENDER******************************/

-- clean up any trailing separation characters

my_sender := RTRIM(lv_sender,',; ');


-- determine multiple sender by looking
-- for separation characters

location := INSTR(my_sender,',',1,1);
IF location = 0 THEN
location := INSTR(my_sender,';',1,1);
END IF;

-- If more then one sender in string, parse out
-- the first sender and use this sender to
-- authenticate with the mail server when
-- calling UTL_SMTP.MAIL, all other senders
-- will be ignored

IF location <> 0 THEN
-- multiple senders, use the first one
UTL_SMTP.MAIL(mail_conn, SUBSTR(my_sender,1,location-1));
ELSE
-- only one sender
UTL_SMTP.MAIL(mail_conn, lv_sender);
END IF;


/*****************RECEIVER*******************************/

-- clean up any trailing separation characters
my_recipients := RTRIM(lv_recipients,',; ');
-- initialize loop variables
my_index := 1;

-- Parse out each recipient and make a call to
-- UTL_SMTP.RCPT to add it to the recipient list

WHILE my_index < LENGTH(my_recipients) LOOP

-- determine multiple recipients by looking for separation characters

location := INSTR(my_recipients,',',my_index,1);
IF location = 0 THEN
location := INSTR(my_recipients,';',my_index,1);
END IF;

IF location <> 0 THEN
-- multiple recipients, add this one to the recipients list
UTL_SMTP.RCPT(mail_conn, TRIM(SUBSTR(my_recipients,my_index,location-my_index)));
my_index := location + 1;
ELSE
-- single recipient or last one in list
UTL_SMTP.RCPT(mail_conn, TRIM(SUBSTR(my_recipients,my_index,LENGTH(my_recipients))));
my_index := LENGTH(my_recipients);
END IF;


END LOOP;

-- Replace separation character ";" with ","
my_recipients := REPLACE(my_recipients,';',',');

/*********************Subject and Body of the Email**************************************/

-- Setup the TO, SUBJECT and BODY sections of the email

UTL_SMTP.OPEN_DATA(mail_conn);
UTL_SMTP.WRITE_DATA(mail_conn, 'To: ' || my_recipients || utl_tcp.CRLF);
      UTL_SMTP.write_data
                         (mail_conn,
                             'Subject: '
                          || 'Escorts SFTP-Escorts ERP Inbound Process Mail Notification'
                          || UTL_TCP.crlf
                         );        
                   
utl_smtp.write_data(mail_conn, 'MIME-Version: 1.0' || utl_tcp.crlf);
utl_smtp.write_data(mail_conn,'Content-Type: multipart/mixed; boundary="' ||boundary || '"' || utl_tcp.crlf);
utl_smtp.write_data(mail_conn, utl_tcp.crlf);

utl_smtp.write_data(mail_conn, first_boundary);
utl_smtp.write_data(mail_conn,'Content-Type: text/html;' || utl_tcp.crlf);
utl_smtp.write_data(mail_conn, 'charset=US-ASCII' || utl_tcp.crlf);
utl_smtp.write_data(mail_conn, utl_tcp.crlf);


      UTL_SMTP.write_data (mail_conn, UTL_TCP.crlf || '<HTML>' || crlf);
      UTL_SMTP.write_data (mail_conn, UTL_TCP.crlf || '<BODY>' || crlf);
      
      UTL_SMTP.write_data (mail_conn,
                              UTL_TCP.crlf
                           || '<font size="2"><font color=''#0000FF''> '
                           || '<p>Dear'
                           || '</font></font>'
                           || ' '
                           || '<font size="2"><font color=''#0000FF''> '
                           || 'Team'
                           || '</font></font>'
                           || ','
                           || '</br>'
                           || '</br>'
                           || crlf
                          );
      UTL_SMTP.write_data (mail_conn,
                              UTL_TCP.crlf
                           || '<font size="2"><font color=''#0000FF''> '
                           || 'For Your Kind Attention:'
                           || '</font></font>'
                           || '</br>'
                           || '</br>'
                           || crlf
                          );
      UTL_SMTP.write_data
                 (mail_conn,
                     UTL_TCP.crlf
                  || '<font size="2"><font color=''#0000FF''> '
                  || 'SFTP File Transfer Process Started today at '
                  || lv_date
                  || '</font></font>'
                  || '</br>'
                  || '</br>'
                  || crlf
                 );
                 
                 
    UTL_SMTP.write_data (mail_conn,
                              UTL_TCP.crlf
                           || '<font size="2"><font color=''#000000''> '
                           || 'Transaction ID:'
                           || '<U>'
                           || p_id
                           ||'</U>'
                           || '</font></font>'
                           || '</br>'
                           || '</br>'
                           || crlf
                          );

                          
      UTL_SMTP.write_data (mail_conn,
                              UTL_TCP.crlf
                           || '<font size="2"><font color=''#000000''> '
                           || 'Escorts ERP server File Path:'
                           || '<U>'
                           || get_inbound_dtls_func('20')
                           ||'</U>'
                           || '</font></font>'
                           || '</br>'
                           || '</br>'
                           || crlf
                          );
     UTL_SMTP.write_data (mail_conn,
                              UTL_TCP.crlf
                           || '<font size="2"><font color=''#000000''> '
                           || 'Escorts SFTP server File Path:'
                           || '<U>'
                           ||get_inbound_dtls_func('50')
                           ||'</U>'
                           || '</font></font>'
                           || '</br>'
                           || '</br>'
                           || crlf
                          );


---Extraction Log:

       UTL_SMTP.write_data (mail_conn,
                              UTL_TCP.crlf
                           || '</br>'
                           || '<font size="3"><font color=''#000000''> '
                           ||'<B><U>Data Extraction Log Details:</U></B>'
                           || '</font></font>'
                           || '</br>'
                           ||'<html>'
                           ||'<head>'
                           || '<TABLE cellSpacing = 0 cellPadding=0 border =1  width="100%">'
                           || '<TR>'
                           || '<TD  BGCOLOR=''#FFFF00''><font color=''#000000''><font size="2"><B><center>Interface Type</center></B></font></font></TD>'
                           || '<TD  BGCOLOR=''#FFFF00''><font color=''#000000''><font size="2"><B><center>Process Name</center></B></font></font></TD>'
                           || '<TD  BGCOLOR=''#FFFF00''><font color=''#000000''><font size="2"><B><center>No.of.records</center></B></font></font></TD>'
                           || '<TD  BGCOLOR=''#FFFF00''><font color=''#000000''><font size="2"><B><center>Status</center></B></font></font></TD>'                         
                           || '<TD  BGCOLOR=''#FFFF00''><font color=''#000000''><font size="2"><B><center>Date</center></B></font></font></TD>'
                           || '</TR>'|| crlf);
    
        for i in (select * from xxes.xxes_syncron_di_control where 1=1 and transaction_id=p_id)    
    loop    
    
    lv_t_status:=NULL;
    SELECT DECODE(i.extracted_flag,'Y','SUCCESS','ERROR') INTO lv_t_status FROM DUAL;
      UTL_SMTP.write_data (mail_conn,
                              UTL_TCP.crlf                           
                           || '<TR>'
                           || '<TD><font size="1.75">'
                           || '<center>'||i.inbound_outbound||'</center>'
                           || '</font></font></TD>'
                           || '<TD><font size="1.75">'
                           ||'<center>'||i.process_name||'</center>'
                           || '</font></font></TD>'
                           || '<TD><font size="1.75">'
                           ||'<center>'||i.no_of_records||'</center>'
                           || '</font></font></TD>'
                           || '<TD><font size="1.75">'
                           ||'<center>'||lv_t_status||'</center>'
                           || '</font></font></TD>'
                           || '<TD><font size="1.75">'
                           ||'<center>'||TO_CHAR(i.extracted_date,'DD-MON-YYYY HH:MI:SS AM')||'</center>'
                           || '</font></font></TD>'
                           || '</TR>'||crlf);
    end loop;
    
                           
                     UTL_SMTP.write_data (mail_conn,
                              UTL_TCP.crlf    
                              ||'</table>'
                           ||'</body>'
                           ||'</html>'|| crlf);

---File Generation Log:
       UTL_SMTP.write_data (mail_conn,
                              UTL_TCP.crlf
                           || '</br>'
                           || '<font size="3"><font color=''#000000''> '
                           ||'<B><U>File Generation Log Details:</U></B>'
                           || '</font></font>'
                           || '</br>'
                           ||'<html>'
                           ||'<head>'
                           || '<TABLE cellSpacing = 0 cellPadding=0 border =1  width="100%">'
                           || '<TR>'                         
                           || '<TD  BGCOLOR=''#FFFF00''><font color=''#000000''><font size="2"><B><center>Process Name</center></B></font></font></TD>'
                           || '<TD  BGCOLOR=''#FFFF00''><font color=''#000000''><font size="2"><B><center>File Name</center></B></font></font></TD>'
                           || '<TD  BGCOLOR=''#FFFF00''><font color=''#000000''><font size="2"><B><center>Status</center></B></font></font></TD>'                        
                           || '<TD  BGCOLOR=''#FFFF00''><font color=''#000000''><font size="2"><B><center>Date</center></B></font></font></TD>'
                           || '</TR>'|| crlf);
    
        for i in (select * from xxes.xxes_syncron_di_control where 1=1 and transaction_id=p_id)    
    loop    
    
        lv_t_status:=NULL;
        SELECT DECODE(i.utl_file_rw_flag,'Y','SUCCESS','ERROR') INTO lv_t_status FROM DUAL;
        
      UTL_SMTP.write_data (mail_conn,
                              UTL_TCP.crlf                           
                           || '<TR>'
                           || '<TD><font size="1.75">'
                           ||'<left>'||i.process_name||'</left>'
                           || '</font></font></TD>'
                           || '<TD><font size="1.75">'
                           ||'<left>'||i.file_name||'</left>'
                           || '</font></font></TD>'
                           || '<TD><font size="1.75">'
                           ||'<center>'||lv_t_status||'</center>'
                           || '</font></font></TD>'
                           || '<TD><font size="1.75">'
                           ||'<center>'||TO_CHAR(i.utl_file_rw_date,'DD-MON-YYYY HH:MI:SS AM')||'</center>'
                           || '</font></font></TD>'
                           || '</TR>'||crlf);
    end loop;
    
                           
                     UTL_SMTP.write_data (mail_conn,
                              UTL_TCP.crlf    
                              ||'</table>'
                           ||'</body>'
                           ||'</html>'|| crlf);


    --- Connection Log:
        UTL_SMTP.write_data (mail_conn,
                              UTL_TCP.crlf
                           || '</br>'
                           || '<font size="3"><font color=''#000000''> '
                           ||'<B><U>Connection Log Details:</U></B>'
                           || '</font></font>'
                           || '</br>'
                           ||'<html>'
                           ||'<head>'
                           || '<TABLE cellSpacing = 0 cellPadding=0 border =1  width="100%">'
                           || '<TR>'
                           || '<TD  BGCOLOR=''#FFFF00''><font color=''#000000''><font size="2"><B><center>Interface Name</center></B></font></font></TD>'
                           || '<TD  BGCOLOR=''#FFFF00''><font color=''#000000''><font size="2"><B><center>Source</center></B></font></font></TD>'
                           || '<TD  BGCOLOR=''#FFFF00''><font color=''#000000''><font size="2"><B><center>Destination</center></B></font></font></TD>'
                           || '<TD  BGCOLOR=''#FFFF00''><font color=''#000000''><font size="2"><B><center>Status</center></B></font></font></TD>'
                           || '<TD  BGCOLOR=''#FFFF00''><font color=''#000000''><font size="2"><B><center>Reason</center></B></font></font></TD>'
                           || '<TD  BGCOLOR=''#FFFF00''><font color=''#000000''><font size="2"><B><center>Date</center></B></font></font></TD>'
                           || '</TR>'|| crlf);
    
        for i in (select * from apps.xxes_in_process_conn_log_tb where 1=1 and id=p_id)    
    loop    
      UTL_SMTP.write_data (mail_conn,
                              UTL_TCP.crlf                           
                           || '<TR>'
                           || '<TD><font size="1.75">'
                           || '<center>'||i.interface_name||'</center>'
                           || '</font></font></TD>'
                           || '<TD><font size="1.75">'
                           ||'<center>'||i.source||'</center>'
                           || '</font></font></TD>'
                           || '<TD><font size="1.75">'
                           ||'<center>'||i.destination||'</center>'
                           || '</font></font></TD>'
                           || '<TD><font size="1.75">'
                           ||'<center>'||i.connection_status||'</center>'
                           || '</font></font></TD>'
                           || '<TD><font size="1.75">'
                           ||'<center>'||i.error_message||'</center>'
                           || '</font></font></TD>'
                           || '<TD><font size="1.75">'
                           ||'<center>'||TO_CHAR(i.connection_check_date,'DD-MON-YYYY HH:MI:SS AM')||'</center>'
                           || '</font></font></TD>'
                           || '</TR>'||crlf);
    end loop;
    
                           
                     UTL_SMTP.write_data (mail_conn,
                              UTL_TCP.crlf    
                              ||'</table>'
                           ||'</body>'
                           ||'</html>'|| crlf);
    
    --- File Log:
    
    UTL_SMTP.write_data (mail_conn,
                              UTL_TCP.crlf
                           || '</br>'
                           || '<font size="3"><font color=''#000000''> '
                           ||'<B><U>File Transfer Log Details:</U></B>'
                           || '</font></font>'
                           || '</br>'
                           ||'<html>'
                           ||'<head>'
                           || '<TABLE cellSpacing = 0 cellPadding=0 border =1  width="100%">'
                           || '<TR>'
                           || '<TD  BGCOLOR=''#FFFF00''><font color=''#000000''><font size="2"><B><center>File Name</center></B></font></font></TD>'
                           || '<TD  BGCOLOR=''#FFFF00''><font color=''#000000''><font size="2"><B><center>Source</center></B></font></font></TD>'
                           || '<TD  BGCOLOR=''#FFFF00''><font color=''#000000''><font size="2"><B><center>Destination</center></B></font></font></TD>'
                           || '<TD  BGCOLOR=''#FFFF00''><font color=''#000000''><font size="2"><B><center>Status</center></B></font></font></TD>'
                           || '<TD  BGCOLOR=''#FFFF00''><font color=''#000000''><font size="2"><B><center>Transfer Date</center></B></font></font></TD>'
                           || '</TR>'|| crlf);

    for i in (select * from apps.xxes_in_process_file_log_tb where 1=1 and id=p_id)    
    loop    
      UTL_SMTP.write_data (mail_conn,
                              UTL_TCP.crlf                           
                           || '<TR>'
                           || '<TD><font size="1.75">'
                           || '<left>'||i.file_name||'</left>'
                           || '</font></font></TD>'
                           || '<TD><font size="1.75">'
                           ||'<center>'||i.source||'</center>'
                           || '</font></font></TD>'
                           || '<TD><font size="1.75">'
                           ||'<center>'||i.destination||'</center>'
                           || '</font></font></TD>'
                           || '<TD><font size="1.75">'
                           ||'<center>'||i.transfer_status ||'</center>'
                           || '</font></font></TD>'
                           || '<TD><font size="1.75">'
                           ||'<center>'||TO_CHAR(i.transfer_date,'DD-MON-YYYY HH:MI:SS AM')||'</center>'
                           || '</font></font></TD>'
                           || '</TR>'||crlf);
    end loop;

                   UTL_SMTP.write_data (mail_conn,
                              UTL_TCP.crlf    
                              ||'</table>'
                           ||'</body>'
                           ||'</html>'|| crlf);

      UTL_SMTP.write_data (mail_conn,
                              UTL_TCP.crlf
                           || '<font size="2"><font color=''#0000FF''> '
                           || '</br>'
                           || '<p> Regards,'
                           || '</font></font>'
                           || '</br>'
                           || '<font size="2"><font color=''#0000FF''> '
                           || 'Team'
                           || '</font></font>'
                           || '</br>'
                           || '</br>'
                           || crlf
                          );
      UTL_SMTP.write_data (mail_conn,
                              UTL_TCP.crlf
                           || '</br>'
                           || '<font size="2"><font color=''#0000FF''> '
                           || '<p>* This is a system generated email.</p>'
                           || '</font></font>'
                           || crlf
                          );
      UTL_SMTP.write_data (mail_conn, UTL_TCP.crlf || '</BODY>' || crlf);
      UTL_SMTP.write_data (mail_conn, UTL_TCP.crlf || '</HTML>' || crlf);
/*********************************************************************************************************/
      
      
----------------------------------------------------------------------------------------------------
UTL_SMTP.write_data(mail_conn, first_boundary);
UTL_SMTP.write_data(mail_conn,'Content-Type' || ': ' || 'application/pdf' ||UTL_TCP.CRLF);
UTL_SMTP.write_data(mail_conn,'Content-Disposition: attachment; ' ||UTL_TCP.CRLF);
UTL_SMTP.write_data(mail_conn,' filename="' || lv_file_name || '"' ||UTL_TCP.CRLF);
UTL_SMTP.write_data(mail_conn,'Content-Transfer-Encoding: base64' ||UTL_TCP.CRLF);
UTL_SMTP.write_data(mail_conn, UTL_TCP.CRLF);

---Comments:Create a Excel File
BEGIN
xxes_xlsx_builder_Pkg.clear_workbook;
xxes_xlsx_builder_pkg.new_sheet ('Exception Details');
xxes_xlsx_builder_pkg.query2sheet (p_sql => 'select interface_type,error_type,error_code,error_data,error_explanation from xxes.xxes_syncron_data_exception order by 1,2,3', p_sheet => 1);
xxes_xlsx_builder_pkg.save (get_inbound_dtls_func('10'), lv_file_name);
END;
----------------------------------------------------------------------------------------------------
SRC_FILE := BFILENAME(get_inbound_dtls_func('10'), lv_file_name);
DBMS_LOB.FILEOPEN(src_file, dbms_lob.file_readonly);
V_LENGTH := dbms_lob.getlength(src_file);

WHILE I < V_LENGTH LOOP
dbms_lob.read(src_file, v_buffer_size, i, v_raw);
utl_smtp.write_raw_data(mail_conn,utl_encode.base64_encode(v_raw));
i := i + v_buffer_size;
END LOOP;
----------------------------------------------------------------------------------------------------
UTL_SMTP.write_data(mail_conn, UTL_TCP.CRLF);
UTL_SMTP.write_data(mail_conn, LAST_BOUNDARY);
UTL_SMTP.write_data(mail_conn, UTL_TCP.CRLF);
DBMS_LOB.fileclose(src_file);
----------------------------------------------------------------------------------------------------

/*****************************************************************************************************************************************/

UTL_SMTP.close_data (mail_conn);
BEGIN
utl_file.fremove (get_inbound_dtls_func('10'), lv_file_name);
END;
szQuit := UTL_SMTP.QUIT(mail_conn);

/*----------------------------------------------------------------------------------------------------------------------------------------------*/
-- Status Reporting/Error Handling

IF szQuit.code = 221 THEN

write_log('Your Mail Successfully sent');

ELSE

write_log('Your e-mail was NOT sent.');
write_log('Reply Code : ' || szQuit.code);
write_log('Message    : ' || szQuit.text);

END IF;

/*----------------------------------------------------------------------------------------------------------------------------------------------*/

EXCEPTION
WHEN OTHERS THEN

   szBuffer := sqlerrm;
   write_log('(EXCEPTION PART) Error Occured While Sending the Inbound Process mail.');
   write_log('Error Code   :' || SQLCODE);
   write_log('Error Message:' || szBuffer);
END  xxes_in_email;
 
---Procedure to execute the Inbound process flow
PROCEDURE xxes_exec_in_flow_proc(errbuf OUT varchar2,retcode OUT varchar2)
AS

lv_errbuf       VARCHAR2(1000):=NULL;
lv_retcode      VARCHAR2(1000):=NULL; 
lv_status       VARCHAR2(1)   :=NULL;
lv_id           NUMBER;
lv_path_status  VARCHAR2(240):=NULL;

BEGIN

write_log('ESCORTS ERP Inbound Process flow from ESCORTS SFTP To ESCORTS ERP has been Started');
write_log('Start Time:'||TO_CHAR(SYSDATE,'DD-MON-YYYY HH12:MI:SS AM'));
write_log('******************************************************************************');

/*********************************************************************************************/

SELECT xxes.xxes_syncron_inbound_trans_s.NEXTVAL INTO lv_id FROM DUAL;

    --- Comments: Check the SFTP Connection
    --- 1-connected
    --- 0-not connected
     BEGIN
     check_ftp_conn_proc(p_id=>lv_id,p_status=>lv_status);
     END;
     
    IF lv_status='1' THEN
     
     write_log('SFTP Connection status: CONNECTED');
     
    --- Path Exists:
    BEGIN
    lv_path_status:=path_exists_or_not;
    END;
    
    IF lv_path_status='SUCCESS' THEN
    
    BEGIN
    get_files_proc(p_id=>lv_id);
    END;
    
    ELSE 
     write_log('SFTP Path not exists');     
    END IF;
    
    ELSE
     write_log('SFTP Connection status: NOT CONNECTED');
     write_log('Please check the Escorts SFTP Connection from Escorts ERP Server');
    END IF; 


  --- Email:
  BEGIN
  xxes_in_email(p_id=>lv_id);
  END;

write_log('******************************************************************************');
write_log('End Time:'||TO_CHAR(SYSDATE,'DD-MON-YYYY HH12:MI:SS AM'));   
write_log('ESCORTS ERP Inbound Process flow from ESCORTS SFTP To ESCORTS ERP has been Completed');

   
EXCEPTION WHEN OTHERS THEN
        write_log('Error occured while executing the inbound Process Flow.');
        write_log('Error Code    :'||SQLCODE);
        write_log('Error Message :'||SQLERRM);  
END xxes_exec_in_flow_proc;
    
    
END xxes_inbound_int_pkg;

/