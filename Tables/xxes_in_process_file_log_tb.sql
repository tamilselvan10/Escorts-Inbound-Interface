Create table xxes_in_process_file_log_tb
(
id                      NUMBER,
interface_name          VARCHAR2(4000),
source                  VARCHAR2(4000),
destination             VARCHAR2(4000),
file_name               VARCHAR2(4000),
transfer_date           DATE,
transfer_status          VARCHAR2(200)
);

GRANT ALL ON xxes_in_process_file_log_tb TO APPS;
CREATE OR REPLACE SYNONYM xxes_in_process_file_log_tb FOR xxes.xxes_in_process_file_log_tb;

/