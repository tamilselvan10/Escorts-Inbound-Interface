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