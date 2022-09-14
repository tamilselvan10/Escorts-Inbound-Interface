#### Escorts-Inbound-Interface


**Installation Steps**

**1. Create tables**
   
   @xxes_in_process_conn_log_tb.sql
   
   @xxes_in_process_file_log_tb.sql

**2. Create Directories**

@Inbound Directories.sql

**3. Lookups**

**Source:** Escorts - TEST

**Target:** Escorts - PROD

**Download:**

FNDLOAD apps/<PWD> 0 Y DOWNLOAD $FND_TOP/patch/115/import/aflvmlu.lct XXES_SFTP_INBOUND_LKPS.ldt FND_LOOKUP_TYPE APPLICATION_SHORT_NAME="XXES" LOOKUP_TYPE="XXES_SFTP_INBOUND_LKPS"

**Upload:**

FNDLOAD apps/<PWD> O Y UPLOAD $FND_TOP/patch/115/import/aflvmlu.lct XXES_SFTP_INBOUND_LKPS.ldt UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
  
  
**4. Concurrent Programs**
  
**Concurrent Program Name:** Escorts SFTP - Escorts ERP Inbound Process Program
**Concurrent Program Short Name:** XXES_INBOUND_PROCESS

**Download:**

FNDLOAD apps/<pwd> O Y DOWNLOAD $FND_TOP/patch/115/import/afcpprog.lct XXES_INBOUND_PROCESS.ldt PROGRAM APPLICATION_SHORT_NAME="XXES" CONCURRENT_PROGRAM_NAME="XXES_INBOUND_PROCESS"

**Upload:**

FNDLOAD apps/<pwd> 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct XXES_INBOUND_PROCESS.ldt - WARNING=YES UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE
  
**5. Create Packages**
  
  @xxes_inbound_int_pkg.pks
  
  @xxes_inbound_int_pkg.pkb
  
**6. Assign Concurrent Program to the required Responsibility**
   
   **Concurrent Program Name:** Escorts SFTP - Escorts ERP Inbound Process Program
   
   
   Note: Check the lookup values XXES_SFTP_INBOUND_LKPS
  
