CREATE OR REPLACE TRIGGER trg_log_user_creation
AFTER CREATE ON DATABASE
DECLARE
  v_sql ORA_NAME_LIST_T;
  v_cnt NUMBER;
  v_stmt VARCHAR2(4000);
BEGIN
  v_cnt := ORA_SQL_TXT(v_sql);

  FOR i IN 1..v_cnt LOOP
    v_stmt := v_stmt || v_sql(i);
  END LOOP;

  IF UPPER(v_stmt) LIKE '%CREATE USER%' THEN
    INSERT INTO User1.AuditTrail
    VALUES (
      User1.seq_audit.NEXTVAL,
      'DATABASE',
      'USER_CREATED',
      NULL,
      SUBSTR(v_stmt,1,3900),
      SYSDATE,
      USER
    );
  END IF;
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
