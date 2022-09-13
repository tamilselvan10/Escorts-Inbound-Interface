CREATE OR REPLACE PACKAGE xxes_inbound_int_pkg
AS

--##################################################################################
--# Filename:xxes_inbound_int_pkg.pks
--# Description:Escorts Inbound Interface
--#   Date       | Name                                      | Remarks
--# -------------------------------------------------------------------------------
--#  12-SEP-2022 | Escorts SFTP - Escorts ERP Integration    | Initial Release
--# -------------------------------------------------------------------------------
--# REF ID:
--##################################################################################

---Procedure to execute the process flow
PROCEDURE xxes_exec_in_flow_proc(errbuf OUT varchar2,retcode OUT varchar2);

END xxes_inbound_int_pkg;