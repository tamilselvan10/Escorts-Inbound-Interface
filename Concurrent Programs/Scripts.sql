
Concurrent Program Name: Escorts SFTP - Escorts ERP Inbound Process Program(XXES_INBOUND_PROCESS)

Download:

FNDLOAD apps/<pwd> O Y DOWNLOAD $FND_TOP/patch/115/import/afcpprog.lct XXES_INBOUND_PROCESS.ldt PROGRAM APPLICATION_SHORT_NAME="XXES" CONCURRENT_PROGRAM_NAME="XXES_INBOUND_PROCESS"

Upload:

FNDLOAD apps/<pwd> 0 Y UPLOAD $FND_TOP/patch/115/import/afcpprog.lct XXES_INBOUND_PROCESS.ldt - WARNING=YES UPLOAD_MODE=REPLACE CUSTOM_MODE=FORCE