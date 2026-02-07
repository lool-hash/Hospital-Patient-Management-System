SELECT
 (SELECT COUNT(*) FROM dba_users
  WHERE username IN ('MANAGERUSER','USER1','USER2')) AS users_created,

 (SELECT COUNT(*) FROM dba_tablespaces
  WHERE tablespace_name='HOSPITAL_TBS') AS tbs_created
FROM dual;
