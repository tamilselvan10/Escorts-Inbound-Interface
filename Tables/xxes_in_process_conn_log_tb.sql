Create table xxes_in_process_conn_log_tb
(
id                NUMBER,
Interface_name    VARCHAR2(4000),
source            VARCHAR2(4000),
destination       VARCHAR2(4000),
connection_status VARCHAR2(4000),
error_message     VARCHAR2(4000),
connection_check_date DATE
);

GRANT ALL ON xxes_in_process_conn_log_tb TO APPS;
CREATE OR REPLACE SYNONYM xxes_in_process_conn_log_tb FOR xxes.xxes_in_process_conn_log_tb;

/